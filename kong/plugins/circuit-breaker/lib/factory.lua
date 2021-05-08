local breaker = require "circuit-breaker-lib.breaker"
local prepare_breaker_settings = require "circuit-breaker-lib.utils".prepare_breaker_settings

-- Meta class
local Breaker_factory = {}

function Breaker_factory:new (obj)
   obj = obj or {}

   -- https://stackoverflow.com/a/6863008
   -- This line will make o inherit all methods of Breaker_factory.
   setmetatable(obj, self)
   self.__index = self
   return obj
end

function Breaker_factory:remove_circuit_breaker (level, name)

   local level_not_exists = self:check_level(level)
   if level_not_exists then
      return false
   end

   self[level][name] = nil
   return true
end

function Breaker_factory:remove_breakers_by_level (level)
   self[level] = nil
   return true
end

function Breaker_factory:get_circuit_breaker (level, name, conf, print_function)

   local level_not_exists = self:check_level(level)
   if level_not_exists or (conf.version and conf.version > self.version) then
        self.version = conf.version
        self[level] = {}
   end

   if self[level][name] == nil then
		self[level][name] = breaker.new(prepare_breaker_settings(conf, name), print_function)
   end
	return self[level][name], nil
end

function Breaker_factory:check_level (level)
   if self[level] == nil then
      return "Trying to access invalid level in circuit breaker factory object: " .. level
   end
end

return Breaker_factory
