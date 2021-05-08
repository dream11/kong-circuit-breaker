local metaclass = {}

function metaclass:__call(...)
    return setmetatable(self:__new(...), self)
end

local function class(prototype)
    prototype = prototype or {}
    prototype.__index = prototype
    return setmetatable(prototype, metaclass)
end

return {
    class = class,
}
