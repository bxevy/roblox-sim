--!nocheck
-- Release: pathfinding, monetization rules, the full roster, v6 saves.

local H = require("../harness")
local test, describe, eq, truthy, falsy = H.test, H.describe, H.eq, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local Path = shared("Util", "Path")
local MonetizationConfig = shared("Config", "MonetizationConfig")
local CreatureConfig = shared("Config", "CreatureConfig")
local EconomyConfig = shared("Config", "EconomyConfig")
local GameConfig = shared("Config", "GameConfig")

local function wall(cells)
	local set = {}
	for _, c in cells do
		set[c[1] .. "," .. c[2]] = true
	end
	return function(x, z)
		return set[x .. "," .. z] == true or x < -10 or z < -10 or x > 30 or z > 30
	end
end

describe("Pathfinding", function()
	test("walks around a building instead of through it", function()
		local blocked = {}
		for x = 3, 6 do
			for z = 0, 6 do
				table.insert(blocked, { x, z })
			end
		end
		local isBlocked = wall(blocked)
		local path = Path.Find({ X = 0, Z = 3 }, { X = 9, Z = 3 }, isBlocked)
		truthy(path, "a path exists")
		for _, cell in path do
			falsy(isBlocked(cell.X, cell.Z), `walked through {cell.X},{cell.Z}`)
		end
		eq(path[1].X, 0)
		eq(path[#path].X, 9)
	end)
	test("no corner cutting between two blocked diagonal cells", function()
		local isBlocked = wall({ { 1, 0 }, { 0, 1 } })
		local path = Path.Find({ X = 0, Z = 0 }, { X = 1, Z = 1 }, isBlocked, 200)
		-- It can't squeeze diagonally between the two walls, so it walks round them.
		truthy(path and #path > 2)
	end)
	test("start and goal cells are allowed even inside buildings", function()
		local isBlocked = wall({ { 0, 0 }, { 5, 5 } })
		truthy(Path.Find({ X = 0, Z = 0 }, { X = 5, Z = 5 }, isBlocked))
	end)
	test("open ground simplifies to a straight line", function()
		local isBlocked = wall({})
		local path = Path.Find({ X = 0, Z = 0 }, { X = 8, Z = 3 }, isBlocked)
		local simple = Path.Simplify(path, isBlocked)
		eq(#simple, 2)
	end)
	test("a fully walled-in goal gives up (creature walks straight instead)", function()
		local ring = {}
		for x = 4, 8 do
			for z = 4, 8 do
				if x == 4 or x == 8 or z == 4 or z == 8 then
					table.insert(ring, { x, z })
				end
			end
		end
		eq(Path.Find({ X = 0, Z = 0 }, { X = 6, Z = 6 }, wall(ring), 3000), nil)
	end)
end)

describe("Monetization rules", function()
	test("ids are unset (0) or real positive ids; nothing random is sold", function()
		for key, pass in MonetizationConfig.Passes do
			truthy(pass.Id == 0 or (pass.Id > 0 and pass.Id % 1 == 0), key)
		end
		local allowed = { Currency = true, FarmBoost = true, LuckBoost = true }
		for key, product in MonetizationConfig.Products do
			truthy(product.Id == 0 or (product.Id > 0 and product.Id % 1 == 0), key)
			truthy(allowed[product.Kind], key .. " sells a known, non-random thing")
			if product.Kind == "Currency" then
				truthy(product.Amount and product.Amount > 0, key .. " amount")
			else
				truthy(product.Seconds and product.Seconds > 0, key .. " duration")
			end
		end
		for key, pass in MonetizationConfig.Passes do
			if pass.Grants and pass.Grants.Species then
				truthy(CreatureConfig.Species[pass.Grants.Species], key .. " grants a real species")
			end
		end
	end)
	test("purchased boosts use the capped Boost category", function()
		truthy(EconomyConfig.BonusRules.Categories.Boost)
		truthy(MonetizationConfig.Boost.Value <= EconomyConfig.BonusRules.Categories.Boost.Cap)
		truthy(MonetizationConfig.Boost.MaxSeconds <= 4 * 3600)
	end)
end)

describe("Full roster", function()
	test("all 34 species are obtainable in the release build", function()
		local count = 0
		for _, species in CreatureConfig.Species do
			truthy(species.Phase <= GameConfig.Phase, species.Id)
			count += 1
		end
		eq(count, 34) -- 32 at release + the Black Dragon (Spin Wheel) + Meadow Sprout (shop)
	end)
end)

describe("Save migration v5 -> v6", function()
	test("adds the Dark Gift charm and boost timer; sanitize clamps them", function()
		local v5 = Schema.Default(0)
		v5.Version = 5
		v5.MutationCharm, v5.BoostUntil = nil, nil
		truthy(Schema.Migrate(v5))
		eq(v5.Version, Schema.CURRENT_VERSION)
		eq(v5.MutationCharm, 0)
		eq(v5.BoostUntil, 0)
		eq(#Schema.Sanitize(v5, 0), 0)
		v5.MutationCharm = 99
		v5.BoostUntil = 1e12
		Schema.Sanitize(v5, 100)
		eq(v5.MutationCharm, 5)
		truthy(v5.BoostUntil <= 100 + 30 * 86400)
	end)
end)
