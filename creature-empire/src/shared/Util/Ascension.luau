--!strict
-- Ascension maths and the reset itself, as pure functions on saved data so the exact
-- "what resets / what stays" behaviour is unit-tested. See AscensionConfig for the rules.

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local AscensionConfig = require(Shared.Config.AscensionConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Research = require(script.Parent.Research)

local Ascension = {}

-- Shards an Ascension right now would pay.
function Ascension.Shards(data: Types.PlayerData): number
	local runGold = math.max(data.Ascension.RunGold or 0, 0)
	local shards = math.floor(AscensionConfig.ShardBase * math.sqrt(runGold / AscensionConfig.ShardGoldUnit))
	return math.max(shards, AscensionConfig.MinShards)
end

-- Can the player ascend? Returns ok and a reason when not.
function Ascension.Check(data: Types.PlayerData): (boolean, string?)
	local core = data.Buildings.core
	if not core or core.Level < AscensionConfig.RequiredCoreTier then
		return false, `Reach Empire Core tier {AscensionConfig.RequiredCoreTier} first.`
	end
	if next(data.Expeditions) ~= nil then
		return false, "Bring every expedition home (and claim it) first."
	end
	return true, nil
end

-- The buildings every plot starts with.
function Ascension.StartingBuildings(): { [string]: Types.BuildingRecord }
	local buildings: { [string]: Types.BuildingRecord } = {}
	for _, list in { PlotConfig.FixedLayout, PlotConfig.StarterBuildings } do
		for _, entry in list do
			buildings[entry.Id] = {
				Id = entry.Id,
				Type = entry.Type,
				Level = 1,
				X = entry.X,
				Z = entry.Z,
				Rot = entry.Rot,
				Stored = {},
			}
		end
	end
	return buildings
end

-- Gold a new run starts with.
function Ascension.StartingGold(data: Types.PlayerData): number
	return (EconomyConfig.StartingCurrencies.Gold or 0) + Research.PerkTotal(data, "StartGold")
end

-- Performs the reset. Returns the shards granted. Call Ascension.Check first.
function Ascension.Apply(data: Types.PlayerData, _now: number): number
	local shards = Ascension.Shards(data)
	-- Resets
	for id in data.Currencies do
		if id ~= "EmpireShards" then
			data.Currencies[id] = 0
		end
	end
	data.Research = {}
	data.Currencies.Gold = Ascension.StartingGold(data)
	data.Currencies.EmpireShards = (data.Currencies.EmpireShards or 0) + shards
	for id in data.Resources do
		local def = ResourceConfig[id]
		if not def or def.Kind ~= "Item" then
			data.Resources[id] = 0
		end
	end
	data.Buildings = Ascension.StartingBuildings()
	data.Expansions = {}
	for _, creature in data.Creatures do
		creature.Assignment = nil
	end
	-- Progress
	data.Ascension.Count += 1
	data.Ascension.Shards += shards
	data.Ascension.RunGold = 0
	data.Stats.Ascensions = (data.Stats.Ascensions or 0) + 1
	return shards
end

-- Cost of the next rank of a perk, or nil when maxed.
function Ascension.PerkCost(data: Types.PlayerData, perkId: string): number?
	local perk = AscensionConfig.Perks[perkId]
	if not perk then
		return nil
	end
	local rank = data.Ascension.Perks[perkId] or 0
	if rank >= perk.MaxRank then
		return nil
	end
	return perk.Cost * (rank + 1)
end

return Ascension
