--!nocheck
-- Update 4: research, synergies, couriers, mutations, Ascension, v4 saves.

local H = require("../harness")
local Vector3 = require("@lune/roblox").Vector3
local test, describe, eq, near, truthy, falsy = H.test, H.describe, H.eq, H.near, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local Research = shared("Util", "Research")
local Synergy = shared("Util", "Synergy")
local Mutation = shared("Util", "Mutation")
local Ascension = shared("Util", "Ascension")
local Production = shared("Util", "Production")
local Expedition = shared("Util", "Expedition")
local Encounter = shared("Util", "Encounter")
local ResearchConfig = shared("Config", "ResearchConfig")
local SynergyConfig = shared("Config", "SynergyConfig")
local MutationConfig = shared("Config", "MutationConfig")
local AscensionConfig = shared("Config", "AscensionConfig")
local CreatureConfig = shared("Config", "CreatureConfig")
local BuildingConfig = shared("Config", "BuildingConfig")
local EggConfig = shared("Config", "EggConfig")
local EconomyConfig = shared("Config", "EconomyConfig")
local ExpeditionConfig = shared("Config", "ExpeditionConfig")
local RegionConfig = shared("Config", "RegionConfig")
local GameConfig = shared("Config", "GameConfig")

local function creature(id, species, extra)
	local record = {
		Id = id,
		Species = species,
		Level = 1,
		Xp = 0,
		Stage = 1,
		Source = "Test",
		ObtainedAt = 0,
		Tradable = false,
		WorkCycles = 0,
		JobCycles = {},
		RestUntil = 0,
		AbilityReadyAt = 0,
	}
	for key, value in extra or {} do
		record[key] = value
	end
	return record
end

local function farmId(data)
	for id, building in data.Buildings do
		if building.Type == "MoonpetalFarm" then
			return id
		end
	end
	return nil
end

describe("Research", function()
	test("nodes are well formed: real prerequisites, known effects, phase 4", function()
		local kinds = {
			Modifier = true,
			Silo = true,
			Offline = true,
			Expedition = true,
			Heat = true,
			Mutation = true,
			Synergy = true,
			Unlock = true,
		}
		for id, node in ResearchConfig.Nodes do
			truthy(table.find(ResearchConfig.Branches, node.Branch), id .. " branch")
			truthy(node.Cost.Insight and node.Cost.Insight > 0, id .. " costs Insight")
			for _, required in node.Requires do
				truthy(ResearchConfig.Nodes[required], id .. " requires " .. required)
			end
			for _, effect in node.Effects do
				truthy(kinds[effect.Kind], id .. " effect " .. effect.Kind)
				if effect.Kind == "Unlock" then
					truthy(BuildingConfig[effect.Target].RequiresResearch == id, id .. " unlock target")
				end
			end
		end
	end)
	test("prerequisites are enforced", function()
		local data = Schema.Default(0)
		local ok, reason = Research.CanResearch(data, "SharpPicks", 4)
		falsy(ok)
		truthy(reason:find("Fertile Soil"))
		truthy(Research.CanResearch(data, "FertileSoil", 4))
		data.Research.FertileSoil = 1
		falsy(Research.CanResearch(data, "FertileSoil", 4), "not twice")
		truthy(Research.CanResearch(data, "SharpPicks", 4))
	end)
	test("Fertile Soil raises farm output by 10%; silo and offline effects add up", function()
		local data = Schema.Default(0)
		data.Creatures.a = creature("a", "Sproutling", { Assignment = farmId(data) })
		local before = Production.Rates(data)[farmId(data)].PerSecond
		data.Research.FertileSoil = 1
		local after = Production.Rates(data)[farmId(data)].PerSecond
		near(after / before, 1.1, 1e-6)
		data.Research.Couriers, data.Research.SiloRacks, data.Research.NightShift = 1, 1, 1
		near(Research.SiloMultiplier(data), 1.25, 1e-9)
		eq(Research.OfflineExtra(data), 7200)
	end)
	test("research bonuses respect the category cap", function()
		eq(EconomyConfig.BonusRules.Categories.Research.Cap, 0.5)
		eq(EconomyConfig.BonusRules.Categories.Mutation.Cap, 0.25)
	end)
	test("Field Kits and Heat Wards change expeditions and heat", function()
		local destination = ExpeditionConfig.Destinations.Foothills
		local team = { { Species = "Pebblit", Level = 3, Stage = 1 } }
		local base = Expedition.Chance(destination, team, "Balanced", {})
		near(Expedition.Chance(destination, team, "Balanced", {}, 0.05), math.min(base + 0.05, 0.97), 1e-9)
		local region = RegionConfig.Regions.Emberfall
		local context = { Offset = Vector3.new(0, 0, 0), Eruption = false, OnBridge = false }
		local normal = Encounter.HeatRate(region, context)
		context.Ward = 0.2
		near(Encounter.HeatRate(region, context), normal * 0.8, 1e-9)
	end)
end)

