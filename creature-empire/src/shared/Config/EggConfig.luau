--!strict
-- Eggs hatched at the Hatchery. Odds are exactly Weight / total weight and the game shows
-- them in full before every hatch. Eggs cost in-game resources only; randomised rewards
-- are never sold for Robux.
--
-- Pity: if PityLimit - 1 hatches in a row give nothing of PityRarity or better, the next
-- hatch is guaranteed to (rolled among those creatures, same relative odds). Hatching one
-- naturally also resets the counter. Each egg type has its own counter.

export type LootEntry = { Species: string, Weight: number }
export type Egg = {
	Id: string,
	Name: string,
	Description: string,
	Cost: { [string]: number },
	Color: Color3,
	Spots: Color3,
	Loot: { LootEntry },
	PityRarity: string,
	PityLimit: number,
	Phase: number,
}

local EggConfig = {}

EggConfig.Eggs = {
	MeadowEgg = {
		Id = "MeadowEgg",
		Name = "Meadow Egg",
		Description = "Warm and grassy. Mostly gentle Verdant and Tideborn creatures.",
		Cost = { Gold = 300 },
		Color = Color3.fromRGB(190, 230, 150),
		Spots = Color3.fromRGB(110, 180, 90),
		Loot = {
			{ Species = "Sproutling", Weight = 28 },
			{ Species = "Puddlefin", Weight = 26 },
			{ Species = "Mossmaw", Weight = 20 },
			{ Species = "Gloomkit", Weight = 18 },
			{ Species = "Bloomhart", Weight = 8 },
		},
		PityRarity = "Rare",
		PityLimit = 15,
		Phase = 2,
	},
	EmberEgg = {
		Id = "EmberEgg",
		Name = "Ember Egg",
		Description = "Hot to the touch. Fire, lightning and clockwork creatures.",
		Cost = { Gold = 900, RawCrystal = 30 },
		Color = Color3.fromRGB(255, 160, 90),
		Spots = Color3.fromRGB(200, 70, 40),
		Loot = {
			{ Species = "Cindercub", Weight = 28 },
			{ Species = "Zappup", Weight = 24 },
			{ Species = "Ashwhisk", Weight = 20 },
			{ Species = "Cogling", Weight = 18 },
			{ Species = "Magmaul", Weight = 6 },
			{ Species = "Stormstrider", Weight = 4 },
		},
		PityRarity = "Rare",
		PityLimit = 15,
		Phase = 2,
	},
	GeodeEgg = {
		Id = "GeodeEgg",
		Name = "Geode Egg",
		Description = "A crystal shell that hums. Crystalkin and Aetherials, with a chance of an Epic.",
		Cost = { Essence = 30, RefinedCrystal = 5 },
		Color = Color3.fromRGB(170, 200, 255),
		Spots = Color3.fromRGB(150, 110, 255),
		Loot = {
			{ Species = "Pebblit", Weight = 26 },
			{ Species = "Shardback", Weight = 24 },
			{ Species = "Wisplet", Weight = 22 },
			{ Species = "Cogling", Weight = 12 },
			{ Species = "Geodon", Weight = 10 },
			{ Species = "Prismaw", Weight = 6 },
		},
		PityRarity = "Rare",
		PityLimit = 12,
		Phase = 2,
	},
	ArcaneEgg = {
		Id = "ArcaneEgg",
		Name = "Arcane Egg",
		Description = "Covered in glowing runes. Scholars, reef dwellers and clockwork helpers.",
		Cost = { Insight = 40, Essence = 20 },
		Color = Color3.fromRGB(110, 90, 190),
		Spots = Color3.fromRGB(120, 230, 200),
		Loot = {
			{ Species = "Runemoth", Weight = 22 },
			{ Species = "Bubblot", Weight = 22 },
			{ Species = "Boltbug", Weight = 22 },
			{ Species = "Gearhound", Weight = 12 },
			{ Species = "Coralisk", Weight = 12 },
			{ Species = "Starweaver", Weight = 10 },
		},
		PityRarity = "Rare",
		PityLimit = 12,
		Phase = 4,
	},
} :: { [string]: Egg }

EggConfig.Order = { "MeadowEgg", "EmberEgg", "GeodeEgg", "ArcaneEgg" }

return EggConfig
