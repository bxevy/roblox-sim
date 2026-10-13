--!strict
-- Small seeded random number generator (LCG). Deterministic on every platform, so a
-- result rolled from a saved seed is the same on any server and in tests.

export type Rng = {
	Next: (self: Rng) -> number, -- [0, 1)
	Int: (self: Rng, min: number, max: number) -> number, -- inclusive
}

local Rng = {}

local MOD = 2147483648 -- 2^31

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % MOD
	local self = {}
	function self.Next(_): number
		state = (state * 1103515245 + 12345) % MOD
		return state / MOD
	end
	function self.Int(this: any, min: number, max: number): number
		return min + math.floor(this:Next() * (max - min + 1))
	end
	return self :: any
end

return Rng
