local cjson = require "cjson"
local pl_utils = require "pl.utils"

local kong = kong
local ngx = ngx

local circuit_breaker_lib = require "circuit-breaker-lib.factory"

local CircuitBreakerHandler = {}
CircuitBreakerHandler.PRIORITY = 930
CircuitBreakerHandler.VERSION = "1.0.0"

-- A table containing all circuit breakers for each API
local circuit_breakers = circuit_breaker_lib:new({})

local function get_api_identifier()
	return kong.request.get_method() .. "_" .. kong.request.get_path()
end

local function is_successful(upstream_status_code)
	return upstream_status_code and upstream_status_code < 500
end

-- Return circuit breaker instance for this API
local function get_circuit_breaker(conf, api_identifier)
	local cb_table_key = "global"
	if conf.route_id ~= nil then
		cb_table_key = conf.route_id
	elseif conf.service_id ~= nil then
		cb_table_key = conf.service_id
	end

	return circuit_breakers:get_circuit_breaker(cb_table_key, api_identifier, conf)
end

local function get_excluded_apis(conf)
	local service_id = conf.service_id
	local route_id = conf.route_id

	local cache_key = kong.db.plugins:cache_key("circuit_breaker_excluded_apis", service_id, route_id)
    local excluded_apis, err = kong.core_cache:get(cache_key,
                                                    nil,
                                                    function(c) return cjson.decode(c["excluded_apis"]) end,
                                                    conf)
	if err then
		error(err)
	end

	return excluded_apis
end

local function p_access(conf)
	local excluded_apis = get_excluded_apis(conf)
	local api_identifier = get_api_identifier()

	if excluded_apis[api_identifier] then
		return
	end

	-- Set timeout for request after which it will be treated as a failure
	ngx.ctx.service.read_timeout = conf["api_call_timeout_ms"]

	-- Start before proxy logic over here
	local cb = get_circuit_breaker(conf, api_identifier)

	local _, err_cb = cb:_before()
	if err_cb then
		local headers = {["Content-Type"] = conf.response_header_override or "text/plain"}
		return kong.response.exit(conf.error_status_code, conf.error_msg_override or err_cb, headers)
	end

	kong.ctx.plugin.cb = cb
	kong.ctx.plugin.generation = cb._generation
end

-- Run pre proxy checks
function CircuitBreakerHandler:access(conf)
	local success, err = pcall(p_access, conf)
	if not success then
		kong.log.err("Error in cb access phase " .. err)
		return
	end
end

local function p_header_filter(conf)
	if kong.response.get_status() and kong.response.get_status() ~= conf.error_status_code then
		local cb = kong.ctx.plugin.cb

		if cb == nil then
			return
		end
		local ok = is_successful(kong.response.get_status())
		cb:_after(kong.ctx.plugin.generation, ok)
	end
end

-- Run post proxy checks
function CircuitBreakerHandler:header_filter(conf)
	local sucess, err = pcall(p_header_filter, conf)
	if not sucess then
		kong.log.err("Error in cb header_filter phase " .. err)
		return
	end
end

function CircuitBreakerHandler:log(conf)
	local api_identifier = get_api_identifier()
	local cb = kong.ctx.plugin.cb

	if cb == nil then
		return
	end
	if cb._last_state_notified == false then
		cb._last_state_notified = true
		-- Send latest state change to your monitoring setup
		kong.log.notice("Circuit breaker state updated for route " .. api_identifier)
	end
end

function CircuitBreakerHandler:init_worker()
	kong.worker_events.register(
		function (data)
			if type(data) ~= "string" then
				return
			end

			local key_parts = pl_utils.split(data, ":")
			if key_parts[1] ~= "plugins" or key_parts[2] ~= "circuit-breaker" then
				return
			end

			local service_id = key_parts[4]
			local route_id = key_parts[3]

			if route_id ~= "" then
				circuit_breakers:remove_breakers_by_level(route_id) -- Route level circuit breaker
			elseif service_id ~= "" then
				circuit_breakers:remove_breakers_by_level(service_id) -- Service level circuit breaker
			else
				circuit_breakers:remove_breakers_by_level("global") -- Global circuit breaker
			end

			local cache_key = kong.db.plugins:cache_key("circuit_breaker_excluded_apis", service_id, route_id)
			kong.core_cache:invalidate(cache_key, false)
		end,
		"mlcache",
		"mlcache:invalidations:kong_core_db_cache"
	)
end

return CircuitBreakerHandler
