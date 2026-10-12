-- Central place for tunable game values. Balance the game here, not in scripts.

local Config = {}

Config.GameName = "Dungeon Delvers"

Config.DataStoreName = "DungeonData_v2"
Config.AutosaveInterval = 120 -- seconds

Config.DefaultData = {
	Level = 1,
	XP = 0,
	Gold = 0,
	-- Class = nil until the player picks one
	Weapons = {}, -- set of owned weapon ids
	Armors = {}, -- set of owned armor piece ids
	Equipped = {}, -- { Weapon = id?, Helmet = id?, Chest = id?, Legs = id?, Boots = id? }
	Potions = {}, -- potion id -> count
	Stats = { -- lifetime stats for leaderboards
		EnemiesKilled = 0,
		DungeonsCleared = 0,
		BossesKilled = 0,
		GoldEarned = 0,
		CratesOpened = 0,
		Deaths = 0,
		MinutesPlayed = 0,
	},
	Prestige = 0,
	SkillPoints = 0,
	Skills = {}, -- skill id -> rank
	Quests = {}, -- managed by QuestService
	Card = {
		Background = "Parchment",
		Title = "Adventurer",
		Frame = "Wood",
		Showcase = { "EnemiesKilled", "DungeonsCleared", "BossesKilled" },
	},
}

-- Leveling ------------------------------------------------------------------

Config.MaxLevel = 50

-- Prestige: at max level you can reset to level 1 for a permanent bonus and a new emblem.
Config.Prestige = {
	Max = 10,
	XPBonus = 0.1, -- +10% XP per prestige
	GoldBonus = 0.1, -- +10% coins per prestige
	SkillPoints = 5, -- bonus skill points each time you prestige
}

-- Skills: 1 point per level gained (plus quest and prestige bonuses). Spent at the
-- Skill Sanctum in the training grounds. Skills are kept when you prestige.
Config.Skills = {
	Vitality = { DisplayName = "Vitality", Description = "+4% max health", MaxRank = 10, PerRank = 0.04, Color = Color3.fromRGB(230, 80, 80) },
	Strength = { DisplayName = "Strength", Description = "+3% damage", MaxRank = 10, PerRank = 0.03, Color = Color3.fromRGB(255, 140, 50) },
	Toughness = { DisplayName = "Toughness", Description = "+1.5% defense", MaxRank = 10, PerRank = 0.015, Color = Color3.fromRGB(150, 160, 180) },
	Agility = { DisplayName = "Agility", Description = "+2% move speed", MaxRank = 5, PerRank = 0.02, Color = Color3.fromRGB(120, 230, 160) },
	Endurance = { DisplayName = "Endurance", Description = "+10 max stamina", MaxRank = 5, PerRank = 10, Color = Color3.fromRGB(240, 200, 60) },
	Precision = { DisplayName = "Precision", Description = "+1.5% critical hit chance", MaxRank = 10, PerRank = 0.015, Color = Color3.fromRGB(255, 220, 120) },
	Focus = { DisplayName = "Focus", Description = "-4% ability cooldowns", MaxRank = 5, PerRank = 0.04, Color = Color3.fromRGB(120, 170, 255) },
	Fortune = { DisplayName = "Fortune", Description = "+5% coins earned", MaxRank = 10, PerRank = 0.05, Color = Color3.fromRGB(255, 200, 60) },
	Wisdom = { DisplayName = "Wisdom", Description = "+5% XP earned", MaxRank = 10, PerRank = 0.05, Color = Color3.fromRGB(180, 120, 255) },
}
Config.SkillOrder = { "Vitality", "Strength", "Toughness", "Agility", "Endurance", "Precision", "Focus", "Fortune", "Wisdom" }

-- Skill points needed to buy the next rank (ranks start at 0).
function Config.SkillCost(currentRank: number): number
	return 1 + math.floor(currentRank / 4)
end

