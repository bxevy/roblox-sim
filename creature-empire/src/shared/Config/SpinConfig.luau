--!strict
-- The Spin Wheel in the plaza. One free spin every 30 minutes (the timer runs while you
-- are offline too, but only one spin is ever waiting). Spins are free only: they are never
-- sold for Robux. The odds below are exact (Weight / total) and shown on the wheel.

export type Prize = {
	Id: string,
	Name: string,
	Short: string, -- text on the wheel segment
	Kind: "Currency" | "Boost" | "Creature",
	Currency: string?,
	Amount: number?,
	Boost: string?, -- "Coins" | "Luck"
	Species: string?,
	Weight: number,
	Color: Color3,
}

local SpinConfig = {}

SpinConfig.FreeEvery = 30 * 60 -- seconds between free spins
SpinConfig.BoostSeconds = 30 * 60 -- how long a 2x boost lasts
SpinConfig.BoostMultiplier = 2
SpinConfig.MaxBoostSeconds = 6 * 3600 -- boosts stack up to this much time
SpinConfig.AnimationSeconds = 4.5 -- how long the wheel spins on screen

SpinConfig.Boosts = {
	Coins = { Id = "Coins", Name = "2× Coins", Glyph = "●", Description = "Double gold from selling and abilities." },
	Luck = {
		Id = "Luck",
		Name = "2× Luck",
		Glyph = "✦",
		Description = "Rare-or-better creatures are twice as likely from eggs.",
	},
}

-- In wheel order (clockwise from the top). Weights add up to 1000.
SpinConfig.Prizes = {
	{
		Id = "Gold500",
		Name = "500 Gold",
		Short = "500",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 500,
		Weight = 321,
		Color = Color3.fromRGB(240, 190, 70),
	},
	{
		Id = "CoinBoost",
		Name = "2× Coins for 30 minutes",
		Short = "2× Coins",
		Kind = "Boost",
		Boost = "Coins",
		Weight = 100,
		Color = Color3.fromRGB(255, 140, 60),
	},
	{
		Id = "Gold1000",
		Name = "1,000 Gold",
		Short = "1K",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 1000,
		Weight = 220,
		Color = Color3.fromRGB(110, 200, 120),
	},
	{
		Id = "Essence25",
		Name = "25 Essence",
		Short = "25 ✧",
		Kind = "Currency",
		Currency = "Essence",
		Amount = 25,
		Weight = 120,
		Color = Color3.fromRGB(150, 120, 255),
	},
	{
		Id = "Gold2500",
		Name = "2,500 Gold",
		Short = "2.5K",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 2500,
		Weight = 100,
		Color = Color3.fromRGB(80, 170, 255),
	},
	{
		Id = "LuckBoost",
		Name = "2× Luck for 30 minutes",
		Short = "2× Luck",
		Kind = "Boost",
		Boost = "Luck",
		Weight = 100,
		Color = Color3.fromRGB(70, 210, 190),
	},
	{
		Id = "Gold5000",
		Name = "5,000 Gold",
		Short = "5K",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 5000,
		Weight = 36,
		Color = Color3.fromRGB(230, 90, 120),
	},
	{
		Id = "BlackDragon",
		Name = "BLACK DRAGON",
		Short = "DRAGON",
		Kind = "Creature",
		Species = "BlackDragon",
		Weight = 3,
		Color = Color3.fromRGB(30, 26, 36),
	},
} :: { Prize }

return SpinConfig
