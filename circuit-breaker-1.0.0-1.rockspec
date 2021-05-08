package = "circuit-breaker"

version = "1.0.0-1"

supported_platforms = {"linux", "macosx"}
source = {
  url = "https://github.com/dream11/d11-kong"
}
description = {
  summary = "Circuit breaker plugin for d11-kong"
}
dependencies = {
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.circuit-breaker.handler"] = "kong/plugins/circuit-breaker/handler.lua",
    ["kong.plugins.circuit-breaker.schema"] = "kong/plugins/circuit-breaker/schema.lua",

    ["circuit-breaker-lib.breaker"] = "kong/plugins/circuit-breaker/lib/breaker.lua",
    ["circuit-breaker-lib.factory"] = "kong/plugins/circuit-breaker/lib/factory.lua",
    ["circuit-breaker-lib.oop"] = "kong/plugins/circuit-breaker/lib/oop.lua",
    ["circuit-breaker-lib.errors"] = "kong/plugins/circuit-breaker/lib/errors.lua",
    ["circuit-breaker-lib.utils"] = "kong/plugins/circuit-breaker/lib/utils.lua",
    ["circuit-breaker-lib.counters"] = "kong/plugins/circuit-breaker/lib/counters.lua",
  }
}