-- XP needed to go from `level` to `level + 1`.
function Config.XPToLevel(level: number): number
	return math.floor(50 * level ^ 1.5)
end

function Config.BaseHealth(level: number): number
	return 100 + (level - 1) * 15
end

function Config.LevelDamageMultiplier(level: number): number
	return 1 + (level - 1) * 0.08
end

Config.BaseWalkSpeed = 16
Config.MaxDefense = 0.8 -- damage reduction can never go above 80%

-- Classes -------------------------------------------------------------------

export type ClassDef = {
	DisplayName: string,
	Description: string,
	WeaponType: string, -- "Sword" | "Staff" | "Bow"
	StarterWeapon: string,
	HealthMultiplier: number,
	DamageMultiplier: number,
	Defense: number,
	SpeedMultiplier: number,
	Abilities: { string }, -- first is on Q, second on E
	Color: Color3,
}

Config.Classes = {
	Warrior = {
		DisplayName = "Warrior",
		Description = "Sword fighter. Tough, extra health and defense.",
		WeaponType = "Sword",
		StarterWeapon = "WoodenSword",
		HealthMultiplier = 1.3,
		DamageMultiplier = 1,
		Defense = 0.1,
		SpeedMultiplier = 1,
		Abilities = { "Whirlwind", "ShieldWall" },
		Color = Color3.fromRGB(220, 70, 60),
	},
	Mage = {
		DisplayName = "Mage",
		Description = "Staff caster. Ranged magic that splashes, can heal the party.",
		WeaponType = "Staff",
		StarterWeapon = "ApprenticeStaff",
		HealthMultiplier = 0.85,
		DamageMultiplier = 1.25,
		Defense = 0,
		SpeedMultiplier = 1,
		Abilities = { "Fireball", "HealingCircle" },
		Color = Color3.fromRGB(80, 120, 255),
	},
	Ranger = {
		DisplayName = "Ranger",
		Description = "Archer. Long range, fast attacks, the quickest on their feet.",
		WeaponType = "Bow",
		StarterWeapon = "HuntingBow",
		HealthMultiplier = 1,
		DamageMultiplier = 1.1,
		Defense = 0.05,
		SpeedMultiplier = 1.15,
		Abilities = { "Volley", "SwiftStep" },
		Color = Color3.fromRGB(70, 190, 90),
	},
} :: { [string]: ClassDef }

Config.ClassOrder = { "Warrior", "Mage", "Ranger" }

-- Abilities -----------------------------------------------------------------

Config.Abilities = {
	-- Warrior
	Whirlwind = {
		DisplayName = "Whirlwind",
		Cooldown = 8,
		Radius = 14,
		DamageMultiplier = 2.5, -- x weapon damage, hits everything around you
		Color = Color3.fromRGB(255, 170, 60),
	},
	ShieldWall = {
		DisplayName = "Shield Wall",
		Cooldown = 18,
		Buff = "ShieldWall",
		Duration = 4,
		Color = Color3.fromRGB(120, 170, 255),
	},
	-- Mage
	Fireball = {
		DisplayName = "Fireball",
		Cooldown = 7,
		Range = 50,
		Radius = 10,
		DamageMultiplier = 3,
		Color = Color3.fromRGB(255, 110, 30),
	},
	HealingCircle = {
		DisplayName = "Healing Circle",
		Cooldown = 18,
		Radius = 22,
		HealPercent = 0.3, -- heals you and nearby teammates
		Color = Color3.fromRGB(90, 230, 120),
	},
	-- Ranger
	Volley = {
		DisplayName = "Volley",
		Cooldown = 7,
		Range = 55,
		MaxTargets = 5,
		DamageMultiplier = 1.8,
		Color = Color3.fromRGB(230, 220, 120),
	},
	SwiftStep = {
		DisplayName = "Swift Step",
		Cooldown = 12,
		Buff = "SwiftStep",
		Duration = 4,
		Color = Color3.fromRGB(120, 255, 200),
	},
}

