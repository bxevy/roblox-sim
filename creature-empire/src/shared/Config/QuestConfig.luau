--!strict
-- The onboarding questline. QuestService checks each step with the evaluator named by
-- `Kind`, so new steps only need a config entry:
--   ChooseStarter                       a starter has been picked
--   Assign      (Amount)                creatures currently assigned to jobs
--   Collect     (Target, Amount)        units collected from buildings during this step
--   Sell        (Target, Amount)        units sold during this step
--   BuildingLevel (Target, Amount)      highest level of a building type
--   BuildingCount (Target, Amount)      how many of a building type are placed
--   UseAbility  (Amount)                active abilities used during this step
--   EarnGold    (Amount)                gold earned during this step
--
-- `Pointer` is the building type the tutorial arrow points at.

local Types = require(script.Parent.Parent.Types)

local QuestConfig = {}

QuestConfig.Tutorial = {
	{
		Id = "Starter",
		Title = "Choose a partner",
		Description = "Pick your first creature.",
		Kind = "ChooseStarter",
		Amount = 1,
		Reward = {},
	},
	{
		Id = "FirstJob",
		Title = "Put it to work",
		Description = "Walk to the Moonpetal Farm, open it and assign your creature.",
		Kind = "Assign",
		Amount = 1,
		Reward = { Gold = 20 },
		Pointer = "MoonpetalFarm",
	},
	{
		Id = "FirstHarvest",
		Title = "First harvest",
		Description = "Collect 10 moonpetals from your farm.",
		Kind = "Collect",
		Target = "Moonpetal",
		Amount = 10,
		Reward = { Gold = 25 },
		Pointer = "MoonpetalFarm",
	},
	{
		Id = "FirstSale",
		Title = "Open for business",
		Description = "Sell 10 moonpetals at the Trading Post.",
		Kind = "Sell",
		Target = "Moonpetal",
		Amount = 10,
		Reward = { Creature = "NextStarter" },
		Pointer = "TradingPost",
	},
	{
		Id = "TwoWorkers",
		Title = "Many paws",
		Description = "Upgrade the farm to level 2, then assign your new friend there too.",
		Kind = "Assign",
		Amount = 2,
		Reward = { Gold = 60 },
		Pointer = "MoonpetalFarm",
	},
	{
		Id = "Ability",
		Title = "Special talents",
		Description = "Use a creature's active ability (open Creatures, or tap a portrait in the creature bar).",
		Kind = "UseAbility",
		Amount = 1,
		Reward = { Gold = 50 },
	},
	{
		Id = "SecondFarm",
		Title = "Expand the fields",
		Description = "Open Build and place a second Moonpetal Farm.",
		Kind = "BuildingCount",
		Target = "MoonpetalFarm",
		Amount = 2,
		Reward = { Creature = "NextStarter" },
	},
	{
		Id = "Silo",
		Title = "Room to grow",
		Description = "Upgrade the Resource Silo to level 2.",
		Kind = "BuildingLevel",
		Target = "ResourceSilo",
		Amount = 2,
		Reward = { Gold = 120 },
		Pointer = "ResourceSilo",
	},
	{
		Id = "Earn",
		Title = "Growing economy",
		Description = "Earn 500 gold.",
		Kind = "EarnGold",
		Amount = 500,
		Reward = { Gold = 100 },
	},
	{
		Id = "CoreTier2",
		Title = "An empire rises",
		Description = "Upgrade the Empire Core to tier 2.",
		Kind = "BuildingLevel",
		Target = "EmpireCore",
		Amount = 2,
		Reward = { Gold = 250, Essence = 25 },
		Pointer = "EmpireCore",
	},
} :: { Types.QuestStep }

return QuestConfig
