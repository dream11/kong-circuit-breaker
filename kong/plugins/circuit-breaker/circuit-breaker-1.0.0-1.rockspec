package = "circuit-breaker"

version = "1.0.0-1"

supported_platforms = {"linux", "macosx"}

source = {
    url = "https://github.com/dream11/kong-plugins"
}

description = {
    summary = "Circuit breaker plugin developed by Dream11."
}

dependencies = {
}

build = {
    type = "builtin",
    modules = {
        ["kong.plugins.circuit-breaker.handler"] = "handler.lua",
        ["kong.plugins.circuit-breaker.schema"] = "schema.lua",
        ["circuit-breaker-lib.factory"] = "circuit-breaker-lib/factory.lua"
    }
}