-- Buffs (from abilities and potions). Values are added together.
--   Damage: +x damage, Speed: +x walk speed, Defense: +x damage reduction
Config.Buffs = {
	ShieldWall = { DisplayName = "Shield Wall", Defense = 0.6 },
	SwiftStep = { DisplayName = "Swift Step", Speed = 0.6 },
	Strength = { DisplayName = "Strength", Damage = 0.3 },
	Swiftness = { DisplayName = "Swiftness", Speed = 0.3 },
	Ironskin = { DisplayName = "Ironskin", Defense = 0.25 },
}

Config.CritChance = 0.1
Config.CritMultiplier = 2

-- Difficulties --------------------------------------------------------------
-- Which level unlocks each difficulty and what loot it drops is set per dungeon
-- in Dungeons.luau. These multipliers apply to every dungeon.

Config.Difficulties = {
	Easy = { DisplayName = "Easy", Health = 0.7, Damage = 0.6, Rewards = 0.7, Color = Color3.fromRGB(110, 210, 110) },
	Normal = { DisplayName = "Normal", Health = 1, Damage = 1, Rewards = 1, Color = Color3.fromRGB(240, 220, 90) },
	Hard = { DisplayName = "Hard", Health = 1.6, Damage = 1.4, Rewards = 1.75, Color = Color3.fromRGB(255, 140, 50) },
	Nightmare = { DisplayName = "Nightmare", Health = 2.6, Damage = 2, Rewards = 2.75, Color = Color3.fromRGB(200, 50, 70) },
}
Config.DifficultyOrder = { "Easy", "Normal", "Hard", "Nightmare" }

-- Shop ----------------------------------------------------------------------

Config.Potions = {
	HealthPotion = {
		DisplayName = "Health Potion",
		Description = "Restores 40% health",
		Price = 25,
		Heal = 0.4,
		Color = Color3.fromRGB(230, 60, 60),
	},
	GreaterHealthPotion = {
		DisplayName = "Greater Health Potion",
		Description = "Restores all health",
		Price = 120,
		Heal = 1,
		Color = Color3.fromRGB(255, 40, 120),
	},
	StrengthPotion = {
		DisplayName = "Strength Potion",
		Description = "+30% damage for 60s",
		Price = 150,
		Buff = "Strength",
		Duration = 60,
		Color = Color3.fromRGB(255, 150, 40),
	},
	SwiftnessPotion = {
		DisplayName = "Swiftness Potion",
		Description = "+30% speed for 60s",
		Price = 80,
		Buff = "Swiftness",
		Duration = 60,
		Color = Color3.fromRGB(80, 220, 255),
	},
	IronskinPotion = {
		DisplayName = "Ironskin Potion",
		Description = "+25% damage reduction for 60s",
		Price = 150,
		Buff = "Ironskin",
		Duration = 60,
		Color = Color3.fromRGB(170, 170, 190),
	},
}
-- Hotbar order: keys 2-6 (key 1 draws / puts away your weapon)
Config.PotionOrder = { "HealthPotion", "GreaterHealthPotion", "StrengthPotion", "SwiftnessPotion", "IronskinPotion" }
Config.MaxPotionStack = 10
Config.HealPotionCooldown = 3 -- seconds between healing potions

Config.Rarities = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 90),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 160, 40),
	Mythic = Color3.fromRGB(130, 150, 255),
	Godly = Color3.fromRGB(255, 60, 120),
}

