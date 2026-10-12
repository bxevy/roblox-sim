-- Dungeon definitions. Each dungeon is a line of rooms; clear a room to open the
-- next door. Halfway through, a mini-boss guards the way; the last room holds the boss.
-- Bosses and mini-bosses have mechanics (see Enemies.luau).
--
-- Every dungeon has 4 difficulties. Each unlocks at a level and drops better loot tiers
-- (see Items.luau for what each tier contains). Difficulty stat multipliers are in Config.

export type DifficultySettings = {
	Level: number, -- level needed to unlock this difficulty
	Loot: { [number]: number }, -- item tier -> weight; each player gets one item on victory
}

export type DungeonDef = {
	DisplayName: string,
	Power: number, -- multiplies enemy Health, Damage, XP and Gold (difficulty multiplies on top)
	Rooms: { { [string]: number } }, -- each room: { EnemyId = count }
	Boss: string,
	Rewards: { XP: number, Gold: number },
	MythicMultiplier: number?, -- multiplies the ultra-rare Mythic drop chance
	Event: string?, -- limited-time event dungeon (Config.Events): only open while it runs
	Difficulties: { [string]: DifficultySettings }, -- keyed by Config.DifficultyOrder ids
	Theme: {
		Style: string, -- "Crypt" | "Forest" | "Temple" | "Ice" | "Volcano" | "Void" | "Halloween"
		Floor: Color3,
		FloorMaterial: Enum.Material,
		Wall: Color3,
		WallMaterial: Enum.Material,
		Torch: Color3,
	},
}

local Dungeons = {}

local rgb = Color3.fromRGB
local M = Enum.Material

