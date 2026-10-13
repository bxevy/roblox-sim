--!strict
-- A creature's effective stats: base stat, raised by level and evolution stage. Used where
-- raw stats matter directly (expeditions, combat, befriending, gathering).

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)

local Stats = {}

function Stats.Effective(species: Types.SpeciesDef, level: number, stage: number, stat: string): number
	local base = species.BaseStats[stat] or 10
	local evolution = species.Evolution[stage] or species.Evolution[1]
	return base * (1 + CreatureConfig.LevelBonus * (level - 1)) * (1 + (evolution.StatBonus or 0))
end

return Stats
