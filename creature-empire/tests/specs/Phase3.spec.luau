--!nocheck
-- Update 3: Emberfall Basin, expeditions, guardian combat, befriending, heat, v3 saves.

local H = require("../harness")
local Vector3 = require("@lune/roblox").Vector3
local test, describe, eq, near, truthy, falsy = H.test, H.describe, H.eq, H.near, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local Rng = shared("Util", "Rng")
local Stats = shared("Util", "Stats")
local Expedition = shared("Util", "Expedition")
local Combat = shared("Util", "Combat")
local Encounter = shared("Util", "Encounter")
local CreatureConfig = shared("Config", "CreatureConfig")
local ExpeditionConfig = shared("Config", "ExpeditionConfig")
local CombatConfig = shared("Config", "CombatConfig")
local RegionConfig = shared("Config", "RegionConfig")
local ResourceConfig = shared("Config", "ResourceConfig")
local GameConfig = shared("Config", "GameConfig")

local region = RegionConfig.Regions.Emberfall

local function member(species, level, stage)
	return { Species = species, Level = level or 1, Stage = stage or 1 }
end

describe("Seeded RNG", function()
	test("same seed, same sequence; different seeds differ", function()
		local a, b, c = Rng.new(42), Rng.new(42), Rng.new(43)
		local same, different = true, false
		for _ = 1, 50 do
			local x, y, z = a:Next(), b:Next(), c:Next()
			same = same and x == y
			different = different or x ~= z
			truthy(x >= 0 and x < 1)
		end
		truthy(same)
		truthy(different)
	end)
	test("Int stays within bounds", function()
		local rng = Rng.new(7)
		for _ = 1, 1000 do
			local n = rng:Int(3, 5)
			truthy(n >= 3 and n <= 5 and n == math.floor(n))
		end
	end)
end)

describe("Effective stats", function()
	test("level and stage raise stats", function()
		local magmaul = CreatureConfig.Species.Magmaul
		eq(Stats.Effective(magmaul, 1, 1, "CombatPower"), 15)
		truthy(Stats.Effective(magmaul, 10, 1, "CombatPower") > 15)
		near(Stats.Effective(magmaul, 1, 2, "CombatPower"), 15 * 1.15)
	end)
end)

