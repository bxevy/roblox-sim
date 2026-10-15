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
