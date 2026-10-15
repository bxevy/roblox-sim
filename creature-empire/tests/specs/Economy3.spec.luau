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
