local typedefs = require "kong.db.schema.typedefs"
local json_safe = require "cjson.safe"

local function json_validator(config_string)
    local config_table, err = json_safe.decode(config_string)

    if config_table == nil then
        return nil, "Invalid Json " .. err
    end

    return true
end

local function cb_schema_validator(conf)
	-- Todo: Other checks can be added here
	return json_validator(conf.excluded_apis)
end

return {
	name = "circuit-breaker",
	fields = {
		{
			consumer = typedefs.no_consumer
		},
		{
			protocols = typedefs.protocols_http
		},
		{
			config = {
				type = "record",
				fields = {
					{version = {type = "number", required = true, default = 1}},
					{min_calls_in_window = {type = "number", gt = 1, required = true, default = 20}},
					{window_time = {type = "number", gt = 0, required = true, default = 10}},
					{api_call_timeout_ms = {type = "number", gt = 0, required = true, default = 2000}},
					{failure_percent_threshold = {type = "number", gt = 0, required = true, default = 51}},
					{wait_duration_in_open_state = {type = "number", gt = 0, required = true, default = 15}},
					{wait_duration_in_half_open_state = {type = "number", gt = 0, required = true, default = 120}},
					{half_open_max_calls_in_window = {type = "number", gt = 1, required = true, default = 10}},
					{half_open_min_calls_in_window = {type = "number", gt = 1, required = true, default = 5}},
					{error_status_code = {type = "number", required = true, default = 599}},
					{error_msg_override = {type = "string"}},
					{response_header_override = {type = "string"}},
					{excluded_apis = {
						type = "string",
						required = true,
						default = "{\"GET_/kong-healthcheck\": true}",
					}},
					{set_logger_metrics_in_ctx = {type = "boolean", default = true}},
				},
				custom_validator = cb_schema_validator
			}
		}
	}
}