-- Crates (Crate Shrine in town). Godly armor only comes from these. Each roll picks a
-- rarity by Chance; Godly gives a random piece of the crate's set, other rarities give a
-- random dungeon armor piece of that rarity. Duplicates refund CrateDuplicateRefund.
Config.Crates = {
	BlackDragonCrate = {
		DisplayName = "Black Dragon Crate",
		Set = "BlackDragon",
		Price = 5000,
		Color = Color3.fromRGB(200, 40, 30),
		Odds = {
			{ Rarity = "Godly", Chance = 0.05 },
			{ Rarity = "Mythic", Chance = 0.15 },
			{ Rarity = "Legendary", Chance = 0.3 },
			{ Rarity = "Rare", Chance = 0.5 },
		},
	},
	ShogunCrate = {
		DisplayName = "Shogun's Crate",
		Set = "ShogunsOath",
		Price = 5000,
		Color = Color3.fromRGB(230, 180, 60),
		Odds = {
			{ Rarity = "Godly", Chance = 0.05 },
			{ Rarity = "Mythic", Chance = 0.15 },
			{ Rarity = "Legendary", Chance = 0.3 },
			{ Rarity = "Rare", Chance = 0.5 },
		},
	},
}
Config.CrateOrder = { "BlackDragonCrate", "ShogunCrate" }
Config.CrateDuplicateRefund = 0.25 -- fraction of the crate price returned for a duplicate

-- Ultra-rare drop: every player who beats any dungeon boss has this chance to also get it.
Config.MythicDrop = {
	Weapon = "VoidlightGreatsword",
	Chance = 0.0005, -- 0.05% (1 in 2,000)
}

-- Parties -------------------------------------------------------------------

Config.Party = {
	MaxSize = 4,
	Countdown = 10, -- seconds on a portal pad before the dungeon starts
	PadRadius = 7,
}

-- Gold given instead of an item you already own (x item tier).
Config.DuplicateGoldPerTier = 20

-- Movement: sprint (hold Shift) and dodge (C) share a stamina bar ------------------

Config.Movement = {
	MaxStamina = 100,
	SprintMultiplier = 1.6, -- walk speed while sprinting
	SprintDrain = 22, -- stamina per second while sprinting and moving
	RegenRate = 30, -- stamina per second
	RegenDelay = 0.8, -- seconds after using stamina before it refills
	DodgeCost = 30,
	DodgeCooldown = 0.6,
	DodgeSpeed = 60, -- studs per second during the dash
	DodgeDuration = 0.22,
	InvulnerableTime = 0.4, -- dodging makes you immune to damage for this long
}

-- Admins ----------------------------------------------------------------------------
-- The game's owner (or group rank 254+ for group games) and anyone testing in Studio are
-- admins automatically. Add extra Roblox user ids here to give them the admin menu.

Config.AdminUserIds = {
	-- 123456789,
}

