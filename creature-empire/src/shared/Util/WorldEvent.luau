--!strict
-- The world event schedule, from the shared server clock alone (server and clients agree
-- without any messages). See WorldEventConfig.

local Shared = script.Parent.Parent
local WorldEventConfig = require(Shared.Config.WorldEventConfig)

export type Slot = {
	Index: number, -- increases by one every Period
	Kind: string, -- event id
	StartsAt: number,
	EndsAt: number,
	Active: boolean,
	NextAt: number, -- when the next event starts
	NextKind: string,
}

local WorldEvent = {}

function WorldEvent.At(t: number): Slot
	local period = WorldEventConfig.Period
	local rotation = WorldEventConfig.Rotation
	local index = math.floor(t / period)
	local kind = rotation[(index % #rotation) + 1]
	local startsAt = index * period
	local def = WorldEventConfig.Events[kind]
	local endsAt = startsAt + def.Duration
	return {
		Index = index,
		Kind = kind,
		StartsAt = startsAt,
		EndsAt = endsAt,
		Active = t >= startsAt and t < endsAt,
		NextAt = startsAt + period,
		NextKind = rotation[((index + 1) % #rotation) + 1],
	}
end

-- Success-chance bonus for a party of `participants` teams in the Ember Rift.
function WorldEvent.RiftBonus(participants: number): number
	local rift = WorldEventConfig.Rift
	return math.min(math.max(participants - 1, 0) * rift.BonusPerParticipant, rift.MaxBonus)
end

-- Grand Bloom goal for the number of players in the server when it started.
function WorldEvent.BloomGoal(players: number): number
	local bloom = WorldEventConfig.Bloom
	return math.max(bloom.MinGoal, bloom.GoalPerPlayer * players)
end

return WorldEvent
