--!strict
-- Every currency and material. Kept short on purpose: each one has a distinct use.

local Types = require(script.Parent.Parent.Types)

local ResourceConfig: { [string]: Types.ResourceDef } = {
	-- Currencies
	Gold = {
		Id = "Gold",
		Name = "Gold",
		Kind = "Currency",
		Description = "Buys and upgrades buildings.",
		Icon = "●",
		Color = Color3.fromRGB(255, 205, 70),
	},
	Essence = {
		Id = "Essence",
		Name = "Essence",
		Kind = "Currency",
		Description = "Magic for evolution and research (Phase 2).",
		Icon = "✧",
		Color = Color3.fromRGB(170, 120, 255),
	},
	EmpireShards = {
		Id = "EmpireShards",
		Name = "Empire Shards",
		Kind = "Currency",
		Description = "Rare milestone and Ascension currency (Phase 4).",
		Icon = "⬢",
		Color = Color3.fromRGB(90, 220, 220),
	},

	-- Materials
	Moonpetal = {
		Id = "Moonpetal",
		Name = "Moonpetals",
		Kind = "Material",
		Description = "Glowing flowers grown at farms. Sell them at the Trading Post, or brew them into elixirs later on.",
		Icon = "✿",
		Color = Color3.fromRGB(150, 200, 255),
		SellPrice = 2,
	},
}

return ResourceConfig
