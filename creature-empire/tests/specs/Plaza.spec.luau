--!nocheck
-- Plaza update: shared Trading Post and Hatchery, the Spin Wheel, boosts, v7 saves.

local H = require("../harness")
local Vector3 = require("@lune/roblox").Vector3
local test, describe, eq, truthy, falsy = H.test, H.describe, H.eq, H.truthy, H.falsy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", ...)
end
local Schema = H.require("ServerScriptService", "Server", "Core", "Schema")
local SpinConfig = shared("Config", "SpinConfig")
local PlazaConfig = shared("Config", "PlazaConfig")
local PlotConfig = shared("Config", "PlotConfig")
local BuildingConfig = shared("Config", "BuildingConfig")
local CreatureConfig = shared("Config", "CreatureConfig")
local EggConfig = shared("Config", "EggConfig")
local Spin = shared("Util", "Spin")
local Hatching = shared("Util", "Hatching")

describe("Spin Wheel", function()
	test("prizes are valid and the odds add up to 100%", function()
		local total = 0
		for _, entry in Spin.Odds() do
			total += entry.Chance
			local prize = entry.Prize
			truthy(prize.Weight > 0, prize.Id)
			if prize.Kind == "Creature" then
				truthy(CreatureConfig.Species[prize.Species], prize.Id .. " species")
			elseif prize.Kind == "Boost" then
				truthy(SpinConfig.Boosts[prize.Boost], prize.Id .. " boost")
			else
				truthy(prize.Currency and prize.Amount and prize.Amount > 0, prize.Id .. " currency")
			end
		end
		truthy(math.abs(total - 1) < 1e-9, "odds sum to 1")
		eq(Spin.TotalWeight(), 1000)
	end)
	test("500 gold, both boosts and a super rare Black Dragon are on the wheel", function()
		local byId = {}
		for _, entry in Spin.Odds() do
			byId[entry.Prize.Id] = entry
		end
		eq(byId.Gold500.Prize.Amount, 500)
		eq(byId.CoinBoost.Prize.Boost, "Coins")
		eq(byId.LuckBoost.Prize.Boost, "Luck")
		eq(CreatureConfig.Species.BlackDragon.Rarity, "Mythic")
		truthy(byId.BlackDragon.Chance < 0.01, "the dragon is super rare")
		for id, entry in byId do
			if id ~= "BlackDragon" then
				truthy(entry.Chance > byId.BlackDragon.Chance, id .. " is commoner than the dragon")
			end
		end
	end)
	test("a roll lands on the prize its number falls in", function()
		eq(
			Spin.Roll(function()
				return 0
			end),
			1
		)
		eq(
			Spin.Roll(function()
				return 0.999999
			end),
			#SpinConfig.Prizes
		)
		-- Rolling evenly across [0, 1) hits each prize in proportion to its weight.
		local hits = {}
		local samples = 10000
		for i = 0, samples - 1 do
			local index = Spin.Roll(function()
				return (i + 0.5) / samples
			end)
			hits[index] = (hits[index] or 0) + 1
		end
		for index, prize in SpinConfig.Prizes do
			truthy(math.abs((hits[index] or 0) / samples - prize.Weight / 1000) < 0.002, prize.Id)
		end
	end)
	test("the free spin timer and boosts", function()
		eq(Spin.FreeIn(0, 100), 0)
		eq(Spin.FreeIn(160, 100), 60)
		eq(Spin.Multiplier({ Coins = 200 }, "Coins", 100), 2)
		eq(Spin.Multiplier({ Coins = 200 }, "Coins", 200), 1)
		eq(Spin.Multiplier({}, "Luck", 100), 1)
		eq(Spin.Multiplier(nil, "Luck", 100), 1)
		-- A boost won while one runs adds the full time, up to the cap.
		eq(Spin.Extend(0, 1000), 1000 + SpinConfig.BoostSeconds)
		eq(Spin.Extend(1500, 1000), 1500 + SpinConfig.BoostSeconds)
		eq(Spin.Extend(1e9, 1000), 1000 + SpinConfig.MaxBoostSeconds)
	end)
end)

