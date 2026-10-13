--!strict
-- Mutations: rare variants rolled when a creature hatches, is befriended, returns from an
-- expedition, or evolves (if it has none yet). Each has a visible look and a small,
-- capped bonus (bonus category "Mutation"). Chances are shown in the Hatchery and the
-- creature journal. Mutations are never sold.

export type Mutation = {
	Id: string,
	Name: string,
	Description: string,
	Chance: number, -- per roll, before research
	Bonuses: { { Stat: "WorkSpeed" | "Yield", Value: number } },
	Color: Color3, -- tint used by the model and the UI chip
	Glyph: string,
}

local MutationConfig = {}

MutationConfig.Mutations = {
	Prismatic = {
		Id = "Prismatic",
		Name = "Prismatic",
		Description = "Shimmers with every colour. +10% yield.",
		Chance = 0.03,
		Bonuses = { { Stat = "Yield", Value = 0.1 } },
		Color = Color3.fromRGB(255, 170, 240),
		Glyph = "✺",
	},
	Ancient = {
		Id = "Ancient",
		Name = "Ancient",
		Description = "Weathered stone and gold markings, like a creature from long ago. +10% work speed.",
		Chance = 0.02,
		Bonuses = { { Stat = "WorkSpeed", Value = 0.1 } },
		Color = Color3.fromRGB(220, 180, 90),
		Glyph = "⌘",
	},
	Shadow = {
		Id = "Shadow",
		Name = "Shadow",
		Description = "Dark as dusk with glowing eyes. +8% work speed and yield.",
		Chance = 0.015,
		Bonuses = { { Stat = "WorkSpeed", Value = 0.08 }, { Stat = "Yield", Value = 0.08 } },
		Color = Color3.fromRGB(80, 60, 120),
		Glyph = "☾",
	},
} :: { [string]: Mutation }

-- Sources that roll for a mutation.
MutationConfig.RollSources = { Egg = true, Wild = true, Expedition = true, Evolve = true }

return MutationConfig
