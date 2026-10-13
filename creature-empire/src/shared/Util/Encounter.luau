--!strict
-- Wild creature befriending and heat. Shown to the player before they throw a lure.

local Shared = script.Parent.Parent
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local RegionConfig = require(Shared.Config.RegionConfig)
local Stats = require(script.Parent.Stats)

local Encounter = {}

local BASE_CHANCE = { 0.7, 0.55, 0.35, 0.2, 0.12, 0.08 } -- by rarity order

export type Companion = { Species: string, Level: number, Stage: number }

function Encounter.BefriendChance(wildSpecies: string, companion: Companion?): number
	local species = CreatureConfig.Species[wildSpecies]
	if not species then
		return 0
	end
	local chance = BASE_CHANCE[RarityConfig.Get(species.Rarity).Order] or 0.1
	if companion then
		local friend = CreatureConfig.Species[companion.Species]
		if friend then
			if friend.Family == species.Family then
				chance += 0.15
			end
			chance += (Stats.Effective(friend, companion.Level, companion.Stage, "Luck") - 10) * 0.01
		end
	end
	return math.clamp(chance, 0.05, 0.95)
end

-- Extra gather yield chance from a companion's Discovery stat.
function Encounter.BonusGatherChance(companion: Companion?): number
	if not companion then
		return 0
	end
	local species = CreatureConfig.Species[companion.Species]
	if not species then
		return 0
	end
	return math.clamp(Stats.Effective(species, companion.Level, companion.Stage, "DiscoveryChance") / 100, 0, 0.5)
end

export type HeatContext = {
	Offset: Vector3, -- player position relative to the region centre
	CompanionFamily: string?,
	Eruption: boolean,
	OnBridge: boolean,
	Ward: number?, -- research: share of heat build-up prevented (0..1)
}

-- Heat change per second at a spot. Vent bursts are added separately when they go off.
function Encounter.HeatRate(region: RegionConfig.Region, context: HeatContext): number
	local heat = region.Heat
	local rate = heat.BaseRate
	if context.Eruption then
		rate *= heat.EruptionMultiplier
	end
	if not context.OnBridge then
		for _, lava in region.Lava do
			if RegionConfig.DistanceToSegment(context.Offset, lava.From, lava.To) <= lava.Width / 2 then
				rate += heat.LavaRate
			end
		end
	end
	local resist = context.CompanionFamily and heat.ResistFamilies[context.CompanionFamily]
	if resist then
		rate *= resist
	end
	rate *= 1 - math.clamp(context.Ward or 0, 0, 0.9)
	for _, pool in region.Pools do
		local flat = Vector3.new(context.Offset.X - pool.X, 0, context.Offset.Z - pool.Z)
		if flat.Magnitude <= heat.PoolRadius then
			return heat.PoolRate
		end
	end
	return rate
end

return Encounter