describe("Expeditions", function()
	local foothills = ExpeditionConfig.Destinations.Foothills
	local rim = ExpeditionConfig.Destinations.Rim
	test("a stronger team has a better chance", function()
		local weak = Expedition.Chance(rim, { member("Sproutling") }, "Balanced", {})
		local strong = Expedition.Chance(
			rim,
			{ member("Pyrewing", 20, 2), member("Magmaul", 20, 2), member("Geodon", 20, 2) },
			"Balanced",
			{}
		)
		truthy(strong > weak + 0.2, `strong {strong} vs weak {weak}`)
	end)
	test("approach and supplies change the chance as described", function()
		local team = { member("Cindercub", 5) }
		local balanced = Expedition.Chance(foothills, team, "Balanced", {})
		near(Expedition.Chance(foothills, team, "Cautious", {}) - balanced, 0.15, 1e-9)
		near(balanced - Expedition.Chance(foothills, team, "Bold", {}), 0.15, 1e-9)
		near(Expedition.Chance(foothills, team, "Balanced", { "HeatShield" }) - balanced, 0.1, 1e-9)
	end)
	test("chance is always between 5% and 97%", function()
		truthy(Expedition.Chance(rim, {}, "Bold", {}) >= 0.05)
		local team = {}
		for _ = 1, 3 do
			table.insert(team, member("Pyrewing", 30, 3))
		end
		truthy(Expedition.Chance(foothills, team, "Cautious", { "HeatShield" }) <= 0.97)
	end)
	test("the same seed always gives the same outcome", function()
		local team = { member("Ashwhisk", 6) }
		local a = Expedition.Resolve(ExpeditionConfig.Destinations.Tunnels, team, "Bold", {}, 99)
		local b = Expedition.Resolve(ExpeditionConfig.Destinations.Tunnels, team, "Bold", {}, 99)
		eq(a.Success, b.Success)
		for resource, amount in a.Rewards do
			eq(b.Rewards[resource], amount)
		end
		eq(#a.Events, #b.Events)
	end)
	test("failure pays a quarter; success pays within the published ranges", function()
		local team = { member("Cindercub") }
		local successes, failures = 0, 0
		for seed = 1, 400 do
			local outcome = Expedition.Resolve(foothills, team, "Balanced", {}, seed)
			local gold = outcome.Rewards.Gold or 0
			if outcome.Success then
				successes += 1
				truthy(gold >= 300, "success gold ≥ min")
			else
				failures += 1
				truthy(gold <= 600 * 0.25 + 250, "failure gold is reduced")
				eq(#outcome.Creatures, 0, "no creatures on failure")
			end
		end
		truthy(successes > 0 and failures > 0)
		near(successes / 400, Expedition.Chance(foothills, team, "Balanced", {}), 0.08)
	end)
	test("rations remove the rest period", function()
		eq(Expedition.RestSeconds(foothills, { "Rations" }), 0)
		eq(Expedition.RestSeconds(foothills, {}), foothills.Duration * ExpeditionConfig.RestFraction)
	end)
	test("every destination's rewards and events reference real things", function()
		for id, destination in ExpeditionConfig.Destinations do
			for _, reward in destination.Rewards do
				truthy(ResourceConfig[reward.Resource], `{id} reward {reward.Resource}`)
				truthy(reward.Max >= reward.Min)
			end
			for _, event in destination.Events do
				for resource in event.Reward or {} do
					truthy(ResourceConfig[resource], `{id} event reward {resource}`)
				end
				if event.Creature then
					local species = CreatureConfig.Species[event.Creature]
					truthy(species and species.Phase <= GameConfig.Phase, `{id} event creature {event.Creature}`)
				end
			end
			for stat in destination.Recommended do
				truthy(CreatureConfig.Species.Sproutling.BaseStats[stat], `{id} recommends unknown stat {stat}`)
			end
		end
	end)
end)

describe("Guardian combat", function()
	local matriarch = CombatConfig.Guardians.Matriarch
	test("elements: Tideborn beats Emberkin, Emberkin resists Emberkin", function()
		local tide = Combat.Damage("Puddlefin", 1, 1, "Emberkin", false, 0)
		local fire = Combat.Damage("Cindercub", 1, 1, "Emberkin", false, 0)
		-- Puddlefin CombatPower 10 x1.5; Cindercub 12 x0.5
		eq(tide, 15)
		eq(fire, 6)
	end)
	test("special hits harder and teams get a capped bonus", function()
		truthy(
			Combat.Damage("Magmaul", 1, 1, "Emberkin", true, 0) > Combat.Damage("Magmaul", 1, 1, "Emberkin", false, 0)
		)
		local solo = Combat.Damage("Geodon", 10, 2, "Emberkin", false, 0)
		local duo = Combat.Damage("Geodon", 10, 2, "Emberkin", false, 1)
		local crowd = Combat.Damage("Geodon", 10, 2, "Emberkin", false, 10)
		truthy(duo > solo)
		near(crowd / solo, 1 + CombatConfig.MaxTeamBonus, 0.05)
	end)
	test("health scales with players; phases follow health", function()
		eq(Combat.MaxHealth(matriarch, 1), matriarch.BaseHealth)
		eq(Combat.MaxHealth(matriarch, 3), matriarch.BaseHealth + 2 * matriarch.HealthPerExtraPlayer)
		eq((Combat.Phase(matriarch, 1)), 1)
		eq((Combat.Phase(matriarch, 0.5)), 2)
		eq((Combat.Phase(matriarch, 0.1)), 3)
	end)
	test("support companions are Verdant and Tideborn", function()
		truthy(Combat.IsSupport("Sproutling"))
		truthy(Combat.IsSupport("Puddlefin"))
		falsy(Combat.IsSupport("Magmaul"))
	end)
	test("a solo starter can win in a reasonable number of hits", function()
		-- Pebblit (Crystalkin, x1.25) at level 10, attacking every 1.2 s.
		local hit = Combat.Damage("Pebblit", 10, 1, "Emberkin", false, 0)
		local special = Combat.Damage("Pebblit", 10, 1, "Emberkin", true, 0)
		local perMinute = hit * (60 / CombatConfig.Attack.Cooldown) + special * (60 / CombatConfig.Special.Cooldown)
		local minutes = matriarch.BaseHealth / perMinute
		print(`      solo Pebblit Lv10: about {math.floor(minutes * 10) / 10} minutes`)
		truthy(minutes > 1 and minutes < 6)
	end)
end)

describe("Befriending and heat", function()
	test("rarer creatures are harder; same-family companions help", function()
		local common = Encounter.BefriendChance("Cindercub", nil)
		local rare = Encounter.BefriendChance("Magmaul", nil)
		truthy(common > rare)
		truthy(Encounter.BefriendChance("Magmaul", member("Cindercub")) > rare, "Emberkin helps Emberkin")
		truthy(Encounter.BefriendChance("Pyrewing", member("Sproutling")) >= 0.05)
	end)
	test("heat builds, pools cool, lava burns, fire companions resist", function()
		local open = Vector3.new(-150, 3, 180)
		local base = Encounter.HeatRate(region, { Offset = open, Eruption = false, OnBridge = false })
		near(base, region.Heat.BaseRate)
		local resisted = Encounter.HeatRate(
			region,
			{ Offset = open, CompanionFamily = "Emberkin", Eruption = false, OnBridge = false }
		)
		near(resisted, base * 0.5)
		local pool = region.Pools[1]
		truthy(Encounter.HeatRate(region, { Offset = pool, Eruption = true, OnBridge = false }) < 0)
		local lava = region.Lava[1].From:Lerp(region.Lava[1].To, 0.3)
		truthy(Encounter.HeatRate(region, { Offset = lava, Eruption = false, OnBridge = false }) > 10)
		near(Encounter.HeatRate(region, { Offset = lava, Eruption = false, OnBridge = true }), base, 1e-9)
		truthy(Encounter.HeatRate(region, { Offset = open, Eruption = true, OnBridge = false }) > base)
	end)
	test("a full heat bar takes over two minutes in the open", function()
		truthy(region.Heat.Max / region.Heat.BaseRate > 120)
	end)
end)

describe("Emberfall layout", function()
	test("nodes, spawns and landmarks are inside the region and off the lava", function()
		local function check(name, offset)
			truthy(RegionConfig.Contains(region, region.Center + offset), name .. " outside region")
			for _, lava in region.Lava do
				truthy(
					RegionConfig.DistanceToSegment(offset, lava.From, lava.To) > lava.Width / 2 + 2,
					name .. " is in lava"
				)
			end
		end
		for _, node in region.Nodes do
			check("node " .. node.Id, node.Offset)
			truthy(region.NodeKinds[node.Kind], node.Id .. " kind")
		end
		for i, spawn in region.WildSpawns do
			check("spawn " .. i, spawn)
		end
		for _, landmark in region.Landmarks do
			truthy(RegionConfig.Contains(region, region.Center + landmark.Offset), landmark.Id)
		end
		check("arrival", region.ArrivalOffset)
	end)
	test("wild table species can be obtained this update", function()
		local total = 0
		for _, entry in region.WildTable do
			local species = CreatureConfig.Species[entry.Species]
			truthy(species and species.Phase <= GameConfig.Phase, entry.Species)
			total += entry.Weight
		end
		eq(total, 100)
		local eruption = CreatureConfig.Species[region.Eruption.SpawnSpecies]
		truthy(eruption and eruption.Phase <= GameConfig.Phase)
	end)
	test("exactly one landmark is hidden and its trail leads there", function()
		local hidden = {}
		for _, landmark in region.Landmarks do
			if landmark.Hidden then
				table.insert(hidden, landmark)
			end
		end
		eq(#hidden, 1)
		local last = region.Footprints[#region.Footprints]
		truthy((last - hidden[1].Offset).Magnitude < 25)
	end)
	test("the region is far from the empire plots", function()
		truthy(RegionConfig.At(Vector3.new(0, 0, 0)) == nil)
		truthy(RegionConfig.At(Vector3.new(150, 0, 150)) == nil)
		truthy(RegionConfig.Contains(region, region.Center))
		-- Only switched-on regions are found (Emberfall is off for now).
		if RegionConfig.IsOpen(region.Id) then
			truthy(RegionConfig.At(region.Center) == region)
		else
			truthy(RegionConfig.At(region.Center) == nil)
		end
	end)

	test("a switched-off region is closed everywhere", function()
		for _, id in RegionConfig.All do
			local open = RegionConfig.IsOpen(id)
			truthy(table.find(RegionConfig.Order, id) ~= nil == open, id)
		end
		truthy(not RegionConfig.IsOpen("Nowhere"))
	end)
end)

describe("Save migration v2 -> v3", function()
	test("adds expedition, discovery and guardian records", function()
		local v2 = H.WithFarm(Schema.Default(0))
		v2.Version = 2
		v2.Expeditions, v2.Discoveries, v2.Guardians = nil, nil, nil
		v2.Creatures.a = {
			Id = "a",
			Species = "Sproutling",
			Level = 3,
			Xp = 0,
			Stage = 1,
			Source = "Starter",
			ObtainedAt = 0,
			Tradable = false,
			WorkCycles = 10,
			JobCycles = { Farmer = 10 },
			AbilityReadyAt = 0,
		}
		truthy(Schema.Migrate(v2))
		eq(v2.Version, Schema.CURRENT_VERSION)
		eq(v2.Creatures.a.RestUntil, 0)
		eq(#Schema.Sanitize(v2, 0), 0)
	end)
	test("broken expeditions free their creatures; companions must be free", function()
		local data = H.WithFarm(Schema.Default(0))
		data.Creatures.a = {
			Id = "a",
			Species = "Sproutling",
			Level = 1,
			Xp = 0,
			Stage = 1,
			Source = "T",
			ObtainedAt = 0,
			Tradable = false,
			WorkCycles = 0,
			JobCycles = {},
			AbilityReadyAt = 0,
			RestUntil = 0,
			Expedition = "x1",
		}
		data.Expeditions.x1 = { Destination = "Nowhere", Creatures = { "a" }, EndsAt = 10, Seed = 1 }
		data.Companion = "a"
		Schema.Sanitize(data, 0)
		eq(data.Expeditions.x1, nil)
		eq(data.Creatures.a.Expedition, nil)
		eq(data.Companion, "a", "a free creature can stay companion")
		data.Creatures.a.Assignment = "farm1"
		Schema.Sanitize(data, 0)
		eq(data.Companion, nil, "a working creature can't also follow you")
	end)
	test("a valid expedition survives and keeps its creature off work", function()
		local data = H.WithFarm(Schema.Default(0))
		data.Creatures.a = {
			Id = "a",
			Species = "Cindercub",
			Level = 1,
			Xp = 0,
			Stage = 1,
			Source = "T",
			ObtainedAt = 0,
			Tradable = false,
			WorkCycles = 0,
			JobCycles = {},
			AbilityReadyAt = 0,
			RestUntil = 0,
			Expedition = "x1",
			Assignment = "farm1",
		}
		data.Expeditions.x1 = {
			Destination = "Foothills",
			Creatures = { "a" },
			StartedAt = 0,
			EndsAt = 300,
			Seed = 5,
			Approach = "Bold",
			Supplies = {},
		}
		Schema.Sanitize(data, 0)
		truthy(data.Expeditions.x1)
		eq(data.Creatures.a.Expedition, "x1")
		eq(data.Creatures.a.Assignment, nil)
	end)
end)
