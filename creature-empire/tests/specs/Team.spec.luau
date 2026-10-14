--!nocheck
-- Team update: an Active Team of up to 3 following creatures, v9 saves.

local H = require("../harness")
local test, describe, eq, truthy, falsy = H.test, H.describe, H.eq, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local Team = shared("Util", "Team")
local Housing = shared("Util", "Housing")

local function creature(id, species, level)
	return {
		Id = id,
		Species = species or "Sproutling",
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

local function data(list)
	local d = Schema.Default(0)
	for _, c in list do
		d.Creatures[c.Id] = c
	end
	return d
end

describe("Active Team", function()
	test("holds up to 3; the first is the leader (companion)", function()
		local d = data({ creature("a"), creature("b"), creature("c"), creature("d") })
		truthy(Team.Add(d, "a"))
		truthy(Team.Add(d, "b"))
		truthy(Team.Add(d, "c"))
		local ok = Team.Add(d, "d")
		falsy(ok, "full")
		eq(#d.Team, 3)
		eq(d.Companion, "a")
		Team.Remove(d, "a")
		eq(d.Companion, "b", "next in line leads")
		truthy(Team.Add(d, "d", true))
		eq(d.Team[1], "d")
		eq(d.Companion, "d")
	end)
	test("joining leaves a job; backpack and expedition creatures can't join", function()
		local d = data({ creature("a"), creature("b"), creature("c") })
		d.Creatures.a.Assignment = "farm1"
		d.Creatures.b.Stored = true
		d.Creatures.c.Expedition = "x"
		truthy(Team.Add(d, "a"))
		eq(d.Creatures.a.Assignment, nil)
		falsy(Team.Add(d, "b"))
		falsy(Team.Add(d, "c"))
	end)
	test("Equip Best picks the rarest, then highest level", function()
		local d = data({
			creature("common9", "Sproutling", 9),
			creature("common2", "Sproutling", 2),
			creature("rare1", "Mossmaw", 1),
			creature("mythic1", "BlackDragon", 1),
		})
		eq(table.concat(Team.Best(d), ","), "mythic1,rare1,common9")
	end)
	test("putting a member in the backpack takes it off the team", function()
		local d = data({ creature("a"), creature("b") })
		Team.Set(d, { "a", "b" })
		Housing.Store(d, "a")
		eq(#d.Team, 1)
		eq(d.Companion, "b")
	end)
	test("save repair drops bad members and keeps the leader in sync", function()
		local d = data({ creature("a"), creature("b") })
		d.Team = { "a", "a", "ghost", "b", 5 }
		d.Creatures.b.Assignment = "farm1"
		Team.Normalize(d)
		eq(#d.Team, 1)
		eq(d.Companion, "a")
	end)
end)

describe("Save migration v8 -> v9", function()
	test("the companion becomes the team leader", function()
		local v8 = data({ creature("pal") })
		v8.Version = 8
		v8.Team = nil
		v8.Companion = "pal"
		truthy(Schema.Migrate(v8))
		Schema.Sanitize(v8, 0)
		eq(v8.Team[1], "pal")
		eq(v8.Companion, "pal")
		eq(#Schema.Sanitize(v8, 0), 0)
	end)
end)
