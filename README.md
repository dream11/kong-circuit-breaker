# Circuit breaker library

- [Circuit breaker library](#circuit-breaker-library)
  - [Overview](#overview)
  - [Sample Usage](#sample-usage)
  - [Installation](#installation)


## Overview

The function of this library is to provide circuit breaker functionality to the circuit breaker plugin as well as the other plugins that make http calls.

## Sample Usage

```lua
--Import Circuit breaker factory.
local circuit_breaker_lib = require "circuit-breaker-lib.factory"

--Create a new instance of the circuit breaker factory. Always set version=0. This is used to flush the circuit breakers when the configuration is changed.
local circuit_breakers = circuit_breaker_lib:new({version = 0})

-- Get a circuit breaker instance from factory. Returns a new instance only if not already created .
local cb, err = circuit_breakers:get_circuit_breaker(
    level, -- Level is used to flush all CBs at a certain level (Golbal / Service / Route) when cb configuration is changed at that level.
    api_identifier, -- This is used to map the cicuit breaker to an api.
    {

        window_time = 10, -- Time window in seconds after which the state of the cb is reset.
        min_calls_in_window= 20, -- The minimum number of requests in a window that go through the cb after which the breaking strategy is applied.
        failure_percent_threshold= 51, -- Failure threshold after which the cb opens from closed or half open state.
        wait_duration_in_open_state= 15, -- Time in seconds for which the cb remains in open state.
        wait_duration_in_half_open_state= 120, -- Time in seconds for which the cb remains in half open state.
        half_open_max_calls_in_window= 10, -- Maximum calls in half open state after which **too_many_requests** error is returned.
        half_open_min_calls_in_window= 5, -- Minimum calls in half open state after which the calculation to open/close the circuit is done in half open state.
        version = 1, -- Version is used to flush the cbs if the configuration is changed.
        notify = function(state) -- This function is executed when the state of cb changes.
            kong.log.info(string.format("Breaker %s state changed to: %s", "/co-auth", state._state))
        end}
)
-- Check state of cb. This function returns an error if the state is open or half_open_max_calls_in_window is breached.
local _, err_cb = cb:_before()
if err_cb then
    return false, "Circuit breaker open error"
end

-- Make the http call for which circuit breaking is required.
local res, err_http = makeHttpCall(options)

-- Update the state of the cb based on successfull / failure response.
local ok = res and res.status and res.status < 500
cb:_after(cb._generation, ok)
```

## Installation

In **test** environment

`gojira run "cd /kong-plugin/kong/plugins/lib && luarocks make"`

On **production / staging**, run the below command inside **d11-kong repo**. Note that all the libraries inside **lib** folder will be installed by running this command only once.

`cd plugins/lib && luarocks make`







## circuit-breaker
![Continuous Integration](https://github.com/dream11/circuit-breaker/workflows/Continuous%20Integration/badge.svg)

**circuit-breaker** is a plugin for [Kong](https://github.com/Mashape/kong) and is used to add a circuit breaker to each route added to Kong API Gateway. It is very useful in gracefully handling any failures in upstream services.  

## How does it work?

1. The plugin reads all the headers from the incoming request specified in the config as `headers`.
2. It transforms the value of the specified headers as per `operation` in the config.
3. It interpolates hostname of the request with above values before making upstream request.

Example:

### Operation = none

```lua
conf = {
    host = "service_<zone>_<shard>.com",
    headers = {"zone", "shard"},
    fallback_host = "service_fallback.com",
    operation = "none",
    modulo_by = 1
}
```

Now a request with headers: <br>
 `zone: us-east-1` <br>
 `shard: z3e67`<br>
on kong will be routed to `host = service_us-east-1_z3e67.com`.

### Operation = modulo

```lua
conf = {
    host = "service_shard_<user_id>.com",
    headers = {"user_id"},
    fallback_host = "service_fallback.com",
    operation = "modulo",
    modulo_by = 3
}
```

Now a request with header:<br>
 `user_id: 13` <br>
on kong will be routed to `host = service_shard_1.com` as `13 % 3 = 1`.

## Installation

### luarocks
```bash
luarocks install circuit-breaker
```

### source
Clone this repo and run:

     luarocks make
-------------------------
You also need to set the `KONG_PLUGINS` environment variable:

     export KONG_PLUGINS=circuit-breaker

## Usage

### Parameters

| Parameter | Default  | Required | description |
| --- | --- | --- | --- |
| `host` | hostname-<PLACE_HOLDER>.com | true | Hostname of upstream service |
| `headers` | {} | true | array of headers read from request for interpolation |
| `operation` | none | false | Operation to apply on header value (none/modulo) |
| `modulo_by` | 1 | false | Number to do modulo by when operation = modulo |
| `fallback_host` | - | false | Route to fallback_host if any of the headers is missing in request else error is returned with status code 422 |
