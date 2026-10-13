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
	Job: string,
	Capacity: number,
	PerSecond: number, -- output units per second while inputs last
	Workers: { WorkerRate },
	Slots: number,
	InputsPerUnit: { [string]: number }, -- silo resources consumed per output unit
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
	local stage = species.Evolution[creature.Stage or 1] or species.Evolution[1]
	local extra = {
		{ Stat = "Yield", Category = "Empire", Value = Production.EmpireBonus(data) },
		{ Stat = "Yield", Category = "Stage", Value = stage.StatBonus or 0 },
		{ Stat = "WorkSpeed", Category = "Stage", Value = stage.StatBonus or 0 },
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
		Affinity = CreatureConfig.Affinity(species, creature.Stage or 1, def.Job),
	}, level, EconomyConfig.BonusRules)
	-- A recipe can make several units per cycle (Essence Condenser: 3).
	local recipe = def.Recipe and RecipeConfig[def.Recipe]
	local output = Production.OutputOf(def)
	local perCycleUnits = if recipe and output then recipe.Outputs[output] or 1 else 1
	return {
		CreatureId = creature.Id,
		PerSecond = result.PerSecond * perCycleUnits,
		PerCycle = result.PerCycle * perCycleUnits,
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
		if def and level and output and def.Job and not def.Locked then
			local recipe = RecipeConfig[def.Recipe :: string]
			local inputs = {}
			for resource, amount in recipe.Inputs do
				inputs[resource] = amount / (recipe.Outputs[output] or 1)
			end
			rates[id] = {
				Output = output,
				Job = def.Job,
				Capacity = level.Storage or 0,
				PerSecond = 0,
				Workers = {},
				Slots = level.Slots or 0,
				InputsPerUnit = inputs,
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

-- One production step for a building: output grows by rate * dt, limited by storage room
-- and by the inputs available in `resources` (which are consumed). Returns the new stored
-- amount, units produced, resources consumed, and whether inputs ran short.
function Production.Step(
	stored: number,
	perSecond: number,
	dt: number,
	capacity: number,
	inputsPerUnit: { [string]: number },
	resources: { [string]: number }
): (number, number, { [string]: number }, boolean)
	local consumed: { [string]: number } = {}
	if dt <= 0 or perSecond <= 0 then
		return stored, 0, consumed, false
	end
	local wanted = math.min(perSecond * dt, math.max(capacity - stored, 0))
	local possible = wanted
	for resource, per in inputsPerUnit do
		if per > 0 then
			possible = math.min(possible, (resources[resource] or 0) / per)
		end
	end
	possible = math.max(possible, 0)
	for resource, per in inputsPerUnit do
		if per > 0 and possible > 0 then
			local amount = possible * per
			resources[resource] = math.max((resources[resource] or 0) - amount, 0)
			consumed[resource] = amount
		end
	end
	return stored + possible, possible, consumed, possible < wanted - 1e-9
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
