--!strict
-- Spin Wheel odds, rolls and boost timers. Pure (time and randomness are passed in) so the
-- published odds, the server's rolls and the tests are the same code.

local Shared = script.Parent.Parent
local SpinConfig = require(Shared.Config.SpinConfig)

local Spin = {}

function Spin.TotalWeight(): number
	local total = 0
	for _, prize in SpinConfig.Prizes do
		total += prize.Weight
	end
	return total
end

-- Exact chance (0..1) of each prize, in wheel order.
function Spin.Odds(): { { Prize: SpinConfig.Prize, Chance: number } }
	local total = Spin.TotalWeight()
	local list = {}
	for _, prize in SpinConfig.Prizes do
		table.insert(list, { Prize = prize, Chance = prize.Weight / total })
	end
	return list
end

-- `random` returns a number in [0, 1). Returns the index of the prize won.
function Spin.Roll(random: () -> number): number
	local roll = random() * Spin.TotalWeight()
	local cumulative = 0
	for index, prize in SpinConfig.Prizes do
		cumulative += prize.Weight
		if roll < cumulative then
			return index
		end
	end
	return #SpinConfig.Prizes
end

-- Seconds until the next free spin (0 = ready now).
function Spin.FreeIn(nextFreeAt: number, now: number): number
	return math.max(nextFreeAt - now, 0)
end

-- The multiplier a boost gives right now (1 when it isn't running).
function Spin.Multiplier(boosts: { [string]: number }?, boostId: string, now: number): number
	local untilTime = boosts and boosts[boostId] or 0
	return if untilTime > now then SpinConfig.BoostMultiplier else 1
end

-- New end time when a boost is won: adds the full time, stacking up to the cap.
function Spin.Extend(current: number, now: number): number
	return math.min(math.max(current, now) + SpinConfig.BoostSeconds, now + SpinConfig.MaxBoostSeconds)
end

return Spin