describe("Synergies", function()
	test("config references real families, species and jobs", function()
		for _, synergy in SynergyConfig do
			for _, family in synergy.Families or {} do
				truthy(CreatureConfig.Families[family], synergy.Id .. " family " .. family)
			end
			for _, id in synergy.Species or {} do
				truthy(CreatureConfig.Species[id], synergy.Id .. " species " .. id)
			end
			truthy(synergy.Value > 0 and synergy.Value <= 0.3, synergy.Id .. " value")
		end
	end)
	test("matching rules", function()
		local function ids(list)
			local out = {}
			for _, s in list do
				out[s.Id] = true
			end
			return out
		end
		local farm = ids(Synergy.Active("Farmer", { "Sproutling", "Cindercub" }))
		truthy(farm.SunAndSoil)
		falsy(farm.Irrigation)
		falsy(ids(Synergy.Active("Smelter", { "Sproutling", "Cindercub" })).SunAndSoil, "job-specific")
		truthy(ids(Synergy.Active("Miner", { "Pebblit", "Shardback", "Geodon" })).Pack, "three of a family")
		truthy(ids(Synergy.Active("Farmer", { "Sproutling", "Cindercub", "Pebblit" })).OldFriends)
		eq(#Synergy.Active("Farmer", { "Sproutling" }), 0)
	end)
	test("a synergy raises the building's output and is reported", function()
		local data = Schema.Default(0)
		local farm = farmId(data)
		data.Buildings[farm].Level = 2 -- two slots
		data.Creatures.a = creature("a", "Sproutling", { Assignment = farm })
		data.Creatures.b = creature("b", "Puddlefin", { Assignment = farm })
		local rate = Production.Rates(data)[farm]
		eq(#rate.Synergies, 1)
		eq(rate.Synergies[1], "Irrigation")
		-- Same pair without the synergy bonus.
		local single = Production.WorkerAt(data, data.Creatures.a, data.Buildings[farm], nil)
		truthy(rate.Workers[1].PerSecond > single.PerSecond)
	end)
end)

describe("Couriers", function()
	test("a staffed Courier Post carries, an empty one doesn't", function()
		local data = Schema.Default(0)
		data.Buildings.post = { Id = "post", Type = "CourierPost", Level = 1, X = 0, Z = 0, Rot = 0, Stored = {} }
		eq(Production.Couriers(data).PerSecond, 0)
		data.Creatures.c = creature("c", "Cogling", { Assignment = "post" })
		local couriers = Production.Couriers(data)
		truthy(couriers.PerSecond > 0)
		eq(#couriers.Posts.post.Workers, 1)
		-- Cogling: Courier 1.0, level 1: 4 items per 5 s trip, plus its own stats and passive.
		truthy(couriers.PerSecond >= 0.8 and couriers.PerSecond < 1.2, tostring(couriers.PerSecond))
		eq(Production.Rates(data).post, nil, "couriers aren't a production building")
	end)
	test("enough obtainable couriers exist", function()
		local count = 0
		for _, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase and (species.JobAffinity.Courier or 0) > 0 then
				count += 1
			end
		end
		truthy(count >= 3)
	end)
end)

describe("Mutations", function()
	test("rolls are deterministic and close to the listed odds", function()
		eq(Mutation.Roll("Sproutling", "abc:Egg", 1), Mutation.Roll("Sproutling", "abc:Egg", 1))
		local counts, n = {}, 40000
		for i = 1, n do
			local m = Mutation.Roll("Sproutling", `creature-{i}:Egg`, 1)
			if m then
				counts[m] = (counts[m] or 0) + 1
			end
		end
		near((counts.Prismatic or 0) / n, 0.03, 0.006)
		near((counts.Ancient or 0) / n, 0.02, 0.005)
		eq(counts.Shadow, nil, "Sproutling can't be Shadow")
		local doubled = 0
		for i = 1, n do
			if Mutation.Roll("Sproutling", `creature-{i}:Egg`, 2) then
				doubled += 1
			end
		end
		near(doubled / n, 0.1, 0.012)
	end)
	test("only Umbral creatures can be Shadow", function()
		truthy(table.find(CreatureConfig.Species.Gloomkit.Mutations, "Shadow"))
		falsy(table.find(CreatureConfig.Species.Sproutling.Mutations, "Shadow"))
	end)
	test("bonuses are small and in the capped category", function()
		local bonuses = Mutation.Bonuses("Shadow")
		eq(#bonuses, 2)
		for _, bonus in bonuses do
			eq(bonus.Category, "Mutation")
		end
		eq(#Mutation.Bonuses(nil), 0)
		eq(#Mutation.Bonuses("Nonsense"), 0)
	end)
	test("every species' mutation list is valid", function()
		for id, species in CreatureConfig.Species do
			for _, mutation in species.Mutations do
				truthy(MutationConfig.Mutations[mutation], id .. " mutation " .. mutation)
			end
		end
	end)
end)

describe("Ascension", function()
	local function readyData()
		local data = Schema.Default(0)
		data.Buildings.core.Level = 5
		data.Currencies.Gold = 123456
		data.Currencies.Essence = 500
		data.Currencies.Insight = 80
		data.Resources.Moonpetal = 900
		data.Resources.EmberLure = 3
		data.Expansions.West = true
		data.Research.FertileSoil = 1
		data.Ascension.RunGold = 400000
		data.Creatures.a = creature("a", "Sproutling", { Level = 20, Stage = 2, Mutation = "Prismatic" })
		data.Creatures.a.Assignment = farmId(data)
		data.Collection.Sproutling = { FirstAt = 0, Count = 1 }
		data.Buildings.extra = { Id = "extra", Type = "CrystalMine", Level = 3, X = 0, Z = 0, Rot = 0, Stored = {} }
		return data
	end
	test("needs Empire Core tier 5 and no expeditions away", function()
		local data = Schema.Default(0)
		falsy(Ascension.Check(data))
		data = readyData()
		truthy(Ascension.Check(data))
		data.Expeditions.x = { Id = "x" }
		falsy(Ascension.Check(data))
	end)
	test("shards: 10 x sqrt(run gold / 100k), at least 10", function()
		local data = readyData()
		eq(Ascension.Shards(data), 20)
		data.Ascension.RunGold = 0
		eq(Ascension.Shards(data), AscensionConfig.MinShards)
	end)
	test("what resets and what stays", function()
		local data = readyData()
		data.Ascension.Perks.GoldenStart = 2
		local shards = Ascension.Apply(data, 0)
		eq(shards, 20)
		-- Resets
		eq(data.Currencies.Gold, EconomyConfig.StartingCurrencies.Gold + 4000)
		eq(data.Currencies.Essence, 0)
		eq(data.Currencies.Insight, 0)
		eq(data.Resources.Moonpetal, 0)
		eq(next(data.Expansions), nil)
		eq(next(data.Research), nil)
		eq(data.Buildings.extra, nil)
		eq(data.Buildings.core.Level, 1)
		truthy(farmId(data), "the free farm is back")
		-- Stays
		eq(data.Resources.EmberLure, 3)
		eq(data.Creatures.a.Level, 20)
		eq(data.Creatures.a.Stage, 2)
		eq(data.Creatures.a.Mutation, "Prismatic")
		eq(data.Creatures.a.Assignment, nil)
		truthy(data.Collection.Sproutling)
		eq(data.Ascension.Perks.GoldenStart, 2)
		-- Progress
		eq(data.Ascension.Count, 1)
		eq(data.Ascension.RunGold, 0)
		eq(data.Currencies.EmpireShards, 20)
		-- The reset profile is valid as saved.
		eq(#Schema.Sanitize(data, 0), 0)
	end)
	test("each Ascension and perk adds capped production bonuses", function()
		local data = Schema.Default(0)
		data.Creatures.a = creature("a", "Sproutling", { Assignment = farmId(data) })
		local before = Production.Rates(data)[farmId(data)].PerSecond
		data.Ascension.Count = 2
		local after = Production.Rates(data)[farmId(data)].PerSecond
		near(after / before, 1.2, 1e-6)
		data.Ascension.Perks.SwiftPaws = 99 -- over max rank is clamped
		truthy(Research.PerkTotal(data, "Modifier", "WorkSpeed") <= 0.25 + 1e-9)
	end)
	test("perk prices rise per rank and stop at max", function()
		local data = Schema.Default(0)
		eq(Ascension.PerkCost(data, "SwiftPaws"), 8)
		data.Ascension.Perks.SwiftPaws = 2
		eq(Ascension.PerkCost(data, "SwiftPaws"), 24)
		data.Ascension.Perks.SwiftPaws = 5
		eq(Ascension.PerkCost(data, "SwiftPaws"), nil)
	end)
	test("the first-Ascension creature exists and is obtainable this phase", function()
		local species = CreatureConfig.Species[AscensionConfig.FirstAscensionCreature]
		truthy(species and species.Phase <= GameConfig.Phase)
	end)
end)

describe("Update 4 content", function()
	test("the Arcane Egg's odds add up and every species can be hatched now", function()
		local egg = EggConfig.Eggs.ArcaneEgg
		local total = 0
		for _, entry in egg.Loot do
			total += entry.Weight
			truthy(CreatureConfig.Species[entry.Species].Phase <= GameConfig.Phase, entry.Species)
		end
		eq(total, 100)
	end)
	test("every obtainable species can actually be obtained somewhere", function()
		local sources = {}
		for _, egg in EggConfig.Eggs do
			for _, entry in egg.Loot do
				sources[entry.Species] = true
			end
		end
		for _, entry in RegionConfig.Regions.Emberfall.WildTable do
			sources[entry.Species] = true
		end
		sources[RegionConfig.Regions.Emberfall.Eruption.SpawnSpecies] = true
		for _, destination in ExpeditionConfig.Destinations do
			for _, event in destination.Events do
				if event.Creature then
					sources[event.Creature] = true
				end
			end
		end
		sources[AscensionConfig.FirstAscensionCreature] = true
		sources[shared("Config", "WorldEventConfig").Bloom.FirstWinCreature] = true
		for _, id in CreatureConfig.Starters do
			sources[id] = true
		end
		for _, prize in shared("Config", "SpinConfig").Prizes do
			if prize.Species then
				sources[prize.Species] = true
			end
		end
		for id, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase then
				truthy(sources[id], id .. " has no source")
			end
		end
	end)
end)

describe("Save migration v3 -> v4", function()
	test("adds research and Ascension fields; run gold starts from lifetime gold", function()
		local v3 = Schema.Default(0)
		v3.Version = 3
		v3.Research = nil
		v3.Ascension = { Count = 0, Shards = 0 }
		v3.Stats.GoldEarned = 55555
		truthy(Schema.Migrate(v3))
		eq(v3.Version, Schema.CURRENT_VERSION)
		eq(v3.Ascension.RunGold, 55555)
		truthy(type(v3.Research) == "table" and type(v3.Ascension.Perks) == "table")
		eq(#Schema.Sanitize(v3, 0), 0)
	end)
	test("sanitize drops broken research, perks and mutations", function()
		local data = Schema.Default(0)
		data.Research = { SharpPicks = 1, Nonsense = 2 } -- SharpPicks without Fertile Soil
		data.Ascension.Perks = { SwiftPaws = 9, Fake = 1 }
		data.Creatures.a = creature("a", "Sproutling", { Mutation = "Glitter" })
		Schema.Sanitize(data, 0)
		eq(next(data.Research), nil)
		eq(data.Ascension.Perks.SwiftPaws, 5)
		eq(data.Ascension.Perks.Fake, nil)
		eq(data.Creatures.a.Mutation, nil)
	end)
end)
