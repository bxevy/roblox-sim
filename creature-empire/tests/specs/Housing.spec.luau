--!nocheck
-- Habitats update: 5 creatures per Creature Habitat, a backpack for the rest, v8 saves.

local H = require("../harness")
local test, describe, eq, truthy, falsy = H.test, H.describe, H.eq, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local Housing = shared("Util", "Housing")
local Formulas = shared("Util", "Formulas")
local BuildingConfig = shared("Config", "BuildingConfig")
local PlotConfig = shared("Config", "PlotConfig")

local function creature(id, level)
	return {
		Id = id,
		Species = "Sproutling",
		Level = level or 1,
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
end

local function withCreatures(n)
	local data = H.WithFarm(Schema.Default(0))
	for i = 1, n do
		local id = string.format("c%02d", i)
		data.Creatures[id] = creature(id, i)
	end
	return data
end

describe("Habitats and backpack", function()
	test("a new plot has one habitat for 5 creatures and a 40-creature backpack", function()
		local data = H.WithFarm(Schema.Default(0))
		eq(Housing.Habitats(data.Buildings), 1)
		eq(Housing.PlotCapacity(data.Buildings), 5)
		eq(Housing.TotalCapacity(data.Buildings), 45)
		eq(BuildingConfig.Habitat.Levels[1].CreatureCapacity, 5)
		truthy(BuildingConfig.Habitat.Placeable, "you can build more")
	end)
	test("more habitats are allowed at higher Empire Core tiers and cost more each", function()
		local last = 0
		for _, level in BuildingConfig.EmpireCore.Levels do
			local limit = level.BuildingLimits.Habitat
			truthy(limit and limit > last, "limit grows")
			last = limit
		end
		local second = Formulas.PlaceCost(BuildingConfig.Habitat, 1).Gold
		local third = Formulas.PlaceCost(BuildingConfig.Habitat, 2).Gold
		eq(second, 1500)
		truthy(third > second)
	end)
	test("extras move to the backpack: idle and low level first, never ones on expeditions", function()
		local data = withCreatures(8)
		data.Creatures.c01.Assignment = "farm1" -- busy: kept on the plot
		data.Creatures.c02.Expedition = "x" -- away: never moved
		local moved = Housing.Fit(data)
		eq(#moved, 3)
		local plot, backpack = Housing.Counts(data)
		eq(plot, 5)
		eq(backpack, 3)
		falsy(data.Creatures.c01.Stored)
		falsy(data.Creatures.c02.Stored)
		truthy(data.Creatures.c03.Stored and data.Creatures.c04.Stored and data.Creatures.c05.Stored)
		eq(#Housing.Fit(data), 0, "already fits")
	end)
	test("a stored creature stops working and following", function()
		local data = withCreatures(1)
		data.Creatures.c01.Assignment = "farm1"
		data.Companion = "c01"
		Housing.Store(data, "c01")
		truthy(data.Creatures.c01.Stored)
		eq(data.Creatures.c01.Assignment, nil)
		eq(data.Companion, nil)
	end)
	test("a second habitat makes room on the plot", function()
		local data = withCreatures(5)
		falsy(Housing.PlotHasRoom(data))
		data.Buildings.h2 = { Id = "h2", Type = "Habitat", Level = 1, X = 8, Z = 18, Rot = 0, Stored = {} }
		truthy(Housing.PlotHasRoom(data))
		eq(Housing.PlotCapacity(data.Buildings), 10)
	end)
	test("the starter habitat can be moved like any other", function()
		for _, entry in PlotConfig.FixedLayout do
			falsy(entry.Type == "Habitat", "not fixed")
		end
	end)
end)

describe("Save migration v7 -> v8", function()
	test("refunds habitat upgrades, keeps one level and moves extras to the backpack", function()
		local v7 = withCreatures(9)
		v7.Version = 7
		v7.Buildings.habitat.Level = 4
		local gold, refined = v7.Currencies.Gold, v7.Resources.RefinedCrystal or 0
		truthy(Schema.Migrate(v7))
		Schema.Sanitize(v7, 0)
		eq(v7.Version, Schema.CURRENT_VERSION)
		eq(v7.Buildings.habitat.Level, 1)
		local refund = Formulas.CostAt(500, 2.6, 1) + Formulas.CostAt(500, 2.6, 2) + Formulas.CostAt(500, 2.6, 3)
		eq(v7.Currencies.Gold, gold + refund)
		eq(v7.Resources.RefinedCrystal, refined + Formulas.CostAt(10, 2.6, 3))
		local plot, backpack = Housing.Counts(v7)
		eq(plot, 5)
		eq(backpack, 4)
		eq(#Schema.Sanitize(v7, 0), 0, "stable after the first repair")
	end)
end)
