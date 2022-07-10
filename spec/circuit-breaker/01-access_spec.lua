local helpers = require "spec.helpers"
local fixtures = require "spec.circuit-breaker.fixtures"

local strategies = {"postgres"}

for _, strategy in ipairs(strategies) do
    describe("circuit breaker plugin [#" .. strategy .. "]", function()
        local mock_host = helpers.mock_upstream_host
        local mock_port = 10001

        local window_time = 10
        local wait_duration_in_open_state = 3
        local half_open_min_calls_in_window = 2
        local half_open_max_calls_in_window = 4
        local min_calls_in_window = 6
        local failure_percent_threshold = 50
        local wait_duration_in_half_open_state = 15
        local api_call_timeout_ms = 10
        local cb_error_status_code = 599
        local excluded_apis = "{\"GET_/kong-healthcheck\": true}"

        local default_config = {
            min_calls_in_window = min_calls_in_window,
            window_time = window_time,
            api_call_timeout_ms = api_call_timeout_ms,
            failure_percent_threshold = failure_percent_threshold,
            wait_duration_in_open_state = wait_duration_in_open_state,
            wait_duration_in_half_open_state = wait_duration_in_half_open_state,
            half_open_max_calls_in_window = half_open_max_calls_in_window,
            half_open_min_calls_in_window = half_open_min_calls_in_window,
            error_status_code = cb_error_status_code,
            excluded_apis = excluded_apis,
        }

        local bp, db = helpers.get_db_utils(strategy, {"routes", "services", "plugins"}, {"circuit-breaker"});

        assert(bp.routes:insert({
            methods = {"GET"},
            protocols = {"http"},
            paths = {"/test"},
            strip_path = false,
            preserve_host = true,
            service = bp.services:insert(
                {
                    protocol = "http",
                    host = mock_host, -- Just a dummy value. Not honoured
                    port = mock_port, -- Just a dummy value. Not honoured
                    name = "test",
                    connect_timeout = 1000,
                    read_timeout = 1000,
                    write_timeout = 1000,
                    retries = 0
                })
        }))

        local circuit_breaker_plugin = bp.plugins:insert{
            name = "circuit-breaker",
            config = default_config
        }

        local get_and_assert = function (res_status_to_be_generated, res_status_expected, put_delay)
            local proxy_client = helpers.proxy_client()
            local res = assert(
                proxy_client:send({
                    method = "GET",
                    path = "/test",
                    headers = {
                        response_http_code = res_status_to_be_generated,
                        put_delay = put_delay or 0,
                    },
                }))
            assert.are.same(res_status_expected, res.status)
            proxy_client:close()
        end

        local update_plugin = function(config, enabled)
            local admin_client = helpers.admin_client()
            local url = "/plugins/" .. circuit_breaker_plugin["id"]

            local admin_res = assert(
                admin_client:patch(url, {
                    headers = {["Content-Type"] = "application/json"},
                    body = {
                        name = "circuit-breaker",
                        config = config,
                        enabled = enabled,
                    },
                }))
            assert.res_status(200, admin_res)
            admin_client:close()
        end

        setup(function()
            print("setting up")
            assert(helpers.start_kong({
                database = strategy,
                plugins = "circuit-breaker",
                nginx_conf = "spec/fixtures/custom_nginx.template"
            }, nil, nil, fixtures.fixtures))
        end)

        lazy_teardown(function()
            db:truncate()
        end)

        before_each(function ()
            print("updating config")
            update_plugin(default_config)
        end)

        -- after_each(function ()
        --     helpers.stop_kong()
        -- end)

        it("should remain closed if request count <=  min_calls_in_window & err % >= failure_percent_threshold ",
        function()
            for _ = 1, min_calls_in_window , 1 do
                get_and_assert(500, 500)
            end
        end)

        it("should remain closed if request count >  min_calls_in_window & error % < failure_percent_threshold ",
        function()
            for _ = 1, min_calls_in_window + 10 , 1 do
                get_and_assert(200, 200)
                get_and_assert(500, 500)
                get_and_assert(200, 200)
            end
        end)

        it("should open if request count >= min_calls_in_window & error % >= failure_percent_threshold ",
        function()
            for _ = 1, min_calls_in_window , 1 do
                get_and_assert(500, 500)
            end
            get_and_assert(200, cb_error_status_code)
        end)

        it("should remain open till t + open_timeout(sec) ", function()
            for _ = 1, min_calls_in_window , 1 do
                get_and_assert(500, 500)
            end
            ngx.sleep(wait_duration_in_open_state - 1)
            get_and_assert(500, cb_error_status_code)
        end)

        it("should be half open after wait_duration_in_open_state ", function()
            for _ = 1, min_calls_in_window - 1 , 1 do
                get_and_assert(500, 500)
            end
            ngx.sleep(wait_duration_in_open_state)
            get_and_assert(500, 500)
        end)

        it("should close from half_open state if err % < failure_percent_threshold "..
            "&& request count >= half_open_min_calls_in_window ",
        function()
            for _ = 1, min_calls_in_window , 1 do
                get_and_assert(500, 500)
            end
            ngx.sleep(wait_duration_in_open_state+1)
            get_and_assert(200, 200)
            for _ = 1, half_open_min_calls_in_window  , 1 do
                -- get_and_assert(ternary(i % 3 ~= 0, 200,500), ternary(i % 3 ~= 0, 200,500))
                get_and_assert(200, 200)
            end
            get_and_assert(200, 200)
        end)

        it("should open after err % >= failure_percent_threshold in half open state ", function()
            for _ = 1, min_calls_in_window , 1 do
                get_and_assert(500, 500)
            end
            ngx.sleep(wait_duration_in_open_state)
            for _ = 1, half_open_min_calls_in_window / 2, 1 do
                get_and_assert(200, 200)
                get_and_assert(500, 500)
            end
            get_and_assert(200, cb_error_status_code)
        end)

        it("should automatically close from half open state after wait_duration_in_half_open_state &"..
        " request count < half_open_max_calls_in_window ", function()
            for _ = 1, min_calls_in_window , 1 do
                get_and_assert(500, 500)
            end
            ngx.sleep(wait_duration_in_open_state)
            for _ = 1, half_open_min_calls_in_window - 1 , 1 do
                get_and_assert(500, 500)
            end
            ngx.sleep(wait_duration_in_half_open_state)
            get_and_assert(200, 200)
        end)

        it("should time out request after api_call_timeout_ms and open circuit ", function()
            get_and_assert(200, 200)
            for _ = 1, min_calls_in_window - 1 , 1 do
                get_and_assert(200, 504, 1)
            end
            for _ = 1, 10 , 1 do
                get_and_assert(200, cb_error_status_code)
            end
        end)

        it("should create new circuit breaker on config change", function()
            get_and_assert(200, 200)
            for _ = 1, min_calls_in_window - 1 , 1 do
                get_and_assert(200, 504, 1)
            end
            for _ = 1, 10 , 1 do
                get_and_assert(200, cb_error_status_code)
            end
            local new_cb_error_status_code = 598
            update_plugin({error_status_code = new_cb_error_status_code})
            get_and_assert(200, 200)
            for _ = 1, min_calls_in_window - 1 , 1 do
                get_and_assert(200, 504, 1)
            end
            for _ = 1, 10 , 1 do
                get_and_assert(200, new_cb_error_status_code)
            end
            finally(function ()
                update_plugin({error_status_code = cb_error_status_code})
            end)
        end)

        it("should not create circuit breakers for excluded apis", function()
            update_plugin({excluded_apis = "{\"GET_/test\": true}"})
            get_and_assert(200, 200)
            for _ = 1, min_calls_in_window + 10 , 1 do
                get_and_assert(500, 500)
            end
            for _ = 1, 10 , 1 do
                get_and_assert(200, 200)
            end
        end)

        it("should fallback to service timeout if plugin is deleted/disabled", function()
            -- First call to /test succeeds as repsonse is immediately returned
            get_and_assert(200, 200)

            -- Calls taking more than default api_call_timeout will be timed out by circuit breaker
            get_and_assert(504, 504, 0.5)

            -- Disable plugin
            update_plugin(default_config, false)

            -- Call taking time t where, api_call_timeout of disable plugin < t < service timeout should succeed
            get_and_assert(200, 200, 0.5)

            -- Call taking time t where, api_call_timeout of disable plugin < service timeout < t should fail
            get_and_assert(504, 504, 1.5)
        end)

        --  This test case can't be tested as requests to really get stuck, we can't use ngx.sleep() in fixtures
        -- it("should accept requests count <= half_open_max_calls_in_window in half_open state ", function()
        --     for _ = 1, min_calls_in_window , 1 do
        --         get_and_assert(500, 500)
        --     end
        --     ngx.sleep(wait_duration_in_open_state+1)
        --     for x = 1, half_open_max_calls_in_window, 1 do
        --         print("\n==================== call num: ", x)
        --         get_and_assert(200, 504, 1)
        --     end

        --     -- print("\n==================== now sending final call")
        --     -- get_and_assert(200, cb_error_status_code)
        -- end)
    end)
end
