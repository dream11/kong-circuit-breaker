local cjson = require "cjson"

local kong = kong

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

local function get_api_identifier()
	return kong.request.get_method() .. "_" .. kong.request.get_path()
end

local function set_logger_metrics(api_identifier, new_state)
	local upstream_host = kong.ctx.shared.upstream_host or ''
	if kong.ctx.shared.logger_metrics == nil then
		kong.ctx.shared.logger_metrics = {}
	end
	-- kong.ctx.shared object is specific to the lifecycle of a request and is used to share data between plugins
	kong.ctx.shared.logger_metrics.circuit_breaker = {
		"upstream:" .. upstream_host,
		"circuit_breaker:" .. api_identifier,
		"cb_state:" .. new_state
	}
end

return {
    get_excluded_apis = get_excluded_apis,
    get_api_identifier = get_api_identifier,
    set_logger_metrics = set_logger_metrics,
}