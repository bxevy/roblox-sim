-- Dungeon definitions. Each dungeon is a line of rooms; clear a room to open the
-- next door. The last room holds the boss.
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
	Difficulties: { [string]: DifficultySettings }, -- keyed by Config.DifficultyOrder ids
	Theme: {
		Floor: Color3,
		FloorMaterial: Enum.Material,
		Wall: Color3,
		WallMaterial: Enum.Material,
		Torch: Color3,
	},
}

local Dungeons = {}

Dungeons.Defs = {
	Crypt = {
		DisplayName = "Crypt of Bones",
		Power = 1,
		Rooms = {
			{ Skeleton = 3 },
			{ Skeleton = 4, Zombie = 1 },
			{ Skeleton = 3, Zombie = 3 },
		},
		Boss = "BoneKing",
		Rewards = { XP = 150, Gold = 60 },
		Difficulties = {
			Easy = { Level = 1, Loot = { [1] = 70, [2] = 30 } },
			Normal = { Level = 3, Loot = { [2] = 70, [3] = 30 } },
			Hard = { Level = 6, Loot = { [3] = 70, [4] = 30 } },
			Nightmare = { Level = 9, Loot = { [4] = 70, [5] = 30 } },
		},
		Theme = {
			Floor = Color3.fromRGB(70, 70, 75),
			FloorMaterial = Enum.Material.Slate,
			Wall = Color3.fromRGB(95, 95, 100),
			WallMaterial = Enum.Material.Cobblestone,
			Torch = Color3.fromRGB(255, 150, 60),
		},
	},
	Temple = {
		DisplayName = "Sunken Temple",
		Power = 3,
		Rooms = {
			{ Mummy = 3, Scarab = 3 },
			{ Mummy = 4, Scarab = 4 },
			{ Mummy = 5, Scarab = 5 },
		},
		Boss = "Pharaoh",
		Rewards = { XP = 600, Gold = 250 },
		Difficulties = {
			Easy = { Level = 10, Loot = { [3] = 70, [4] = 30 } },
			Normal = { Level = 13, Loot = { [4] = 70, [5] = 30 } },
			Hard = { Level = 16, Loot = { [5] = 70, [6] = 30 } },
			Nightmare = { Level = 19, Loot = { [6] = 75, [7] = 25 } },
		},
		Theme = {
			Floor = Color3.fromRGB(200, 170, 110),
			FloorMaterial = Enum.Material.Sandstone,
			Wall = Color3.fromRGB(180, 150, 95),
			WallMaterial = Enum.Material.Sandstone,
			Torch = Color3.fromRGB(80, 255, 170),
		},
	},
	Keep = {
		DisplayName = "Frozen Keep",
		Power = 8,
		Rooms = {
			{ Yeti = 2, FrostWraith = 4 },
			{ Yeti = 3, FrostWraith = 5 },
			{ Yeti = 4, FrostWraith = 6 },
		},
		Boss = "FrostLord",
		Rewards = { XP = 2000, Gold = 800 },
		Difficulties = {
			Easy = { Level = 20, Loot = { [5] = 70, [6] = 30 } },
			Normal = { Level = 24, Loot = { [6] = 70, [7] = 30 } },
			Hard = { Level = 28, Loot = { [7] = 75, [8] = 25 } },
			Nightmare = { Level = 32, Loot = { [7] = 40, [8] = 60 } },
		},
		Theme = {
			Floor = Color3.fromRGB(200, 225, 240),
			FloorMaterial = Enum.Material.Glacier,
			Wall = Color3.fromRGB(150, 180, 210),
			WallMaterial = Enum.Material.Ice,
			Torch = Color3.fromRGB(120, 200, 255),
		},
	},
} :: { [string]: DungeonDef }

-- Order the portals appear in the lobby (left to right).
Dungeons.Order = { "Crypt", "Temple", "Keep" }

return Dungeons
