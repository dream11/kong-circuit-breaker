![lua-circuit-breaker](./kong-circuit-breaker.svg)

[![Continuous Integration](https://github.com/dream11/lua-circuit-breaker/actions/workflows/ci.yml/badge.svg)](https://github.com/dream11/lua-circuit-breaker/actions/workflows/ci.yml)
[![Code Coverage](https://codecov.io/gh/dream11/lua-circuit-breaker/branch/master/graph/badge.svg?token=6wyFuRgmdG)](https://codecov.io/gh/dream11/lua-circuit-breaker)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Overview
`kong-circuit-breaker` is a Kong plugin which provides circuit-breaker functionality at route level. It uses [lua-circuit-breaker](https://github.com/dream11/lua-circuit-breaker) library internally to wrap proxy calls around a circuit-breaker pattern. The functionality provided by this plugin is similar to libraries like [resilience4j](https://github.com/resilience4j/resilience4j) in Java.

## Usecase
In high throughput use cases, if an API of an upstream service results in timeouts/failures, the following will happen:
1. It will bring a cascading failure effect to Kong and reduce its performance
2. Continued calls to upstream service (which is facing downtime) wil prevent the upstream service from recovering
Thus, it is essential for proxy calls made from Kong to fail fast using a smart configurable mechanism, leading to improved resiliency and fault tolerance.

## Behaviour
The circuit breaker has 3 states:
1. Open: no calls will be made to this route
2. Half-open: some calls will be made to this route to check if it is responding with success or failure
3. Closed: calls will be made to this route as usual


## How does it work?
Internally, the plugin uses [lua-circuit-breaker](https://github.com/dream11/lua-circuit-breaker) library to wrap proxy calls made by Kong with a circuit-breaker.
1. To decide whether a route is in healthy/unhealthy state, success % and failure % is calculated in a time window of `window_time` seconds. 
2. For any calculation to happen in step 1, total number of requests in time window should >= `min_calls_in_window`.
3. If failure % calculated crosses `failure_percent_threshold` circuit is opened. This prevents anymore calls to this route until `wait_duration_in_open_state seconds` have elapsed. After this the circuit transitions to half-open state automatically
4. In half open state, when total_requests are >= `half_open_min_calls_in_window`, failure % is calculated to resolve circuit-breaker into open or closed state.
5. If the circuit-breaker is unable to resolve the state in `wait_duration_in_half_open_state` seconds, it automatically transitions into closed state.


## Installation

### luarocks
```bash
luarocks install kong-circuit-breaker
```

### source
Clone this repo and run:
```
luarocks make
```


### Parameters

| Key | Default  | Type  | Required | Description |
| --- | --- | --- | --- | --- |
| version | 0 | number | true | Version of configuration, for changes to take affect always increment this number |
| window_time | 10 | number | true | Window size in seconds |
| api_call_timeout_ms |  2000 | number | Duration to wait before request is timed out and counted as failure |
| min_calls_in_window | 20 | number | true | Minimum number of calls to be present in the window to start calculation |
| failure_percent_threshold | 51 | number | true | % of requests that should fail to open the circuit |
| wait_duration_in_open_state | 15 | number | true | Duration(sec) to wait before automatically transitioning from open to half-open state |
| wait_duration_in_half_open_state | 120 | number | true | Duration(sec) to wait in half-open state before automatically transitioning to closed state |
| half_open_min_calls_in_window | 5 | number | true | Minimum number of calls to be present in the half open state to start calculation |
| half_open_max_calls_in_window | 10 | number | true | Maximum calls to allow in half open state |
| error_status_code | 599 | number | Override  response status when circuit-breaker blocks the request |
| error_msg_override | nil | string | Override with ustom messa gewhen circuit-breaker blocks the request |
| response_header_override | nil | string | Override "Content-Type" response header when circuit-breaker blocks the request |
| excluded_apis | "{\"GET_/kong-healthcheck\": true}" | string | Stringified json to prevent running circuit-breaker on these APIs |
| set_logger_metrics_in_ctx | true | boolean | Sets circuit-breaker events in kong.ctx.shared to be consumed by other plugins (logger, APM etc) |

## Caveats

1. Circuit breaker uses time window to count failures, successes and total_requests. These windows are not sliding i.e. if you create a window of 10 seconds, windows will be created like: 
``` 
    window_1 (  0s - 10s ), 
    window_2 ( 10s - 20s ),
    window_3 ( 20s - 30s ) ... 
```
2. Circuit breaker uses failure % to figure out if a route is healthy or not. Always set `min_calls_in_window` to start calculations else you may open the circuit when total_requests are fairly low.
3. Set `half_open_max_calls_in_window` to prevent allowing too many calls to the route in half-open state.
4. `set_logger_metrics_in_ctx` sets circuit_breaker_name, upstream_service_host and circuit_breaker_state in `kong.ctx.shared.logger_metrics.circuit_breaker`. You can later use this data within context of a request to log these events.
5. `version` helps in recreating a new circuit-breaker object for a route if conf_new.version > conf_old.version, so whenever you make a change in configuration of the plugin also increment the version for changes to take affect.


## Inspired by
- [lua-circuit-breaker](https://github.com/dream11/lua-circuit-breaker)
- [resilience4j](https://github.com/resilience4j/resilience4j)
