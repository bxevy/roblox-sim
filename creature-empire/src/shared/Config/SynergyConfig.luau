--!strict
-- Synergies: bonuses when particular creatures work at the same building. Every synergy
-- adds to the "Synergy" bonus category, which is capped (EconomyConfig.BonusRules), so
-- stacking them can't run away. All of a building's workers share its synergies.
--
-- Match kinds:
--   Families { a, b }   at least one worker of each listed family
--   SameFamily n        at least n workers of one family
--   Species { a, b }    each listed species is working there

export type Synergy = {
	Id: string,
	Name: string,
	Description: string,
	Job: string?, -- only at buildings with this job (nil = any production building)
	Families: { string }?,
	SameFamily: number?,
	Species: { string }?,
	Stat: "WorkSpeed" | "Yield",
	Value: number,
}

local SynergyConfig: { Synergy } = {
	{
		Id = "SunAndSoil",
		Name = "Sun and Soil",
		Description = "A Verdant and an Emberkin farming together: +15% yield.",
		Job = "Farmer",
		Families = { "Verdant", "Emberkin" },
		Stat = "Yield",
		Value = 0.15,
	},
	{
		Id = "Irrigation",
		Name = "Irrigation",
		Description = "A Verdant and a Tideborn farming together: +15% work speed.",
		Job = "Farmer",
		Families = { "Verdant", "Tideborn" },
		Stat = "WorkSpeed",
		Value = 0.15,
	},
	{
		Id = "DeepForge",
		Name = "Deep Forge",
		Description = "A Crystalkin and an Emberkin at a smelter: +20% work speed.",
		Job = "Smelter",
		Families = { "Crystalkin", "Emberkin" },
		Stat = "WorkSpeed",
		Value = 0.2,
	},
	{
		Id = "Quench",
		Name = "Quench",
		Description = "An Emberkin and a Tideborn at a smelter: +15% yield.",
		Job = "Smelter",
		Families = { "Emberkin", "Tideborn" },
		Stat = "Yield",
		Value = 0.15,
	},
	{
		Id = "Resonance",
		Name = "Resonance",
		Description = "A Crystalkin and an Aetherial at a condenser: +20% yield.",
		Job = "Alchemist",
		Families = { "Crystalkin", "Aetherial" },
		Stat = "Yield",
		Value = 0.2,
	},
	{
		Id = "Scholars",
		Name = "Scholars",
		Description = "An Aetherial and a Mechafauna researching together: +20% work speed.",
		Job = "Researcher",
		Families = { "Aetherial", "Mechafauna" },
		Stat = "WorkSpeed",
		Value = 0.2,
	},
	{
		Id = "Clockwork",
		Name = "Clockwork Relay",
		Description = "A Mechanica and a Voltbeast at a Courier Post: +20% work speed.",
		Job = "Courier",
		Families = { "Mechafauna", "Voltbeast" },
		Stat = "WorkSpeed",
		Value = 0.2,
	},
	{
		Id = "Pack",
		Name = "Pack Work",
		Description = "Three creatures of the same family at one building: +10% yield.",
		SameFamily = 3,
		Stat = "Yield",
		Value = 0.1,
	},
	{
		Id = "OldFriends",
		Name = "Old Friends",
		Description = "Sproutling, Cindercub and Pebblit at the same building: +25% work speed.",
		Species = { "Sproutling", "Cindercub", "Pebblit" },
		Stat = "WorkSpeed",
		Value = 0.25,
	},
}

return SynergyConfig
