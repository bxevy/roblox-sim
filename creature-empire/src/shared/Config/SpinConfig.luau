--!strict
-- The Spin Wheel in the plaza. One free spin every 30 minutes (the timer runs while you
-- are offline too, but only one spin is ever waiting). Spins are free only: they are never
-- sold for Robux. The odds below are exact (Weight / total) and shown on the wheel.

export type Prize = {
	Id: string,
	Name: string,
	Short: string, -- text on the wheel segment (two lines)
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
-- Where the prizes sit on the wheel picture (degrees, clockwise): the slices go round in
-- Prizes order and this turns them so 1,000 Gold is at the top, like the creator's art.
-- Change it if a wheel image (AssetConfig.Images.SpinWheelFace) is laid out differently.
SpinConfig.WheelOffset = -112.5

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
		Short = "500\nGold",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 500,
		Weight = 320,
		Color = Color3.fromRGB(250, 210, 40),
	},
	{
		Id = "CoinBoost",
		Name = "2× Coins for 30 minutes",
		Short = "2×\nCoins",
		Kind = "Boost",
		Boost = "Coins",
		Weight = 150,
		Color = Color3.fromRGB(255, 140, 30),
	},
	{
		Id = "Gold1000",
		Name = "1,000 Gold",
		Short = "1,000\nGold",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 1000,
		Weight = 200,
		Color = Color3.fromRGB(40, 215, 140),
	},
	{
		Id = "Essence25",
		Name = "25 Essence",
		Short = "25\nEssence",
		Kind = "Currency",
		Currency = "Essence",
		Amount = 25,
		Weight = 150,
		Color = Color3.fromRGB(150, 70, 230),
	},
	{
		Id = "Gold2500",
		Name = "2,500 Gold",
		Short = "2,500\nGold",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 2500,
		Weight = 100,
		Color = Color3.fromRGB(40, 215, 240),
	},
	{
		Id = "LuckBoost",
		Name = "2× Luck for 30 minutes",
		Short = "2×\nLuck",
		Kind = "Boost",
		Boost = "Luck",
		Weight = 25,
		Color = Color3.fromRGB(30, 200, 190),
	},
	{
		Id = "Gold5000",
		Name = "5,000 Gold",
		Short = "5,000\nGold",
		Kind = "Currency",
		Currency = "Gold",
		Amount = 5000,
		Weight = 50,
		Color = Color3.fromRGB(240, 60, 140),
	},
	{
		Id = "BlackDragon",
		Name = "BLACK DRAGON",
		Short = "BLACK\nDRAGON",
		Kind = "Creature",
		Species = "BlackDragon",
		Weight = 5,
		Color = Color3.fromRGB(28, 22, 52),
	},
} :: { Prize }

return SpinConfig
