--!strict
-- Central economy numbers. Building and upgrade prices live in BuildingConfig (built with
-- Formulas.CostAt so every curve follows Cost(level) = Base * Growth^(level - 1)).

local EconomyConfig = {}

EconomyConfig.StartingCurrencies = {
	Gold = 50,
	Essence = 0,
	EmpireShards = 0,
	Insight = 0,
}

EconomyConfig.StartingResources = {
	Moonpetal = 0,
}

-- Hard ceiling for any balance. Well below 2^53 so whole numbers stay exact.
EconomyConfig.MaxBalance = 1e15

-- Production ------------------------------------------------------------------------------

-- How often the server advances production (seconds). Output depends on elapsed time, not
-- on the tick rate, so this only affects how fresh stored amounts are.
EconomyConfig.ProductionTick = 1

-- Creature experience per completed work cycle.
EconomyConfig.XpPerCycle = 2

-- Offline production: while away, buildings keep working at reduced efficiency for up to
-- MaxSeconds, and still stop when their storage is full.
EconomyConfig.Offline = {
	MaxSeconds = 2 * 60 * 60,
	Efficiency = 0.5,
	MinSeconds = 60, -- shorter absences are not reported
}

-- How bonuses combine. Bonuses in the same category ADD together and are capped at Cap.
-- Each category then MULTIPLIES the others: (1 + passive) * (1 + level) * ...
-- A creature can never get more than MaxMultiplier from bonuses in total, which stops
-- stacking exploits when synergies and boosts arrive in later phases.
EconomyConfig.BonusRules = {
	Categories = {
		Level = { Cap = 0.6 }, -- creature level
		Stage = { Cap = 0.3 }, -- evolution stage
		Passive = { Cap = 0.5 }, -- passive abilities
		Empire = { Cap = 0.5 }, -- Empire Core tier
		Ability = { Cap = 1.0 }, -- temporary active abilities (Kindle, ...)
		Synergy = { Cap = 0.75 }, -- creatures working well together (SynergyConfig)
		Research = { Cap = 0.5 }, -- research tree (ResearchConfig)
		Mutation = { Cap = 0.25 }, -- rare mutations (MutationConfig)
		Ascension = { Cap = 1.0 }, -- Ascension count and perks (AscensionConfig)
		Boost = { Cap = 1.0 }, -- Phase 6 optional boosts
	},
	MaxMultiplier = 6,
}

-- Rewards -----------------------------------------------------------------------------------

-- Pebblit's Rockseek and similar finds: Power * (1 + PerCoreLevel * (coreLevel - 1)).
EconomyConfig.GoldFindPerCoreLevel = 0.75

-- Trading (Phase 5). Listed here so restrictions live with the rest of the economy.
EconomyConfig.Trading = {
	Enabled = false,
	MaxCreaturesPerSide = 4,
	UntradableSources = { "Starter", "Quest" },
}

return EconomyConfig