Dungeons.Defs = {
	Crypt = {
		DisplayName = "Crypt of Bones",
		Power = 1,
		Rooms = {
			{ Skeleton = 3 },
			{ Skeleton = 3, Zombie = 1 },
			{ Skeleton = 3, SkeletonArcher = 2 },
			{ GraveWarden = 1, Skeleton = 2 },
			{ Zombie = 3, SkeletonArcher = 2 },
			{ Skeleton = 4, Zombie = 2, SkeletonArcher = 2 },
		},
		Boss = "BoneKing",
		Rewards = { XP = 220, Gold = 90 },
		Difficulties = {
			Easy = { Level = 1, Loot = { [1] = 70, [2] = 30 } },
			Normal = { Level = 3, Loot = { [2] = 70, [3] = 30 } },
			Hard = { Level = 6, Loot = { [3] = 70, [4] = 30 } },
			Nightmare = { Level = 9, Loot = { [4] = 70, [5] = 30 } },
		},
		Theme = { Style = "Crypt", Floor = rgb(70, 70, 75), FloorMaterial = M.Slate, Wall = rgb(95, 95, 100), WallMaterial = M.Cobblestone, Torch = rgb(255, 150, 60) },
	},
	Witchwood = {
		DisplayName = "Witchwood Hollow",
		Power = 2,
		Rooms = {
			{ Wolf = 4 },
			{ Wolf = 3, Treant = 1 },
			{ Witch = 2, Wolf = 3 },
			{ AlphaWolf = 1, Wolf = 2 },
			{ Treant = 2, Witch = 2 },
			{ Wolf = 4, Treant = 2, Witch = 2 },
		},
		Boss = "HagQueen",
		Rewards = { XP = 450, Gold = 180 },
		Difficulties = {
			Easy = { Level = 5, Loot = { [2] = 60, [3] = 40 } },
			Normal = { Level = 8, Loot = { [3] = 60, [4] = 40 } },
			Hard = { Level = 11, Loot = { [4] = 60, [5] = 40 } },
			Nightmare = { Level = 14, Loot = { [5] = 70, [6] = 30 } },
		},
		Theme = { Style = "Forest", Floor = rgb(70, 95, 50), FloorMaterial = M.Grass, Wall = rgb(80, 60, 40), WallMaterial = M.Wood, Torch = rgb(190, 110, 255) },
	},
	Temple = {
		DisplayName = "Sunken Temple",
		Power = 3,
		Rooms = {
			{ Mummy = 3, Scarab = 3 },
			{ Mummy = 3, CobraPriest = 2 },
			{ Scarab = 6, CobraPriest = 1 },
			{ AnubisSentinel = 1, Mummy = 2 },
			{ Mummy = 4, Scarab = 4, CobraPriest = 2 },
			{ Mummy = 5, Scarab = 5, CobraPriest = 2 },
		},
		Boss = "Pharaoh",
		Rewards = { XP = 900, Gold = 380 },
		Difficulties = {
			Easy = { Level = 12, Loot = { [3] = 70, [4] = 30 } },
			Normal = { Level = 15, Loot = { [4] = 70, [5] = 30 } },
			Hard = { Level = 18, Loot = { [5] = 70, [6] = 30 } },
			Nightmare = { Level = 21, Loot = { [6] = 75, [7] = 25 } },
		},
		Theme = { Style = "Temple", Floor = rgb(200, 170, 110), FloorMaterial = M.Sandstone, Wall = rgb(180, 150, 95), WallMaterial = M.Sandstone, Torch = rgb(80, 255, 170) },
	},
	Keep = {
		DisplayName = "Frozen Keep",
		Power = 8,
		Rooms = {
			{ Yeti = 2, FrostWraith = 4 },
			{ FrostWraith = 4, FrostMage = 2 },
			{ Yeti = 3, FrostMage = 2 },
			{ FrostGiant = 1, FrostWraith = 3 },
			{ Yeti = 3, FrostWraith = 4, FrostMage = 2 },
			{ Yeti = 4, FrostWraith = 6, FrostMage = 2 },
		},
		Boss = "FrostLord",
		Rewards = { XP = 3000, Gold = 1200 },
		Difficulties = {
			Easy = { Level = 22, Loot = { [5] = 70, [6] = 30 } },
			Normal = { Level = 25, Loot = { [6] = 70, [7] = 30 } },
			Hard = { Level = 28, Loot = { [7] = 75, [8] = 25 } },
			Nightmare = { Level = 31, Loot = { [7] = 40, [8] = 60 } },
		},
		Theme = { Style = "Ice", Floor = rgb(200, 225, 240), FloorMaterial = M.Glacier, Wall = rgb(150, 180, 210), WallMaterial = M.Ice, Torch = rgb(120, 200, 255) },
	},
	Forge = {
		DisplayName = "Infernal Forge",
		Power = 18,
		Rooms = {
			{ MagmaImp = 5 },
			{ MagmaImp = 3, ObsidianGolem = 1, FireCaster = 1 },
			{ ObsidianGolem = 2, FireCaster = 2 },
			{ Forgemaster = 1, MagmaImp = 3 },
			{ MagmaImp = 4, FireCaster = 3 },
			{ MagmaImp = 4, ObsidianGolem = 3, FireCaster = 2 },
		},
		Boss = "Infernus",
		Rewards = { XP = 7000, Gold = 2800 },
		Difficulties = {
			Easy = { Level = 33, Loot = { [6] = 60, [7] = 40 } },
			Normal = { Level = 36, Loot = { [7] = 70, [8] = 30 } },
			Hard = { Level = 39, Loot = { [7] = 45, [8] = 55 } },
			Nightmare = { Level = 42, Loot = { [8] = 100 } },
		},
		Theme = { Style = "Volcano", Floor = rgb(45, 35, 35), FloorMaterial = M.Basalt, Wall = rgb(60, 45, 40), WallMaterial = M.Slate, Torch = rgb(255, 120, 30) },
	},
	Abyss = {
		DisplayName = "Abyssal Rift",
		Power = 35,
		Rooms = {
			{ VoidStalker = 4, Shade = 1 },
			{ Shade = 3, AbyssalHorror = 1 },
			{ VoidStalker = 4, AbyssalHorror = 2 },
			{ VoidHerald = 1, Shade = 2 },
			{ VoidStalker = 4, Shade = 3, AbyssalHorror = 1 },
			{ VoidStalker = 5, Shade = 3, AbyssalHorror = 3 },
		},
		Boss = "VoidEmperor",
		Rewards = { XP = 15000, Gold = 6000 },
		MythicMultiplier = 3,
		Difficulties = {
			Easy = { Level = 40, Loot = { [7] = 50, [8] = 50 } },
			Normal = { Level = 44, Loot = { [8] = 100 } },
			Hard = { Level = 47, Loot = { [8] = 100 } },
			Nightmare = { Level = 50, Loot = { [8] = 100 } },
		},
		Theme = { Style = "Void", Floor = rgb(25, 20, 35), FloorMaterial = M.Glass, Wall = rgb(35, 25, 50), WallMaterial = M.Slate, Torch = rgb(190, 110, 255) },
	},
	-- Halloween event: SUPER HARD. Every clear gives event candies (Config.Events.Halloween).
	Haunted = {
		DisplayName = "Haunted Manor",
		Power = 50,
		Rooms = {
			{ JackOLantern = 3, VampireBat = 4 },
			{ Phantom = 4, Banshee = 2, VampireBat = 2 },
			{ JackOLantern = 4, Banshee = 3 },
			{ HeadlessHorseman = 1, VampireBat = 4 },
			{ Phantom = 5, JackOLantern = 3, Banshee = 2 },
			{ JackOLantern = 5, Phantom = 4, Banshee = 3, VampireBat = 4 },
		},
		Boss = "PumpkinKing",
		Rewards = { XP = 25000, Gold = 9000 },
		MythicMultiplier = 2,
		Event = "Halloween",
		Difficulties = {
			Easy = { Level = 35, Loot = { [7] = 60, [8] = 40 } },
			Normal = { Level = 42, Loot = { [8] = 100 } },
			Hard = { Level = 47, Loot = { [8] = 100 } },
			Nightmare = { Level = 50, Loot = { [8] = 100 } },
		},
		Theme = { Style = "Halloween", Floor = rgb(45, 35, 40), FloorMaterial = M.WoodPlanks, Wall = rgb(55, 40, 60), WallMaterial = M.Brick, Torch = rgb(255, 130, 30) },
	},
} :: { [string]: DungeonDef }

-- Order the portals appear in the lobby (left to right). Event dungeons only get a portal
-- while their event runs.
Dungeons.Order = { "Crypt", "Witchwood", "Temple", "Keep", "Forge", "Abyss", "Haunted" }

return Dungeons
