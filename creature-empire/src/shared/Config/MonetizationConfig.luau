--!strict
-- Robux purchases (the Empire Shop). Currency packs and boosts are things you can also earn
-- by playing; the Meadow Sprout is the one shop-exclusive creature (in the Starter Bundle).
-- The one random purchase is an extra Spin Wheel spin (PaidSpin, below), sold only next to
-- the wheel's exact odds and never to players where paid random items are restricted.
--
-- Ids are 0 until you create the pass or developer product on the Creator Dashboard
-- (Monetization) and paste its id here. While an id is 0 the shop shows "Coming soon" and
-- the server refuses it. The price shown is the one you set on the dashboard.

export type Tab = "Featured" | "Coins" | "Essence" | "Boosts" | "Passes"

export type Pass = {
	Id: number,
	Name: string,
	Description: string,
	Glyph: string,
	Color: Color3,
	Tab: Tab,
	Featured: boolean?,
	Badge: string?, -- ribbon text ("Exclusive Pet!")
	-- One-time rewards granted once when the pass is owned (Starter Bundle).
	Grants: { Gold: number?, Species: string?, FarmBoostSeconds: number? }?,
}

export type Product = {
	Id: number,
	Name: string,
	Description: string, -- the line under the picture ("500 Gold")
	Glyph: string,
	Color: Color3,
	Tab: Tab,
	Featured: boolean?,
	Kind: "Currency" | "FarmBoost" | "LuckBoost",
	Currency: string?,
	Amount: number?,
	Seconds: number?,
}

local MonetizationConfig = {}

MonetizationConfig.Tabs = { "Featured", "Coins", "Essence", "Boosts", "Passes" } :: { Tab }

MonetizationConfig.Passes = {
	StarterBundle = {
		Id = 0,
		Name = "Meadow Starter Bundle",
		Description = "Get a head start on your empire! Exclusive Meadow Sprout pet, 500 Gold and 2x Farm Speed (15 minutes).",
		Glyph = "❦",
		Color = Color3.fromRGB(110, 200, 80),
		Tab = "Passes",
		Featured = true,
		Badge = "Exclusive Pet!",
		Grants = { Gold = 500, Species = "MeadowSprout", FarmBoostSeconds = 15 * 60 },
	},
	Supporter = {
		Id = 0,
		Name = "Supporter",
		Description = "A golden ★ on your plot sign and name, and a sparkle trail on your companion. Purely cosmetic: thank you for supporting the game!",
		Glyph = "★",
		Color = Color3.fromRGB(255, 200, 70),
		Tab = "Passes",
	},
} :: { [string]: Pass }

MonetizationConfig.Products = {
	GoldPouch = {
		Id = 0,
		Name = "Pouch of Gold",
		Description = "500 Gold",
		Glyph = "●",
		Color = Color3.fromRGB(240, 190, 70),
		Tab = "Coins",
		Featured = true,
		Kind = "Currency",
		Currency = "Gold",
		Amount = 500,
	},
	GoldChest = {
		Id = 0,
		Name = "Chest of Gold",
		Description = "5,000 Gold",
		Glyph = "●",
		Color = Color3.fromRGB(255, 170, 40),
		Tab = "Coins",
		Featured = true,
		Kind = "Currency",
		Currency = "Gold",
		Amount = 5000,
	},
	EssenceVial = {
		Id = 0,
		Name = "Essence Vial",
		Description = "150 Essence",
		Glyph = "✧",
		Color = Color3.fromRGB(170, 100, 240),
		Tab = "Essence",
		Featured = true,
		Kind = "Currency",
		Currency = "Essence",
		Amount = 150,
	},
	LuckElixir = {
		Id = 0,
		Name = "2x Luck Elixir",
		Description = "2x chance for rare creatures from eggs (15 minutes)",
		Glyph = "✦",
		Color = Color3.fromRGB(90, 200, 90),
		Tab = "Boosts",
		Featured = true,
		Kind = "LuckBoost",
		Seconds = 15 * 60,
	},
	FarmSpeed = {
		Id = 0,
		Name = "2x Farm Speed",
		Description = "Your creatures work twice as fast (15 minutes)",
		Glyph = "⚡",
		Color = Color3.fromRGB(80, 170, 255),
		Tab = "Boosts",
		Featured = true,
		Kind = "FarmBoost",
		Seconds = 15 * 60,
	},
} :: { [string]: Product }

-- An extra Spin Wheel spin for Robux (a developer product; not listed in the shop). Same
-- prizes and odds as the free spin, which it doesn't touch. Offered only where Roblox's
-- PolicyService allows paid random items (ArePaidRandomItemsRestricted is false).
MonetizationConfig.PaidSpin = { Id = 0, Price = 199 }

-- Farm Speed: +100% work speed in the capped Boost bonus category, stacking up to MaxSeconds.
MonetizationConfig.Boost = { Stat = "WorkSpeed", Value = 1.0, MaxSeconds = 2 * 60 * 60 }
MonetizationConfig.MaxReceipts = 200 -- receipts kept per profile (oldest pruned)

return MonetizationConfig
