--!nocheck
-- Three currencies; each starter's own building; buildings any creature can work.

local H = require("../harness")
local test, describe, eq, truthy, falsy = H.test, H.describe, H.eq, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local WorkRules = shared("Util", "WorkRules")
local BuildingConfig = shared("Config", "BuildingConfig")
local ResourceConfig = shared("Config", "ResourceConfig")
local CreatureConfig = shared("Config", "CreatureConfig")

describe("Currencies", function()
	test("exactly three: Gold, Essence and Empire Shards", function()
		local currencies = {}
		for id, def in ResourceConfig do
			if type(def) == "table" and def.Kind == "Currency" then
				table.insert(currencies, id)
			end
		end
		table.sort(currencies)
		eq(table.concat(currencies, ","), "EmpireShards,Essence,Gold")
	end)
	test("saved Insight becomes Essence", function()
		local data = Schema.Default(0)
		data.Version = 9
		data.Currencies.Essence = 10
		data.Currencies.Insight = 25
		Schema.Migrate(data)
		eq(data.Currencies.Essence, 35)
		eq(data.Currencies.Insight, nil)
	end)
end)

describe("Who works where", function()
	test("each starter's building takes only that starter", function()
		local own = { MoonpetalFarm = "Sproutling", CrystalMine = "Pebblit", CrystalSmelter = "Cindercub" }
		for typeId, owner in own do
			local def = BuildingConfig[typeId]
			for speciesId in CreatureConfig.Species do
				eq(WorkRules.CanWork(def, speciesId, 1), speciesId == owner, `{speciesId} at {typeId}`)
			end
		end
	end)
	test("any creature can work the Workshop, Condenser, Research Station and Courier Post", function()
		for _, typeId in { "Workshop", "EssenceCondenser", "ResearchStation", "CourierPost" } do
			local def = BuildingConfig[typeId]
			truthy(def.AnyCreature, typeId)
			for speciesId in CreatureConfig.Species do
				truthy(WorkRules.CanWork(def, speciesId, 1), `{speciesId} at {typeId}`)
			end
		end
	end)
	test("skilled creatures still do better at any-creature buildings", function()
		local def = BuildingConfig.EssenceCondenser
		truthy(WorkRules.Affinity(def, "Zappup", 1) == WorkRules.AnyAffinity)
		truthy(WorkRules.Affinity(def, "Wisplet", 1) >= WorkRules.AnyAffinity)
	end)
	test("the reason names the building's owner", function()
		local why = WorkRules.WhyNot(BuildingConfig.CrystalMine, "Sproutling", "Sproutling")
		truthy(string.find(why, "Only Pebblit", 1, true), why)
		falsy(string.find(WorkRules.WhyNot(BuildingConfig.MoonpetalFarm, "Zappup", "Zappup"), "Pebblit", 1, true))
	end)
	test("every starter's building can be placed at Empire Core tier 1", function()
		local limits = BuildingConfig.EmpireCore.Levels[1].BuildingLimits
		for _, typeId in { "MoonpetalFarm", "CrystalMine", "CrystalSmelter", "Workshop" } do
			truthy((limits[typeId] or 0) >= 1, typeId)
		end
	end)
end)

