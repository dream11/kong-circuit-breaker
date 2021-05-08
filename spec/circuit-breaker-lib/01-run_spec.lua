local circuit_breaker_lib = require "circuit-breaker-lib.factory"
local breaker = require "circuit-breaker-lib.breaker"
local cb_errors = require "circuit-breaker-lib.errors"
local mocks = require "custom_specs/plugins/circuit-breaker-lib/mocks"

describe("circuit-breaker-lib", function()
    local circuit_breakers
    local window_time = 10
    local wait_duration_in_open_state = 10
    local half_open_min_calls_in_window = 60
    local half_open_max_calls_in_window = 90
    local min_calls_in_window = 100
    local failure_percent_threshold = 50
    local wait_duration_in_half_open_state = 120
    local clock = mocks.Clock()
    local cb_conf

    local get_cb = function (conf, level, name)
        return circuit_breakers:get_circuit_breaker(level, name, conf, function () end)
    end
    local before_cb_assert = function(conf, err_cb_expected)
        local cb = get_cb(conf, "global", "GET/test")
        local _, err_cb = cb:_before()
        assert.are.same(err_cb_expected, err_cb)
        return cb
    end

    local check_and_assert_cb = function (conf, err_cb_expected, ok, breaker_state_expected)
        local cb = get_cb(conf, "global", "GET/test")
        local _, err_cb = cb:_before()
        assert.are.same(err_cb_expected, err_cb)
        assert.are.same(breaker_state_expected, cb._state)
        cb:_after(cb._generation, ok)
        return cb
    end

    before_each(function ()
        circuit_breakers = circuit_breaker_lib:new({version = 0})

        cb_conf = {
            min_calls_in_window = min_calls_in_window,
            window_time = window_time,
            failure_percent_threshold = failure_percent_threshold,
            wait_duration_in_open_state = wait_duration_in_open_state,
            wait_duration_in_half_open_state = wait_duration_in_half_open_state,
            half_open_max_calls_in_window = half_open_max_calls_in_window,
            half_open_min_calls_in_window = half_open_min_calls_in_window,
            version = 1,
            now = clock
        }
    end)

    it("should remain closed if request count <=  min_calls_in_window & error % >= failure_percent_threshold ",
    function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
    end)
    it("should remain closed if request count >  min_calls_in_window & error % < failure_percent_threshold",
    function()
        -- This loop will produce error % of 33 % which is less than failure_percent_threshold (50%)
        for _ = 1, min_calls_in_window + 100 , 1 do
            check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
            check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
    end)
    it("should open if request count >= min_calls_in_window & error % >= failure_percent_threshold",
    function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
        check_and_assert_cb(cb_conf, cb_errors.open, false, breaker.states.open)
    end)
    it("should remain open till t + open_timeout(sec)", function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
        clock:advance(wait_duration_in_open_state - 1)
        check_and_assert_cb(cb_conf, cb_errors.open, false, breaker.states.open)
    end)
    it("should be half open after wait_duration_in_open_state", function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
        clock:advance(wait_duration_in_open_state)
        check_and_assert_cb(cb_conf, nil, false, breaker.states.half_open)
    end)
    it("should accept requests count <= half_open_max_calls_in_window in half_open state", function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
        clock:advance(wait_duration_in_open_state)
        for _ = 1, half_open_max_calls_in_window , 1 do
            before_cb_assert(cb_conf, nil)
        end
        before_cb_assert(cb_conf, cb_errors.too_many_requests)
    end)
    it("should close from half_open state if err % < failure_percent_threshold "..
        "&& request count >= half_open_min_calls_in_window",
     function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
        clock:advance(wait_duration_in_open_state)
        check_and_assert_cb(cb_conf, nil, true, breaker.states.half_open)
        for i = 1, half_open_min_calls_in_window - 1  , 1 do
            check_and_assert_cb(cb_conf, nil, i % 3 ~= 0, breaker.states.half_open)
        end
        check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
    end)
    it("should open after err % >= failure_percent_threshold in half open state", function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
        clock:advance(wait_duration_in_open_state)
        for _ = 1, half_open_min_calls_in_window / 2, 1 do
            check_and_assert_cb(cb_conf,nil, true, breaker.states.half_open)
            check_and_assert_cb(cb_conf,nil, false, breaker.states.half_open)
        end
        check_and_assert_cb(cb_conf, cb_errors.open, false, breaker.states.open)
    end)
    it("should automatically close from half open state after wait_duration_in_half_open_state &"..
    " request count < half_open_max_calls_in_window", function()
        for _ = 1, min_calls_in_window , 1 do
            check_and_assert_cb(cb_conf, nil, false, breaker.states.closed)
        end
        clock:advance(wait_duration_in_open_state)
        for _ = 1, half_open_min_calls_in_window - 1 , 1 do
            check_and_assert_cb(cb_conf,nil, false, breaker.states.half_open)
        end
        clock:advance(wait_duration_in_half_open_state)
        check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
    end)
    it("should create new cb if version is increased in config ", function()

        for _ = 1, 10 , 1 do
            check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
        end
        cb_conf.version = cb_conf.version + 1
        local cb = check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
        assert.are.same(cb_conf.version, circuit_breakers.version)
        assert.are.same(1, cb._counters.requests)
    end)
    it("should change generation after window_timeout and counters  should be reset", function()
        local cb
        for i = 1, min_calls_in_window , 1 do
            cb = check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
            assert(0, cb._generation)
            assert.are.same(i, cb._counters.requests)
        end
        clock:advance(window_time)

        for i = 1, min_calls_in_window , 1 do
            cb = check_and_assert_cb(cb_conf, nil, true, breaker.states.closed)
            assert(1, cb._generation)
            assert.are.same(i, cb._counters.requests)
        end

    end)
end)