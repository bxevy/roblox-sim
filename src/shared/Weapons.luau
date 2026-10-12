-- Every weapon in the game. Drop tables live in Dungeons.luau.

export type WeaponDef = {
	DisplayName: string,
	Rarity: string,
	Damage: number,
	Cooldown: number, -- seconds between swings
	Range: number, -- studs in front of you
	BladeColor: Color3,
	BladeMaterial: Enum.Material,
	BladeLength: number,
}

local Weapons = {}

Weapons.Defs = {
	WoodenSword = {
		DisplayName = "Wooden Sword",
		Rarity = "Common",
		Damage = 10,
		Cooldown = 0.5,
		Range = 7,
		BladeColor = Color3.fromRGB(150, 105, 60),
		BladeMaterial = Enum.Material.Wood,
		BladeLength = 3.5,
	},
	IronSword = {
		DisplayName = "Iron Sword",
		Rarity = "Uncommon",
		Damage = 18,
		Cooldown = 0.5,
		Range = 7,
		BladeColor = Color3.fromRGB(165, 165, 175),
		BladeMaterial = Enum.Material.Metal,
		BladeLength = 4,
	},
	SteelBlade = {
		DisplayName = "Steel Blade",
		Rarity = "Rare",
		Damage = 30,
		Cooldown = 0.45,
		Range = 7.5,
		BladeColor = Color3.fromRGB(210, 215, 225),
		BladeMaterial = Enum.Material.Metal,
		BladeLength = 4.2,
	},
	KnightsLongsword = {
		DisplayName = "Knight's Longsword",
		Rarity = "Rare",
		Damage = 42,
		Cooldown = 0.6,
		Range = 9,
		BladeColor = Color3.fromRGB(235, 235, 245),
		BladeMaterial = Enum.Material.Metal,
		BladeLength = 5,
	},
	SandReaver = {
		DisplayName = "Sand Reaver",
		Rarity = "Epic",
		Damage = 65,
		Cooldown = 0.5,
		Range = 8,
		BladeColor = Color3.fromRGB(235, 195, 90),
		BladeMaterial = Enum.Material.Metal,
		BladeLength = 4.5,
	},
	ObsidianCleaver = {
		DisplayName = "Obsidian Cleaver",
		Rarity = "Epic",
		Damage = 90,
		Cooldown = 0.7,
		Range = 9,
		BladeColor = Color3.fromRGB(45, 30, 60),
		BladeMaterial = Enum.Material.Glass,
		BladeLength = 5,
	},
	Frostbrand = {
		DisplayName = "Frostbrand",
		Rarity = "Epic",
		Damage = 120,
		Cooldown = 0.5,
		Range = 8.5,
		BladeColor = Color3.fromRGB(150, 220, 255),
		BladeMaterial = Enum.Material.Ice,
		BladeLength = 4.8,
	},
	Dragonfang = {
		DisplayName = "Dragonfang",
		Rarity = "Legendary",
		Damage = 200,
		Cooldown = 0.5,
		Range = 10,
		BladeColor = Color3.fromRGB(255, 110, 40),
		BladeMaterial = Enum.Material.Neon,
		BladeLength = 5.5,
	},
} :: { [string]: WeaponDef }

-- Display order in the inventory (weakest first).
Weapons.Order = {
	"WoodenSword",
	"IronSword",
	"SteelBlade",
	"KnightsLongsword",
	"SandReaver",
	"ObsidianCleaver",
	"Frostbrand",
	"Dragonfang",
}

return Weapons
