--!strict
-- Every currency and material. Kept short on purpose: each one has a distinct use.

local Types = require(script.Parent.Parent.Types)

-- Sell prices are set so each starter's own building earns about 80-95 Gold a minute at
-- level 1 (the smelter: on top of the raw crystal it uses). See Economy3.spec.
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
		Description = "Condensed magic. Evolves creatures, pays for research and hatches Geode and Arcane Eggs. Made at the Essence Condenser and the Research Station.",
		Icon = "✧",
		Color = Color3.fromRGB(170, 120, 255),
	},
	EmpireShards = {
		Id = "EmpireShards",
		Name = "Empire Shards",
		Kind = "Currency",
		Description = "Earned by Ascending (and a few milestones). Spend them on permanent Ascension perks.",
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
		SellPrice = 6,
	},
	RawCrystal = {
		Id = "RawCrystal",
		Name = "Raw Crystal",
		Kind = "Material",
		Description = "Rough crystal chipped from the ground at a Crystal Mine. Smelt it, or sell it cheaply.",
		Icon = "◇",
		Color = Color3.fromRGB(150, 200, 230),
		SellPrice = 11,
	},
	Emberstone = {
		Id = "Emberstone",
		Name = "Emberstone",
		Kind = "Material",
		Description = "Warm stone gathered in Emberfall Basin. Used for lures, heat shields and guardian rewards.",
		Icon = "◉",
		Color = Color3.fromRGB(255, 120, 60),
		SellPrice = 6,
		Enabled = false, -- out for now, with Emberfall Basin (one line to bring back)
	},
	EmberLure = {
		Id = "EmberLure",
		Name = "Ember Lure",
		Kind = "Item",
		Description = "A warm, sweet-smelling bundle. Throw it to befriend a wild creature. Crafted at the Trading Post.",
		Icon = "❂",
		Color = Color3.fromRGB(255, 170, 80),
		MaxStack = 20,
		Enabled = false, -- out for now, with Emberfall Basin (lures befriend its wild creatures)
	},
	RefinedCrystal = {
		Id = "RefinedCrystal",
		Name = "Refined Crystal",
		Kind = "Material",
		Description = "Smelted crystal. Needed for high Empire Core tiers, expansions and Essence.",
		Icon = "◆",
		Color = Color3.fromRGB(120, 230, 255),
		SellPrice = 46,
	},
}

return ResourceConfig
