--!nocheck
-- Configuration integrity: catches typos and broken references before they reach a server.

local H = require("../harness")
local test, describe, eq, truthy = H.test, H.describe, H.eq, H.truthy

local function shared(...)
	return H.require("ReplicatedStorage", "Shared", "Config", ...)
end
local CreatureConfig = shared("CreatureConfig")
local JobConfig = shared("JobConfig")
local RarityConfig = shared("RarityConfig")
local BuildingConfig = shared("BuildingConfig")
local RecipeConfig = shared("RecipeConfig")
local ResourceConfig = shared("ResourceConfig")
local QuestConfig = shared("QuestConfig")
local BiomeConfig = shared("BiomeConfig")
local AssetConfig = shared("AssetConfig")
local GameConfig = shared("GameConfig")

local QUEST_KINDS = {
	"ChooseStarter",
	"Assign",
	"Collect",
	"Sell",
	"BuildingLevel",
	"BuildingCount",
	"UseAbility",
	"EarnGold",
	"Hatch",
	"Evolve",
}
local PHASE1_ABILITIES = { InstantHarvest = true, SpeedBurst = true, GoldFind = true }

describe("Creatures", function()
	test("eight families with at least four species each", function()
		local counts = {}
		for _, species in CreatureConfig.Species do
			counts[species.Family] = (counts[species.Family] or 0) + 1
		end
		eq(#CreatureConfig.FamilyOrder, 8)
		for _, family in CreatureConfig.FamilyOrder do
			truthy((counts[family] or 0) >= 4, family .. " has " .. tostring(counts[family]))
		end
	end)
	test("three starters, all obtainable in phase 1 and able to farm", function()
		eq(#CreatureConfig.Starters, 3)
		for _, id in CreatureConfig.Starters do
			local species = CreatureConfig.Species[id]
			eq(species.Phase, 1, id)
			truthy((species.JobAffinity.Farmer or 0) > 0, id .. " must be able to farm in phase 1")
			truthy(PHASE1_ABILITIES[species.Active.Kind], id .. " ability must be implemented")
		end
	end)
	test("every species references real jobs, rarities, biomes and has 3 stages", function()
		for id, species in CreatureConfig.Species do
			truthy(RarityConfig.Tiers[species.Rarity], id .. " rarity")
			truthy(BiomeConfig[species.Habitat], id .. " habitat " .. species.Habitat)
			for job, value in species.JobAffinity do
				truthy(JobConfig[job], `{id} job {job}`)
				truthy(value > 0 and value <= 1.5, `{id} affinity {job}`)
			end
			eq(#species.Evolution, 3, id .. " stages")
			for _, stat in CreatureConfig.Stats do
				truthy(type(species.BaseStats[stat.Id]) == "number", `{id} stat {stat.Id}`)
			end
			truthy(species.Active.Cooldown > 0, id .. " cooldown")
			truthy(#species.Description > 0 and #species.Discovery > 0, id .. " text")
			-- Species obtainable in this phase must only use implemented abilities.
			if species.Phase <= GameConfig.Phase then
				truthy(
					PHASE1_ABILITIES[species.Active.Kind],
					id .. " uses unimplemented ability " .. species.Active.Kind
				)
			end
		end
	end)
	test("passive modifiers use known stats and bonus categories", function()
		local Economy = shared("EconomyConfig")
		for id, species in CreatureConfig.Species do
			for _, modifier in species.Passive.Modifiers do
				truthy(modifier.Stat == "WorkSpeed" or modifier.Stat == "Yield", id .. " modifier stat")
				truthy(Economy.BonusRules.Categories[modifier.Category], id .. " modifier category")
				if modifier.Job then
					truthy(JobConfig[modifier.Job], id .. " modifier job")
				end
			end
		end
	end)
	test("experience curve grows", function()
		for level = 1, CreatureConfig.MaxLevel - 1 do
			truthy(CreatureConfig.XpToNext(level + 1) > CreatureConfig.XpToNext(level))
		end
	end)
end)

describe("Buildings, recipes, resources", function()
	test("production buildings have a recipe with known resources and a job", function()
		for id, def in BuildingConfig do
			if def.Recipe then
				local recipe = RecipeConfig[def.Recipe]
				truthy(recipe, id .. " recipe")
				truthy(def.Job and JobConfig[def.Job], id .. " job")
				for resource in recipe.Outputs do
					truthy(ResourceConfig[resource], `{id} output {resource}`)
				end
				for level, data in def.Levels do
					truthy(
						data.CycleTime and data.YieldPerCycle and data.Slots and data.Storage,
						`{id} level {level} production fields`
					)
				end
			end
		end
	end)
	test("levels never get worse", function()
		for id, def in BuildingConfig do
			for level = 2, #def.Levels do
				local a, b = def.Levels[level - 1], def.Levels[level]
				for _, key in { "Slots", "Storage", "YieldPerCycle", "EmpireBonus" } do
					if a[key] and b[key] then
						truthy(b[key] >= a[key], `{id} {key} drops at level {level}`)
					end
				end
				if a.CycleTime and b.CycleTime then
					truthy(b.CycleTime <= a.CycleTime, `{id} cycle time grows at level {level}`)
				end
				truthy(b.Description, `{id} level {level} needs an upgrade description`)
			end
		end
	end)
	test("empire core limits only name placeable buildings", function()
		for _, level in BuildingConfig.EmpireCore.Levels do
			for typeId in level.BuildingLimits do
				truthy(BuildingConfig[typeId] and BuildingConfig[typeId].Placeable, typeId)
			end
		end
	end)
	test("sellable materials have a price", function()
		for id, def in ResourceConfig do
			if def.Kind == "Material" then
				truthy(def.SellPrice and def.SellPrice > 0, id)
			end
		end
	end)
end)

describe("Quests", function()
	test("every step uses a known kind and valid targets", function()
		for i, step in QuestConfig.Tutorial do
			truthy(table.find(QUEST_KINDS, step.Kind), `step {i} kind {step.Kind}`)
			truthy(step.Amount > 0, `step {i} amount`)
			if step.Kind == "BuildingLevel" or step.Kind == "BuildingCount" then
				truthy(BuildingConfig[step.Target], `step {i} target {step.Target}`)
			elseif step.Kind == "Collect" or step.Kind == "Sell" then
				truthy(ResourceConfig[step.Target], `step {i} target {step.Target}`)
			end
			if step.Pointer then
				truthy(BuildingConfig[step.Pointer], `step {i} pointer {step.Pointer}`)
			end
		end
	end)
	test("the tutorial hands out exactly the two remaining starters", function()
		local count = 0
		for _, step in QuestConfig.Tutorial do
			if step.Reward.Creature == "NextStarter" then
				count += 1
			end
		end
		eq(count, #CreatureConfig.Starters - 1)
	end)
	test("building-level steps are reachable given the core gate", function()
		for i, step in QuestConfig.Tutorial do
			if step.Kind == "BuildingLevel" and step.Target ~= "EmpireCore" then
				truthy(step.Amount <= 1 + GameConfig.MaxLevelAboveCore, `step {i} needs a higher core tier first`)
			end
		end
	end)
end)

describe("Assets", function()
	test("no invented asset ids: every id is empty or a built-in rbxasset", function()
		for key, def in AssetConfig.Sounds do
			truthy(def.Id == "" or string.sub(def.Id, 1, 11) == "rbxasset://", key .. " has an unverified id")
		end
		for key, id in AssetConfig.Images do
			truthy(id == "" or string.sub(id, 1, 11) == "rbxasset://", key)
		end
	end)
	test("every species sound key exists in the asset config", function()
		for id, species in CreatureConfig.Species do
			if species.Phase <= GameConfig.Phase then
				for _, key in { species.Sounds.Idle, species.Sounds.Move, species.Sounds.Work } do
					truthy(AssetConfig.Sounds[key], `{id} sound {key}`)
				end
			end
		end
	end)
end)
