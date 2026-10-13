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
	Receipts = {}, -- Robux purchase ids already granted
	Candies = 0, -- Halloween event currency
	Pets = {}, -- set of owned pet ids
	-- EquippedPet = nil
	LimitedClasses = {}, -- limited-time classes you own (switch to them any time)
	ClassSlots = { "", "", "" }, -- rolled class in each slot ("" = empty)
	SlotsUnlocked = 1, -- slot 1 is free; more are bought with Robux (Config.ClassSlots)
	ActiveSlot = 1,
	Perks = {}, -- Robux Store perks granted outside game passes (admin gifts): perk id -> true
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
	WeaponType: string, -- each class has its own weapon type (Items.luau)
	Rarity: string,
	Weight: number, -- chance when rolling a class (relative)
	Passive: string,
	LootLuck: number?, -- chance to upgrade dungeon loot by one tier
	HealOnHit: number?, -- heals the most hurt nearby teammate by this share of damage dealt
	CritBonus: number?, -- extra critical hit chance
	CritDamage: number?, -- extra critical hit damage (0.5 = crits hit 50% harder)
	Rage: number?, -- up to this much extra damage as your health drops
	Regen: number?, -- share of max health regenerated per second
	LifeSteal: number?, -- heals you by this share of damage dealt
	Reach: number?, -- melee range multiplier
	Revive: boolean?, -- once per life, survive a killing blow
	Limited: boolean?, -- event class: never rolled, only won from event crates
	CandyBonus: number?, -- extra event candies
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
		Rarity = "Common",
		Weight = 20,
		Passive = "+30% health, +10% defense",
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
		Rarity = "Common",
		Weight = 18,
		Passive = "+25% damage, magic splashes",
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
		Rarity = "Common",
		Weight = 18,
		Passive = "+15% speed, longest range",
	},
	Healer = {
		DisplayName = "Healer",
		Description = "Holy caster. Your attacks heal hurt teammates; keeps the party alive.",
		WeaponType = "Tome",
		StarterWeapon = "PrayerBook",
		HealthMultiplier = 1.1,
		DamageMultiplier = 0.95,
		Defense = 0.05,
		SpeedMultiplier = 1,
		Abilities = { "HolyNova", "DivineShield" },
		Color = Color3.fromRGB(255, 230, 130),
		Rarity = "Rare",
		Weight = 8,
		Passive = "Hits heal the most hurt teammate for 20% of damage",
		HealOnHit = 0.2,
	},
	Assassin = {
		DisplayName = "Assassin",
		Description = "Twin daggers. Very fast attacks, huge critical hits, teleports behind foes.",
		WeaponType = "Dagger",
		StarterWeapon = "RustyShiv",
		HealthMultiplier = 0.9,
		DamageMultiplier = 1.15,
		Defense = 0,
		SpeedMultiplier = 1.2,
		Abilities = { "ShadowStrike", "Vanish" },
		Color = Color3.fromRGB(160, 90, 220),
		Rarity = "Epic",
		Weight = 5,
		Passive = "+20% speed, +15% critical hit chance",
		CritBonus = 0.15,
	},
	Treasurer = {
		DisplayName = "Treasurer",
		Description = "Gilded mace. Heavy hits, showers enemies in coins, finds better loot.",
		WeaponType = "Mace",
		StarterWeapon = "WoodenCudgel",
		HealthMultiplier = 1.15,
		DamageMultiplier = 1,
		Defense = 0.05,
		SpeedMultiplier = 1,
		Abilities = { "CoinBarrage", "MidasTouch" },
		Color = Color3.fromRGB(255, 200, 50),
		Rarity = "Legendary",
		Weight = 2.5,
		Passive = "10% better loot drops (chance for a higher tier)",
		LootLuck = 0.1,
	},
	Berserker = {
		DisplayName = "Berserker",
		Description = "Axe brute. The more hurt you are, the harder you hit. Leaps into the fray.",
		WeaponType = "Axe",
		StarterWeapon = "WoodcutterAxe",
		HealthMultiplier = 1.25,
		DamageMultiplier = 1.15,
		Defense = 0.05,
		SpeedMultiplier = 1.05,
		Abilities = { "Bloodlust", "LeapSmash" },
		Color = Color3.fromRGB(200, 40, 40),
		Rarity = "Rare",
		Weight = 8,
		Passive = "Rage: up to +40% damage as your health drops",
		Rage = 0.4,
	},
	Paladin = {
		DisplayName = "Paladin",
		Description = "Holy greatsword knight. Heavily armored, heals over time, smites evil.",
		WeaponType = "Greatsword",
		StarterWeapon = "TrainingGreatsword",
		HealthMultiplier = 1.35,
		DamageMultiplier = 1,
		Defense = 0.15,
		SpeedMultiplier = 0.95,
		Abilities = { "Consecration", "Judgment" },
		Color = Color3.fromRGB(255, 225, 150),
		Rarity = "Rare",
		Weight = 8,
		Passive = "+15% defense, regenerate 1.5% health per second",
		Regen = 0.015,
	},
	Necromancer = {
		DisplayName = "Necromancer",
		Description = "Scythe-wielding death mage. Drains life with every hit, raises the dead.",
		WeaponType = "Scythe",
		StarterWeapon = "FarmersScythe",
		HealthMultiplier = 0.95,
		DamageMultiplier = 1.2,
		Defense = 0,
		SpeedMultiplier = 1,
		Abilities = { "RaiseDead", "SoulHarvest" },
		Color = Color3.fromRGB(110, 230, 140),
		Rarity = "Epic",
		Weight = 5,
		Passive = "Hits heal you for 8% of damage dealt",
		LifeSteal = 0.08,
	},
	Dragoon = {
		DisplayName = "Dragoon",
		Description = "Dragon-knight spearman. Huge reach, dives from the sky onto enemies.",
		WeaponType = "Spear",
		StarterWeapon = "WoodenPike",
		HealthMultiplier = 1.1,
		DamageMultiplier = 1.1,
		Defense = 0.05,
		SpeedMultiplier = 1.1,
		Abilities = { "DragonDive", "WyvernLance" },
		Color = Color3.fromRGB(60, 140, 220),
		Rarity = "Epic",
		Weight = 5,
		Passive = "+25% melee reach, +10% speed",
		Reach = 1.25,
	},
	Ronin = {
		DisplayName = "Ronin",
		Description = "Wandering katana master. Lightning-fast draws and devastating critical hits.",
		WeaponType = "Katana",
		StarterWeapon = "BambooKatana",
		HealthMultiplier = 1,
		DamageMultiplier = 1.2,
		Defense = 0.05,
		SpeedMultiplier = 1.15,
		Abilities = { "Iaido", "ThousandCuts" },
		Color = Color3.fromRGB(230, 60, 90),
		Rarity = "Legendary",
		Weight = 2.45,
		Passive = "+10% crit chance, critical hits deal +50% damage",
		CritBonus = 0.1,
		CritDamage = 0.5,
	},
	Seraph = {
		DisplayName = "Seraph",
		Description = "GODLY. A winged warrior of heaven. Cheats death.",
		WeaponType = "Halberd",
		StarterWeapon = "AcolyteHalberd",
		HealthMultiplier = 1.5,
		DamageMultiplier = 1.5,
		Defense = 0.2,
		SpeedMultiplier = 1.25,
		Abilities = { "HeavensWrath", "Ascension" },
		Color = Color3.fromRGB(255, 240, 170),
		Rarity = "Godly",
		Weight = 0.05,
		Passive = "+50% health and damage, +20% defense, wings, heals allies on hit, revives once per life, better loot",
		CritBonus = 0.1,
		HealOnHit = 0.1,
		LootLuck = 0.1,
		Revive = true,
	},
	-- Limited (Halloween event crate only - never rolled)
	PumpkinWarlock = {
		DisplayName = "Pumpkin Warlock",
		Description = "LIMITED. A cursed warlock who hurls flaming jack-o'-lanterns and calls bat swarms.",
		WeaponType = "Lantern",
		StarterWeapon = "CarvedLantern",
		HealthMultiplier = 1.25,
		DamageMultiplier = 1.4,
		Defense = 0.1,
		SpeedMultiplier = 1.15,
		Abilities = { "PumpkinBomb", "WitchingHour" },
		Color = Color3.fromRGB(255, 130, 30),
		Rarity = "Limited",
		Weight = 0,
		Passive = "+40% damage, +15% speed, ghostfire splash, +50% event candies",
		Limited = true,
		CandyBonus = 0.5,
	},
} :: { [string]: ClassDef }

