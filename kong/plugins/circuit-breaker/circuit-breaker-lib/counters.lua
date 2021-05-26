local oop = require "circuit-breaker-lib.oop"

local Counters = oop.class()

function Counters:__new()
	return {
		requests = 0,
		total_successes = 0,
		total_failures = 0,
		consecutive_successes = 0,
		consecutive_failures = 0
	}
end

function Counters:total_samples()
	return self.total_successes + self.total_failures
end

function Counters:_on_request()
	self.requests = self.requests + 1
end

function Counters:_on_success()
	self.total_successes = self.total_successes + 1
	self.consecutive_successes = self.consecutive_successes + 1
	self.consecutive_failures = 0
end

function Counters:_on_failure()
	self.total_failures = self.total_failures + 1
	self.consecutive_failures = self.consecutive_failures + 1
	self.consecutive_successes = 0
end

return Counters