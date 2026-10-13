--!strict
-- Guardian fight maths: damage, guardian health and phases.

local Shared = script.Parent.Parent
local CreatureConfig = require(Shared.Config.CreatureConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local Stats = require(script.Parent.Stats)

local Combat = {}

-- Damage from one companion hit. `special` uses the Special power; `others` = number of
-- other players currently in the arena (team bonus).
function Combat.Damage(
	speciesId: string,
	level: number,
	stage: number,
	defenderFamily: string,
	special: boolean,
	others: number
): number
	local species = CreatureConfig.Species[speciesId]
	if not species then
		return 0
	end
	local power = if special then CombatConfig.Special.Power else CombatConfig.Attack.Power
	local combat = Stats.Effective(species, level, stage, "CombatPower") / 10
	local element = CombatConfig.ElementMultiplier(species.Family, defenderFamily)
	local team = 1 + math.min(others * CombatConfig.TeamBonusPerPlayer, CombatConfig.MaxTeamBonus)
	return math.floor(power * combat * element * team + 0.5)
end

function Combat.MaxHealth(guardian: any, players: number): number
	return guardian.BaseHealth + guardian.HealthPerExtraPlayer * math.max(players - 1, 0)
end

-- The phase for a health fraction (phases are ordered from first to last).
function Combat.Phase(guardian: any, fraction: number): (number, any)
	for index, phase in guardian.Phases do
		if fraction > phase.Above then
			return index, phase
		end
	end
	return #guardian.Phases, guardian.Phases[#guardian.Phases]
end

-- Support companions (Verdant, Tideborn) cool allies with their Special instead.
function Combat.IsSupport(speciesId: string): boolean
	local species = CreatureConfig.Species[speciesId]
	return species ~= nil and CombatConfig.SupportFamilies[species.Family] == true
end

return Combat
