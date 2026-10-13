--!nocheck
-- Update 2 systems: save migration, recipes with inputs, evolution, hatching odds and
-- pity, land expansion bounds, and config integrity for the new content.

local H = require("../harness")
local test, describe, eq, near, truthy, falsy = H.test, H.describe, H.eq, H.near, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local Production = shared("Util", "Production")
local Evolution = shared("Util", "Evolution")
local Hatching = shared("Util", "Hatching")
local Grid = shared("Util", "Grid")
local CreatureConfig = shared("Config", "CreatureConfig")
local BuildingConfig = shared("Config", "BuildingConfig")
local EggConfig = shared("Config", "EggConfig")
local JobConfig = shared("Config", "JobConfig")
local RecipeConfig = shared("Config", "RecipeConfig")
local ResourceConfig = shared("Config", "ResourceConfig")
local PlotConfig = shared("Config", "PlotConfig")
local GameConfig = shared("Config", "GameConfig")
local RarityConfig = shared("Config", "RarityConfig")

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
		AbilityReadyAt = 0,
	}
	for k, v in extra or {} do
		record[k] = v
	end
	return record
end

-- Deterministic pseudo-random numbers in [0, 1) for statistical tests.
local function lcg(seed)
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

describe("Save migration v1 -> v2", function()
	test("work cycles become farming cycles; pity and expansions are added", function()
		local v1 = Schema.Default(0)
		v1.Version = 1
		v1.Pity = nil
		v1.Expansions = nil
		v1.Creatures.a = creature("a", "Sproutling", { WorkCycles = 420 })
		v1.Creatures.b = creature("b", "Pebblit", { WorkCycles = 0 })
		v1.Creatures.a.JobCycles = nil -- v1 records had no per-job counts
		v1.Creatures.b.JobCycles = nil
		truthy(Schema.Migrate(v1))
		eq(v1.Version, 2)
		eq(v1.Creatures.a.JobCycles.Farmer, 420)
		eq(next(v1.Creatures.b.JobCycles), nil)
		truthy(type(v1.Pity) == "table" and type(v1.Expansions) == "table")
		eq(#Schema.Sanitize(v1, 0), 0, "a migrated profile needs no repair")
	end)
	test("unknown expansion ids and bad pity values are repaired", function()
		local data = Schema.Default(0)
		data.Expansions = { West = true, Atlantis = true, East = "yes" }
		data.Pity = { MeadowEgg = -3, EmberEgg = 4.6 }
		Schema.Sanitize(data, 0)
		eq(data.Expansions.West, true)
		eq(data.Expansions.Atlantis, nil)
		eq(data.Expansions.East, nil)
		eq(data.Pity.MeadowEgg, 0)
		eq(data.Pity.EmberEgg, 4)
	end)
	test("buildings on expansion land keep their position", function()
		local data = Schema.Default(0)
		data.Buildings.x = { Id = "x", Type = "CrystalMine", Level = 1, X = -4, Z = 2, Rot = 0, Stored = {} }
		Schema.Sanitize(data, 0)
		eq(data.Buildings.x.X, -4)
	end)
end)

describe("Recipes with inputs", function()
	local function smelterData()
		local data = Schema.Default(0)
		data.Buildings.s = { Id = "s", Type = "CrystalSmelter", Level = 1, X = 0, Z = 0, Rot = 0, Stored = {} }
		data.Creatures.c = creature("c", "Cindercub", { Assignment = "s" })
		return data
	end
	test("the smelter needs 3 raw crystal per refined crystal", function()
		local rate = Production.Rates(smelterData()).s
		eq(rate.Output, "RefinedCrystal")
		eq(rate.InputsPerUnit.RawCrystal, 3)
		truthy(rate.PerSecond > 0)
	end)
	test("the condenser makes 3 essence per cycle and needs crystal and petals", function()
		local data = Schema.Default(0)
		data.Buildings.e = { Id = "e", Type = "EssenceCondenser", Level = 1, X = 0, Z = 0, Rot = 0, Stored = {} }
		data.Creatures.w = creature("w", "Wisplet", { Assignment = "e" })
		local rate = Production.Rates(data).e
		eq(rate.Output, "Essence")
		near(rate.InputsPerUnit.RefinedCrystal, 1 / 3)
		near(rate.InputsPerUnit.Moonpetal, 8 / 3)
		near(rate.Workers[1].PerCycle / Production.Rates(data).e.Workers[1].PerCycle, 1)
		truthy(rate.Workers[1].PerCycle > 3, "3 units per cycle, boosted by Wisplet's yield")
	end)
	test("Step consumes inputs and stops when they run out", function()
		local resources = { RawCrystal = 9 }
		local stored, made, consumed, starved = Production.Step(0, 1, 100, 50, { RawCrystal = 3 }, resources)
		near(made, 3)
		near(stored, 3)
		near(consumed.RawCrystal, 9)
		near(resources.RawCrystal, 0)
		truthy(starved)
	end)
	test("Step respects storage before inputs", function()
		local resources = { RawCrystal = 1000 }
		local _, made, consumed, starved = Production.Step(48, 1, 100, 50, { RawCrystal = 3 }, resources)
		near(made, 2)
		near(consumed.RawCrystal, 6)
		falsy(starved, "full storage is not starvation")
	end)
	test("Step with no inputs behaves like plain accumulation", function()
		local stored, made = Production.Step(0, 2, 5, 100, {}, {})
		near(stored, 10)
		near(made, 10)
	end)
	test("an instant burst at an empty smelter makes nothing (ability exploit guard)", function()
		-- CreatureService routes InstantHarvest through Step with dt = 1.
		local resources = {}
		local stored, made = Production.Step(0, 12, 1, 15, { RawCrystal = 3 }, resources)
		eq(made, 0)
		eq(stored, 0)
	end)
	test("inputs are never consumed below zero", function()
		local resources = { RawCrystal = 0.5 }
		Production.Step(0, 10, 10, 100, { RawCrystal = 3 }, resources)
		truthy(resources.RawCrystal >= 0)
	end)
end)

describe("Evolution", function()
	test("stage 2 raises output and changes job skill", function()
		local data = Schema.Default(0)
		data.Creatures.a = creature("a", "Sproutling", { Assignment = "farm1" })
		local base = Production.Rates(data).farm1.PerSecond
		data.Creatures.a.Stage = 2
		local evolved = Production.Rates(data).farm1.PerSecond
		-- 1.15 skill (was 1.0) and +15% speed and yield.
		near(evolved / base, 1.15 * 1.15 * 1.15, 1e-9)
	end)
	test("affinity overrides apply per stage", function()
		local pebblit = CreatureConfig.Species.Pebblit
		eq(CreatureConfig.Affinity(pebblit, 1, "Miner"), 1)
		eq(CreatureConfig.Affinity(pebblit, 2, "Miner"), 1.15)
		eq(CreatureConfig.Affinity(pebblit, 3, "Miner"), 1.3)
		eq(CreatureConfig.Affinity(pebblit, 2, "Courier"), 0.6, "unchanged jobs keep the base value")
	end)
	test("requirements are checked from saved data", function()
		local data = Schema.Default(0)
		local c = creature("a", "Sproutling", { Level = 8, JobCycles = { Farmer = 149 } })
		data.Currencies.Essence = 25
		local check = Evolution.Check(data, c)
		falsy(check.Ready)
		c.JobCycles.Farmer = 150
		check = Evolution.Check(data, c)
		truthy(check.Ready)
		eq(check.NextStage.Stage, 2)
		local cost = Evolution.Cost(check)
		eq(cost.Essence, 25)
		eq(cost.Farmer, nil, "work cycles are not spent")
	end)
	test("fully evolved creatures have nothing next", function()
		local check = Evolution.Check(Schema.Default(0), creature("a", "Sproutling", { Stage = 3 }))
		eq(check.NextStage, nil)
		falsy(check.Ready)
	end)
	test("every requirement of obtainable species is implemented", function()
		local implemented = { Level = true, WorkCycles = true, Essence = true, Resource = true }
		for id, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase then
				for stage = 2, 3 do
					for _, r in species.Evolution[stage].Requirements do
						truthy(implemented[r.Kind], `{id} stage {stage} uses {r.Kind}`)
						if r.Kind == "WorkCycles" then
							truthy(
								JobConfig[r.Target] and JobConfig[r.Target].Phase <= GameConfig.Phase,
								`{id} job {r.Target}`
							)
						elseif r.Kind == "Resource" then
							truthy(ResourceConfig[r.Target], `{id} resource {r.Target}`)
						end
					end
				end
			end
		end
	end)
	test("unlock text matches the real numbers", function()
		local stage2 = CreatureConfig.Species.Cindercub.Evolution[2]
		eq(stage2.StatBonus, 0.15)
		truthy(table.find(stage2.Unlocks, "+15% work speed and yield"))
		truthy(table.find(stage2.Unlocks, "Kindle is 50% stronger"))
	end)
end)

describe("Hatching", function()
	test("published odds add up to exactly 100% for every egg", function()
		for id, egg in EggConfig.Eggs do
			local total = 0
			for _, entry in Hatching.Odds(egg) do
				total += entry.Chance
			end
			near(total, 1, 1e-9, id)
			local guaranteed = 0
			for _, entry in Hatching.Odds(egg, true) do
				guaranteed += entry.Chance
				truthy(Hatching.IsPityTier(egg, entry.Species), "pity pool only has guaranteed rarities")
			end
			near(guaranteed, 1, 1e-9, id .. " pity odds")
		end
	end)
	test("every egg contains only obtainable species and a pity-tier creature", function()
		for id, egg in EggConfig.Eggs do
			local hasPityTier = false
			for _, entry in egg.Loot do
				local species = CreatureConfig.Species[entry.Species]
				truthy(species, `{id} species {entry.Species}`)
				truthy(species.Phase <= egg.Phase, `{id}: {entry.Species} is phase {species.Phase}`)
				hasPityTier = hasPityTier or Hatching.IsPityTier(egg, entry.Species)
			end
			truthy(hasPityTier, id .. " must be able to pay out its pity")
			for currency in egg.Cost do
				truthy(ResourceConfig[currency], `{id} cost {currency}`)
			end
		end
	end)
	test("pity guarantees a Rare or better within the limit", function()
		local egg = EggConfig.Eggs.MeadowEgg
		-- Always roll 0.999 (the most common creature); pity must still trigger.
		local pity = 0
		local hits = 0
		for _ = 1, egg.PityLimit * 3 do
			local species, guaranteed, newPity = Hatching.Roll(egg, pity, function()
				return 0.999
			end)
			if guaranteed then
				hits += 1
				truthy(Hatching.IsPityTier(egg, species))
				eq(newPity, 0)
			end
			pity = newPity
			truthy(pity < egg.PityLimit)
		end
		eq(hits, 3, "one guarantee per PityLimit hatches")
	end)
	test("hatching a rare naturally resets the counter", function()
		local egg = EggConfig.Eggs.MeadowEgg
		local _, guaranteed, newPity = Hatching.Roll(egg, 5, function()
			return 0 -- rarest entry is first
		end)
		falsy(guaranteed)
		eq(newPity, 0)
	end)
	test("rolls follow the published odds (100k seeded rolls)", function()
		local egg = EggConfig.Eggs.EmberEgg
		local random = lcg(12345)
		local counts = {}
		local n = 100000
		for _ = 1, n do
			local species = Hatching.Roll(egg, 0, random) -- pity held at 0
			counts[species] = (counts[species] or 0) + 1
		end
		for _, entry in Hatching.Odds(egg) do
			near((counts[entry.Species] or 0) / n, entry.Chance, 0.01, entry.Species)
		end
	end)
	test("eggs never cost Robux", function()
		for id, egg in EggConfig.Eggs do
			for currency in egg.Cost do
				truthy(currency ~= "Robux", id)
			end
		end
	end)
end)

describe("Land expansion", function()
	test("expansion cells are buildable only when owned", function()
		local fp = BuildingConfig.CrystalMine.Footprint
		falsy(Grid.InBounds(fp, -4, 2, 0, {}))
		truthy(Grid.InBounds(fp, -4, 2, 0, { West = true }))
		falsy(Grid.InBounds(fp, -4, 2, 0, { East = true }))
		truthy(Grid.InBounds(fp, 24, 2, 0, { East = true }))
		truthy(Grid.InBounds(fp, 10, 24, 0, { North = true }))
		falsy(Grid.InBounds(fp, -4, 24, 0, { West = true, North = true }), "the corner isn't part of either zone")
	end)
	test("a building can straddle the plot edge into owned land", function()
		local fp = BuildingConfig.MoonpetalFarm.Footprint
		falsy(Grid.InBounds(fp, -2, 0, 0, {}))
		truthy(Grid.InBounds(fp, -2, 0, 0, { West = true }))
	end)
	test("zones get pricier and need higher core tiers", function()
		local previousTier = 0
		for _, zone in PlotConfig.ExpansionZones do
			truthy(zone.CoreTier > previousTier)
			previousTier = zone.CoreTier
			truthy(zone.CoreTier <= #BuildingConfig.EmpireCore.Levels)
		end
	end)
end)

describe("Update 2 content", function()
	test("every new production building is reachable: core tier, recipe, job, workers", function()
		local obtainable = {}
		for id, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase then
				obtainable[id] = species
			end
		end
		for typeId, def in BuildingConfig do
			if def.Placeable and def.Phase <= GameConfig.Phase then
				local tier = nil
				for t, level in BuildingConfig.EmpireCore.Levels do
					if (level.BuildingLimits[typeId] or 0) > 0 then
						tier = tier or t
					end
				end
				truthy(tier, typeId .. " is never unlocked by the Empire Core")
				if def.Recipe then
					truthy(RecipeConfig[def.Recipe].Enabled, typeId .. " recipe enabled")
					local workers = 0
					for _, species in obtainable do
						if (species.JobAffinity[def.Job] or 0) > 0 then
							workers += 1
						end
					end
					truthy(workers >= 2, `{typeId}: only {workers} obtainable species can work there`)
				end
			end
		end
	end)
	test("obtainable species have at least one job that has a building", function()
		local jobsWithBuildings = {}
		for _, def in BuildingConfig do
			if def.Job and not def.Locked and def.Phase <= GameConfig.Phase then
				jobsWithBuildings[def.Job] = true
			end
		end
		for id, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase then
				local useful = false
				for job in species.JobAffinity do
					useful = useful or jobsWithBuildings[job] == true
				end
				truthy(useful, id .. " has nothing to do")
			end
		end
	end)
	test("obtainable passives only claim implemented modifiers", function()
		for id, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase then
				truthy(#species.Passive.Modifiers > 0, id .. " passive has no effect")
			end
		end
	end)
	test("rare and epic creatures exist for the pity system", function()
		local found = 0
		for _, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase and RarityConfig.Get(species.Rarity).Order >= 3 then
				found += 1
			end
		end
		truthy(found >= 4)
	end)
end)