describe("2x Luck on eggs", function()
	test("doubles the weight of rare-or-better creatures and the odds still add up", function()
		local egg = EggConfig.Eggs.MeadowEgg
		local function rareChance(luck)
			local total, rare = 0, 0
			for _, entry in Hatching.Odds(egg, nil, luck) do
				total += entry.Chance
				if Hatching.IsPityTier(egg, entry.Species) then
					rare += entry.Chance
				end
			end
			truthy(math.abs(total - 1) < 1e-9, "odds sum to 1")
			return rare
		end
		local normal, lucky = rareChance(1), rareChance(2)
		truthy(lucky > normal, "luck helps")
		-- With weights r (rare) and c (common): lucky = 2r / (2r + c).
		local r = normal
		truthy(math.abs(lucky - 2 * r / (2 * r + (1 - r))) < 1e-9, "exactly double weight")
		eq(rareChance(nil), normal)
	end)
end)

describe("Plaza", function()
	test("the Trading Post and Hatchery are no longer on plots", function()
		for _, entry in PlotConfig.FixedLayout do
			falsy(PlazaConfig.BuildingTypes[entry.Type], entry.Type)
		end
		falsy(BuildingConfig.Hatchery.Placeable)
		falsy(BuildingConfig.TradingPost.Placeable)
		for _, level in BuildingConfig.EmpireCore.Levels do
			falsy(level.BuildingLimits and level.BuildingLimits.Hatchery, "no Hatchery limit")
		end
	end)
	test("stations sit inside the plaza, apart from each other and off the paths", function()
		local positions = {}
		for id in PlazaConfig.Stations do
			local p = PlazaConfig.Position(id)
			truthy(Vector3.new(p.X, 0, p.Z).Magnitude + 9 <= 35, id .. " inside the plaza")
			for otherId, other in positions do
				truthy((p - other).Magnitude > 16, `{id} and {otherId} overlap`)
			end
			positions[id] = p
			-- Paths leave the plaza every 60 degrees: keep stations between them.
			local angle = PlazaConfig.Stations[id].Angle % 60
			truthy(angle >= 15 and angle <= 45, id .. " is between two paths")
		end
	end)
end)

describe("Save migration v6 -> v7", function()
	test("removes plot Trading Posts and Hatcheries, refunds the Hatchery, adds the wheel", function()
		local v6 = Schema.Default(0)
		v6.Version = 6
		v6.Spin, v6.Boosts = nil, nil
		v6.Buildings.trading = { Id = "trading", Type = "TradingPost", Level = 1, X = 6, Z = 3, Rot = 0, Stored = {} }
		v6.Buildings.nest = { Id = "nest", Type = "Hatchery", Level = 1, X = 2, Z = 2, Rot = 0, Stored = {} }
		local gold = v6.Currencies.Gold
		truthy(Schema.Migrate(v6))
		eq(v6.Version, Schema.CURRENT_VERSION)
		eq(v6.Buildings.trading, nil)
		eq(v6.Buildings.nest, nil)
		eq(v6.Currencies.Gold, gold + BuildingConfig.Hatchery.PlaceCost.Gold)
		eq(v6.Spin.NextFreeAt, 0)
		eq(#Schema.Sanitize(v6, 0), 0)
	end)
	test("sanitize drops stray plaza buildings and clamps the wheel and boosts", function()
		local data = Schema.Default(0)
		data.Buildings.extra = { Id = "extra", Type = "Hatchery", Level = 1, X = 1, Z = 1, Rot = 0, Stored = {} }
		data.Spin = { NextFreeAt = 1e12, Count = -5 }
		data.Boosts = { Coins = 1e12, Luck = 50, Fake = 1e9 }
		Schema.Sanitize(data, 100)
		eq(data.Buildings.extra, nil)
		eq(data.Spin.NextFreeAt, 100 + SpinConfig.FreeEvery)
		eq(data.Spin.Count, 0)
		eq(data.Boosts.Coins, 100 + SpinConfig.MaxBoostSeconds)
		eq(data.Boosts.Luck, nil) -- already over
		eq(data.Boosts.Fake, nil)
	end)
end)
