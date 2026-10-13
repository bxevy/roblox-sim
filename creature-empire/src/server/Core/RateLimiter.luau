--!strict
-- Token bucket rate limiter. Each key (player + action) can make `capacity` requests at
-- once and regains `refillPerSecond` tokens per second.

export type RateLimiter = {
	Allow: (self: RateLimiter, key: string, now: number?) -> boolean,
	Forget: (self: RateLimiter, prefix: string) -> (),
}

local RateLimiter = {}

function RateLimiter.new(capacity: number, refillPerSecond: number, clock: (() -> number)?): RateLimiter
	local buckets: { [string]: { Tokens: number, Updated: number } } = {}
	local getTime = clock or os.clock
	local self = {}

	function self.Allow(_, key: string, now: number?): boolean
		local t = now or getTime()
		local bucket = buckets[key]
		if not bucket then
			bucket = { Tokens = capacity, Updated = t }
			buckets[key] = bucket
		end
		bucket.Tokens = math.min(capacity, bucket.Tokens + (t - bucket.Updated) * refillPerSecond)
		bucket.Updated = t
		if bucket.Tokens >= 1 then
			bucket.Tokens -= 1
			return true
		end
		return false
	end

	function self.Forget(_, prefix: string)
		for key in buckets do
			if string.sub(key, 1, #prefix) == prefix then
				buckets[key] = nil
			end
		end
	end

	return self :: any
end

return RateLimiter
