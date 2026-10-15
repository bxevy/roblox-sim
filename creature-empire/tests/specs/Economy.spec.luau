--!nocheck
-- Formulas, grid placement, production rates and rate limiting.

local H = require("../harness")
local test, describe, eq, near, truthy, falsy = H.test, H.describe, H.eq, H.near, H.truthy, H.falsy

local Formulas = H.require("ReplicatedStorage", "Shared", "Util", "Formulas")
local Grid = H.require("ReplicatedStorage", "Shared", "Util", "Grid")
local Production = H.require("ReplicatedStorage", "Shared", "Util", "Production")
local EconomyConfig = H.require("ReplicatedStorage", "Shared", "Config", "EconomyConfig")
local BuildingConfig = H.require("ReplicatedStorage", "Shared", "Config", "BuildingConfig")
local CreatureConfig = H.require("ReplicatedStorage", "Shared", "Config", "CreatureConfig")
local PlotConfig = H.require("ReplicatedStorage", "Shared", "Config", "PlotConfig")
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local RateLimiter = H.require("ServerScriptService", "Server", "Core", "RateLimiter")

describe("Formulas.CostAt", function()
	test("level 1 costs the base", function()
		eq(Formulas.CostAt(120, 2.2, 1), 120)
	end)
	test("follows Base * Growth^(level-1), rounded to 2 significant figures", function()
		eq(Formulas.CostAt(120, 2.2, 2), 260) -- 264 -> 260
		eq(Formulas.CostAt(600, 3.6, 3), 7800) -- 7776 -> 7800
	end)
	test("costs strictly increase for every upgradeable building", function()
		for id, def in BuildingConfig do
			local previous = 0
			for level = 2, #def.Levels do
				local cost = def.Levels[level].Cost.Gold
				truthy(cost > previous, `{id} level {level} cost {cost} <= {previous}`)
				previous = cost
			end
		end
	end)
end)

describe("Formulas.CombineBonuses", function()
	local rules = EconomyConfig.BonusRules
	test("same category adds", function()
		near(
			Formulas.CombineBonuses(
				{ { Category = "Passive", Value = 0.1 }, { Category = "Passive", Value = 0.15 } },
				rules
			),
			1.25
		)
	end)
	test("different categories multiply", function()
		near(
			Formulas.CombineBonuses(
				{ { Category = "Passive", Value = 0.1 }, { Category = "Empire", Value = 0.1 } },
				rules
			),
			1.21
		)
	end)
	test("each category is capped", function()
		local cap = rules.Categories.Passive.Cap
		near(Formulas.CombineBonuses({ { Category = "Passive", Value = 5 } }, rules), 1 + cap)
	end)
	test("total is capped at MaxMultiplier", function()
		local list = {}
		for category in rules.Categories do
			table.insert(list, { Category = category, Value = 100 })
		end
		near(Formulas.CombineBonuses(list, rules), rules.MaxMultiplier)
	end)
	test("unknown categories and NaN are ignored", function()
		near(
			Formulas.CombineBonuses(
				{ { Category = "Hacked", Value = 99 }, { Category = "Passive", Value = 0 / 0 } },
				rules
			),
			1
		)
	end)
end)

