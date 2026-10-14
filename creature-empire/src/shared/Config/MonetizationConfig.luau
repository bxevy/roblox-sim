--!strict
-- Optional Robux purchases. Fair by design:
--   * cosmetics and convenience only; nothing random is ever sold (eggs, mutations and
--     creatures can't be bought), and nothing that can't also be earned by playing
--   * every boost uses the capped "Boost" bonus category, like world events and cheers
--
-- Ids are 0 until you create the pass and product on the Creator Dashboard (Monetization)
-- and paste their ids here. While an id is 0 the shop shows the item as "coming soon" and
-- the server refuses it. Never paste an id you haven't created yourself.

export type Pass = { Id: number, Name: string, Description: string, Glyph: string }
export type Product = {
	Id: number,
	Name: string,
	Description: string,
	Glyph: string,
	Kind: "Boost",
	Seconds: number,
}

local MonetizationConfig = {}

MonetizationConfig.Passes = {
	Supporter = {
		Id = 0,
		Name = "Supporter",
		Description = "A golden ★ on your plot sign and name, and a sparkle trail on your companion. Purely cosmetic: thank you for supporting the game!",
		Glyph = "★",
	},
} :: { [string]: Pass }

MonetizationConfig.Products = {
	Boost30 = {
		Id = 0,
		Name = "Production Boost · 30 min",
		Description = "Your creatures work 25% faster for 30 minutes (stacks up to 2 hours). Uses the same capped bonus as Golden Hour.",
		Glyph = "⚡",
		Kind = "Boost",
		Seconds = 30 * 60,
	},
} :: { [string]: Product }

-- The shop doesn't sell a boost that would take the time left past MaxSeconds.
MonetizationConfig.Boost = { Stat = "WorkSpeed", Value = 0.25, MaxSeconds = 2 * 60 * 60 }
MonetizationConfig.MaxReceipts = 200 -- receipts kept per profile (oldest pruned)

return MonetizationConfig
