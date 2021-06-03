![Continuous Integration](https://github.com/dream11/kong-host-interpolate-by-header/workflows/Continuous%20Integration/badge.svg)

**host-interpolate-by-header** is a plugin for [Kong](https://github.com/Mashape/kong) and is used to dynamically update hostname of upstream service by interpolating url with values of request headers.

## How does it work?

1. The plugin reads all the headers from the incoming request specified in the config as `headers`.
2. It transforms the value of the specified headers as per `operation` in the config.
3. It interpolates hostname of the request with above values before making upstream request.

Example:

### Operation = none

```
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

```
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
luarocks install host-interpolate-by-header
```

### source
Clone this repo and run:

     luarocks make

------------------
You also need to set the `KONG_PLUGINS` environment variable:

     export KONG_PLUGINS=host-interpolate-by-header

## Usage

### Parameters

| Parameter | Default  | Required | description |
| --- | --- | --- | --- |
| `host` | hostname-\<PLACE_HOLDER\>.com | true | Hostname of upstream service |
| `headers` | {} | true | array of headers read from request for interpolation |
| `operation` | none | false | Operation to apply on header value (none/modulo) |
| `modulo_by` | 1 | false | Number to do modulo by when operation = modulo |
| `fallback_host` | - | false | Route to fallback_host if any of the headers is missing in request else error is returned with status code 422 |
