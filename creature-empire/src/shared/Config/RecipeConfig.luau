--!strict
-- Production recipes. A production building names its recipe; each work cycle turns the
-- inputs into outputs (scaled by the building level's YieldPerCycle and the worker).
--
-- Chains:
--   Moonpetal Farm -> Moonpetals ----------------------------.
--   Crystal Mine -> Raw Crystal -> Crystal Smelter -> Refined Crystal -> Essence Condenser -> Essence
--   (Refined Crystal also pays for Empire Core tiers 3+ and land expansions; Essence
--    evolves creatures and hatches Geode Eggs.)
--   Research Station -> Essence (from Moonpetals) -> research, evolving and eggs

local Types = require(script.Parent.Parent.Types)

local RecipeConfig: { [string]: Types.RecipeDef & { Enabled: boolean } } = {
	GrowMoonpetal = {
		Id = "GrowMoonpetal",
		Name = "Grow Moonpetals",
		Inputs = {},
		Outputs = { Moonpetal = 1 },
		Power = 0,
		RequiresJob = "Farmer",
		Enabled = true,
	},
	MineCrystal = {
		Id = "MineCrystal",
		Name = "Mine Raw Crystal",
		Inputs = {},
		Outputs = { RawCrystal = 1 },
		Power = 0,
		RequiresJob = "Miner",
		Enabled = true,
	},
	-- Inputs are taken from the Resource Silo as the building works, at a fixed amount per
	-- unit of output: better workers produce faster, and use inputs faster too.
	SmeltCrystal = {
		Id = "SmeltCrystal",
		Name = "Smelt Crystal",
		Inputs = { RawCrystal = 3 },
		Outputs = { RefinedCrystal = 1 },
		Power = 0,
		RequiresJob = "Smelter",
		Enabled = true,
	},
	CondenseEssence = {
		Id = "CondenseEssence",
		Name = "Condense Essence",
		Inputs = { RefinedCrystal = 1, Moonpetal = 8 },
		Outputs = { Essence = 3 },
		Power = 0,
		RequiresJob = "Alchemist",
		Enabled = true,
	},
	StudyEssence = {
		Id = "StudyEssence",
		Name = "Study",
		Inputs = { Moonpetal = 3 },
		Outputs = { Essence = 1 },
		Power = 0,
		RequiresJob = "Researcher",
		Enabled = true,
	},
	-- The Workshop: any creature crafts trinkets that go straight to the wallet as Gold,
	-- 10 Gold for each point of work.
	CraftTrinkets = {
		Id = "CraftTrinkets",
		Name = "Craft Trinkets",
		Inputs = {},
		Outputs = { Gold = 10 },
		Power = 0,
		RequiresJob = "Crafter",
		Enabled = true,
	},
	BrewGrowthElixir = {
		Id = "BrewGrowthElixir",
		Name = "Brew Growth Elixir",
		Inputs = { Moonpetal = 10 },
		Outputs = { GrowthElixir = 1 },
		Power = 1,
		Enabled = false, -- a later update (Alchemy Lab)
	},
}

return RecipeConfig
