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
local Research = require(script.Parent.Research)
local Synergy = require(script.Parent.Synergy)
local Mutation = require(script.Parent.Mutation)

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
	Synergies: { string }, -- active synergy ids
}

export type CourierRate = {
	PerSecond: number, -- units carried per second across every Courier Post
	Posts: { [string]: { PerSecond: number, Workers: { WorkerRate }, Slots: number, Synergies: { string } } },
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
	for _, bonus in Research.Bonuses(data, def.Job) do
		table.insert(extra, bonus)
	end
	for _, bonus in Mutation.Bonuses(creature.Mutation) do
		table.insert(extra, bonus)
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

-- The creatures working at each building, up to its slots (sorted by id so slot
-- overflow, which Sanitize prevents, is deterministic).
local function staff(data: Types.PlayerData): { [string]: { Types.CreatureRecord } }
	local creatureIds = {}
	for id in data.Creatures do
		table.insert(creatureIds, id)
	end
	table.sort(creatureIds)
	local members: { [string]: { Types.CreatureRecord } } = {}
	for _, creatureId in creatureIds do
		local creature = data.Creatures[creatureId]
		local building = creature.Assignment and data.Buildings[creature.Assignment]
		local def = building and BuildingConfig[building.Type]
		local level = def and building and def.Levels[building.Level]
		if building and level and def and def.Job and not def.Locked then
			local list = members[building.Id] or {}
			if #list < (level.Slots or 0) then
				table.insert(list, creature)
				members[building.Id] = list
			end
		end
	end
	return members
end

-- Synergy bonuses (and ids) for one building's workers.
local function synergiesFor(
	data: Types.PlayerData,
	job: string,
	workers: { Types.CreatureRecord }
): ({ Buff }, { string })
	local species = {}
	for _, creature in workers do
		table.insert(species, creature.Species)
	end
	local active = Synergy.Active(job, species)
	local ids = {}
	for _, synergy in active do
		table.insert(ids, synergy.Id)
	end
	local strength = 1 + Research.Total(data, "Synergy")
	local bonuses: { Buff } = {}
	for _, bonus in Synergy.Bonuses(active, strength) do
		table.insert(
			bonuses,
			{ Stat = bonus.Stat, Category = bonus.Category, Value = bonus.Value, Expires = math.huge }
		)
	end
	return bonuses, ids
end

local function withSynergies(buffs: { Buff }?, synergies: { Buff }): { Buff }
	local all = table.clone(buffs or {})
	for _, bonus in synergies do
		table.insert(all, bonus)
	end
	return all
end

-- Rates for every production building. `buffs` maps building id -> active buffs.
function Production.Rates(data: Types.PlayerData, buffs: { [string]: { Buff } }?): { [string]: BuildingRate }
	local rates: { [string]: BuildingRate } = {}
	local members = staff(data)
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
			local workers: { Types.CreatureRecord } = members[id] or {}
			local synergies, synergyIds = synergiesFor(data, def.Job, workers)
			local rate: BuildingRate = {
				Output = output,
				Job = def.Job,
				Capacity = level.Storage or 0,
				PerSecond = 0,
				Workers = {},
				Slots = level.Slots or 0,
				InputsPerUnit = inputs,
				Synergies = synergyIds,
			}
			local all = withSynergies(buffs and buffs[id], synergies)
			for _, creature in workers do
				local worker = Production.WorkerAt(data, creature, building, all)
				if worker and worker.PerSecond > 0 then
					table.insert(rate.Workers, worker)
					rate.PerSecond += worker.PerSecond
				end
			end
			rates[id] = rate
		end
	end
	return rates
end

-- Courier Posts: how fast couriers carry stored output to the silo. A worker's PerCycle
-- is how many units one trip carries.
function Production.Couriers(data: Types.PlayerData, buffs: { [string]: { Buff } }?): CourierRate
	local result: CourierRate = { PerSecond = 0, Posts = {} }
	local members = staff(data)
	for id, building in data.Buildings do
		local def = BuildingConfig[building.Type]
		local level = def and def.Levels[building.Level]
		if def and level and def.Job == "Courier" and not def.Recipe then
			local workers: { Types.CreatureRecord } = members[id] or {}
			local synergies, synergyIds = synergiesFor(data, "Courier", workers)
			local post = { PerSecond = 0, Workers = {}, Slots = level.Slots or 0, Synergies = synergyIds }
			local all = withSynergies(buffs and buffs[id], synergies)
			for _, creature in workers do
				local worker = Production.WorkerAt(data, creature, building, all)
				if worker and worker.PerSecond > 0 then
					table.insert(post.Workers, worker)
					post.PerSecond += worker.PerSecond
				end
			end
			result.Posts[id] = post
			result.PerSecond += post.PerSecond
		end
	end
	return result
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
