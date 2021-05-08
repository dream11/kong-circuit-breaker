local oop = require "circuit-breaker-lib.oop"

local Clock = oop.class()

function Clock:__new(time)
    return {
        _time = time or 1,
    }
end

function Clock:__call()
    return self._time
end

function Clock:advance(delta)
    self._time = self._time + delta
end

return {
    Clock = Clock
}