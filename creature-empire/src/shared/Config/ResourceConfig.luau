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
		Description = "Condensed magic. Evolves creatures and hatches Geode Eggs. Made at the Essence Condenser.",
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
		Description = "Glowing flowers grown at farms. Sell them at the Trading Post, or condense them into Essence.",
		Icon = "✿",
		Color = Color3.fromRGB(150, 200, 255),
		SellPrice = 2,
	},
	RawCrystal = {
		Id = "RawCrystal",
		Name = "Raw Crystal",
		Kind = "Material",
		Description = "Rough crystal chipped from the ground at a Crystal Mine. Smelt it, or sell it cheaply.",
		Icon = "◇",
		Color = Color3.fromRGB(150, 200, 230),
		SellPrice = 3,
	},
	RefinedCrystal = {
		Id = "RefinedCrystal",
		Name = "Refined Crystal",
		Kind = "Material",
		Description = "Smelted crystal. Needed for high Empire Core tiers, expansions and Essence.",
		Icon = "◆",
		Color = Color3.fromRGB(120, 230, 255),
		SellPrice = 14,
	},
}

return ResourceConfig
