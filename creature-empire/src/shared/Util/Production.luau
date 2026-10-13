--!strict
-- Production rates for a whole empire, from saved data alone. Pure: the server uses it to
-- advance production, the client uses it to preview an assignment, and tests check it.

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local RecipeConfig = require(Shared.Config.RecipeConfig)
local Formulas = require(script.Parent.Formulas)

export type Buff = { Stat: string, Category: string, Value: number, Expires: number }

export type WorkerRate = {
	CreatureId: string,
	PerSecond: number,
	PerCycle: number,
	CycleTime: number,
	Affinity: number,
	SpeedMultiplier: number,
	YieldMultiplier: number,
}

export type BuildingRate = {
	Output: string,
	Capacity: number,
	PerSecond: number,
	Workers: { WorkerRate },
	Slots: number,
}

local Production = {}

function Production.CoreTier(data: Types.PlayerData): number
	local core = data.Buildings.core
	return if core then core.Level else 1
end

function Production.EmpireBonus(data: Types.PlayerData): number
	local level = BuildingConfig.EmpireCore.Levels[Production.CoreTier(data)]
	return level and level.EmpireBonus or 0
end

-- The main output of a production building's recipe.
function Production.OutputOf(def: Types.BuildingDef): string?
	local recipe = def.Recipe and RecipeConfig[def.Recipe]
	if not recipe then
		return nil
	end
	for resource in recipe.Outputs do
		return resource
	end
	return nil
end

-- Rate for one creature at one building (also used to preview before assigning).
function Production.WorkerAt(
	data: Types.PlayerData,
	creature: Types.CreatureRecord,
	building: Types.BuildingRecord,
	buffs: { Buff }?
): WorkerRate?
	local def = BuildingConfig[building.Type]
	local species = CreatureConfig.Species[creature.Species]
	local level = def and def.Levels[building.Level]
	if not def or not species or not level or not def.Job then
		return nil
	end
	local extra = {
		{ Stat = "Yield", Category = "Empire", Value = Production.EmpireBonus(data) },
	}
	local active: { Buff } = buffs or {}
	for _, buff in active do
		table.insert(extra, { Stat = buff.Stat, Category = buff.Category, Value = buff.Value })
	end
	local result = Formulas.WorkerRate({
		Species = species,
		Level = creature.Level,
		Job = def.Job,
		ExtraBonuses = extra,
		LevelBonus = CreatureConfig.LevelBonus,
	}, level, EconomyConfig.BonusRules)
	return {
		CreatureId = creature.Id,
		PerSecond = result.PerSecond,
		PerCycle = result.PerCycle,
		CycleTime = result.CycleTime,
		Affinity = result.Affinity,
		SpeedMultiplier = result.SpeedMultiplier,
		YieldMultiplier = result.YieldMultiplier,
	}
end

-- Rates for every production building. `buffs` maps building id -> active buffs.
function Production.Rates(data: Types.PlayerData, buffs: { [string]: { Buff } }?): { [string]: BuildingRate }
	local rates: { [string]: BuildingRate } = {}
	for id, building in data.Buildings do
		local def = BuildingConfig[building.Type]
		local level = def and def.Levels[building.Level]
		local output = def and Production.OutputOf(def)
		if def and level and output and not def.Locked then
			rates[id] = {
				Output = output,
				Capacity = level.Storage or 0,
				PerSecond = 0,
				Workers = {},
				Slots = level.Slots or 0,
			}
		end
	end
	-- Sorted so slot overflow (should never happen after Sanitize) is deterministic.
	local creatureIds = {}
	for id in data.Creatures do
		table.insert(creatureIds, id)
	end
	table.sort(creatureIds)
	for _, creatureId in creatureIds do
		local creature = data.Creatures[creatureId]
		local rate = creature.Assignment and rates[creature.Assignment]
		if rate and #rate.Workers < rate.Slots then
			local building = data.Buildings[creature.Assignment :: string]
			local worker = Production.WorkerAt(data, creature, building, buffs and buffs[creature.Assignment :: string])
			if worker and worker.PerSecond > 0 then
				table.insert(rate.Workers, worker)
				rate.PerSecond += worker.PerSecond
			end
		end
	end
	return rates
end

-- Experience: adds xp to a creature record and levels it up. Returns levels gained.
function Production.AddXp(creature: Types.CreatureRecord, xp: number): number
	local gained = 0
	creature.Xp += xp
	while creature.Level < CreatureConfig.MaxLevel do
		local need = CreatureConfig.XpToNext(creature.Level)
		if creature.Xp < need then
			break
		end
		creature.Xp -= need
		creature.Level += 1
		gained += 1
	end
	if creature.Level >= CreatureConfig.MaxLevel then
		creature.Xp = 0
	end
	return gained
end

return Production