describe("Starter tutorial", function()
	local Tutorial = shared("Util", "Tutorial")
	local QuestConfig = shared("Config", "QuestConfig")
	local EconomyConfig = shared("Config", "EconomyConfig")
	local Formulas = shared("Util", "Formulas")

	test("whichever starter you pick, you meet all three, each with its own building", function()
		for _, chosen in CreatureConfig.Starters do
			local order = Tutorial.StarterOrder(chosen)
			eq(order[1], chosen)
			eq(#order, 3)
			local buildings = {}
			for _, speciesId in order do
				local typeId = Tutorial.BuildingFor(speciesId)
				truthy(typeId, speciesId .. " has a building")
				buildings[typeId] = true
				truthy(WorkRules.CanWork(BuildingConfig[typeId], speciesId, 1), speciesId .. " works its building")
			end
			eq(buildings.MoonpetalFarm and buildings.CrystalMine and buildings.CrystalSmelter, true)
		end
	end)
	test("starter steps resolve to real buildings and resources, with names filled in", function()
		for _, chosen in CreatureConfig.Starters do
			for i, step in QuestConfig.Tutorial do
				if Tutorial.IsStarterKind(step.Kind) then
					local resolved = Tutorial.Resolve(step, chosen)
					falsy(string.find(resolved.Title .. resolved.Description, "{", 1, true), `step {i} text filled`)
					if resolved.Kind == "BuildingCount" or resolved.Kind == "AssignSpecies" then
						truthy(BuildingConfig[resolved.Target], `step {i} building`)
					else
						truthy(ResourceConfig[resolved.Target], `step {i} resource {resolved.Target}`)
					end
					if resolved.Pointer then
						truthy(
							BuildingConfig[resolved.Pointer] or resolved.Pointer == "TradingPost",
							`step {i} pointer`
						)
					end
				end
			end
		end
	end)
	test("before choosing, starter steps wait (and still read well)", function()
		local resolved = Tutorial.Resolve(QuestConfig.Tutorial[2], nil)
		eq(resolved.Kind, "Waiting")
		falsy(string.find(resolved.Title, "{", 1, true))
	end)
	test("you can afford your first starter's building, and the smelter gets crystal to start", function()
		for _, typeId in { "MoonpetalFarm", "CrystalMine", "CrystalSmelter" } do
			local cost = Formulas.PlaceCost(BuildingConfig[typeId], 0).Gold or 0
			truthy(EconomyConfig.StartingCurrencies.Gold >= cost, typeId .. " affordable at the start")
		end
		local kit = Tutorial.Kit("CrystalSmelter")
		truthy((kit.RawCrystal or 0) >= 30, "enough raw crystal for the first 10 refined")
		eq(next(Tutorial.Kit("MoonpetalFarm")), nil)
	end)
	test("the opening hands out the two other starters", function()
		local count = 0
		for i, step in QuestConfig.Tutorial do
			if step.Reward.Creature == "NextStarter" then
				count += 1
				truthy(i < 12, "early in the tutorial")
			end
		end
		eq(count, 2)
	end)
end)

describe("Tutorial progress in older saves", function()
	local QuestConfig = shared("Config", "QuestConfig")
	local function migrated(oldIndex)
		local data = Schema.Default(0)
		data.Version = 9
		data.Quests = { Tutorial = oldIndex, Progress = 3, Claimable = true }
		Schema.Migrate(data)
		return data.Quests
	end
	local function idAt(index)
		local step = QuestConfig.Tutorial[index]
		return step and step.Id
	end
	test("players in the old opening start the starter steps", function()
		eq(idAt(migrated(1).Tutorial), "Starter")
		for old = 2, 7 do
			eq(idAt(migrated(old).Tutorial), "Build1", `old step {old}`)
		end
	end)
	test("later steps keep their place by id; counters reset", function()
		eq(idAt(migrated(8).Tutorial), "Silo")
		eq(idAt(migrated(10).Tutorial), "CoreTier2")
		eq(idAt(migrated(13).Tutorial), "Chamber", "the old Mine step")
		eq(idAt(migrated(32).Tutorial), "WorldEvent")
		local q = migrated(16)
		eq(idAt(q.Tutorial), "Evolve")
		eq(q.Progress, 0)
		eq(q.Claimable, false)
		eq(migrated(33).Tutorial, #QuestConfig.Tutorial + 1, "finished stays finished")
	end)
end)

describe("Switched-off materials (Emberstone for now)", function()
	local ExpeditionConfig = shared("Config", "ExpeditionConfig")
	local ResearchConfig = shared("Config", "ResearchConfig")
	local RecipeConfig = shared("Config", "RecipeConfig")
	local function offList()
		local list = {}
		for id, def in ResourceConfig do
			if type(def) == "table" and def.Enabled == false then
				table.insert(list, id)
			end
		end
		return list
	end
	test("Emberstone is switched off", function()
		eq(ResourceConfig.Emberstone.Enabled, false)
	end)
	test("nothing gives or asks for a switched-off material", function()
		for _, id in offList() do
			for _, destination in ExpeditionConfig.Destinations do
				for _, reward in destination.Rewards do
					truthy(reward.Resource ~= id, destination.Id .. " reward")
				end
				for _, event in destination.Events do
					eq((event.Reward or {})[id], nil, destination.Id .. " event")
				end
			end
			for supplyId, supply in ExpeditionConfig.Supplies do
				eq(supply.Cost[id], nil, supplyId)
			end
			for nodeId, node in ResearchConfig.Nodes do
				eq(node.Cost[id], nil, nodeId)
			end
			for typeId, def in BuildingConfig do
				eq((def.PlaceCost or {})[id], nil, typeId .. " place cost")
				for level, info in def.Levels do
					eq((info.Cost or {})[id], nil, `{typeId} level {level}`)
				end
			end
		end
	end)
	test("the Workshop pays 10 Gold per point of work", function()
		eq(RecipeConfig.CraftTrinkets.Outputs.Gold, 10)
	end)
end)

describe("Workshop income", function()
	local Production = shared("Util", "Production")
	local GameConfig = shared("Config", "GameConfig")
	test("a level-1 Workshop averages 150 Gold a minute across every creature", function()
		local data = Schema.Default(0)
		data.Buildings.ws = { Id = "ws", Type = "Workshop", Level = 1, X = 2, Z = 2, Rot = 0, Stored = {} }
		local sum, count = 0, 0
		for id, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase then
				local creature = {
					Id = "x",
					Species = id,
					Level = 1,
					Stage = 1,
					Xp = 0,
					ObtainedAt = 0,
					Tradable = false,
					WorkCycles = 0,
					AbilityReadyAt = 0,
				}
				local worker = Production.WorkerAt(data, creature, data.Buildings.ws, nil)
				sum += worker.PerSecond * 60
				count += 1
			end
		end
		H.near(sum / count, 150, 0.5)
		-- About 10 minutes of work before the Workshop is full.
		truthy(BuildingConfig.Workshop.Levels[1].Storage >= 150 * 9)
	end)
end)

describe("Starter building income", function()
	local Production = shared("Util", "Production")
	local RecipeConfig = shared("Config", "RecipeConfig")
	local function perMinute(typeId, speciesId)
		local data = Schema.Default(0)
		data.Buildings.b = { Id = "b", Type = typeId, Level = 1, X = 2, Z = 2, Rot = 0, Stored = {} }
		local creature = {
			Id = "x",
			Species = speciesId,
			Level = 1,
			Stage = 1,
			Xp = 0,
			ObtainedAt = 0,
			Tradable = false,
			WorkCycles = 0,
			AbilityReadyAt = 0,
		}
		local worker = Production.WorkerAt(data, creature, data.Buildings.b, nil)
		local def = BuildingConfig[typeId]
		local recipe = RecipeConfig[def.Recipe]
		local output = Production.OutputOf(def)
		local units = worker.PerSecond * 60
		-- Gold from selling the output, minus what its inputs would have sold for.
		local value = ResourceConfig[output].SellPrice
		for resource, amount in recipe.Inputs do
			value -= amount / (recipe.Outputs[output] or 1) * (ResourceConfig[resource].SellPrice or 0)
		end
		return units * value
	end
	test("each starter's building earns about 80-95 Gold a minute at level 1", function()
		for typeId, speciesId in { MoonpetalFarm = "Sproutling", CrystalMine = "Pebblit", CrystalSmelter = "Cindercub" } do
			local gold = perMinute(typeId, speciesId)
			truthy(gold >= 80 and gold <= 95, `{typeId}: {math.floor(gold)} gold/min`)
		end
	end)
end)

describe("Prices (medium pace)", function()
	local Production = shared("Util", "Production")
	local RecipeConfig = shared("Config", "RecipeConfig")
	local GameConfig = shared("Config", "GameConfig")
	local Formulas = shared("Util", "Formulas")
	local OWNER = { MoonpetalFarm = "Sproutling", CrystalMine = "Pebblit", CrystalSmelter = "Cindercub" }
	local function creature(speciesId)
		return {
			Id = "x",
			Species = speciesId,
			Level = 1,
			Stage = 1,
			Xp = 0,
			ObtainedAt = 0,
			Tradable = false,
			WorkCycles = 0,
			AbilityReadyAt = 0,
		}
	end
	local function value(typeId)
		local def = BuildingConfig[typeId]
		local recipe = RecipeConfig[def.Recipe]
		local out = Production.OutputOf(def)
		local v = ResourceConfig[out].SellPrice or 1
		for resource, amount in recipe.Inputs do
			v -= amount / (recipe.Outputs[out] or 1) * (ResourceConfig[resource].SellPrice or 0)
		end
		return v
	end
	local function perWorker(typeId, speciesId, level)
		local data = Schema.Default(0)
		data.Buildings.b = { Id = "b", Type = typeId, Level = level, X = 2, Z = 2, Rot = 0, Stored = {} }
		return Production.WorkerAt(data, creature(speciesId), data.Buildings.b, nil).PerSecond * 60 * value(typeId)
	end
	-- Gold a minute with every slot filled (starter buildings by their starter, the
	-- Workshop by an average creature).
	local function full(typeId, level)
		local per
		if OWNER[typeId] then
			per = perWorker(typeId, OWNER[typeId], level)
		else
			local sum, count = 0, 0
			for id, species in CreatureConfig.Species do
				if species.Phase <= GameConfig.Phase then
					sum += perWorker(typeId, id, level)
					count += 1
				end
			end
			per = sum / count
		end
		return per * BuildingConfig[typeId].Levels[level].Slots
	end
	local function near(minutes, target, label)
		truthy(
			minutes >= target * 0.75 and minutes <= target * 1.25,
			`{label}: {math.floor(minutes)} min (target {target})`
		)
	end
	test("upgrades pay back in 10 / 15 / 25 / 40 minutes", function()
		local targets = { [2] = 10, [3] = 15, [4] = 25, [5] = 40 }
		for _, typeId in { "MoonpetalFarm", "CrystalMine", "CrystalSmelter", "Workshop" } do
			for level = 2, 5 do
				local gain = full(typeId, level) - full(typeId, level - 1)
				near(BuildingConfig[typeId].Levels[level].Cost.Gold / gain, targets[level], `{typeId} L{level}`)
			end
		end
	end)
	test("extra copies pay back in 10, then 20, then 40 minutes", function()
		for _, typeId in { "MoonpetalFarm", "CrystalMine", "CrystalSmelter", "Workshop" } do
			local income = full(typeId, 1)
			local first = if OWNER[typeId] then 1 else 0 -- your first starter building is the tutorial's
			for i, target in { 10, 20, 40 } do
				local price = Formulas.PlaceCost(BuildingConfig[typeId], first + i - 1).Gold
				near(price / income, target, `{typeId} copy {first + i}`)
			end
		end
	end)
end)

describe("Plot layout", function()
	test("the Moonpetal Farm and Crystal Mine take 3x3 tiles", function()
		for _, typeId in { "MoonpetalFarm", "CrystalMine" } do
			local footprint = BuildingConfig[typeId].Footprint
			eq(footprint.X, 3, typeId)
			eq(footprint.Z, 3, typeId)
		end
	end)
end)

describe("Evolutions", function()
	local AssetConfig = shared("Config", "AssetConfig")
	test("every creature has its own three stage names", function()
		for id, species in CreatureConfig.Species do
			local names = {}
			for stage = 1, 3 do
				local name = species.Evolution[stage].Name
				truthy(name and name ~= "", `{id} stage {stage}`)
				falsy(string.find(name, "^Mature ") or string.find(name, "^Ascended "), `{id}: {name}`)
				falsy(names[name], `{id}: {name} repeats`)
				names[name] = true
			end
		end
	end)
	test("every creature has a slot for its stage 2 and 3 models", function()
		for id in CreatureConfig.Species do
			local slots = AssetConfig.EvolutionModels[id]
			truthy(slots and slots[2] ~= nil and slots[3] ~= nil, id)
		end
	end)
end)
