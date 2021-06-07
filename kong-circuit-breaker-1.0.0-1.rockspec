package = "kong-circuit-breaker"

version = "1.0.0-1"

supported_platforms = {"linux", "macosx"}
source = {
    url = "git://github.com/dream11/kong-circuit-breaker",
    tag = "v1.0.0"
}

description = {
    summary = "Kong plugin to wrap each API call with a circuit breaker",
    homepage = "https://github.com/dream11/kong-circuit-breaker",
    license = "MIT",
    maintainer = "Dream11 <tech@dream11.com>"
}

dependencies = {
    "lua >= 5.1",
    "lua-circuit-breaker >= 1.0.2",
}

build = {
    type = "builtin",
    modules = {
        ["kong.plugins.circuit-breaker.handler"] = "kong/plugins/circuit-breaker/handler.lua",
        ["kong.plugins.circuit-breaker.schema"] = "kong/plugins/circuit-breaker/schema.lua",
        ["kong.plugins.circuit-breaker.helpers"] = "kong/plugins/circuit-breaker/helpers.lua",
    },
}
