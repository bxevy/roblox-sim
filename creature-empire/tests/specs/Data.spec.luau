--!nocheck
-- Saved data: schema defaults, migrations, repair, and session-locked storage against a
-- fake DataStore that can fail, be slow, or be held by another server.

local serde = require("@lune/serde")
local H = require("../harness")
local test, describe, eq, truthy, falsy = H.test, H.describe, H.eq, H.truthy, H.falsy

local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local ProfileCore = H.require("ServerScriptService", "Server", "Core", "ProfileCore")
local EconomyConfig = H.require("ReplicatedStorage", "Shared", "Config", "EconomyConfig")
local PlotConfig = H.require("ReplicatedStorage", "Shared", "Config", "PlotConfig")

-- Fake DataStore ----------------------------------------------------------------------------
-- Stores records as JSON (like Roblox does), so non-serialisable data would show up.
-- `failNext` makes the next N calls error; `transformTwice` runs transforms twice, as
-- UpdateAsync may do under contention.
local function fakeStore()
	local store = { Data = {}, Calls = 0, FailNext = 0, TransformTwice = false }
	function store:UpdateAsync(key, transform)
		self.Calls += 1
		if self.FailNext > 0 then
			self.FailNext -= 1
			error("502: API Services rejected request (simulated)")
		end
		local raw = self.Data[key]
		local current = if raw ~= nil then serde.decode("json", raw) else nil
		if self.TransformTwice then
			transform(if raw ~= nil then serde.decode("json", raw) else nil)
		end
		local result = transform(current)
		if result ~= nil then
			self.Data[key] = serde.encode("json", result)
		end
		return result
	end
	function store:Peek(key)
		local raw = self.Data[key]
		return if raw then serde.decode("json", raw) else nil
	end
	return store
end

local function newCore(store, jobId, clock)
	return ProfileCore.new({
		Store = store,
		JobId = jobId,
		Now = function()
			return clock.t
		end,
		Wait = function(seconds)
			clock.t += seconds
		end,
		LockTimeout = 240,
		Attempts = 3,
		LockedAttempts = 3,
		LockedRetryDelay = 5,
	})
end

