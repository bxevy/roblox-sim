--!nocheck
-- Update 5: trading, world events, leaderboards, collaborators, v5 saves.

local H = require("../harness")
local test, describe, eq, near, truthy, falsy = H.test, H.describe, H.eq, H.near, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local Trade = shared("Util", "Trade")
local WorldEvent = shared("Util", "WorldEvent")
local Leaderboard = shared("Util", "Leaderboard")
local Expedition = shared("Util", "Expedition")
local SocialConfig = shared("Config", "SocialConfig")
local WorldEventConfig = shared("Config", "WorldEventConfig")
local ExpeditionConfig = shared("Config", "ExpeditionConfig")
local LeaderboardConfig = shared("Config", "LeaderboardConfig")
local CreatureConfig = shared("Config", "CreatureConfig")
local GameConfig = shared("Config", "GameConfig")

local function creature(id, species, extra)
	local record = {
		Id = id,
		Species = species,
		Level = 5,
		Xp = 0,
		Stage = 1,
		Source = "Egg",
		ObtainedAt = 0,
		Tradable = true,
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

local function limits(creatures, capacity)
	return {
		CreatureCapacity = creatures or 6,
		Capacity = function()
			return capacity or 150
		end,
	}
end

describe("Trading rules", function()
	test("offers from clients are shape-checked", function()
		truthy(Trade.Clean({ Creatures = { "a" }, Resources = { EmberLure = 2 } }))
		falsy(Trade.Clean({ Creatures = { "a", "a" }, Resources = {} }), "duplicate creature")
		falsy(Trade.Clean({ Creatures = {}, Resources = { Gold = 10 } }), "gold can't be traded")
		falsy(Trade.Clean({ Creatures = {}, Resources = { Moonpetal = 10 } }), "materials can't be traded")
		falsy(Trade.Clean({ Creatures = {}, Resources = { EmpireShards = 5 } }), "shards can't be traded")
		falsy(Trade.Clean({ Creatures = {}, Resources = { EmberLure = -5 } }), "negative")
		falsy(Trade.Clean({ Creatures = {}, Resources = { EmberLure = 1.5 } }), "fractional")
		falsy(Trade.Clean({ Creatures = {}, Resources = { EmberLure = 0 / 0 } }), "NaN")
		falsy(Trade.Clean({ Creatures = { "a", "b", "c", "d", "e" }, Resources = {} }), "too many creatures")
		falsy(Trade.Clean("nope"))
		eq(next(Trade.Clean({ Creatures = {}, Resources = { EmberLure = 0 } }).Resources), nil, "zero amounts dropped")
	end)
	test("only your own tradable, free creatures and items you have", function()
		local data = H.WithFarm(Schema.Default(0))
		data.Creatures.a = creature("a", "Mossmaw")
		data.Creatures.s = creature("s", "Sproutling", { Tradable = false, Source = "Starter" })
		data.Creatures.e = creature("e", "Zappup", { Expedition = "x" })
		data.Creatures.c = creature("c", "Ashwhisk")
		data.Companion = "c"
		data.Resources.EmberLure = 3
		truthy(Trade.CanGive(data, { Creatures = { "a" }, Resources = { EmberLure = 3 } }))
		falsy(Trade.CanGive(data, { Creatures = { "s" }, Resources = {} }), "starter")
		falsy(Trade.CanGive(data, { Creatures = { "e" }, Resources = {} }), "away")
		falsy(Trade.CanGive(data, { Creatures = { "c" }, Resources = {} }), "companion")
		falsy(Trade.CanGive(data, { Creatures = { "zzz" }, Resources = {} }), "not owned")
		falsy(Trade.CanGive(data, { Creatures = {}, Resources = { EmberLure = 4 } }), "too many lures")
	end)
	test("the receiver needs habitat and stack room (after what they give away)", function()
		local data = H.WithFarm(Schema.Default(0))
		for i = 1, 6 do
			data.Creatures["c" .. i] = creature("c" .. i, "Mossmaw")
		end
		data.Resources.EmberLure = 18
		local incoming = { Creatures = { "x" }, Resources = {} }
		falsy(Trade.CanReceive(data, incoming, Trade.Empty(), limits(6, 20)), "habitat full")
		falsy(Trade.CanReceive(data, { Creatures = {}, Resources = { EmberLure = 3 } }, Trade.Empty(), limits(6, 20)))
		truthy(
			Trade.CanReceive(data, incoming, { Creatures = { "c1" }, Resources = {} }, limits(6, 20)),
			"giving one away makes room"
		)
	end)
	test("a trade swaps everything exactly once", function()
		local a, b = H.WithFarm(Schema.Default(0)), H.WithFarm(Schema.Default(0))
		a.Creatures.m = creature("m", "Mossmaw", { Assignment = "farm1" })
		b.Creatures.z = creature("z", "Zappup")
		a.Resources.EmberLure = 5
		local offerA = { Creatures = { "m" }, Resources = { EmberLure = 2 } }
		local offerB = { Creatures = { "z" }, Resources = {} }
		truthy(Trade.Validate(a, offerA, limits(), b, offerB, limits()))
		Trade.Apply(a, offerA, b, offerB, 100)
		eq(a.Creatures.m, nil)
		eq(b.Creatures.m.Species, "Mossmaw")
		eq(b.Creatures.m.Assignment, nil, "unassigned on arrival")
		eq(a.Creatures.z.Species, "Zappup")
		eq(a.Resources.EmberLure, 3)
		eq(b.Resources.EmberLure, 2)
		truthy(b.Collection.Mossmaw and a.Collection.Zappup, "journals updated")
		eq(a.Stats.Trades, 1)
		eq(#Schema.Sanitize(a, 0), 0)
		eq(#Schema.Sanitize(b, 0), 0)
	end)
	test("empty trades are refused", function()
		local a, b = H.WithFarm(Schema.Default(0)), H.WithFarm(Schema.Default(0))
		falsy(Trade.Validate(a, Trade.Empty(), limits(), b, Trade.Empty(), limits()))
	end)
end)

describe("World events", function()
	test("the schedule rotates and every event fits inside its period", function()
		local period = WorldEventConfig.Period
		local kinds = {}
		for i = 0, #WorldEventConfig.Rotation - 1 do
			local slot = WorldEvent.At(1e6 * period + i * period + 1)
			kinds[slot.Kind] = true
			truthy(slot.Active)
			truthy(slot.EndsAt - slot.StartsAt <= period)
			eq(slot.NextAt, slot.StartsAt + period)
		end
		for _, kind in WorldEventConfig.Rotation do
			truthy(kinds[kind], kind)
			truthy(WorldEventConfig.Events[kind], kind .. " defined")
		end
		local quiet =
			WorldEvent.At(1e6 * period + WorldEventConfig.Events[WorldEvent.At(1e6 * period).Kind].Duration + 5)
		falsy(quiet.Active)
	end)
	test("rift bonus grows per team and is capped; bloom goal scales with players", function()
		eq(WorldEvent.RiftBonus(1), 0)
		near(WorldEvent.RiftBonus(3), 0.12, 1e-9)
		eq(WorldEvent.RiftBonus(50), WorldEventConfig.Rift.MaxBonus)
		eq(WorldEvent.BloomGoal(0), WorldEventConfig.Bloom.MinGoal)
		eq(WorldEvent.BloomGoal(4), 4 * WorldEventConfig.Bloom.GoalPerPlayer)
	end)
	test("the rift is an event-only destination and more teams mean better odds", function()
		local rift = ExpeditionConfig.Destinations[WorldEventConfig.Rift.Destination]
		truthy(rift and rift.EventOnly)
		local team = { { Species = "Pebblit", Level = 10, Stage = 1 } }
		local solo = Expedition.Chance(rift, team, "Balanced", {}, WorldEvent.RiftBonus(1))
		local party = Expedition.Chance(rift, team, "Balanced", {}, WorldEvent.RiftBonus(4))
		truthy(party > solo)
		-- Same seed, same result.
		local a = Expedition.Resolve(rift, team, "Balanced", {}, 1234, 0.1)
		local b = Expedition.Resolve(rift, team, "Balanced", {}, 1234, 0.1)
		eq(a.Success, b.Success)
	end)
	test("rewarded creatures exist and are obtainable now", function()
		local species = CreatureConfig.Species[WorldEventConfig.Bloom.FirstWinCreature]
		truthy(species and species.Phase <= GameConfig.Phase)
	end)
end)

describe("Leaderboards", function()
	test("weeks start on Monday 00:00 UTC", function()
		-- 2024-01-01 was a Monday.
		local monday = 1704067200
		eq(Leaderboard.Week(monday), Leaderboard.Week(monday + 6 * 86400 + 86399))
		eq(Leaderboard.Week(monday) + 1, Leaderboard.Week(monday + 7 * 86400))
		eq(Leaderboard.Week(monday - 1) + 1, Leaderboard.Week(monday))
	end)
	test("scores come from saved data", function()
		local data = H.WithFarm(Schema.Default(0))
		local base = Leaderboard.Score("Empire", data, 0)
		data.Buildings.core.Level = 3
		data.Creatures.a = creature("a", "Mossmaw", { Level = 10, Stage = 2 })
		data.Ascension.Count = 1
		eq(Leaderboard.Score("Empire", data, 0), base + 2000 + 150 + 5000)
		data.Collection.Mossmaw = { FirstAt = 0, Count = 1 }
		eq(Leaderboard.Score("Collection", data, 0), 1)
		data.Stats.Expeditions = 4
		data.Discoveries.Gate = 1
		data.Guardians.Matriarch = { Defeats = 2, LastRewardAt = 0 }
		eq(Leaderboard.Score("Explorers", data, 0), 7)
		local now = 1704067200
		data.Season = { Week = Leaderboard.Week(now), Gold = 1234.7 }
		eq(Leaderboard.Score("WeeklyGold", data, now), 1234)
		eq(Leaderboard.Score("WeeklyGold", data, now + 8 * 86400), 0, "last week's gold doesn't count")
	end)
	test("every board has a score function", function()
		local data = H.WithFarm(Schema.Default(0))
		for _, board in LeaderboardConfig.Boards do
			truthy(type(Leaderboard.Score(board.Id, data, 0)) == "number", board.Id)
		end
	end)
end)

describe("Save migration v4 -> v5", function()
	test("adds collaborators, world event records and the weekly season", function()
		local v4 = H.WithFarm(Schema.Default(0))
		v4.Version = 4
		v4.Collaborators, v4.WorldEvents, v4.Season = nil, nil, nil
		truthy(Schema.Migrate(v4))
		eq(v4.Version, Schema.CURRENT_VERSION)
		truthy(type(v4.Collaborators) == "table" and type(v4.WorldEvents) == "table")
		eq(v4.Season.Gold, 0)
		eq(#Schema.Sanitize(v4, 0), 0)
	end)
	test("sanitize caps collaborators and drops bad ids", function()
		local data = H.WithFarm(Schema.Default(0))
		data.Collaborators = { ["0"] = true, abc = true, ["12"] = "yes" }
		for i = 1, 10 do
			data.Collaborators[tostring(1000 + i)] = true
		end
		Schema.Sanitize(data, 0)
		local count = 0
		for key in data.Collaborators do
			count += 1
			truthy(tonumber(key) > 0)
		end
		eq(count, SocialConfig.MaxCollaborators)
	end)
end)
