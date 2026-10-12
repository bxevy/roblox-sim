-- Dungeon definitions. Each dungeon is a line of rooms; clear a room to open the
-- next door. The last room holds the boss.

export type LootEntry = { Weapon: string, Weight: number }

export type DungeonDef = {
	DisplayName: string,
	MinLevel: number,
	Power: number, -- multiplies enemy Health, Damage, XP and Gold
	Rooms: { { [string]: number } }, -- each room: { EnemyId = count }
	Boss: string,
	Rewards: { XP: number, Gold: number },
	Loot: { LootEntry }, -- one weapon is rolled for each player on victory
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
		MinLevel = 1,
		Power = 1,
		Rooms = {
			{ Skeleton = 3 },
			{ Skeleton = 4, Zombie = 1 },
			{ Skeleton = 3, Zombie = 3 },
		},
		Boss = "BoneKing",
		Rewards = { XP = 150, Gold = 60 },
		Loot = {
			{ Weapon = "IronSword", Weight = 60 },
			{ Weapon = "SteelBlade", Weight = 30 },
			{ Weapon = "KnightsLongsword", Weight = 10 },
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
		MinLevel = 5,
		Power = 3,
		Rooms = {
			{ Mummy = 3, Scarab = 3 },
			{ Mummy = 4, Scarab = 4 },
			{ Mummy = 5, Scarab = 5 },
		},
		Boss = "Pharaoh",
		Rewards = { XP = 600, Gold = 250 },
		Loot = {
			{ Weapon = "SteelBlade", Weight = 40 },
			{ Weapon = "KnightsLongsword", Weight = 35 },
			{ Weapon = "SandReaver", Weight = 23 },
			{ Weapon = "Dragonfang", Weight = 2 },
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
		MinLevel = 10,
		Power = 7,
		Rooms = {
			{ Yeti = 2, FrostWraith = 4 },
			{ Yeti = 3, FrostWraith = 5 },
			{ Yeti = 4, FrostWraith = 6 },
		},
		Boss = "FrostLord",
		Rewards = { XP = 2000, Gold = 800 },
		Loot = {
			{ Weapon = "SandReaver", Weight = 40 },
			{ Weapon = "ObsidianCleaver", Weight = 32 },
			{ Weapon = "Frostbrand", Weight = 23 },
			{ Weapon = "Dragonfang", Weight = 5 },
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
