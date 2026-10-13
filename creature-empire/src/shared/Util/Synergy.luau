--!strict
-- Which synergies (SynergyConfig) a group of workers at one building triggers.

local Shared = script.Parent.Parent
local CreatureConfig = require(Shared.Config.CreatureConfig)
local SynergyConfig = require(Shared.Config.SynergyConfig)

local Synergy = {}

-- `species` lists the species id of every worker at the building (duplicates allowed).
function Synergy.Active(job: string?, species: { string }): { SynergyConfig.Synergy }
	local families: { [string]: number } = {}
	local present: { [string]: boolean } = {}
	for _, id in species do
		local def = CreatureConfig.Species[id]
		if def then
			families[def.Family] = (families[def.Family] or 0) + 1
			present[id] = true
		end
	end
	local active = {}
	for _, synergy in SynergyConfig do
		if synergy.Job == nil or synergy.Job == job then
			local ok = true
			local needFamilies: { string } = synergy.Families or {}
			local needSpecies: { string } = synergy.Species or {}
			for _, family in needFamilies do
				ok = ok and (families[family] or 0) > 0
			end
			for _, id in needSpecies do
				ok = ok and present[id] == true
			end
			if synergy.SameFamily then
				local best = 0
				for _, count in families do
					best = math.max(best, count)
				end
				ok = ok and best >= synergy.SameFamily
			end
			if ok then
				table.insert(active, synergy)
			end
		end
	end
	return active
end

-- Bonuses for the workers of a building. `strength` scales them (Harmony research).
function Synergy.Bonuses(
	active: { SynergyConfig.Synergy },
	strength: number
): { { Stat: string, Category: string, Value: number } }
	local bonuses: { { Stat: string, Category: string, Value: number } } = {}
	for _, synergy in active do
		table.insert(bonuses, { Stat = synergy.Stat :: string, Category = "Synergy", Value = synergy.Value * strength })
	end
	return bonuses
end

return Synergy
