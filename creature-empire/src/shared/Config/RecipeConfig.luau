--!strict
-- Production recipes. A production building names its recipe; each work cycle turns the
-- inputs into outputs (scaled by the building level's YieldPerCycle and the worker).
--
-- Phase 1 has the first link of the Moonpetal chain. Later recipes are listed (disabled)
-- so the chain is visible in one place:
--   Moonpetal Farm -> Moonpetals -> Alchemy Lab -> Growth Elixir -> creature training
--   Crystal Mine -> Raw Crystal -> Smelter -> Refined Crystal -> Condenser -> Arcane Core

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
	BrewGrowthElixir = {
		Id = "BrewGrowthElixir",
		Name = "Brew Growth Elixir",
		Inputs = { Moonpetal = 10 },
		Outputs = { GrowthElixir = 1 },
		Power = 1,
		Enabled = false, -- Phase 2
	},
	SmeltCrystal = {
		Id = "SmeltCrystal",
		Name = "Smelt Crystal",
		Inputs = { RawCrystal = 3 },
		Outputs = { RefinedCrystal = 1 },
		Power = 2,
		RequiresJob = "Smelter",
		Enabled = false, -- Phase 2
	},
	CondenseArcaneCore = {
		Id = "CondenseArcaneCore",
		Name = "Condense Arcane Core",
		Inputs = { RefinedCrystal = 5, Essence = 20 },
		Outputs = { ArcaneCore = 1 },
		Power = 4,
		Enabled = false, -- Phase 2
	},
}

return RecipeConfig