describe("Schema", function()
	test("defaults are valid and need no repair", function()
		local data = Schema.Default(1000)
		local fixes = Schema.Sanitize(data, 1000)
		eq(#fixes, 0, "fixes on a fresh profile: " .. table.concat(fixes, ", "))
		eq(data.Currencies.Gold, EconomyConfig.StartingCurrencies.Gold)
		eq(data.Version, Schema.CURRENT_VERSION)
	end)
	test("defaults survive a JSON round trip", function()
		local data = Schema.Default(1000)
		local copy = serde.decode("json", serde.encode("json", data))
		eq(#Schema.Sanitize(copy, 1000), 0)
		eq(copy.Buildings.core.Type, "EmpireCore")
	end)
	test("every fixed building and the starter farm exist", function()
		local data = Schema.Default(0)
		for _, entry in PlotConfig.FixedLayout do
			truthy(data.Buildings[entry.Id], entry.Id)
		end
		truthy(data.Buildings.farm1)
	end)
	test("v0 profiles migrate (Coins -> Gold)", function()
		local legacy = { Coins = 300, Currencies = { Gold = 5 } }
		local ok = Schema.Migrate(legacy)
		truthy(ok)
		eq(legacy.Version, Schema.CURRENT_VERSION)
		eq(legacy.Currencies.Gold, 305)
		eq(legacy.Coins, nil)
		Schema.Sanitize(legacy, 0)
		truthy(legacy.Buildings.core, "missing sections are rebuilt")
	end)
	test("profiles from a newer version are refused (never overwritten)", function()
		local future = { Version = Schema.CURRENT_VERSION + 1 }
		local ok, reason = Schema.Migrate(future)
		falsy(ok)
		truthy(reason)
	end)
	test("malformed numbers are repaired", function()
		local data = Schema.Default(0)
		data.Currencies.Gold = 0 / 0
		data.Currencies.Essence = -50
		data.Currencies.EmpireShards = math.huge
		data.Resources.Moonpetal = 12.7
		data.Currencies.Gold2 = EconomyConfig.MaxBalance * 10
		data.Buildings.farm1.Level = 99
		data.Buildings.farm1.Rot = 7
		data.Buildings.farm1.Stored = { Moonpetal = -3 }
		Schema.Sanitize(data, 0)
		eq(data.Currencies.Gold, 0)
		eq(data.Currencies.Essence, 0)
		eq(data.Currencies.EmpireShards, 0, "corrupt infinite balances reset to 0, never to the maximum")
		eq(data.Resources.Moonpetal, 12)
		eq(data.Currencies.Gold2, EconomyConfig.MaxBalance, "huge but finite balances are capped")
		eq(data.Buildings.farm1.Level, 5)
		eq(data.Buildings.farm1.Rot, 3)
		eq(data.Buildings.farm1.Stored.Moonpetal, 0)
	end)
	test("invalid assignments are cleared; slot overflow is trimmed", function()
		local data = Schema.Default(0)
		local function c(id, species, assignment)
			data.Creatures[id] = {
				Id = id,
				Species = species,
				Level = 1,
				Xp = 0,
				Stage = 1,
				Source = "T",
				ObtainedAt = 0,
				Tradable = false,
				WorkCycles = 0,
				AbilityReadyAt = 0,
				Assignment = assignment,
			}
		end
		c("a", "Sproutling", "farm1")
		c("b", "Sproutling", "farm1") -- level 1 farm has only 1 slot
		c("c", "Sproutling", "nowhere")
		c("d", "Zappup", "farm1") -- cannot farm
		c("e", "Sproutling", "research") -- locked building
		Schema.Sanitize(data, 0)
		local assigned = 0
		for _, creature in data.Creatures do
			if creature.Assignment == "farm1" then
				assigned += 1
			end
		end
		eq(assigned, 1)
		eq(data.Creatures.c.Assignment, nil)
		eq(data.Creatures.d.Assignment, nil)
		eq(data.Creatures.e.Assignment, nil)
	end)
	test("missing or moved fixed buildings are restored to the layout", function()
		local data = Schema.Default(0)
		data.Buildings.core = nil
		data.Buildings.silo.X = 0
		Schema.Sanitize(data, 0)
		eq(data.Buildings.core.Type, "EmpireCore")
		eq(data.Buildings.silo.X, 15)
	end)
	test("ability cooldowns far in the future are clamped", function()
		local data = Schema.Default(0)
		data.Creatures.a = {
			Id = "a",
			Species = "Pebblit",
			Level = 1,
			Xp = 0,
			Stage = 1,
			Source = "T",
			ObtainedAt = 0,
			Tradable = false,
			WorkCycles = 0,
			AbilityReadyAt = 1e12,
		}
		Schema.Sanitize(data, 100)
		truthy(data.Creatures.a.AbilityReadyAt <= 100 + 3600)
	end)
end)

describe("ProfileCore (session locking)", function()
	test("a new player gets nil data (caller builds defaults) and the lock", function()
		local store, clock = fakeStore(), { t = 1000 }
		local core = newCore(store, "server-A", clock)
		local status, data, isNew = core:Load("Player_1")
		eq(status, "Ok")
		eq(data, nil)
		truthy(isNew)
		eq(store:Peek("Player_1").Meta.Lock.JobId, "server-A")
	end)
	test("save then load round-trips data and release clears the lock", function()
		local store, clock = fakeStore(), { t = 1000 }
		local core = newCore(store, "server-A", clock)
		core:Load("Player_1")
		eq(core:Save("Player_1", { Gold = 42 }, true), "Ok")
		eq(store:Peek("Player_1").Meta.Lock, nil)
		local status, data = newCore(store, "server-B", clock):Load("Player_1")
		eq(status, "Ok")
		eq(data.Gold, 42)
	end)
	test("a live lock on another server blocks loading (no fresh profile)", function()
		local store, clock = fakeStore(), { t = 1000 }
		newCore(store, "server-A", clock):Load("Player_1")
		newCore(store, "server-A", clock):Save("Player_1", { Gold = 99 }, false)
		local status = newCore(store, "server-B", clock):Load("Player_1")
		eq(status, "Locked")
		eq(store:Peek("Player_1").Data.Gold, 99, "data untouched")
		eq(store:Peek("Player_1").Meta.Lock.JobId, "server-A", "lock untouched")
	end)
	test("a lock released while we wait is picked up on retry", function()
		local store, clock = fakeStore(), { t = 1000 }
		local a = newCore(store, "server-A", clock)
		a:Load("Player_1")
		local b = ProfileCore.new({
			Store = store,
			JobId = "server-B",
			Now = function()
				return clock.t
			end,
			Wait = function(seconds)
				clock.t += seconds
				a:Save("Player_1", { Gold = 7 }, true) -- server A finishes saving meanwhile
			end,
			LockedAttempts = 3,
			LockedRetryDelay = 5,
		})
		local status, data = b:Load("Player_1")
		eq(status, "Ok")
		eq(data.Gold, 7)
	end)
	test("an abandoned lock (crashed server) is taken after the timeout", function()
		local store, clock = fakeStore(), { t = 1000 }
		newCore(store, "server-A", clock):Load("Player_1")
		newCore(store, "server-A", clock):Save("Player_1", { Gold = 5 }, false)
		clock.t += 300 -- no refresh for longer than LockTimeout
		local status, data = newCore(store, "server-B", clock):Load("Player_1")
		eq(status, "Ok")
		eq(data.Gold, 5)
		eq(store:Peek("Player_1").Meta.Lock.JobId, "server-B")
	end)
	test("a server that lost its lock cannot overwrite the new owner's data", function()
		local store, clock = fakeStore(), { t = 1000 }
		local a = newCore(store, "server-A", clock)
		a:Load("Player_1")
		a:Save("Player_1", { Gold = 1 }, false)
		clock.t += 300
		local b = newCore(store, "server-B", clock)
		b:Load("Player_1")
		b:Save("Player_1", { Gold = 500 }, false)
		local status = a:Save("Player_1", { Gold = 2 }, false)
		eq(status, "LockLost")
		eq(store:Peek("Player_1").Data.Gold, 500)
	end)
	test("transient DataStore errors are retried", function()
		local store, clock = fakeStore(), { t = 1000 }
		store.FailNext = 2
		local status = newCore(store, "server-A", clock):Load("Player_1")
		eq(status, "Ok")
		eq(store.Calls, 3)
	end)
	test("persistent DataStore errors report Error and write nothing", function()
		local store, clock = fakeStore(), { t = 1000 }
		store.Data.Player_1 = serde.encode("json", { Data = { Gold = 1234 }, Meta = {} })
		store.FailNext = 99
		local status = newCore(store, "server-A", clock):Load("Player_1")
		eq(status, "Error")
		store.FailNext = 0
		eq(store:Peek("Player_1").Data.Gold, 1234, "existing data untouched")
	end)
	test("retries back off with bounded waits", function()
		local store, clock = fakeStore(), { t = 0 }
		store.FailNext = 99
		newCore(store, "server-A", clock):Load("Player_1")
		-- 3 attempts -> waits of 1 and 2 seconds
		eq(clock.t, 3)
	end)
	test("transforms that run twice give the same result", function()
		local store, clock = fakeStore(), { t = 1000 }
		store.TransformTwice = true
		local core = newCore(store, "server-A", clock)
		eq(core:Load("Player_1"), "Ok")
		eq(core:Save("Player_1", { Gold = 3 }, false), "Ok")
		eq(store:Peek("Player_1").Meta.SaveCount, 1)
	end)
	test("unrecognised record formats are refused, not overwritten", function()
		local store, clock = fakeStore(), { t = 1000 }
		store.Data.Player_1 = serde.encode("json", "legacy string value")
		local status = newCore(store, "server-A", clock):Load("Player_1")
		eq(status, "Error")
		eq(store:Peek("Player_1"), "legacy string value")
	end)
	test("a full profile is well under the 4 MB DataStore limit", function()
		local data = Schema.Default(0)
		for i = 1, 300 do
			data.Creatures["creature-" .. i] = {
				Id = "creature-" .. i,
				Species = "Sproutling",
				Level = 30,
				Xp = 1234,
				Stage = 3,
				Source = "Hatch",
				ObtainedAt = 1700000000,
				Tradable = true,
				WorkCycles = 999999,
				AbilityReadyAt = 1700000000,
				Assignment = "farm1",
				Mutation = "Prismatic",
			}
		end
		local bytes = #serde.encode("json", data)
		print(`      300-creature profile: {bytes} bytes`)
		truthy(bytes < 400000)
	end)
end)