-- Audio -------------------------------------------------------------------------------
-- Music uses Creator Store audio ids. Roblox only lets public or owned audio play, so if a
-- track is silent, find one in Studio (Toolbox > Audio, or the Creator Store website),
-- copy its id, and paste it here as "rbxassetid://<id>".
-- Sound effects use sounds built into every Roblox install (rbxasset://sounds/...).

Config.Audio = {
	MusicVolume = 0.35,
	Music = {
		Town = "rbxassetid://1846853445",
		Training = "rbxassetid://1846853445",
		Crypt = "rbxassetid://139743346356072",
		Temple = "rbxassetid://139743346356072",
		Ice = "rbxassetid://139743346356072",
		Boss = "rbxassetid://101000446004472",
	},
	-- { Id, Volume, PlaybackSpeed }
	Sfx = {
		Swing = { "rbxasset://sounds/swordslash.wav", 0.6, 1 },
		Lunge = { "rbxasset://sounds/swordlunge.wav", 0.7, 1 },
		Cast = { "rbxasset://sounds/swordlunge.wav", 0.5, 1.6 },
		BowShot = { "rbxasset://sounds/Rubber band.wav", 0.8, 0.8 },
		Unsheath = { "rbxasset://sounds/unsheath.wav", 0.6, 1 },
		Hit = { "rbxasset://sounds/action_jump_land.mp3", 0.8, 1.3 },
		EnemyDeath = { "rbxasset://sounds/action_jump_land.mp3", 1, 0.6 },
		Slam = { "rbxasset://sounds/action_jump_land.mp3", 2, 0.35 },
		Door = { "rbxasset://sounds/action_jump_land.mp3", 1.5, 0.3 },
		Drink = { "rbxasset://sounds/impact_water.mp3", 0.6, 1.4 },
		Heal = { "rbxasset://sounds/electronicpingshort.wav", 0.5, 0.8 },
		LevelUp = { "rbxasset://sounds/electronicpingshort.wav", 0.8, 1.2 },
		Coins = { "rbxasset://sounds/electronicpingshort.wav", 0.5, 1.6 },
		Dodge = { "rbxasset://sounds/action_jump.mp3", 0.7, 1.4 },
		Click = { "rbxasset://sounds/button.wav", 0.4, 1 },
	},
}

-- Leaderboards ----------------------------------------------------------------------
-- Global boards (all servers) shown in the Hall of Heroes and the Stats window (T).
-- Stat "Level" ranks by level, then XP.

Config.Leaderboards = {
	{ Id = "Level", DisplayName = "Highest Level", Color = Color3.fromRGB(255, 215, 90) },
	{ Id = "EnemiesKilled", DisplayName = "Enemies Slain", Color = Color3.fromRGB(230, 80, 70) },
	{ Id = "DungeonsCleared", DisplayName = "Dungeons Cleared", Color = Color3.fromRGB(110, 190, 255) },
	{ Id = "GoldEarned", DisplayName = "Gold Earned", Color = Color3.fromRGB(255, 190, 60) },
}
Config.LeaderboardRefresh = 120 -- seconds between saving scores and refreshing boards

-- Every tracked stat, in the order the Stats window lists them.
Config.StatNames = {
	{ "PotionsUsed", "Potions drunk" },
	{ "EnemiesKilled", "Enemies slain" },
	{ "DungeonsCleared", "Dungeons cleared" },
	{ "BossesKilled", "Bosses defeated" },
	{ "GoldEarned", "Gold earned" },
	{ "CratesOpened", "Crates opened" },
	{ "Deaths", "Deaths in dungeons" },
	{ "MinutesPlayed", "Minutes played" },
}

-- Quests -----------------------------------------------------------------------------
-- Progress is counted from a lifetime stat (see PlayerService.AddStat) starting when the
-- quest is given. Stats include: EnemiesKilled, Kills_<EnemyId>, DungeonsCleared,
-- Clears_<DungeonId>, Clears_<Difficulty>, Clears_<DungeonId>_<Difficulty>,
-- Clears_HardPlus, BossesKilled, GoldEarned, CratesOpened, PotionsUsed, Dodges,
-- AbilitiesUsed, PrestigeCount.

-- Story quests: one at a time, in order.
Config.StoryQuests = {
	{ Title = "First Steps", Description = "Clear the Crypt of Bones", Stat = "Clears_Crypt", Target = 1, Reward = { XP = 300, Gold = 200, SkillPoints = 1 } },
	{ Title = "Monster Hunter", Description = "Defeat 60 enemies", Stat = "EnemiesKilled", Target = 60, Reward = { XP = 600, Gold = 400, SkillPoints = 1 } },
	{ Title = "Seasoned Delver", Description = "Clear the Crypt of Bones on Hard", Stat = "Clears_Crypt_Hard", Target = 1, Reward = { XP = 1500, Gold = 800, SkillPoints = 1 } },
	{ Title = "Into the Sands", Description = "Clear the Sunken Temple", Stat = "Clears_Temple", Target = 1, Reward = { XP = 3000, Gold = 1500, SkillPoints = 2 } },
	{ Title = "Treasure Seeker", Description = "Open a crate at the Crate Shrine", Stat = "CratesOpened", Target = 1, Reward = { XP = 2000, Gold = 2500, SkillPoints = 1 } },
	{ Title = "Pharaoh's Bane", Description = "Clear the Sunken Temple on Hard", Stat = "Clears_Temple_Hard", Target = 1, Reward = { XP = 6000, Gold = 3000, SkillPoints = 2 } },
	{ Title = "Into the Cold", Description = "Clear the Frozen Keep", Stat = "Clears_Keep", Target = 1, Reward = { XP = 10000, Gold = 5000, SkillPoints = 2 } },
	{ Title = "Waking Nightmare", Description = "Clear any dungeon on Nightmare", Stat = "Clears_Nightmare", Target = 1, Reward = { XP = 15000, Gold = 7500, SkillPoints = 2 } },
	{ Title = "Frost Lord's End", Description = "Clear the Frozen Keep on Nightmare", Stat = "Clears_Keep_Nightmare", Target = 1, Reward = { XP = 25000, Gold = 12000, SkillPoints = 3 } },
	{ Title = "Ascension", Description = "Prestige for the first time", Stat = "PrestigeCount", Target = 1, Reward = { XP = 5000, Gold = 25000, SkillPoints = 5 } },
}

-- Daily quests: 3 are picked each day from those your level allows. Rewards scale with
-- your level (see Config.DailyReward).
Config.DailyQuests = {
	{ Id = "Slay", Title = "Thin the Herd", Description = "Defeat 40 enemies", Stat = "EnemiesKilled", Target = 40 },
	{ Id = "Clear", Title = "Delver's Duty", Description = "Clear 3 dungeons", Stat = "DungeonsCleared", Target = 3 },
	{ Id = "Bosses", Title = "Boss Slayer", Description = "Defeat 2 bosses", Stat = "BossesKilled", Target = 2 },
	{ Id = "Gold", Title = "Gold Rush", Description = "Earn 2,000 coins", Stat = "GoldEarned", Target = 2000 },
	{ Id = "Potions", Title = "Alchemist", Description = "Drink 5 potions", Stat = "PotionsUsed", Target = 5 },
	{ Id = "Dodge", Title = "Light on Your Feet", Description = "Dodge 30 times", Stat = "Dodges", Target = 30 },
	{ Id = "Abilities", Title = "Spellslinger", Description = "Use abilities 25 times", Stat = "AbilitiesUsed", Target = 25 },
	{ Id = "Skeletons", Title = "Bonebreaker", Description = "Defeat 25 Skeletons", Stat = "Kills_Skeleton", Target = 25, MaxLevel = 15 },
	{ Id = "Zombies", Title = "Grave Duty", Description = "Defeat 10 Zombies", Stat = "Kills_Zombie", Target = 10, MaxLevel = 15 },
	{ Id = "Mummies", Title = "Unwrapped", Description = "Defeat 20 Mummies", Stat = "Kills_Mummy", Target = 20, MinLevel = 10 },
	{ Id = "Scarabs", Title = "Bug Hunt", Description = "Defeat 25 Scarabs", Stat = "Kills_Scarab", Target = 25, MinLevel = 10 },
	{ Id = "Yetis", Title = "Yeti Hunter", Description = "Defeat 12 Yetis", Stat = "Kills_Yeti", Target = 12, MinLevel = 20 },
	{ Id = "Wraiths", Title = "Ghostbuster", Description = "Defeat 20 Frost Wraiths", Stat = "Kills_FrostWraith", Target = 20, MinLevel = 20 },
	{ Id = "Hard", Title = "Hardened", Description = "Clear a dungeon on Hard or Nightmare", Stat = "Clears_HardPlus", Target = 1, MinLevel = 6 },
}
Config.DailyQuestCount = 3

function Config.DailyReward(level: number): { XP: number, Gold: number }
	return { XP = math.floor(Config.XPToLevel(level) * 0.35), Gold = 150 + level * 25 }
end

-- Training grounds ----------------------------------------------------------------------

Config.TrainingSpawn = Vector3.new(0, 4, 75)

return Config
