--!strict
-- Effects of completed research and Ascension perks, from saved data alone. Pure: the
-- server applies them, the client previews them, tests check them.

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local ResearchConfig = require(Shared.Config.ResearchConfig)
local AscensionConfig = require(Shared.Config.AscensionConfig)

export type Bonus = { Stat: string, Category: string, Value: number }

local Research = {}

function Research.Has(data: Types.PlayerData, nodeId: string): boolean
	return data.Research ~= nil and data.Research[nodeId] ~= nil
end

-- Sum of every completed node's effects of one kind.
function Research.Total(data: Types.PlayerData, kind: string): number
	local total = 0
	local done: { [string]: number } = data.Research or {}
	for nodeId in done do
		local node = ResearchConfig.Nodes[nodeId]
		if node then
			for _, effect in node.Effects do
				if effect.Kind == kind then
					total += effect.Value or 0
				end
			end
		end
	end
	return total
end

-- Sum of every perk's value of one kind (value * rank).
function Research.PerkTotal(data: Types.PlayerData, kind: string, stat: string?): number
	local total = 0
	local perks: { [string]: number } = data.Ascension and data.Ascension.Perks or {}
	for perkId, rank in perks do
		local perk = AscensionConfig.Perks[perkId]
		if perk and perk.Kind == kind and (stat == nil or perk.Stat == stat) then
			total += perk.Value * math.min(rank, perk.MaxRank)
		end
	end
	return total
end

-- Production bonuses for a worker doing `job` (research, Ascension count and perks).
function Research.Bonuses(data: Types.PlayerData, job: string): { Bonus }
	local bonuses: { Bonus } = {}
	local done: { [string]: number } = data.Research or {}
	for nodeId in done do
		local node = ResearchConfig.Nodes[nodeId]
		if node then
			for _, effect in node.Effects do
				if effect.Kind == "Modifier" and effect.Stat and (effect.Job == nil or effect.Job == job) then
					table.insert(bonuses, { Stat = effect.Stat, Category = "Research", Value = effect.Value or 0 })
				end
			end
		end
	end
	local count = data.Ascension and data.Ascension.Count or 0
	if count > 0 then
		table.insert(
			bonuses,
			{ Stat = "Yield", Category = "Ascension", Value = count * AscensionConfig.YieldPerAscension }
		)
	end
	for _, stat in { "WorkSpeed", "Yield" } do
		local value = Research.PerkTotal(data, "Modifier", stat)
		if value > 0 then
			table.insert(bonuses, { Stat = stat, Category = "Perk", Value = value })
		end
	end
	return bonuses
end

-- Silo capacity multiplier (research + perks).
function Research.SiloMultiplier(data: Types.PlayerData): number
	return 1 + Research.Total(data, "Silo") + Research.PerkTotal(data, "Silo")
end

-- Extra seconds of offline production.
function Research.OfflineExtra(data: Types.PlayerData): number
	return Research.Total(data, "Offline") + Research.PerkTotal(data, "Offline")
end

-- Can this node be researched now? Returns ok and a reason when not.
function Research.CanResearch(data: Types.PlayerData, nodeId: string, phase: number): (boolean, string?)
	local node = ResearchConfig.Nodes[nodeId]
	if not node or node.Phase > phase then
		return false, "Unknown research."
	end
	if Research.Has(data, nodeId) then
		return false, "Already researched."
	end
	for _, required in node.Requires do
		if not Research.Has(data, required) then
			local def = ResearchConfig.Nodes[required]
			return false, `Research {def and def.Name or required} first.`
		end
	end
	return true, nil
end

return Research