describe("Formulas.Accumulate / Offline", function()
	test("never exceeds capacity", function()
		local stored, made = Formulas.Accumulate(35, 1, 100, 40)
		eq(stored, 40)
		eq(made, 5)
	end)
	test("no production for negative time or rate", function()
		local stored, made = Formulas.Accumulate(10, 1, -5, 40)
		eq(stored, 10)
		eq(made, 0)
		stored, made = Formulas.Accumulate(10, -1, 5, 40)
		eq(made, 0)
	end)
	test("offline seconds are clamped", function()
		eq(Formulas.OfflineSeconds(1000, 1000 + 99999, 7200), 7200)
		eq(Formulas.OfflineSeconds(1000, 1500, 7200), 500)
		eq(Formulas.OfflineSeconds(2000, 1500, 7200), 0) -- clock went backwards
		eq(Formulas.OfflineSeconds(0, 1500, 7200), 0) -- no record
	end)
	test("placement price follows each building's price list, then doubles", function()
		local farm = BuildingConfig.MoonpetalFarm
		eq(Formulas.PlaceCost(farm, 0).Gold, 150) -- your first one (the tutorial)
		eq(Formulas.PlaceCost(farm, 1).Gold, farm.PlaceCostList[2])
		local last = farm.PlaceCostList[#farm.PlaceCostList]
		eq(Formulas.PlaceCost(farm, #farm.PlaceCostList).Gold, last * 2)
	end)
end)

describe("Grid", function()
	local footprints = {}
	for id, def in BuildingConfig do
		footprints[id] = def.Footprint
	end
	local defaults = H.WithFarm(Schema.Default(0))

	test("rotation swaps the footprint sides", function()
		local x, z = Grid.Rotated({ X = 5, Z = 4 }, 1)
		eq(x, 4)
		eq(z, 5)
		x, z = Grid.Rotated({ X = 5, Z = 4 }, 2)
		eq(x, 5)
	end)
	test("the default layout has no overlaps", function()
		local occupied = {}
		for id, b in defaults.Buildings do
			for _, cell in Grid.Cells(footprints[b.Type], b.X, b.Z, b.Rot) do
				falsy(occupied[cell], `{id} overlaps {occupied[cell]} at {cell}`)
				occupied[cell] = id
			end
			truthy(Grid.InBounds(footprints[b.Type], b.X, b.Z, b.Rot), id .. " out of bounds")
		end
	end)
	test("rejects overlap, out of bounds, the path and bad input", function()
		local occupancy = Grid.Occupancy(defaults.Buildings, footprints)
		local fp = footprints.MoonpetalFarm
		local ok, reason = Grid.CanPlace(occupancy, fp, 4, 10, 0) -- on the starter farm
		falsy(ok)
		eq(reason, "Something is already there.")
		ok = Grid.CanPlace(occupancy, fp, 22, 0, 0) -- hangs off the edge
		falsy(ok)
		ok, reason = Grid.CanPlace(occupancy, fp, 10, 0, 0) -- across the entrance path
		falsy(ok)
		eq(reason, "Keep the entrance path clear.")
		falsy(Grid.CanPlace(occupancy, fp, 1.5, 0, 0))
		falsy(Grid.CanPlace(occupancy, fp, 0, 0, 7))
		falsy(Grid.CanPlace(occupancy, fp, 0 / 0, 0, 0))
		falsy(Grid.CanPlace(occupancy, fp, -1, 0, 0))
	end)
	test("accepts a free spot", function()
		local occupancy = Grid.Occupancy(defaults.Buildings, footprints)
		truthy(Grid.CanPlace(occupancy, footprints.MoonpetalFarm, 0, 0, 0))
		truthy(Grid.CanPlace(occupancy, footprints.MoonpetalFarm, 14, 2, 1))
	end)
	test("a plot has room for the maximum number of farms", function()
		-- Greedy fill: the highest Empire Core tier must be reachable on an empty plot.
		local maxFarms = 0
		for _, level in BuildingConfig.EmpireCore.Levels do
			maxFarms = math.max(maxFarms, level.BuildingLimits.MoonpetalFarm)
		end
		local buildings = H.deepCopy(defaults.Buildings)
		local placed = 1
		for z = 0, PlotConfig.GridZ - 4 do
			for x = 0, PlotConfig.GridX - 4 do
				if placed < maxFarms then
					local occupancy = Grid.Occupancy(buildings, footprints)
					if Grid.CanPlace(occupancy, footprints.MoonpetalFarm, x, z, 0) then
						placed += 1
						buildings["f" .. placed] = { Type = "MoonpetalFarm", X = x, Z = z, Rot = 0 }
					end
				end
			end
		end
		eq(placed, maxFarms, "farms that fit")
	end)
end)

describe("Production", function()
	local function profileWith(speciesId: string, level: number?)
		local data = H.WithFarm(Schema.Default(0))
		data.Creatures.c1 = {
			Id = "c1",
			Species = speciesId,
			Level = level or 1,
			Xp = 0,
			Stage = 1,
			Source = "Test",
			ObtainedAt = 0,
			Tradable = false,
			WorkCycles = 0,
			AbilityReadyAt = 0,
			Assignment = "farm1",
		}
		return data
	end

	test("an assigned Sproutling produces at the expected rate", function()
		local data = profileWith("Sproutling")
		local rate = Production.Rates(data).farm1
		-- speed 1.1 (stat) ; yield 1.2 (stat) * 1.0 affinity * 1.15 (Green Thumb)
		local cycle = 6 / 1.1
		local perCycle = 1 * 1.2 * 1.15
		near(rate.PerSecond, perCycle / cycle, 1e-9)
		eq(#rate.Workers, 1)
		eq(rate.Capacity, 40)
		eq(rate.Output, "Moonpetal")
	end)
	test("the Moonpetal Farm is Sproutling's own: other creatures produce nothing there", function()
		local sprout = Production.Rates(profileWith("Sproutling")).farm1.PerSecond
		local cub = Production.Rates(profileWith("Cindercub")).farm1.PerSecond
		truthy(sprout > 0, "Sproutling farms")
		eq(cub, 0, "Cindercub can't work Sproutling's farm")
	end)
	test("creatures without the job affinity produce nothing", function()
		local data = profileWith("Zappup") -- no Farmer affinity
		eq(Production.Rates(data).farm1.PerSecond, 0)
	end)
	test("unassigned creatures produce nothing", function()
		local data = profileWith("Sproutling")
		data.Creatures.c1.Assignment = nil
		eq(Production.Rates(data).farm1.PerSecond, 0)
	end)
	test("worker slots are enforced", function()
		local data = profileWith("Sproutling")
		data.Creatures.c2 = H.deepCopy(data.Creatures.c1)
		data.Creatures.c2.Id = "c2"
		eq(#Production.Rates(data).farm1.Workers, 1, "level 1 farm has 1 slot")
		data.Buildings.farm1.Level = 2
		eq(#Production.Rates(data).farm1.Workers, 2, "level 2 farm has 2 slots")
	end)
	test("empire tier and level raise output", function()
		local base = Production.Rates(profileWith("Sproutling")).farm1.PerSecond
		local data = profileWith("Sproutling", 10)
		local leveled = Production.Rates(data).farm1.PerSecond
		truthy(leveled > base, "level 10 > level 1")
		data.Buildings.core.Level = 3
		truthy(Production.Rates(data).farm1.PerSecond > leveled, "core tier 3 > tier 1")
	end)
	test("speed buffs apply to the buffed building only", function()
		local data = profileWith("Sproutling")
		local base = Production.Rates(data).farm1.PerSecond
		local buffed = Production.Rates(
			data,
			{ farm1 = { { Stat = "WorkSpeed", Category = "Ability", Value = 0.75, Expires = math.huge } } }
		).farm1.PerSecond
		near(buffed / base, 1.75, 1e-9)
		local elsewhere = Production.Rates(
			data,
			{ other = { { Stat = "WorkSpeed", Category = "Ability", Value = 0.75, Expires = math.huge } } }
		).farm1.PerSecond
		near(elsewhere, base, 1e-12)
	end)
	test("experience levels creatures up and stops at the max level", function()
		local creature = { Level = 1, Xp = 0 }
		local gained = Production.AddXp(creature, CreatureConfig.XpToNext(1) + CreatureConfig.XpToNext(2))
		eq(gained, 2)
		eq(creature.Level, 3)
		eq(creature.Xp, 0)
		Production.AddXp(creature, 1e9)
		eq(creature.Level, CreatureConfig.MaxLevel)
		eq(creature.Xp, 0)
	end)
end)

describe("RateLimiter", function()
	test("allows a burst, then refills over time", function()
		local limiter = RateLimiter.new(3, 1)
		truthy(limiter:Allow("a", 0))
		truthy(limiter:Allow("a", 0))
		truthy(limiter:Allow("a", 0))
		falsy(limiter:Allow("a", 0), "4th request in the same instant")
		truthy(limiter:Allow("b", 0), "other keys are independent")
		truthy(limiter:Allow("a", 1.01), "one token after a second")
		falsy(limiter:Allow("a", 1.02))
	end)
	test("forget clears a player's buckets", function()
		local limiter = RateLimiter.new(1, 0)
		truthy(limiter:Allow("42:x", 0))
		falsy(limiter:Allow("42:x", 0))
		limiter:Forget("42")
		truthy(limiter:Allow("42:x", 0))
	end)
end)

describe("Pacing (informational)", function()
	test("first hour of play reaches Empire Core tier 2", function()
		-- Simulates the new opening: your first starter at its own building, the second
		-- after 5 minutes and the third after 15 (each building bought as it arrives), the
		-- tutorial's gold rewards, and everything sold at the Trading Post every 10 seconds.
		local RecipeConfig = H.require("ReplicatedStorage", "Shared", "Config", "RecipeConfig")
		local ResourceConfig = H.require("ReplicatedStorage", "Shared", "Config", "ResourceConfig")
		local data = Schema.Default(0)
		local gold = data.Currencies.Gold
		local function value(typeId)
			local def = BuildingConfig[typeId]
			local recipe = RecipeConfig[def.Recipe]
			local out = Production.OutputOf(def)
			local v = ResourceConfig[out].SellPrice or 0
			for resource, amount in recipe.Inputs do
				v -= amount / (recipe.Outputs[out] or 1) * (ResourceConfig[resource].SellPrice or 0)
			end
			return v
		end
		local arrivals = {
			{ At = 0, Species = "Sproutling", Building = "MoonpetalFarm", Reward = 170 },
			{ At = 300, Species = "Cindercub", Building = "CrystalSmelter", Reward = 130 },
			{ At = 900, Species = "Pebblit", Building = "CrystalMine", Reward = 270 },
		}
		local pending = {}
		local t = 0
		local tier2At = nil
		while t < 3600 and not tier2At do
			for i, arrival in arrivals do
				if arrival.At == t then
					table.insert(pending, arrival)
				end
				local _ = i
			end
			-- Build each starter's building as soon as it's affordable, then staff it.
			for i = #pending, 1, -1 do
				local arrival = pending[i]
				local cost = Formulas.PlaceCost(BuildingConfig[arrival.Building], 0).Gold
				if gold >= cost then
					gold -= cost
					local id = arrival.Building
					data.Buildings[id] =
						{ Id = id, Type = arrival.Building, Level = 1, X = 0, Z = 0, Rot = 0, Stored = {} }
					data.Creatures[arrival.Species] = {
						Id = arrival.Species,
						Species = arrival.Species,
						Level = 1,
						Xp = 0,
						Stage = 1,
						Source = "Sim",
						ObtainedAt = 0,
						Tradable = false,
						WorkCycles = 0,
						AbilityReadyAt = 0,
						Assignment = id,
					}
					gold += arrival.Reward -- that starter's tutorial steps
					table.remove(pending, i)
				end
			end
			if gold >= BuildingConfig.EmpireCore.Levels[2].Cost.Gold then
				tier2At = t
			end
			t += 10
			for id, rate in Production.Rates(data) do
				gold += rate.PerSecond * 10 * value(data.Buildings[id].Type)
			end
		end
		print(`      tier 2 reached after {tier2At and math.floor(tier2At / 60) or ">60"} minutes`)
		truthy(tier2At and tier2At <= 45 * 60, "tier 2 should be reachable within 45 minutes")
		truthy(tier2At and tier2At >= 15 * 60, "tier 2 should take at least 15 minutes (medium pace)")
	end)
end)
