local function prepare_breaker_settings(conf, name)
	return {
		interval = conf.window_time, -- expiry_time of a bucket
		half_open_timeout = conf.wait_duration_in_half_open_state,
		open_timeout = conf.wait_duration_in_open_state,
		min_calls_in_window = conf.min_calls_in_window,
		failure_percent_threshold = conf.failure_percent_threshold,
		half_open_min_calls_in_window = conf.half_open_min_calls_in_window,
		half_open_max_calls_in_window = conf.half_open_max_calls_in_window,
        now = conf.now,
        notify = conf.notify,
        name = name or ""
	}
end

return {
    prepare_breaker_settings = prepare_breaker_settings
}