-- Central place for tunable game values. Balance the game here, not in scripts.

local Config = {}

Config.GameName = "Dungeon Delvers"

Config.DataStoreName = "DungeonData_v1"
Config.AutosaveInterval = 120 -- seconds

Config.DefaultData = {
	Level = 1,
	XP = 0,
	Gold = 0,
	Equipped = "WoodenSword",
	Inventory = { WoodenSword = true }, -- set of owned weapon ids
}

-- Leveling ---------------------------------------------------------------

Config.MaxLevel = 100

-- XP needed to go from `level` to `level + 1`.
function Config.XPToLevel(level: number): number
	return math.floor(100 * level ^ 1.5)
end

function Config.MaxHealth(level: number): number
	return 100 + (level - 1) * 15
end

function Config.DamageMultiplier(level: number): number
	return 1 + (level - 1) * 0.08
end

-- Combat -----------------------------------------------------------------

Config.CritChance = 0.1
Config.CritMultiplier = 2

Config.Abilities = {
	Whirlwind = {
		Key = Enum.KeyCode.Q,
		DisplayName = "Whirlwind",
		Cooldown = 8,
		Radius = 14,
		DamageMultiplier = 2.5, -- x your weapon damage, hits everything around you
		Color = Color3.fromRGB(255, 170, 60),
	},
	Heal = {
		Key = Enum.KeyCode.E,
		DisplayName = "Heal",
		Cooldown = 20,
		HealPercent = 0.35, -- of max health
		Color = Color3.fromRGB(90, 230, 120),
	},
}
Config.AbilityOrder = { "Whirlwind", "Heal" }

Config.Rarities = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 90),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 160, 40),
}

-- Parties ----------------------------------------------------------------

Config.Party = {
	MaxSize = 4,
	Countdown = 10, -- seconds on a portal pad before the dungeon starts
	PadRadius = 7,
}

-- Gold given instead of a weapon you already own.
Config.DuplicateWeaponGold = 25

return Config
