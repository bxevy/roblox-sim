--!strict
-- Production recipes. A production building names its recipe; each work cycle turns the
-- inputs into outputs (scaled by the building level's YieldPerCycle and the worker).
--
-- Chains:
--   Moonpetal Farm -> Moonpetals ----------------------------.
--   Crystal Mine -> Raw Crystal -> Crystal Smelter -> Refined Crystal -> Essence Condenser -> Essence
--   (Refined Crystal also pays for Empire Core tiers 3+ and land expansions; Essence
--    evolves creatures and hatches Geode Eggs.)
--   Research Station -> Insight (from Moonpetals) -> research and Arcane Eggs

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
	StudyInsight = {
		Id = "StudyInsight",
		Name = "Study",
		Inputs = { Moonpetal = 2 },
		Outputs = { Insight = 1 },
		Power = 0,
		RequiresJob = "Researcher",
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