Config.ClassOrder = {
	"Warrior", "Mage", "Ranger",
	"Healer", "Berserker", "Paladin",
	"Assassin", "Necromancer", "Dragoon",
	"Treasurer", "Ronin", "Seraph",
}
-- Limited classes: shown separately, won from event crates
Config.LimitedClassOrder = { "PumpkinWarlock" }

-- Classes are rolled, not chosen. New players get one free roll.
Config.ClassRoll = {
	CoinCost = 10000,
	-- Robux rolls: create a Developer Product priced at 150 Robux on your game's page (Creator Dashboard >
	-- your experience > Monetization > Developer Products) and paste its id here.
	RobuxProductId = 3718280437,
	RobuxPriceLabel = "R$ 150",
}

-- Class slots: keep several rolled classes and switch between them in town (Classes
-- window). Slot 1 is free; each extra slot is a Robux Developer Product. A newly unlocked
-- slot comes with a free roll.
Config.ClassSlots = {
	Max = 3,
	-- Create a Developer Product priced at 125 Robux (Creator Dashboard > your experience >
	-- Monetization > Developer Products) and paste its id here. It's bought once per slot.
	RobuxProductId = 3718280298,
	RobuxPriceLabel = "R$ 125",
}

-- Robux Store ----------------------------------------------------------------
-- Perks are Game Passes (bought once, kept forever). Create each pass (Creator Dashboard >
-- your experience > Monetization > Passes), set its price, and paste its id here.
-- Exclusive armor sets are Developer Products that grant the full 4-piece set.
Config.RobuxStore = {
	Perks = {
		Luck = {
			DisplayName = "2x Luck",
			Glyph = "🍀",
			Description = "Every class roll, crate and dungeon drop rolls twice and keeps the rarer result. Mythic drop chance doubled.",
			GamePassId = 2033012279,
			PriceLabel = "R$ 249",
			Color = Color3.fromRGB(70, 200, 100),
		},
		Coins = {
			DisplayName = "2x Coins",
			Glyph = "💰",
			Description = "Double coins from dungeons, quests and every other reward, forever.",
			GamePassId = 2034176274,
			PriceLabel = "R$ 199",
			Color = Color3.fromRGB(240, 190, 50),
		},
	},
	PerkOrder = { "Luck", "Coins" },
	-- Exclusive armor (Items.luau sets with Source = "Robux")
	Armor = {
		Starforged = { ProductId = 3718280148, PriceLabel = "R$ 499" },
		Frostbound = { ProductId = 3718280194, PriceLabel = "R$ 399" },
	},
	ArmorOrder = { "Starforged", "Frostbound" },
}

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
	-- Healer
	HolyNova = {
		DisplayName = "Holy Nova",
		Cooldown = 10,
		Radius = 25, -- heals teammates in this radius
		DamageRadius = 14,
		HealPercent = 0.25,
		DamageMultiplier = 2,
		Color = Color3.fromRGB(255, 235, 140),
	},
	DivineShield = {
		DisplayName = "Divine Shield",
		Cooldown = 20,
		Radius = 25,
		Buff = "DivineShield",
		Duration = 5,
		Color = Color3.fromRGB(255, 250, 200),
	},
	-- Assassin
	ShadowStrike = {
		DisplayName = "Shadow Strike",
		Cooldown = 8,
		Range = 30,
		DamageMultiplier = 4,
		Color = Color3.fromRGB(150, 80, 230),
	},
	Vanish = {
		DisplayName = "Vanish",
		Cooldown = 16,
		Buff = "Vanish",
		Duration = 4,
		Color = Color3.fromRGB(90, 60, 140),
	},
	-- Treasurer
	CoinBarrage = {
		DisplayName = "Coin Barrage",
		Cooldown = 8,
		Range = 45,
		MaxTargets = 6,
		DamageMultiplier = 1.6,
		CoinsPerHit = 2,
		Color = Color3.fromRGB(255, 210, 60),
	},
	MidasTouch = {
		DisplayName = "Midas Touch",
		Cooldown = 25,
		Buff = "Midas",
		Duration = 10,
		Color = Color3.fromRGB(255, 220, 80),
	},
	-- Berserker
	Bloodlust = {
		DisplayName = "Bloodlust",
		Cooldown = 18,
		Buff = "Bloodlust",
		Duration = 8,
		HealPercent = 0.1,
		Color = Color3.fromRGB(220, 30, 30),
	},
	LeapSmash = {
		DisplayName = "Leap Smash",
		Cooldown = 9,
		Range = 35,
		Radius = 12,
		DamageMultiplier = 3.5,
		Stun = 1.5,
		Color = Color3.fromRGB(255, 120, 60),
	},
	-- Paladin
	Consecration = {
		DisplayName = "Consecration",
		Cooldown = 16,
		Radius = 16,
		Duration = 6,
		DamageMultiplier = 0.6, -- per second
		HealPercent = 0.03, -- per second
		Color = Color3.fromRGB(255, 220, 120),
	},
	Judgment = {
		DisplayName = "Judgment",
		Cooldown = 12,
		Range = 45,
		Radius = 10,
		DamageMultiplier = 5,
		Stun = 2,
		Color = Color3.fromRGB(255, 245, 190),
	},
	-- Necromancer
	RaiseDead = {
		DisplayName = "Raise Dead",
		Cooldown = 18,
		Count = 3,
		Duration = 8,
		DamageMultiplier = 0.8, -- per spirit hit
		Color = Color3.fromRGB(110, 255, 150),
	},
	SoulHarvest = {
		DisplayName = "Soul Harvest",
		Cooldown = 11,
		Radius = 18,
		DamageMultiplier = 2.2,
		HealPerEnemy = 0.04,
		Color = Color3.fromRGB(80, 220, 120),
	},
	-- Dragoon
	DragonDive = {
		DisplayName = "Dragon Dive",
		Cooldown = 10,
		Range = 40,
		Radius = 12,
		DamageMultiplier = 4,
		Color = Color3.fromRGB(80, 160, 255),
	},
	WyvernLance = {
		DisplayName = "Wyvern Lance",
		Cooldown = 8,
		Range = 28,
		DamageMultiplier = 3,
		Color = Color3.fromRGB(120, 200, 255),
	},
	-- Ronin
	Iaido = {
		DisplayName = "Iaido",
		Cooldown = 9,
		Range = 26,
		DamageMultiplier = 4.5,
		Color = Color3.fromRGB(255, 80, 110),
	},
	ThousandCuts = {
		DisplayName = "Thousand Cuts",
		Cooldown = 14,
		Radius = 14,
		Ticks = 10,
		DamageMultiplier = 0.6,
		Color = Color3.fromRGB(255, 150, 170),
	},
	-- Pumpkin Warlock (limited)
	PumpkinBomb = {
		DisplayName = "Pumpkin Bomb",
		Cooldown = 8,
		Range = 55,
		Radius = 14,
		DamageMultiplier = 4.5,
		Color = Color3.fromRGB(255, 130, 30),
	},
	WitchingHour = {
		DisplayName = "Witching Hour",
		Cooldown = 20,
		Radius = 15,
		Duration = 6,
		DamageMultiplier = 0.6, -- per half second
		Buff = "WitchingHour",
		Color = Color3.fromRGB(150, 70, 220),
	},
	-- Seraph (Godly)
	HeavensWrath = {
		DisplayName = "Heaven's Wrath",
		Cooldown = 12,
		Range = 50,
		Radius = 14,
		Count = 10,
		DamageMultiplier = 1.6,
		Color = Color3.fromRGB(255, 235, 140),
	},
	Ascension = {
		DisplayName = "Ascension",
		Cooldown = 25,
		Radius = 22,
		Duration = 2.5,
		DamageMultiplier = 5,
		HealPercent = 0.5,
		Color = Color3.fromRGB(255, 250, 220),
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
	DivineShield = { DisplayName = "Divine Shield", Defense = 0.5 },
	Vanish = { DisplayName = "Vanish", Crit = 0.4, Speed = 0.3 },
	Midas = { DisplayName = "Midas Touch", Damage = 0.2, Gold = 0.5 },
	Bloodlust = { DisplayName = "Bloodlust", Damage = 0.35, Speed = 0.2 },
	WitchingHour = { DisplayName = "Witching Hour", Speed = 0.3, Damage = 0.15 },
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
	Limited = Color3.fromRGB(255, 120, 20), -- limited-time event items
	Exclusive = Color3.fromRGB(40, 220, 255), -- Robux Store exclusives
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

-- The game owner (and anyone listed here) also gets the Creator Rank button in the admin
-- menu: level 999, prestige 999, with its own emblem, title, card background and frame.
-- Other admins don't see it.
Config.OwnerUserIds = {
	-- 123456789,
}
Config.CreatorRank = { Level = 999, Prestige = 999 }

-- Events -------------------------------------------------------------------------------
-- Limited-time events. Each runs between StartsAt and EndsAt (Unix time, UTC); set
-- Enabled = false to switch one off early. Items won stay with players after it ends.

Config.Events = {
	Halloween = {
		DisplayName = "Halloween Event",
		Enabled = true,
		-- Event icon (assets/halloween/halloween_icon_hud_256.png): upload it in Studio
		-- (Game Explorer > Images, or Creator Hub > Development Items > Images) and paste the
		-- id here as "rbxassetid://<id>". Shown on the HUD button and in the event window.
		Icon = "",
		StartsAt = 1790812800, -- 2026-10-01 00:00 UTC
		EndsAt = 1794182400, -- 2026-11-09 00:00 UTC
		Dungeon = "Haunted", -- event dungeon (only has a portal while the event runs)
		CandiesPerClear = 100, -- candies for clearing the event dungeon (pets/class add more)
		Crate = {
			DisplayName = "Halloween Crate",
			CandyCost = 1000,
			-- Robux: create a Developer Product (Creator Dashboard > your experience >
			-- Monetization > Developer Products) priced at 100 Robux and paste its id here.
			RobuxProductId = 3718280467,
			RobuxPriceLabel = "R$ 100",
			DuplicateRefund = 150, -- candies back for an item you already own
			-- What a crate can give. Chances add up to 1 (100%); shown to players in the crate window.
			Odds = {
				{ Kind = "Class", Id = "PumpkinWarlock", Chance = 0.005 },
				{ Kind = "Armor", Id = "VampireLord", Chance = 0.04 },
				{ Kind = "Armor", Id = "PumpkinReaper", Chance = 0.1 },
				{ Kind = "Pet", Id = "PumpkinSpirit", Chance = 0.035 },
				{ Kind = "Pet", Id = "SkeletonPup", Chance = 0.08 },
				{ Kind = "Pet", Id = "Ghostie", Chance = 0.14 },
				{ Kind = "Pet", Id = "CandyCornSlime", Chance = 0.15 },
				{ Kind = "Pet", Id = "MiniBat", Chance = 0.22 },
				{ Kind = "Pet", Id = "BlackCat", Chance = 0.23 },
			},
		},
	},
}

-- Is an event running right now? (`now` defaults to the current Unix time)
function Config.IsEventActive(eventId: string, now: number?): boolean
	local event = Config.Events[eventId]
	if not event or not event.Enabled then
		return false
	end
	local t = now or os.time()
	return t >= event.StartsAt and t < event.EndsAt
end

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
		Forest = "rbxassetid://139743346356072",
		Volcano = "rbxassetid://139743346356072",
		Void = "rbxassetid://139743346356072",
		Halloween = "rbxassetid://139743346356072",
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
	{ "MiniBossesKilled", "Mini-bosses defeated" },
	{ "TotemsDestroyed", "Boss totems destroyed" },
	{ "CandiesEarned", "Candies collected" },
	{ "EventCratesOpened", "Event crates opened" },
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
	{ Title = "Into the Woods", Description = "Clear Witchwood Hollow", Stat = "Clears_Witchwood", Target = 1, Reward = { XP = 1200, Gold = 600, SkillPoints = 1 } },
	{ Title = "Into the Sands", Description = "Clear the Sunken Temple", Stat = "Clears_Temple", Target = 1, Reward = { XP = 3000, Gold = 1500, SkillPoints = 2 } },
	{ Title = "Treasure Seeker", Description = "Open a crate at the Crate Shrine", Stat = "CratesOpened", Target = 1, Reward = { XP = 2000, Gold = 2500, SkillPoints = 1 } },
	{ Title = "Pharaoh's Bane", Description = "Clear the Sunken Temple on Hard", Stat = "Clears_Temple_Hard", Target = 1, Reward = { XP = 6000, Gold = 3000, SkillPoints = 2 } },
	{ Title = "Into the Cold", Description = "Clear the Frozen Keep", Stat = "Clears_Keep", Target = 1, Reward = { XP = 10000, Gold = 5000, SkillPoints = 2 } },
	{ Title = "Waking Nightmare", Description = "Clear any dungeon on Nightmare", Stat = "Clears_Nightmare", Target = 1, Reward = { XP = 15000, Gold = 7500, SkillPoints = 2 } },
	{ Title = "Frost Lord's End", Description = "Clear the Frozen Keep on Nightmare", Stat = "Clears_Keep_Nightmare", Target = 1, Reward = { XP = 25000, Gold = 12000, SkillPoints = 3 } },
	{ Title = "Through the Fire", Description = "Clear the Infernal Forge", Stat = "Clears_Forge", Target = 1, Reward = { XP = 40000, Gold = 20000, SkillPoints = 3 } },
	{ Title = "Into the Abyss", Description = "Clear the Abyssal Rift", Stat = "Clears_Abyss", Target = 1, Reward = { XP = 80000, Gold = 40000, SkillPoints = 3 } },
	{ Title = "Emperor's Fall", Description = "Clear the Abyssal Rift on Nightmare", Stat = "Clears_Abyss_Nightmare", Target = 1, Reward = { XP = 150000, Gold = 75000, SkillPoints = 5 } },
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
	{ Id = "Wolves", Title = "Wolf Pack", Description = "Defeat 20 Dire Wolves", Stat = "Kills_Wolf", Target = 20, MinLevel = 5, MaxLevel = 25 },
	{ Id = "Imps", Title = "Imp Exterminator", Description = "Defeat 25 Magma Imps", Stat = "Kills_MagmaImp", Target = 25, MinLevel = 33 },
	{ Id = "Stalkers", Title = "Void Hunter", Description = "Defeat 20 Void Stalkers", Stat = "Kills_VoidStalker", Target = 20, MinLevel = 40 },
	{ Id = "Totems", Title = "Shieldbreaker", Description = "Destroy 4 boss totems", Stat = "TotemsDestroyed", Target = 4, MinLevel = 5 },
	{ Id = "Hard", Title = "Hardened", Description = "Clear a dungeon on Hard or Nightmare", Stat = "Clears_HardPlus", Target = 1, MinLevel = 6 },
}
Config.DailyQuestCount = 3

function Config.DailyReward(level: number): { XP: number, Gold: number }
	return { XP = math.floor(Config.XPToLevel(level) * 0.35), Gold = 150 + level * 25 }
end

-- Training grounds ----------------------------------------------------------------------

Config.TrainingSpawn = Vector3.new(0, 4, 75)

-- Buffs granted by weapon abilities (Empower / Guardian) are named "Skill_<WeaponId>".
do
	local Items = require(script.Parent.Items)
	for id, weapon in Items.Weapons do
		if weapon.Skill.Buff then
			local buff = table.clone(weapon.Skill.Buff)
			buff.DisplayName = weapon.Skill.Name
			Config.Buffs[`Skill_{id}`] = buff
		end
	end
end

return Config
