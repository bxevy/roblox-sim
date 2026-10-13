--!strict
-- Creature jobs. A building's `Job` decides which job a creature does there, and a
-- species' `JobAffinity` decides how well it does it. `Stats` lists the creature stats
-- that matter for the job, so the UI can show only what is relevant.

export type Job = {
	Id: string,
	Name: string,
	Verb: string, -- shown as the creature's current task
	Description: string,
	Stats: { string },
	Phase: number,
}

local JobConfig: { [string]: Job } = {
	Farmer = {
		Id = "Farmer",
		Name = "Farmer",
		Verb = "Tending moonpetals",
		Description = "Grows and harvests crops at farms.",
		Stats = { "WorkSpeed", "Yield" },
		Phase = 1,
	},
	Miner = {
		Id = "Miner",
		Name = "Miner",
		Verb = "Mining crystals",
		Description = "Breaks ore and crystal deposits.",
		Stats = { "WorkSpeed", "Yield" },
		Phase = 2,
	},
	Smelter = {
		Id = "Smelter",
		Name = "Smelter",
		Verb = "Smelting crystals",
		Description = "Keeps furnaces hot and refines raw materials.",
		Stats = { "WorkSpeed", "Yield" },
		Phase = 2,
	},
	PowerOperator = {
		Id = "PowerOperator",
		Name = "Power Operator",
		Verb = "Generating power",
		Description = "Powers machines and relays.",
		Stats = { "EnergyEfficiency", "AbilityStrength" },
		Phase = 6,
	},
	Alchemist = {
		Id = "Alchemist",
		Name = "Alchemist",
		Verb = "Distilling essence",
		Description = "Condenses crystals and petals into Essence.",
		Stats = { "WorkSpeed", "Yield" },
		Phase = 2,
	},
	Researcher = {
		Id = "Researcher",
		Name = "Research Assistant",
		Verb = "Researching",
		Description = "Speeds up research projects.",
		Stats = { "AbilityStrength", "DiscoveryChance" },
		Phase = 4,
	},
	Courier = {
		Id = "Courier",
		Name = "Courier",
		Verb = "Hauling",
		Description = "Moves resources between buildings.",
		Stats = { "WorkSpeed", "Capacity" },
		Phase = 4,
	},
	Guardian = {
		Id = "Guardian",
		Name = "Guardian",
		Verb = "Standing guard",
		Description = "Defends the empire from hostile creatures.",
		Stats = { "CombatPower" },
		Phase = 3,
	},
	Explorer = {
		Id = "Explorer",
		Name = "Explorer",
		Verb = "Exploring",
		Description = "Goes on expeditions.",
		Stats = { "Exploration", "Luck", "CombatPower" },
		Phase = 3,
	},
	Breeder = {
		Id = "Breeder",
		Name = "Breeder",
		Verb = "Caring for eggs",
		Description = "Looks after eggs at breeding sanctuaries.",
		Stats = { "Luck", "AbilityStrength" },
		Phase = 6,
	},
	RelicInvestigator = {
		Id = "RelicInvestigator",
		Name = "Relic Investigator",
		Verb = "Studying relics",
		Description = "Uncovers hidden relics and secrets.",
		Stats = { "DiscoveryChance", "Exploration" },
		Phase = 6,
	},
}

return JobConfig
