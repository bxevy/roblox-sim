-- Every weapon and armor in the game.
--
-- Items have a Tier (1-8, plus 9 for ultra-rare Mythic drops). Tier sets rarity and base power; dungeons drop items by tier
-- (see Dungeons.luau). Each class uses one weapon type; armor works for every class.

export type Effect = {
	Type: string, -- "Burn" | "Frost" | "Lifesteal"
	Amount: number, -- Burn: fraction of hit dealt per second, Frost: slow fraction, Lifesteal: fraction healed
	Duration: number?, -- seconds (Burn, Frost)
}

export type WeaponDef = {
	Id: string,
	Kind: "Weapon",
	DisplayName: string,
	Type: string, -- a key of WEAPON_TYPES (each class uses one type)
	Tier: number,
	Rarity: string,
	Damage: number,
	Cooldown: number,
	Range: number,
	Splash: number?, -- staffs: area damage radius around the target
	Effect: Effect?,
	Color: Color3, -- blade / shaft / limbs
	Accent: Color3, -- guard / gem / string
	Material: Enum.Material,
	Model: string?, -- custom model builder in CombatService (otherwise built from Type)
	Combo: string, -- WeaponMoves.Combos style
	Design: { [string]: any },
	Skill: { [string]: any }, -- R ability (see WeaponSkills on the server)
}

-- Armor comes in sets of 4 pieces. Each piece is its own item; wearing all 4 pieces of
-- one set gives that set's bonus and an extra aura.
export type ArmorDef = {
	Id: string,
	Kind: "Armor",
	DisplayName: string,
	Set: string,
	Slot: string, -- "Helmet" | "Chest" | "Legs" | "Boots"
	Tier: number,
	Rarity: string,
	Health: number,
	Defense: number,
}

export type SetBonus = {
	Health: number?,
	Defense: number?,
	Damage: number?,
	Speed: number?,
	Description: string,
}

export type ArmorSetDef = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Tier: number,
	Source: string, -- "Loot" (dungeon drops by tier) | "Crate"
	Health: number, -- full-set totals, split across the pieces
	Defense: number,
	SetBonus: SetBonus,
	Pieces: { [string]: string }, -- slot -> piece id
	Style: { [string]: any }, -- looks + effects, read by ArmorVisuals on the server
}

local Items = {}

local TIER_RARITY = { "Common", "Uncommon", "Uncommon", "Rare", "Rare", "Epic", "Epic", "Legendary", "Mythic" }
local TIER_DAMAGE = { 10, 16, 24, 36, 52, 75, 105, 150, 230 }

local WEAPON_TYPES = {
	Sword = { DamageMultiplier = 1, Cooldown = 0.5, Range = 7 },
	Staff = { DamageMultiplier = 1.3, Cooldown = 0.8, Range = 45, Splash = 5 },
	Bow = { DamageMultiplier = 0.8, Cooldown = 0.45, Range = 60 },
	Dagger = { DamageMultiplier = 0.7, Cooldown = 0.3, Range = 5.5 },
	Tome = { DamageMultiplier = 0.95, Cooldown = 0.7, Range = 40 },
	Mace = { DamageMultiplier = 1.4, Cooldown = 0.75, Range = 7.5 },
	Axe = { DamageMultiplier = 1.3, Cooldown = 0.65, Range = 7.5 },
	Greatsword = { DamageMultiplier = 1.45, Cooldown = 0.8, Range = 9 },
	Scythe = { DamageMultiplier = 1.15, Cooldown = 0.6, Range = 9.5 },
	Spear = { DamageMultiplier = 1.05, Cooldown = 0.5, Range = 10 },
	Katana = { DamageMultiplier = 1, Cooldown = 0.4, Range = 7.5 },
	Halberd = { DamageMultiplier = 1.5, Cooldown = 0.6, Range = 10 },
}

local rgb = Color3.fromRGB
local M = Enum.Material

-- Every weapon has:
--   Combo  - its combo style (WeaponMoves.Combos)
--   Design - how CombatService's weapon builder shapes it (blade/head/limbs, guard, effects)
--   Skill  - its own ability on R (mechanic run by WeaponSkills on the server)
-- Effects: Burn (damage over time), Frost (slow), Lifesteal.

local burn = function(amount: number): Effect
	return { Type = "Burn", Amount = amount, Duration = 3 }
end
local frost = function(amount: number): Effect
	return { Type = "Frost", Amount = amount, Duration = 2 }
end
local lifesteal = function(amount: number): Effect
	return { Type = "Lifesteal", Amount = amount }
end

local WEAPON_LIST = {
	-- Swords (Warrior) ---------------------------------------------------------------
	{ Id = "WoodenSword", Name = "Wooden Sword", Type = "Sword", Tier = 1, Color = rgb(150, 105, 60), Accent = rgb(90, 60, 35), Material = M.Wood, Combo = "Blademaster",
		Design = { Blade = "Straight", Guard = "Cross", Pommel = "Ball", Trail = rgb(220, 190, 140) },
		Skill = { Name = "Splinter Spin", Mechanic = "Cyclone", Damage = 0.6, Radius = 8, Ticks = 4, Cooldown = 10, Color = rgb(200, 160, 100), Style = "Wood", Description = "Spin, hitting everything around you 4 times" } },
	{ Id = "IronSword", Name = "Iron Sword", Type = "Sword", Tier = 2, Color = rgb(165, 165, 175), Accent = rgb(90, 70, 40), Material = M.Metal, Combo = "Duelist",
		Design = { Blade = "Straight", Guard = "Cross", Pommel = "Ball", Fuller = true, Trail = rgb(220, 225, 235) },
		Skill = { Name = "Iron Will", Mechanic = "Empower", Buff = { Damage = 0.25, Defense = 0.1 }, Duration = 6, Cooldown = 15, Color = rgb(200, 200, 215), Style = "Steel", Description = "+25% damage and +10% defense for 6s" } },
	{ Id = "SteelBlade", Name = "Steel Blade", Type = "Sword", Tier = 3, Color = rgb(210, 215, 225), Accent = rgb(60, 60, 70), Material = M.Metal, Combo = "Blademaster",
		Design = { Blade = "Broad", Guard = "Wings", Pommel = "Gem", Fuller = true, Trail = rgb(230, 235, 255) },
		Skill = { Name = "Steel Shockwave", Mechanic = "Shockwave", Damage = 2.2, Range = 22, Cooldown = 9, Color = rgb(210, 220, 240), Style = "Steel", Description = "A blade wave that cuts through enemies in front" } },
	{ Id = "KnightsLongsword", Name = "Knight's Longsword", Type = "Sword", Tier = 4, Color = rgb(235, 235, 245), Accent = rgb(200, 170, 60), Material = M.Metal, Combo = "Duelist",
		Design = { Blade = "Long", Guard = "Crescent", Pommel = "Gem", Fuller = true, Runes = rgb(255, 215, 90), Trail = rgb(255, 230, 150) },
		Skill = { Name = "Valor's Charge", Mechanic = "Blink", Damage = 2.5, Range = 18, Cooldown = 10, Color = rgb(255, 215, 90), Style = "Holy", Description = "Charge forward, striking everything you pass" } },
	{ Id = "BoneCleaver", Name = "Bone Cleaver", Type = "Sword", Tier = 5, Color = rgb(230, 225, 205), Accent = rgb(140, 40, 40), Material = M.Marble, Effect = lifesteal(0.06), Combo = "Executioner",
		Design = { Blade = "Cleaver", Guard = "Skull", Pommel = "Spike", Serrated = true, Aura = { Kind = "Smoke", Color = rgb(120, 30, 30) }, Trail = rgb(200, 40, 40) },
		Skill = { Name = "Bone Eruption", Mechanic = "Spikes", Damage = 2.4, Range = 24, Cooldown = 11, Color = rgb(235, 230, 210), Style = "Bone", Description = "Jagged bones burst from the ground in a line" } },
	{ Id = "SandReaver", Name = "Sand Reaver", Type = "Sword", Tier = 6, Color = rgb(235, 195, 90), Accent = rgb(40, 60, 140), Material = M.Metal, Effect = burn(0.15), Combo = "Blademaster",
		Design = { Blade = "Curved", Guard = "Disc", Pommel = "Gem", Runes = rgb(80, 200, 255), Aura = { Kind = "Dust", Color = rgb(230, 200, 130) }, Trail = rgb(255, 210, 120) },
		Skill = { Name = "Sandstorm", Mechanic = "Vortex", Damage = 0.5, Radius = 14, Ticks = 6, Duration = 3, Cooldown = 14, Color = rgb(230, 200, 130), Style = "Sand", Description = "A swirling storm drags enemies in and grinds them" } },
	{ Id = "Frostbrand", Name = "Frostbrand", Type = "Sword", Tier = 7, Color = rgb(150, 220, 255), Accent = rgb(230, 245, 255), Material = M.Ice, Effect = frost(0.4), Combo = "Duelist",
		Design = { Blade = "Crystal", Guard = "Wings", Pommel = "Gem", Aura = { Kind = "Snow", Color = rgb(220, 240, 255) }, Trail = rgb(170, 230, 255), Glow = rgb(140, 210, 255) },
		Skill = { Name = "Blizzard", Mechanic = "Rain", Damage = 0.8, Radius = 12, Count = 14, Duration = 2.5, Cooldown = 13, Color = rgb(170, 230, 255), Style = "Ice", Description = "Ice shards rain down where you aim" } },
	{ Id = "Dragonfang", Name = "Dragonfang", Type = "Sword", Tier = 8, Color = rgb(255, 110, 40), Accent = rgb(60, 20, 20), Material = M.Neon, Effect = burn(0.25), Combo = "Executioner",
		Design = { Blade = "Flame", Guard = "Claws", Pommel = "Spike", Aura = { Kind = "Embers", Color = rgb(255, 120, 40) }, Trail = rgb(255, 140, 50), Glow = rgb(255, 120, 40) },
		Skill = { Name = "Dragon's Breath", Mechanic = "Breath", Damage = 0.7, Range = 22, Ticks = 6, Duration = 1.8, Cooldown = 14, Color = rgb(255, 120, 40), Style = "Fire", Description = "Breathe a cone of dragonfire" } },

	-- Staffs (Mage) ------------------------------------------------------------------
	{ Id = "ApprenticeStaff", Name = "Apprentice Staff", Type = "Staff", Tier = 1, Color = rgb(120, 85, 50), Accent = rgb(120, 180, 255), Material = M.Wood, Combo = "Arcanist",
		Design = { Head = "Orb", Shaft = "Straight", Trail = rgb(140, 190, 255) },
		Skill = { Name = "Arcane Barrage", Mechanic = "Missiles", Damage = 0.9, Count = 5, Range = 45, Cooldown = 9, Color = rgb(140, 190, 255), Style = "Arcane", Description = "Fire 5 seeking arcane missiles" } },
	{ Id = "WillowStaff", Name = "Willow Staff", Type = "Staff", Tier = 2, Color = rgb(140, 120, 80), Accent = rgb(120, 255, 140), Material = M.Wood, Combo = "Stormcaller",
		Design = { Head = "Leaf", Shaft = "Twisted", Aura = { Kind = "Leaves", Color = rgb(140, 230, 120) }, Trail = rgb(140, 255, 160) },
		Skill = { Name = "Thorn Snare", Mechanic = "Root", Damage = 0.4, Radius = 10, Ticks = 6, Duration = 3, Cooldown = 12, Color = rgb(110, 200, 90), Style = "Nature", Description = "Thorny roots hold enemies in place and squeeze" } },
	{ Id = "CrystalStaff", Name = "Crystal Staff", Type = "Staff", Tier = 3, Color = rgb(200, 200, 220), Accent = rgb(200, 120, 255), Material = M.Metal, Combo = "Arcanist",
		Design = { Head = "Crystals", Shaft = "Straight", Aura = { Kind = "Sparkles", Color = rgb(220, 160, 255) }, Trail = rgb(210, 150, 255), Glow = rgb(200, 120, 255) },
		Skill = { Name = "Prism Beam", Mechanic = "Beam", Damage = 0.7, Range = 40, Ticks = 6, Duration = 1.8, Cooldown = 12, Color = rgb(210, 150, 255), Style = "Arcane", Description = "Channel a piercing beam of light" } },
	{ Id = "NecroStaff", Name = "Necro Staff", Type = "Staff", Tier = 4, Color = rgb(50, 45, 55), Accent = rgb(120, 255, 120), Material = M.Slate, Effect = lifesteal(0.05), Combo = "Stormcaller",
		Design = { Head = "Skull", Shaft = "Twisted", Aura = { Kind = "Smoke", Color = rgb(80, 200, 100) }, Trail = rgb(120, 255, 140), Glow = rgb(120, 255, 120) },
		Skill = { Name = "Soul Siphon", Mechanic = "Chain", Damage = 1.2, Count = 5, Range = 35, Heal = 0.3, Cooldown = 11, Color = rgb(120, 255, 140), Style = "Shadow", Description = "Drain life chaining through 5 enemies" } },
	{ Id = "StaffOfCinders", Name = "Staff of Cinders", Type = "Staff", Tier = 5, Color = rgb(70, 40, 30), Accent = rgb(255, 120, 40), Material = M.Wood, Effect = burn(0.15), Combo = "Arcanist",
		Design = { Head = "Brazier", Shaft = "Twisted", Aura = { Kind = "Embers", Color = rgb(255, 130, 50) }, Trail = rgb(255, 140, 60), Glow = rgb(255, 120, 40) },
		Skill = { Name = "Meteor", Mechanic = "Meteor", Damage = 4.5, Radius = 12, Range = 50, Cooldown = 12, Color = rgb(255, 120, 40), Style = "Fire", Description = "Call a meteor down on your target" } },
	{ Id = "SunspireScepter", Name = "Sunspire Scepter", Type = "Staff", Tier = 6, Color = rgb(230, 190, 70), Accent = rgb(255, 240, 150), Material = M.Metal, Effect = burn(0.2), Combo = "Stormcaller",
		Design = { Head = "Sun", Shaft = "Straight", Aura = { Kind = "Holy", Color = rgb(255, 230, 140) }, Trail = rgb(255, 230, 140), Glow = rgb(255, 230, 120) },
		Skill = { Name = "Solar Flare", Mechanic = "Nova", Damage = 3.2, Radius = 18, Cooldown = 13, Color = rgb(255, 220, 110), Style = "Holy", Description = "Explode with the light of the sun around you" } },
	{ Id = "RimefrostStaff", Name = "Rimefrost Staff", Type = "Staff", Tier = 7, Color = rgb(170, 210, 240), Accent = rgb(120, 220, 255), Material = M.Ice, Effect = frost(0.4), Combo = "Stormcaller",
		Design = { Head = "Crescent", Shaft = "Straight", Aura = { Kind = "Snow", Color = rgb(220, 240, 255) }, Trail = rgb(150, 220, 255), Glow = rgb(120, 220, 255) },
		Skill = { Name = "Frozen Orb", Mechanic = "Orb", Damage = 0.8, Radius = 8, Range = 40, Ticks = 8, Duration = 2.5, Cooldown = 12, Color = rgb(150, 220, 255), Style = "Ice", Description = "Launch a slow orb that shreds everything it passes" } },
	{ Id = "ArchmagesInferno", Name = "Archmage's Inferno", Type = "Staff", Tier = 8, Color = rgb(40, 20, 30), Accent = rgb(255, 80, 20), Material = M.Basalt, Effect = burn(0.3), Combo = "Arcanist",
		Design = { Head = "Eye", Shaft = "Twisted", Aura = { Kind = "Embers", Color = rgb(255, 90, 30) }, Trail = rgb(255, 90, 30), Glow = rgb(255, 80, 20) },
		Skill = { Name = "Armageddon", Mechanic = "Rain", Projectile = "Meteor", Damage = 2.6, Radius = 18, Count = 6, Duration = 2.5, Cooldown = 18, Color = rgb(255, 90, 30), Style = "Fire", Description = "A storm of meteors around your target" } },

	-- Bows (Ranger) ------------------------------------------------------------------
	{ Id = "HuntingBow", Name = "Hunting Bow", Type = "Bow", Tier = 1, Color = rgb(140, 95, 55), Accent = rgb(230, 230, 230), Material = M.Wood, Combo = "Marksman",
		Design = { Limbs = "Recurve", Trail = rgb(230, 230, 230) },
		Skill = { Name = "Piercing Arrow", Mechanic = "Pierce", Damage = 2.5, Range = 60, Cooldown = 8, Color = rgb(230, 230, 230), Style = "Wind", Description = "An arrow that goes through every enemy in a line" } },
	{ Id = "RecurveBow", Name = "Recurve Bow", Type = "Bow", Tier = 2, Color = rgb(110, 70, 40), Accent = rgb(230, 230, 230), Material = M.Wood, Combo = "Hunter",
		Design = { Limbs = "Recurve", Trail = rgb(230, 230, 230) },
		Skill = { Name = "Hail of Arrows", Mechanic = "Rain", Projectile = "Arrow", Damage = 0.6, Radius = 10, Count = 16, Duration = 2, Cooldown = 11, Color = rgb(230, 230, 230), Style = "Wind", Description = "Arrows rain down on an area" } },
	{ Id = "Longbow", Name = "Longbow", Type = "Bow", Tier = 3, Color = rgb(160, 120, 70), Accent = rgb(255, 255, 255), Material = M.Wood, Combo = "Marksman",
		Design = { Limbs = "Long", Trail = rgb(255, 255, 255) },
		Skill = { Name = "Snipe", Mechanic = "Execute", Damage = 5, Range = 80, Cooldown = 10, Color = rgb(255, 255, 255), Style = "Steel", Description = "A precise shot; +50% damage to wounded enemies" } },
	{ Id = "BoneBow", Name = "Bone Bow", Type = "Bow", Tier = 4, Color = rgb(225, 220, 200), Accent = rgb(160, 40, 40), Material = M.Marble, Effect = lifesteal(0.05), Combo = "Hunter",
		Design = { Limbs = "Bone", Aura = { Kind = "Smoke", Color = rgb(140, 40, 40) }, Trail = rgb(200, 60, 60) },
		Skill = { Name = "Bone Shrapnel", Mechanic = "Missiles", Projectile = "Arrow", Damage = 1, Count = 7, Range = 50, Cooldown = 10, Color = rgb(235, 230, 210), Style = "Bone", Description = "Split into 7 bone shards that seek enemies" } },
	{ Id = "DesertWind", Name = "Desert Wind", Type = "Bow", Tier = 5, Color = rgb(220, 185, 110), Accent = rgb(60, 200, 200), Material = M.Sandstone, Effect = frost(0.3), Combo = "Hunter",
		Design = { Limbs = "Wing", Aura = { Kind = "Dust", Color = rgb(230, 210, 150) }, Trail = rgb(120, 230, 230) },
		Skill = { Name = "Gale Volley", Mechanic = "Shockwave", Damage = 2.4, Range = 26, Knockback = true, Cooldown = 10, Color = rgb(150, 240, 240), Style = "Wind", Description = "A howling gust that blasts enemies back" } },
	{ Id = "ViperSting", Name = "Viper's Sting", Type = "Bow", Tier = 6, Color = rgb(40, 110, 50), Accent = rgb(140, 255, 80), Material = M.Metal, Effect = burn(0.2), Combo = "Marksman",
		Design = { Limbs = "Serpent", Aura = { Kind = "Smoke", Color = rgb(120, 220, 60) }, Trail = rgb(150, 255, 90), Glow = rgb(140, 255, 80) },
		Skill = { Name = "Venom Cloud", Mechanic = "Cloud", Damage = 0.5, Radius = 10, Ticks = 8, Duration = 4, Cooldown = 12, Color = rgb(140, 230, 70), Style = "Poison", Description = "A toxic cloud that poisons all inside" } },
	{ Id = "FrostbiteBow", Name = "Frostbite Bow", Type = "Bow", Tier = 7, Color = rgb(160, 210, 245), Accent = rgb(230, 250, 255), Material = M.Ice, Effect = frost(0.45), Combo = "Marksman",
		Design = { Limbs = "Crystal", Aura = { Kind = "Snow", Color = rgb(230, 245, 255) }, Trail = rgb(180, 235, 255), Glow = rgb(150, 220, 255) },
		Skill = { Name = "Glacial Arrow", Mechanic = "Bomb", Damage = 3.5, Radius = 10, Range = 60, Cooldown = 11, Color = rgb(170, 230, 255), Style = "Ice", Description = "An arrow that explodes in freezing ice" } },
	{ Id = "PhoenixBow", Name = "Phoenix Bow", Type = "Bow", Tier = 8, Color = rgb(255, 120, 30), Accent = rgb(255, 230, 120), Material = M.Neon, Effect = burn(0.25), Combo = "Hunter",
		Design = { Limbs = "Flame", Aura = { Kind = "Embers", Color = rgb(255, 150, 50) }, Trail = rgb(255, 170, 60), Glow = rgb(255, 140, 40) },
		Skill = { Name = "Phoenix Dive", Mechanic = "Pierce", Projectile = "Phoenix", Damage = 3.6, Range = 60, Cooldown = 13, Color = rgb(255, 150, 50), Style = "Fire", Description = "Loose a blazing phoenix that burns through a line" } },

	-- Daggers (Assassin) ---------------------------------------------------------------
	{ Id = "RustyShiv", Name = "Rusty Shiv", Type = "Dagger", Tier = 1, Color = rgb(140, 110, 90), Accent = rgb(70, 50, 40), Material = M.CorrodedMetal, Combo = "Flurry",
		Design = { Blade = "Straight", Trail = rgb(180, 150, 130) },
		Skill = { Name = "Dirty Trick", Mechanic = "Execute", Damage = 3, Range = 10, Cooldown = 8, Color = rgb(200, 60, 60), Style = "Blood", Description = "A vicious stab; +50% damage to wounded enemies" } },
	{ Id = "IronDirk", Name = "Iron Dirk", Type = "Dagger", Tier = 2, Color = rgb(165, 165, 175), Accent = rgb(60, 45, 35), Material = M.Metal, Combo = "Twinfang",
		Design = { Blade = "Straight", Trail = rgb(220, 220, 230) },
		Skill = { Name = "Fan of Knives", Mechanic = "Nova", Projectile = "Knives", Damage = 2, Radius = 10, Cooldown = 9, Color = rgb(220, 220, 230), Style = "Steel", Description = "Throw knives in every direction" } },
	{ Id = "SteelStiletto", Name = "Steel Stiletto", Type = "Dagger", Tier = 3, Color = rgb(210, 215, 225), Accent = rgb(40, 40, 45), Material = M.Metal, Combo = "Flurry",
		Design = { Blade = "Needle", Trail = rgb(230, 235, 255) },
		Skill = { Name = "Shadowstep Slash", Mechanic = "Blink", Damage = 2.4, Range = 16, Cooldown = 8, Color = rgb(120, 90, 200), Style = "Shadow", Description = "Dash through enemies in a blur of shadow" } },
	{ Id = "VenomFang", Name = "Venom Fang", Type = "Dagger", Tier = 4, Color = rgb(90, 200, 90), Accent = rgb(30, 60, 30), Material = M.Glass, Effect = burn(0.15), Combo = "Twinfang",
		Design = { Blade = "Fang", Aura = { Kind = "Smoke", Color = rgb(110, 220, 80) }, Trail = rgb(130, 255, 100), Glow = rgb(110, 255, 90) },
		Skill = { Name = "Toxic Cloud", Mechanic = "Cloud", Damage = 0.5, Radius = 9, Ticks = 8, Duration = 4, Cooldown = 12, Color = rgb(120, 230, 80), Style = "Poison", Description = "Burst into a poison cloud" } },
	{ Id = "NightshadeKris", Name = "Nightshade Kris", Type = "Dagger", Tier = 5, Color = rgb(120, 60, 160), Accent = rgb(30, 15, 40), Material = M.Metal, Effect = lifesteal(0.06), Combo = "Flurry",
		Design = { Blade = "Wavy", Aura = { Kind = "Smoke", Color = rgb(120, 60, 160) }, Trail = rgb(170, 90, 230) },
		Skill = { Name = "Blood Frenzy", Mechanic = "Empower", Buff = { Crit = 0.3, Speed = 0.2 }, Duration = 6, Cooldown = 16, Color = rgb(200, 40, 70), Style = "Blood", Description = "+30% crit chance and +20% speed for 6s" } },
	{ Id = "Shadowfang", Name = "Shadowfang", Type = "Dagger", Tier = 6, Color = rgb(40, 40, 55), Accent = rgb(150, 110, 255), Material = M.Slate, Effect = frost(0.35), Combo = "Twinfang",
		Design = { Blade = "Curved", Aura = { Kind = "Void", Color = rgb(150, 110, 255) }, Trail = rgb(150, 110, 255), Glow = rgb(150, 110, 255) },
		Skill = { Name = "Phantom Blades", Mechanic = "Summon", Damage = 0.6, Radius = 7, Ticks = 10, Duration = 5, Cooldown = 15, Color = rgb(150, 110, 255), Style = "Shadow", Description = "Ghostly blades orbit you, slicing nearby enemies" } },
	{ Id = "EclipseEdge", Name = "Eclipse Edge", Type = "Dagger", Tier = 7, Color = rgb(255, 170, 60), Accent = rgb(40, 20, 60), Material = M.Neon, Effect = burn(0.22), Combo = "Flurry",
		Design = { Blade = "Crescent", Aura = { Kind = "Embers", Color = rgb(255, 170, 60) }, Trail = rgb(255, 180, 80), Glow = rgb(255, 160, 50) },
		Skill = { Name = "Eclipse", Mechanic = "Collapse", Damage = 4, Radius = 12, Duration = 1.2, Cooldown = 15, Color = rgb(255, 160, 60), Style = "Void", Description = "Pull enemies into a dark sun, then detonate it" } },
	{ Id = "PhantomReaper", Name = "Phantom Reaper", Type = "Dagger", Tier = 8, Color = rgb(170, 240, 255), Accent = rgb(20, 30, 50), Material = M.Glass, Effect = lifesteal(0.1), Combo = "Twinfang",
		Design = { Blade = "Phantom", Aura = { Kind = "Spirit", Color = rgb(170, 240, 255) }, Trail = rgb(170, 240, 255), Glow = rgb(150, 230, 255) },
		Skill = { Name = "Reap", Mechanic = "Ricochet", Damage = 2.2, Count = 5, Range = 30, Cooldown = 14, Color = rgb(170, 240, 255), Style = "Spirit", Description = "Flicker between up to 5 enemies, striking each" } },

	-- Tomes (Healer) -------------------------------------------------------------------
	{ Id = "PrayerBook", Name = "Prayer Book", Type = "Tome", Tier = 1, Color = rgb(120, 80, 50), Accent = rgb(255, 240, 200), Material = M.Leather, Combo = "Psalm",
		Design = { Cover = "Plain", Trail = rgb(255, 240, 200) },
		Skill = { Name = "Blessing", Mechanic = "Heal", HealPercent = 0.2, Radius = 25, Cooldown = 12, Color = rgb(255, 240, 180), Style = "Holy", Description = "Heal yourself and nearby teammates for 20%" } },
	{ Id = "HymnalOfDawn", Name = "Hymnal of Dawn", Type = "Tome", Tier = 2, Color = rgb(170, 70, 50), Accent = rgb(255, 220, 150), Material = M.Leather, Combo = "Judgment",
		Design = { Cover = "Clasped", Trail = rgb(255, 220, 150) },
		Skill = { Name = "Dawn Light", Mechanic = "Missiles", Projectile = "Pillar", Damage = 2, Count = 3, Range = 40, Cooldown = 10, Color = rgb(255, 220, 150), Style = "Holy", Description = "Pillars of dawn strike up to 3 enemies" } },
	{ Id = "CodexOfLight", Name = "Codex of Light", Type = "Tome", Tier = 3, Color = rgb(230, 225, 210), Accent = rgb(255, 230, 120), Material = M.Leather, Combo = "Psalm",
		Design = { Cover = "Jeweled", Runes = rgb(255, 230, 120), Trail = rgb(255, 230, 120), Glow = rgb(255, 230, 120) },
		Skill = { Name = "Radiant Beam", Mechanic = "Beam", Damage = 0.7, Range = 40, Ticks = 6, Duration = 1.8, Cooldown = 12, Color = rgb(255, 235, 140), Style = "Holy", Description = "Channel a beam of holy light" } },
	{ Id = "TomeOfMending", Name = "Tome of Mending", Type = "Tome", Tier = 4, Color = rgb(60, 140, 90), Accent = rgb(150, 255, 170), Material = M.Leather, Effect = lifesteal(0.06), Combo = "Judgment",
		Design = { Cover = "Vine", Aura = { Kind = "Leaves", Color = rgb(150, 255, 170) }, Trail = rgb(150, 255, 170), Glow = rgb(150, 255, 170) },
		Skill = { Name = "Sanctuary", Mechanic = "Zone", Damage = 0.4, HealPercent = 0.04, Radius = 12, Ticks = 5, Duration = 5, Cooldown = 16, Color = rgb(150, 255, 170), Style = "Nature", Description = "A circle that heals allies and hurts enemies for 5s" } },
	{ Id = "RadiantScripture", Name = "Radiant Scripture", Type = "Tome", Tier = 5, Color = rgb(240, 200, 90), Accent = rgb(255, 255, 220), Material = M.Metal, Effect = burn(0.15), Combo = "Psalm",
		Design = { Cover = "Gilded", Orbit = 3, Aura = { Kind = "Holy", Color = rgb(255, 240, 170) }, Trail = rgb(255, 240, 170), Glow = rgb(255, 230, 140) },
		Skill = { Name = "Holy Fire", Mechanic = "Rain", Projectile = "Holy", Damage = 0.8, Radius = 12, Count = 14, Duration = 2.5, Cooldown = 13, Color = rgb(255, 230, 140), Style = "Holy", Description = "Sacred flames fall across an area" } },
	{ Id = "SeraphsGospel", Name = "Seraph's Gospel", Type = "Tome", Tier = 6, Color = rgb(245, 245, 255), Accent = rgb(140, 200, 255), Material = M.Fabric, Effect = frost(0.3), Combo = "Judgment",
		Design = { Cover = "Winged", Orbit = 4, Aura = { Kind = "Holy", Color = rgb(190, 225, 255) }, Trail = rgb(170, 220, 255), Glow = rgb(150, 210, 255) },
		Skill = { Name = "Seraph's Wings", Mechanic = "Guardian", Buff = { Defense = 0.3, Speed = 0.15 }, Radius = 25, Duration = 6, Cooldown = 18, Color = rgb(190, 225, 255), Style = "Holy", Description = "Teammates nearby get +30% defense and +15% speed" } },
	{ Id = "CelestialCanticle", Name = "Celestial Canticle", Type = "Tome", Tier = 7, Color = rgb(60, 70, 160), Accent = rgb(255, 240, 150), Material = M.Fabric, Effect = burn(0.2), Combo = "Psalm",
		Design = { Cover = "Starry", Orbit = 5, Aura = { Kind = "Sparkles", Color = rgb(255, 240, 150) }, Trail = rgb(255, 240, 150), Glow = rgb(255, 240, 150) },
		Skill = { Name = "Starfall", Mechanic = "Rain", Projectile = "Star", Damage = 1, Radius = 14, Count = 16, Duration = 2.5, Cooldown = 14, Color = rgb(255, 240, 150), Style = "Arcane", Description = "Stars fall from the heavens onto your foes" } },
	{ Id = "BookOfGenesis", Name = "Book of Genesis", Type = "Tome", Tier = 8, Color = rgb(255, 250, 235), Accent = rgb(255, 200, 60), Material = M.Neon, Effect = lifesteal(0.1), Combo = "Judgment",
		Design = { Cover = "Radiant", Orbit = 6, Aura = { Kind = "Holy", Color = rgb(255, 220, 120) }, Trail = rgb(255, 220, 120), Glow = rgb(255, 210, 100) },
		Skill = { Name = "Genesis", Mechanic = "Nova", Damage = 4, Radius = 18, HealPercent = 0.4, Cooldown = 20, Color = rgb(255, 220, 120), Style = "Holy", Description = "Unleash creation: heavy damage and heal allies 40%" } },

	-- Maces (Treasurer) ----------------------------------------------------------------
	{ Id = "WoodenCudgel", Name = "Wooden Cudgel", Type = "Mace", Tier = 1, Color = rgb(140, 100, 60), Accent = rgb(90, 60, 35), Material = M.Wood, Combo = "Crusher",
		Design = { Head = "Club", Trail = rgb(200, 160, 110) },
		Skill = { Name = "Bonk", Mechanic = "Execute", Damage = 3, Range = 10, Stun = 1.5, Cooldown = 8, Color = rgb(255, 230, 120), Style = "Wood", Description = "A huge bonk that stuns the target" } },
	{ Id = "CopperMace", Name = "Copper Mace", Type = "Mace", Tier = 2, Color = rgb(200, 120, 70), Accent = rgb(90, 60, 35), Material = M.Metal, Combo = "Juggernaut",
		Design = { Head = "Flanged", Trail = rgb(230, 150, 100) },
		Skill = { Name = "Ground Pound", Mechanic = "Nova", Damage = 2.4, Radius = 12, Cooldown = 9, Color = rgb(200, 150, 100), Style = "Earth", Description = "Slam the ground, hitting everything around you" } },
	{ Id = "SilverScepter", Name = "Silver Scepter", Type = "Mace", Tier = 3, Color = rgb(215, 220, 230), Accent = rgb(120, 180, 255), Material = M.Metal, Combo = "Crusher",
		Design = { Head = "Crown", Trail = rgb(200, 220, 255), Glow = rgb(120, 180, 255) },
		Skill = { Name = "Silver Lining", Mechanic = "Empower", Buff = { Damage = 0.2, Gold = 0.3 }, Duration = 8, Cooldown = 16, Color = rgb(200, 220, 255), Style = "Gold", Description = "+20% damage and +30% coins for 8s" } },
	{ Id = "GoldenMorningstar", Name = "Golden Morningstar", Type = "Mace", Tier = 4, Color = rgb(240, 200, 70), Accent = rgb(120, 80, 20), Material = M.Metal, Combo = "Juggernaut",
		Design = { Head = "SpikedBall", Aura = { Kind = "Sparkles", Color = rgb(255, 220, 100) }, Trail = rgb(255, 220, 100) },
		Skill = { Name = "Golden Cyclone", Mechanic = "Cyclone", Damage = 0.7, Radius = 9, Ticks = 5, Cooldown = 12, Color = rgb(255, 215, 80), Style = "Gold", Description = "Whirl in a golden storm, hitting 5 times" } },
	{ Id = "JeweledFlail", Name = "Jeweled Flail", Type = "Mace", Tier = 5, Color = rgb(230, 190, 80), Accent = rgb(200, 40, 80), Material = M.Metal, Effect = burn(0.15), Combo = "Crusher",
		Design = { Head = "Gem", Aura = { Kind = "Sparkles", Color = rgb(255, 80, 140) }, Trail = rgb(255, 90, 150), Glow = rgb(255, 60, 120) },
		Skill = { Name = "Gem Shatter", Mechanic = "Missiles", Projectile = "Gem", Damage = 1.2, Count = 6, Range = 40, Cooldown = 11, Color = rgb(255, 80, 140), Style = "Gem", Description = "Shatter gems that seek 6 enemies" } },
	{ Id = "MidasHammer", Name = "Midas Hammer", Type = "Mace", Tier = 6, Color = rgb(255, 215, 60), Accent = rgb(255, 250, 200), Material = M.Neon, Effect = lifesteal(0.06), Combo = "Juggernaut",
		Design = { Head = "Hammer", Aura = { Kind = "Sparkles", Color = rgb(255, 230, 120) }, Trail = rgb(255, 225, 90), Glow = rgb(255, 215, 60) },
		Skill = { Name = "Midas Quake", Mechanic = "Shockwave", Damage = 3, Range = 24, Coins = 3, Cooldown = 12, Color = rgb(255, 215, 60), Style = "Gold", Description = "A golden quake that turns hits into coins" } },
	{ Id = "CrownBreaker", Name = "Crown Breaker", Type = "Mace", Tier = 7, Color = rgb(120, 60, 160), Accent = rgb(255, 210, 80), Material = M.Metal, Effect = frost(0.4), Combo = "Crusher",
		Design = { Head = "Crown", Aura = { Kind = "Void", Color = rgb(170, 110, 255) }, Trail = rgb(180, 120, 255), Glow = rgb(255, 210, 80) },
		Skill = { Name = "Royal Decree", Mechanic = "Collapse", Damage = 4, Radius = 14, Duration = 1.2, Cooldown = 15, Color = rgb(180, 120, 255), Style = "Void", Description = "Command enemies to kneel: pull them in and crush them" } },
	{ Id = "ScepterOfAvarice", Name = "Scepter of Avarice", Type = "Mace", Tier = 8, Color = rgb(255, 200, 40), Accent = rgb(40, 200, 120), Material = M.Metal, Effect = burn(0.25), Combo = "Juggernaut",
		Design = { Head = "Gem", Aura = { Kind = "Coins", Color = rgb(255, 215, 60) }, Trail = rgb(255, 215, 60), Glow = rgb(60, 255, 150) },
		Skill = { Name = "Avarice", Mechanic = "Rain", Projectile = "Coin", Damage = 1, Radius = 14, Count = 18, Duration = 2.5, Coins = 1, Cooldown = 16, Color = rgb(255, 215, 60), Style = "Gold", Description = "Make it rain: falling gold crushes enemies and pays you" } },

	-- Axes (Berserker) -----------------------------------------------------------------
	{ Id = "WoodcutterAxe", Name = "Woodcutter's Axe", Type = "Axe", Tier = 1, Color = rgb(170, 170, 175), Accent = rgb(120, 85, 50), Material = M.Metal, Combo = "Ravager",
		Design = { Head = "Hatchet", Trail = rgb(220, 200, 160) },
		Skill = { Name = "Timber!", Mechanic = "Execute", Damage = 3, Range = 10, Stun = 1, Cooldown = 8, Color = rgb(230, 200, 140), Style = "Wood", Description = "A mighty chop that stuns the target" } },
	{ Id = "BeardedAxe", Name = "Bearded Axe", Type = "Axe", Tier = 2, Color = rgb(160, 160, 170), Accent = rgb(90, 60, 35), Material = M.Metal, Combo = "Lumberjack",
		Design = { Head = "Bearded", Trail = rgb(210, 210, 220) },
		Skill = { Name = "Whirling Axe", Mechanic = "Cyclone", Damage = 0.65, Radius = 9, Ticks = 4, Cooldown = 10, Color = rgb(210, 210, 220), Style = "Steel", Description = "Spin with your axe out, hitting 4 times" } },
	{ Id = "IronBattleaxe", Name = "Iron Battleaxe", Type = "Axe", Tier = 3, Color = rgb(200, 205, 215), Accent = rgb(60, 55, 60), Material = M.Metal, Combo = "Ravager",
		Design = { Head = "Double", Trail = rgb(230, 235, 245) },
		Skill = { Name = "Earthsplitter", Mechanic = "Shockwave", Damage = 2.4, Range = 22, Cooldown = 9, Color = rgb(190, 160, 120), Style = "Earth", Description = "Split the ground in a line ahead of you" } },
	{ Id = "Bloodreaver", Name = "Bloodreaver", Type = "Axe", Tier = 4, Color = rgb(150, 25, 30), Accent = rgb(40, 30, 30), Material = M.Metal, Effect = lifesteal(0.05), Combo = "Lumberjack",
		Design = { Head = "Jagged", Aura = { Kind = "Smoke", Color = rgb(150, 20, 20) }, Trail = rgb(220, 30, 40), Glow = rgb(255, 40, 40) },
		Skill = { Name = "Blood Frenzy", Mechanic = "Empower", Buff = { Damage = 0.3, Speed = 0.15 }, Duration = 6, Cooldown = 15, Color = rgb(220, 30, 40), Style = "Blood", Description = "+30% damage and +15% speed for 6s" } },
	{ Id = "GlacierCleaver", Name = "Glacier Cleaver", Type = "Axe", Tier = 5, Color = rgb(160, 220, 255), Accent = rgb(70, 110, 160), Material = M.Ice, Effect = frost(0.35), Combo = "Ravager",
		Design = { Head = "Crescent", Aura = { Kind = "Snow", Color = rgb(220, 240, 255) }, Trail = rgb(170, 230, 255), Glow = rgb(140, 210, 255) },
		Skill = { Name = "Avalanche", Mechanic = "Rain", Damage = 0.9, Radius = 12, Count = 14, Duration = 2.5, Cooldown = 13, Color = rgb(170, 230, 255), Style = "Ice", Description = "Bury the area you aim at under falling ice" } },
	{ Id = "InfernoAxe", Name = "Inferno Axe", Type = "Axe", Tier = 6, Color = rgb(60, 40, 40), Accent = rgb(255, 120, 30), Material = M.Slate, Effect = burn(0.2), Combo = "Lumberjack",
		Design = { Head = "Double", Runes = rgb(255, 140, 40), Aura = { Kind = "Embers", Color = rgb(255, 120, 40) }, Trail = rgb(255, 130, 40), Glow = rgb(255, 120, 30) },
		Skill = { Name = "Hellfall", Mechanic = "Meteor", Damage = 4.5, Radius = 12, Range = 50, Cooldown = 12, Color = rgb(255, 110, 30), Style = "Fire", Description = "Call a burning meteor down on your target" } },
	{ Id = "Stormbreaker", Name = "Stormbreaker", Type = "Axe", Tier = 7, Color = rgb(190, 200, 220), Accent = rgb(80, 150, 255), Material = M.Metal, Effect = frost(0.4), Combo = "Ravager",
		Design = { Head = "Bearded", Runes = rgb(120, 200, 255), Aura = { Kind = "Sparkles", Color = rgb(140, 200, 255) }, Trail = rgb(140, 200, 255), Glow = rgb(100, 180, 255) },
		Skill = { Name = "Thunderclap", Mechanic = "Chain", Damage = 1.5, Count = 6, Range = 35, Cooldown = 11, Color = rgb(140, 200, 255), Style = "Storm", Description = "Lightning leaps between 6 enemies" } },
	{ Id = "Worldeater", Name = "Worldeater", Type = "Axe", Tier = 8, Color = rgb(30, 25, 30), Accent = rgb(255, 40, 40), Material = M.Slate, Effect = burn(0.25), Combo = "Lumberjack",
		Design = { Head = "Demon", Aura = { Kind = "Void", Color = rgb(255, 40, 40) }, Trail = rgb(255, 50, 50), Glow = rgb(255, 40, 40) },
		Skill = { Name = "Cataclysm", Mechanic = "Collapse", Damage = 5, Radius = 16, Duration = 1.3, Cooldown = 15, Color = rgb(255, 50, 50), Style = "Void", Description = "Rip the ground open: drag enemies in, then crush them" } },

	-- Greatswords (Paladin) ------------------------------------------------------------
	{ Id = "TrainingGreatsword", Name = "Training Greatsword", Type = "Greatsword", Tier = 1, Color = rgb(150, 110, 70), Accent = rgb(90, 60, 35), Material = M.Wood, Combo = "Crusader",
		Design = { Blade = "Broad", Guard = "Cross", Pommel = "Ball", Trail = rgb(220, 190, 140) },
		Skill = { Name = "Heavy Spin", Mechanic = "Cyclone", Damage = 0.65, Radius = 10, Ticks = 4, Cooldown = 10, Color = rgb(220, 190, 140), Style = "Wood", Description = "Spin your greatsword, hitting all around 4 times" } },
	{ Id = "IronClaymore", Name = "Iron Claymore", Type = "Greatsword", Tier = 2, Color = rgb(170, 170, 180), Accent = rgb(90, 70, 40), Material = M.Metal, Combo = "Titan",
		Design = { Blade = "Long", Guard = "Cross", Pommel = "Ball", Fuller = true, Trail = rgb(220, 225, 235) },
		Skill = { Name = "Bulwark", Mechanic = "Empower", Buff = { Defense = 0.25, Damage = 0.1 }, Duration = 6, Cooldown = 15, Color = rgb(200, 210, 230), Style = "Steel", Description = "+25% defense and +10% damage for 6s" } },
	{ Id = "Zweihander", Name = "Zweihander", Type = "Greatsword", Tier = 3, Color = rgb(215, 220, 230), Accent = rgb(60, 60, 70), Material = M.Metal, Combo = "Crusader",
		Design = { Blade = "Long", Guard = "Wings", Pommel = "Spike", Fuller = true, Trail = rgb(230, 235, 255) },
		Skill = { Name = "Sweeping Gale", Mechanic = "Shockwave", Damage = 2.4, Range = 24, Cooldown = 9, Color = rgb(220, 230, 250), Style = "Steel", Description = "A huge sword wave that cuts through enemies" } },
	{ Id = "Oathkeeper", Name = "Oathkeeper", Type = "Greatsword", Tier = 4, Color = rgb(235, 235, 245), Accent = rgb(220, 180, 60), Material = M.Metal, Combo = "Titan",
		Design = { Blade = "Broad", Guard = "Crescent", Pommel = "Gem", Fuller = true, Runes = rgb(255, 220, 100), Aura = { Kind = "Holy", Color = rgb(255, 230, 140) }, Trail = rgb(255, 230, 150) },
		Skill = { Name = "Sacred Oath", Mechanic = "Guardian", Buff = { Defense = 0.3, Damage = 0.1 }, Radius = 25, Duration = 6, Cooldown = 18, Color = rgb(255, 225, 120), Style = "Holy", Description = "You and nearby allies: +30% defense, +10% damage" } },
	{ Id = "SunforgedBlade", Name = "Sunforged Blade", Type = "Greatsword", Tier = 5, Color = rgb(255, 200, 90), Accent = rgb(160, 90, 30), Material = M.Metal, Effect = burn(0.15), Combo = "Crusader",
		Design = { Blade = "Flame", Guard = "Disc", Pommel = "Gem", Aura = { Kind = "Embers", Color = rgb(255, 190, 80) }, Trail = rgb(255, 200, 90), Glow = rgb(255, 180, 60) },
		Skill = { Name = "Solar Flare", Mechanic = "Nova", Damage = 3.2, Radius = 16, HealPercent = 0.15, Cooldown = 13, Color = rgb(255, 200, 90), Style = "Holy", Description = "Burst with sunlight: damage enemies, heal allies 15%" } },
	{ Id = "Lionheart", Name = "Lionheart", Type = "Greatsword", Tier = 6, Color = rgb(240, 200, 80), Accent = rgb(150, 30, 35), Material = M.Metal, Effect = lifesteal(0.06), Combo = "Titan",
		Design = { Blade = "Broad", Guard = "Claws", Pommel = "Gem", Runes = rgb(255, 80, 60), Aura = { Kind = "Sparkles", Color = rgb(255, 210, 100) }, Trail = rgb(255, 210, 100), Glow = rgb(255, 200, 80) },
		Skill = { Name = "Pride of Lions", Mechanic = "Blink", Damage = 3, Range = 20, Cooldown = 10, Color = rgb(255, 200, 80), Style = "Holy", Description = "Charge forward with a lion's roar, striking all you pass" } },
	{ Id = "Dawnbreaker", Name = "Dawnbreaker", Type = "Greatsword", Tier = 7, Color = rgb(255, 245, 210), Accent = rgb(255, 190, 70), Material = M.Glass, Effect = burn(0.2), Combo = "Crusader",
		Design = { Blade = "Crystal", Guard = "Wings", Pommel = "Gem", Aura = { Kind = "Holy", Color = rgb(255, 230, 150) }, Trail = rgb(255, 230, 150), Glow = rgb(255, 220, 120) },
		Skill = { Name = "Daybreak", Mechanic = "Beam", Damage = 0.9, Range = 40, Ticks = 6, Duration = 1.8, Cooldown = 12, Color = rgb(255, 230, 140), Style = "Holy", Description = "Fire a searing beam of dawn light" } },
	{ Id = "Judicator", Name = "The Judicator", Type = "Greatsword", Tier = 8, Color = rgb(220, 235, 255), Accent = rgb(255, 215, 90), Material = M.Neon, Effect = frost(0.45), Combo = "Titan",
		Design = { Blade = "Phantom", Guard = "Wings", Pommel = "Gem", Aura = { Kind = "Holy", Color = rgb(200, 230, 255) }, Trail = rgb(200, 230, 255), Glow = rgb(170, 210, 255) },
		Skill = { Name = "Final Verdict", Mechanic = "Execute", Damage = 6.5, Range = 40, Stun = 2, Cooldown = 11, Color = rgb(200, 230, 255), Style = "Holy", Description = "A giant blade of light falls on your target and stuns it" } },

	-- Scythes (Necromancer) ------------------------------------------------------------
	{ Id = "FarmersScythe", Name = "Farmer's Scythe", Type = "Scythe", Tier = 1, Color = rgb(170, 170, 175), Accent = rgb(130, 95, 55), Material = M.Metal, Combo = "Reaper",
		Design = { Blade = "Farm", Trail = rgb(220, 220, 200) },
		Skill = { Name = "Harvest", Mechanic = "Cyclone", Damage = 0.6, Radius = 10, Ticks = 4, Cooldown = 10, Color = rgb(220, 220, 200), Style = "Wood", Description = "Sweep in a full circle 4 times" } },
	{ Id = "Gravedigger", Name = "Gravedigger", Type = "Scythe", Tier = 2, Color = rgb(120, 125, 130), Accent = rgb(60, 50, 45), Material = M.Metal, Combo = "Harvester",
		Design = { Blade = "Reaper", Ornament = "Lantern", Glow = rgb(120, 255, 150), Trail = rgb(150, 255, 170) },
		Skill = { Name = "Grasping Dead", Mechanic = "Root", Damage = 0.45, Radius = 10, Ticks = 6, Duration = 3, Cooldown = 12, Color = rgb(110, 220, 130), Style = "Shadow", Description = "Hands claw up from the ground, holding enemies in place" } },
	{ Id = "BoneReaper", Name = "Bone Reaper", Type = "Scythe", Tier = 3, Color = rgb(230, 225, 205), Accent = rgb(70, 60, 55), Material = M.Marble, Combo = "Reaper",
		Design = { Blade = "Bone", Ornament = "Skull", Trail = rgb(235, 230, 210) },
		Skill = { Name = "Ossuary", Mechanic = "Spikes", Damage = 2.4, Range = 24, Cooldown = 11, Color = rgb(235, 230, 210), Style = "Bone", Description = "Bones burst from the ground in a line" } },
	{ Id = "Plaguebringer", Name = "Plaguebringer", Type = "Scythe", Tier = 4, Color = rgb(110, 160, 60), Accent = rgb(50, 40, 40), Material = M.Metal, Effect = burn(0.15), Combo = "Harvester",
		Design = { Blade = "Reaper", Shaft = "Twisted", Ornament = "Gem", Aura = { Kind = "Smoke", Color = rgb(120, 200, 60) }, Trail = rgb(140, 220, 80), Glow = rgb(140, 255, 80) },
		Skill = { Name = "Plague Cloud", Mechanic = "Cloud", Damage = 0.55, Radius = 11, Ticks = 8, Duration = 4, Cooldown = 12, Color = rgb(140, 220, 80), Style = "Poison", Description = "Release a cloud of plague that eats at enemies" } },
	{ Id = "Soulreaver", Name = "Soulreaver", Type = "Scythe", Tier = 5, Color = rgb(120, 230, 255), Accent = rgb(40, 40, 60), Material = M.Glass, Effect = lifesteal(0.06), Combo = "Reaper",
		Design = { Blade = "Spectral", Ornament = "Lantern", Aura = { Kind = "Spirit", Color = rgb(120, 230, 255) }, Trail = rgb(120, 230, 255), Glow = rgb(100, 220, 255) },
		Skill = { Name = "Soul Chain", Mechanic = "Chain", Damage = 1.3, Count = 5, Range = 35, Heal = 0.3, Cooldown = 11, Color = rgb(120, 230, 255), Style = "Spirit", Description = "Rip souls from 5 enemies, healing you" } },
	{ Id = "TwinMoons", Name = "Twin Moons", Type = "Scythe", Tier = 6, Color = rgb(200, 200, 230), Accent = rgb(60, 50, 110), Material = M.Metal, Effect = frost(0.3), Combo = "Harvester",
		Design = { Blade = "Twin", Ornament = "Gem", Aura = { Kind = "Sparkles", Color = rgb(190, 180, 255) }, Trail = rgb(190, 180, 255), Glow = rgb(170, 150, 255) },
		Skill = { Name = "Lunar Ricochet", Mechanic = "Ricochet", Damage = 2.3, Count = 6, Range = 30, Cooldown = 13, Color = rgb(190, 180, 255), Style = "Spirit", Description = "Hurl a spinning moon blade that bounces between 6 foes" } },
	{ Id = "Frostreaper", Name = "Frostreaper", Type = "Scythe", Tier = 7, Color = rgb(170, 225, 255), Accent = rgb(60, 90, 140), Material = M.Ice, Effect = frost(0.45), Combo = "Reaper",
		Design = { Blade = "Moon", Shaft = "Twisted", Ornament = "Skull", Aura = { Kind = "Snow", Color = rgb(220, 240, 255) }, Trail = rgb(170, 230, 255), Glow = rgb(140, 210, 255) },
		Skill = { Name = "Frozen Souls", Mechanic = "Orb", Damage = 0.9, Radius = 9, Range = 40, Ticks = 8, Duration = 2.5, Cooldown = 12, Color = rgb(170, 230, 255), Style = "Ice", Description = "A slow orb of frozen souls grinds through enemies" } },
	{ Id = "DeathsEmbrace", Name = "Death's Embrace", Type = "Scythe", Tier = 8, Color = rgb(25, 25, 30), Accent = rgb(110, 255, 150), Material = M.Slate, Effect = lifesteal(0.08), Combo = "Harvester",
		Design = { Blade = "Spectral", Shaft = "Twisted", Ornament = "Skull", Aura = { Kind = "Void", Color = rgb(100, 255, 150) }, Trail = rgb(110, 255, 150), Glow = rgb(90, 255, 140) },
		Skill = { Name = "Army of the Dead", Mechanic = "Summon", Damage = 0.9, Radius = 8, Ticks = 12, Duration = 6, Cooldown = 15, Color = rgb(110, 255, 150), Style = "Shadow", Description = "Raise spectral reapers that cut down nearby enemies" } },

	-- Spears (Dragoon) -----------------------------------------------------------------
	{ Id = "WoodenPike", Name = "Wooden Pike", Type = "Spear", Tier = 1, Color = rgb(170, 170, 175), Accent = rgb(130, 95, 55), Material = M.Metal, Combo = "Impaler",
		Design = { Head = "Pike", Trail = rgb(220, 210, 190) },
		Skill = { Name = "Javelin", Mechanic = "Pierce", Damage = 2.2, Range = 45, Cooldown = 8, Color = rgb(220, 210, 190), Style = "Wind", Description = "Hurl a javelin that pierces every enemy in a line" } },
	{ Id = "IronSpear", Name = "Iron Spear", Type = "Spear", Tier = 2, Color = rgb(170, 170, 180), Accent = rgb(150, 40, 40), Material = M.Metal, Combo = "Skewer",
		Design = { Head = "Leaf", Tassel = rgb(170, 40, 40), Trail = rgb(220, 225, 235) },
		Skill = { Name = "Spear Rush", Mechanic = "Blink", Damage = 2.4, Range = 18, Cooldown = 10, Color = rgb(220, 225, 235), Style = "Steel", Description = "Rush forward, skewering everything you pass" } },
	{ Id = "SteelPartisan", Name = "Steel Partisan", Type = "Spear", Tier = 3, Color = rgb(215, 220, 230), Accent = rgb(60, 60, 70), Material = M.Metal, Combo = "Impaler",
		Design = { Head = "Winged", Tassel = rgb(40, 70, 150), Trail = rgb(230, 235, 255) },
		Skill = { Name = "Sweeping Strike", Mechanic = "Shockwave", Damage = 2.3, Range = 22, Cooldown = 9, Color = rgb(220, 230, 250), Style = "Steel", Description = "A spear wave that cuts through enemies in front" } },
	{ Id = "TidecallerTrident", Name = "Tidecaller Trident", Type = "Spear", Tier = 4, Color = rgb(60, 160, 200), Accent = rgb(230, 200, 90), Material = M.Metal, Effect = frost(0.3), Combo = "Skewer",
		Design = { Head = "Trident", Aura = { Kind = "Sparkles", Color = rgb(90, 200, 255) }, Trail = rgb(90, 200, 255), Glow = rgb(70, 190, 255) },
		Skill = { Name = "Maelstrom", Mechanic = "Vortex", Damage = 0.55, Radius = 14, Ticks = 6, Duration = 3, Cooldown = 14, Color = rgb(70, 170, 230), Style = "Water", Description = "A whirlpool drags enemies in and drowns them" } },
	{ Id = "GaleLance", Name = "Gale Lance", Type = "Spear", Tier = 5, Color = rgb(170, 240, 200), Accent = rgb(60, 130, 90), Material = M.Glass, Combo = "Impaler",
		Design = { Head = "Leaf", Tassel = rgb(120, 230, 170), Aura = { Kind = "Leaves", Color = rgb(150, 240, 180) }, Trail = rgb(170, 255, 210), Glow = rgb(120, 255, 180) },
		Skill = { Name = "Cyclone Thrust", Mechanic = "Pierce", Damage = 3, Range = 60, Cooldown = 8, Color = rgb(170, 255, 210), Style = "Wind", Description = "A spiralling gust that pierces everything in a line" } },
	{ Id = "WyrmfangSpear", Name = "Wyrmfang Spear", Type = "Spear", Tier = 6, Color = rgb(200, 60, 40), Accent = rgb(60, 25, 20), Material = M.Metal, Effect = burn(0.2), Combo = "Skewer",
		Design = { Head = "Dragon", Aura = { Kind = "Embers", Color = rgb(255, 120, 40) }, Trail = rgb(255, 130, 50), Glow = rgb(255, 110, 40) },
		Skill = { Name = "Wyrm Breath", Mechanic = "Breath", Damage = 0.75, Range = 22, Ticks = 6, Duration = 1.8, Cooldown = 14, Color = rgb(255, 120, 40), Style = "Fire", Description = "Your spear breathes a cone of dragonfire" } },
	{ Id = "Starpiercer", Name = "Starpiercer", Type = "Spear", Tier = 7, Color = rgb(170, 120, 255), Accent = rgb(40, 30, 80), Material = M.Glass, Effect = frost(0.4), Combo = "Impaler",
		Design = { Head = "Crystal", Aura = { Kind = "Sparkles", Color = rgb(200, 170, 255) }, Trail = rgb(190, 160, 255), Glow = rgb(170, 130, 255) },
		Skill = { Name = "Starfall", Mechanic = "Missiles", Projectile = "Star", Damage = 1.2, Count = 7, Range = 45, Cooldown = 10, Color = rgb(200, 170, 255), Style = "Arcane", Description = "Call down 7 seeking stars" } },
	{ Id = "Skyrender", Name = "Skyrender", Type = "Spear", Tier = 8, Color = rgb(60, 120, 230), Accent = rgb(230, 240, 255), Material = M.Metal, Effect = burn(0.25), Combo = "Skewer",
		Design = { Head = "Dragon", Runes = rgb(150, 220, 255), Aura = { Kind = "Sparkles", Color = rgb(130, 200, 255) }, Trail = rgb(130, 200, 255), Glow = rgb(100, 180, 255) },
		Skill = { Name = "Heaven's Lance", Mechanic = "Meteor", Damage = 5, Radius = 13, Range = 50, Cooldown = 12, Color = rgb(120, 190, 255), Style = "Storm", Description = "A spear of lightning crashes down from the sky" } },

	-- Katanas (Ronin) ------------------------------------------------------------------
	{ Id = "BambooKatana", Name = "Bamboo Katana", Type = "Katana", Tier = 1, Color = rgb(190, 200, 120), Accent = rgb(70, 90, 40), Material = M.Wood, Combo = "Iaijutsu",
		Design = { Tsuba = "Round", Trail = rgb(220, 230, 170) },
		Skill = { Name = "Quick Draw", Mechanic = "Blink", Damage = 2.2, Range = 16, Cooldown = 9, Color = rgb(220, 230, 170), Style = "Wood", Description = "Dash forward with one clean cut" } },
	{ Id = "IronKatana", Name = "Iron Katana", Type = "Katana", Tier = 2, Color = rgb(190, 195, 205), Accent = rgb(40, 40, 50), Material = M.Metal, Combo = "Kenjutsu",
		Design = { Tsuba = "Square", Hamon = rgb(240, 240, 250), Trail = rgb(230, 235, 245) },
		Skill = { Name = "Focus", Mechanic = "Empower", Buff = { Crit = 0.2, Speed = 0.1 }, Duration = 6, Cooldown = 15, Color = rgb(230, 235, 245), Style = "Steel", Description = "+20% crit chance and +10% speed for 6s" } },
	{ Id = "TemperedKatana", Name = "Tempered Katana", Type = "Katana", Tier = 3, Color = rgb(215, 220, 230), Accent = rgb(120, 30, 30), Material = M.Metal, Combo = "Iaijutsu",
		Design = { Tsuba = "Flower", Hamon = rgb(255, 255, 255), Trail = rgb(240, 245, 255) },
		Skill = { Name = "Wind Scar", Mechanic = "Shockwave", Damage = 2.4, Range = 24, Cooldown = 9, Color = rgb(230, 240, 255), Style = "Wind", Description = "A cutting wind slices through enemies ahead" } },
	{ Id = "SakuraBlade", Name = "Sakura Blade", Type = "Katana", Tier = 4, Color = rgb(255, 200, 220), Accent = rgb(60, 30, 40), Material = M.Metal, Combo = "Kenjutsu",
		Design = { Tsuba = "Flower", Hamon = rgb(255, 120, 170), Aura = { Kind = "Leaves", Color = rgb(255, 160, 200) }, Trail = rgb(255, 170, 210), Glow = rgb(255, 130, 180) },
		Skill = { Name = "Petal Storm", Mechanic = "Vortex", Damage = 0.6, Radius = 14, Ticks = 6, Duration = 3, Cooldown = 14, Color = rgb(255, 160, 200), Style = "Nature", Description = "A storm of razor petals pulls enemies in" } },
	{ Id = "Muramasa", Name = "Muramasa", Type = "Katana", Tier = 5, Color = rgb(170, 20, 40), Accent = rgb(25, 20, 25), Material = M.Metal, Effect = lifesteal(0.07), Combo = "Iaijutsu",
		Design = { Tsuba = "Square", Hamon = rgb(255, 40, 60), Aura = { Kind = "Smoke", Color = rgb(170, 20, 30) }, Trail = rgb(230, 30, 50), Glow = rgb(255, 30, 50) },
		Skill = { Name = "Cursed Edge", Mechanic = "Execute", Damage = 5.5, Range = 30, Cooldown = 10, Color = rgb(230, 30, 50), Style = "Blood", Description = "One cursed strike on your target" } },
	{ Id = "RaijinsEdge", Name = "Raijin's Edge", Type = "Katana", Tier = 6, Color = rgb(255, 235, 120), Accent = rgb(40, 40, 90), Material = M.Metal, Effect = burn(0.2), Combo = "Kenjutsu",
		Design = { Tsuba = "Round", Hamon = rgb(150, 220, 255), Aura = { Kind = "Sparkles", Color = rgb(255, 240, 140) }, Trail = rgb(255, 240, 140), Glow = rgb(255, 230, 100) },
		Skill = { Name = "Thunder God", Mechanic = "Chain", Damage = 1.6, Count = 6, Range = 35, Cooldown = 11, Color = rgb(255, 240, 140), Style = "Storm", Description = "Lightning arcs between 6 enemies" } },
	{ Id = "Yukikaze", Name = "Yukikaze", Type = "Katana", Tier = 7, Color = rgb(200, 235, 255), Accent = rgb(60, 80, 130), Material = M.Ice, Effect = frost(0.45), Combo = "Iaijutsu",
		Design = { Tsuba = "Flower", Hamon = rgb(140, 210, 255), Aura = { Kind = "Snow", Color = rgb(230, 245, 255) }, Trail = rgb(180, 230, 255), Glow = rgb(140, 210, 255) },
		Skill = { Name = "Snow Flurry", Mechanic = "Rain", Damage = 1, Radius = 12, Count = 16, Duration = 2.5, Cooldown = 13, Color = rgb(180, 230, 255), Style = "Ice", Description = "A flurry of ice blades rains where you aim" } },
	{ Id = "Kusanagi", Name = "Kusanagi", Type = "Katana", Tier = 8, Color = rgb(30, 30, 40), Accent = rgb(255, 210, 80), Material = M.Metal, Effect = burn(0.25), Combo = "Kenjutsu",
		Design = { Tsuba = "Round", Hamon = rgb(170, 120, 255), Aura = { Kind = "Void", Color = rgb(170, 120, 255) }, Trail = rgb(180, 130, 255), Glow = rgb(170, 110, 255) },
		Skill = { Name = "Thousand Blades", Mechanic = "Summon", Damage = 1, Radius = 8, Ticks = 12, Duration = 5, Cooldown = 15, Color = rgb(180, 130, 255), Style = "Shadow", Description = "Summon phantom blades that cut down everything nearby" } },

	-- Halberds (Seraph, Godly class) -----------------------------------------------------
	{ Id = "AcolyteHalberd", Name = "Acolyte's Halberd", Type = "Halberd", Tier = 1, Color = rgb(225, 225, 230), Accent = rgb(220, 180, 70), Material = M.Metal, Combo = "Seraphic",
		Design = { Head = "Axe", Trail = rgb(255, 240, 190) },
		Skill = { Name = "Light Burst", Mechanic = "Nova", Damage = 2.5, Radius = 14, Cooldown = 11, Color = rgb(255, 240, 180), Style = "Holy", Description = "Burst with holy light, hitting everything around you" } },
	{ Id = "TempleHalberd", Name = "Temple Guard Halberd", Type = "Halberd", Tier = 2, Color = rgb(235, 235, 240), Accent = rgb(220, 180, 70), Material = M.Metal, Combo = "Archangel",
		Design = { Head = "Axe", Tassel = rgb(240, 240, 255), Trail = rgb(255, 240, 190) },
		Skill = { Name = "Blessed Ground", Mechanic = "Zone", Damage = 0.45, HealPercent = 0.04, Radius = 12, Ticks = 5, Duration = 5, Cooldown = 16, Color = rgb(255, 235, 150), Style = "Holy", Description = "Holy ground that hurts enemies and heals allies" } },
	{ Id = "SilverwingPoleaxe", Name = "Silverwing Poleaxe", Type = "Halberd", Tier = 3, Color = rgb(225, 230, 245), Accent = rgb(140, 190, 255), Material = M.Metal, Combo = "Seraphic",
		Design = { Head = "Crescent", Wings = true, Trail = rgb(220, 235, 255) },
		Skill = { Name = "Wing Gust", Mechanic = "Shockwave", Damage = 2.6, Range = 24, Cooldown = 9, Color = rgb(220, 235, 255), Style = "Holy", Description = "Beat your blade's wings: a wave of light cuts ahead" } },
	{ Id = "DawnguardHalberd", Name = "Dawnguard Halberd", Type = "Halberd", Tier = 4, Color = rgb(255, 225, 140), Accent = rgb(255, 255, 230), Material = M.Metal, Combo = "Archangel",
		Design = { Head = "Axe", Halo = true, Aura = { Kind = "Holy", Color = rgb(255, 230, 150) }, Trail = rgb(255, 230, 150), Glow = rgb(255, 220, 120) },
		Skill = { Name = "Sun Lance", Mechanic = "Beam", Damage = 1, Range = 40, Ticks = 6, Duration = 1.8, Cooldown = 12, Color = rgb(255, 230, 140), Style = "Holy", Description = "Fire a lance of sunlight" } },
	{ Id = "StarforgedHalberd", Name = "Starforged Halberd", Type = "Halberd", Tier = 5, Color = rgb(200, 210, 255), Accent = rgb(255, 230, 140), Material = M.Glass, Effect = frost(0.35), Combo = "Seraphic",
		Design = { Head = "Crescent", Halo = true, Aura = { Kind = "Sparkles", Color = rgb(220, 220, 255) }, Trail = rgb(220, 220, 255), Glow = rgb(190, 200, 255) },
		Skill = { Name = "Constellation", Mechanic = "Missiles", Projectile = "Star", Damage = 1.3, Count = 7, Range = 45, Cooldown = 10, Color = rgb(230, 230, 255), Style = "Holy", Description = "7 stars seek out enemies" } },
	{ Id = "Glorybringer", Name = "Glorybringer", Type = "Halberd", Tier = 6, Color = rgb(255, 215, 90), Accent = rgb(255, 250, 230), Material = M.Metal, Effect = lifesteal(0.06), Combo = "Archangel",
		Design = { Head = "Axe", Wings = true, Halo = true, Aura = { Kind = "Holy", Color = rgb(255, 230, 140) }, Trail = rgb(255, 230, 140), Glow = rgb(255, 215, 90) },
		Skill = { Name = "Halo Strike", Mechanic = "Execute", Damage = 6, Range = 40, Stun = 1.5, Cooldown = 10, Color = rgb(255, 230, 140), Style = "Holy", Description = "A halo of light crashes onto your target" } },
	{ Id = "CelestialGlaive", Name = "Celestial Glaive", Type = "Halberd", Tier = 7, Color = rgb(235, 245, 255), Accent = rgb(130, 180, 255), Material = M.Glass, Effect = burn(0.2), Combo = "Seraphic",
		Design = { Head = "Crescent", Wings = true, Halo = true, Aura = { Kind = "Holy", Color = rgb(200, 225, 255) }, Trail = rgb(200, 225, 255), Glow = rgb(160, 200, 255) },
		Skill = { Name = "Comet", Mechanic = "Meteor", Damage = 5.5, Radius = 14, Range = 50, Cooldown = 12, Color = rgb(200, 225, 255), Style = "Holy", Description = "Call a holy comet down on your target" } },
	{ Id = "HandOfGod", Name = "Hand of God", Type = "Halberd", Tier = 8, Color = rgb(255, 250, 235), Accent = rgb(255, 200, 60), Material = M.Neon, Effect = burn(0.3), Combo = "Archangel",
		Design = { Head = "Axe", Wings = true, Halo = true, Runes = rgb(255, 210, 80), Aura = { Kind = "Holy", Color = rgb(255, 235, 150) }, Trail = rgb(255, 235, 150), Glow = rgb(255, 220, 100) },
		Skill = { Name = "Divine Intervention", Mechanic = "Nova", Damage = 6, Radius = 22, HealPercent = 0.5, Cooldown = 18, Color = rgb(255, 235, 150), Style = "Holy", Description = "Heaven answers: massive damage and heal allies 50%" } },

	-- Mythic: never in normal loot tables, only from the ultra-rare drop (Config.MythicDrop)
	{ Id = "VoidlightGreatsword", Name = "Voidlight Greatsword", Type = "Sword", Tier = 9, Color = rgb(236, 240, 252), Accent = rgb(28, 34, 92), Material = M.Metal, Effect = frost(0.5), Combo = "Executioner", Model = "Voidlight",
		Design = { Aura = { Kind = "Void", Color = rgb(110, 140, 255) }, Trail = rgb(110, 140, 255) },
		Skill = { Name = "Voidrend", Mechanic = "Collapse", Damage = 7, Radius = 18, Duration = 1.5, Cooldown = 14, Color = rgb(110, 140, 255), Style = "Void", Description = "Tear open the void: drag everything in, then implode" } },
}

-- Armor sets ------------------------------------------------------------------------
-- Health/Defense are full-set totals; each piece gets a share (SLOT_SHARE).
-- Style keys (see ArmorVisuals): Primary, Secondary, Accent (glow), Cloth, Material,
-- TrimMaterial, Helmet, Pauldron, Emblem, Tabard, Cape, Fur, Wings, Skirt, Boots, Vfx.

Items.ArmorSlots = { "Helmet", "Chest", "Legs", "Boots" }
local SLOT_SHARE = { Helmet = 0.2, Chest = 0.4, Legs = 0.25, Boots = 0.15 }

local ARMOR_SETS = {
	{
		Id = "SquireLeathers",
		DisplayName = "Squire's Leathers",
		Rarity = "Common",
		Tier = 1,
		Health = 30,
		Defense = 0.04,
		SetBonus = { Health = 10, Description = "+10 health" },
		Names = { "Squire's Coif", "Squire's Jerkin", "Squire's Breeches", "Squire's Boots" },
		Style = {
			Primary = rgb(130, 90, 55), Secondary = rgb(85, 58, 38), Accent = rgb(200, 175, 120), Cloth = rgb(120, 45, 40),
			Material = M.Leather, TrimMaterial = M.Leather,
			Helmet = "Coif", Pauldron = "Leather", Skirt = "Loincloth", Boots = "Leather",
			Vfx = { Kind = "Dust", Color = rgb(200, 180, 140), Rate = 2 },
		},
	},
	{
		Id = "MilitiaChainmail",
		DisplayName = "Militia Chainmail",
		Rarity = "Common",
		Tier = 2,
		Health = 50,
		Defense = 0.06,
		SetBonus = { Defense = 0.02, Description = "+2% defense" },
		Names = { "Militia Kettle Hat", "Militia Hauberk", "Militia Chausses", "Militia Boots" },
		Style = {
			Primary = rgb(150, 150, 160), Secondary = rgb(105, 105, 115), Accent = rgb(230, 230, 240), Cloth = rgb(40, 70, 150),
			Material = M.DiamondPlate, TrimMaterial = M.Metal,
			Helmet = "Kettle", Pauldron = "Round", Tabard = true, Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Glint", Color = rgb(255, 255, 255), Rate = 2 },
		},
	},
	{
		Id = "KnightsPlate",
		DisplayName = "Knight's Plate",
		Rarity = "Rare",
		Tier = 3,
		Health = 90,
		Defense = 0.09,
		SetBonus = { Health = 20, Defense = 0.03, Description = "+20 health, +3% defense" },
		Names = { "Knight's Great Helm", "Knight's Cuirass", "Knight's Cuisses", "Knight's Sabatons" },
		Style = {
			Primary = rgb(195, 198, 208), Secondary = rgb(125, 125, 135), Accent = rgb(255, 255, 255), Cloth = rgb(160, 30, 35),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "GreatHelm", Plume = rgb(170, 30, 35), Pauldron = "Layered", Tabard = true, Skirt = "Tassets", Boots = "Plate",
			Vfx = { Kind = "Glint", Color = rgb(255, 255, 255), Rate = 5 },
		},
	},
	{
		Id = "CrusaderPlate",
		DisplayName = "Crusader's Plate",
		Rarity = "Rare",
		Tier = 4,
		Health = 130,
		Defense = 0.12,
		SetBonus = { Health = 30, Damage = 0.05, Description = "+30 health, +5% damage" },
		Names = { "Crusader's Helm", "Crusader's Hauberk", "Crusader's Greaves", "Crusader's Boots" },
		Style = {
			Primary = rgb(235, 232, 225), Secondary = rgb(215, 175, 60), Accent = rgb(200, 30, 30), Cloth = rgb(240, 238, 230),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Crusader", Pauldron = "Round", Emblem = "Cross", Tabard = true, Cape = true, Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Motes", Color = rgb(255, 215, 120), Rate = 5 },
		},
	},
	{
		Id = "RoyalGuard",
		DisplayName = "Royal Guard Regalia",
		Rarity = "Legendary",
		Tier = 5,
		Health = 190,
		Defense = 0.15,
		SetBonus = { Health = 40, Defense = 0.03, Description = "+40 health, +3% defense" },
		Names = { "Royal Guard Crown Helm", "Royal Guard Breastplate", "Royal Guard Tassets", "Royal Guard Sabatons" },
		Style = {
			Primary = rgb(45, 65, 145), Secondary = rgb(225, 180, 60), Accent = rgb(90, 180, 255), Cloth = rgb(110, 30, 120),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Crowned", Pauldron = "Winged", Emblem = "Crest", Cape = true, Skirt = "Tassets", Boots = "Plate",
			Vfx = { Kind = "Sparkles", Color = rgb(255, 215, 100), Rate = 8, Light = true },
		},
	},
	{
		Id = "WarlordsBastion",
		DisplayName = "Warlord's Bastion",
		Rarity = "Legendary",
		Tier = 6,
		Health = 260,
		Defense = 0.18,
		SetBonus = { Health = 30, Damage = 0.08, Description = "+30 health, +8% damage" },
		Names = { "Warlord's Horned Helm", "Warlord's Bastion", "Warlord's Legplates", "Warlord's Stompers" },
		Style = {
			Primary = rgb(55, 52, 56), Secondary = rgb(115, 35, 28), Accent = rgb(255, 90, 30),
			Material = M.Metal, TrimMaterial = M.CorrodedMetal,
			Helmet = "Horned", Pauldron = "Spiked", Emblem = "Skull", Fur = rgb(115, 92, 70), Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Embers", Color = rgb(255, 110, 40), Rate = 10, Light = true },
		},
	},
	{
		Id = "PaladinsRadiance",
		DisplayName = "Paladin's Radiance",
		Rarity = "Mythic",
		Tier = 7,
		Health = 360,
		Defense = 0.21,
		SetBonus = { Health = 60, Defense = 0.04, Description = "+60 health, +4% defense, holy wings glow" },
		Names = { "Radiant Halo Helm", "Radiant Aegis", "Radiant Greaves", "Radiant Sabatons" },
		Style = {
			Primary = rgb(245, 240, 230), Secondary = rgb(235, 190, 70), Accent = rgb(255, 230, 130), Cloth = rgb(250, 245, 235),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Halo", Pauldron = "Winged", Emblem = "Sun", Wings = "Angel", Cape = true, Skirt = "Tassets", Boots = "Plate",
			Vfx = { Kind = "Holy", Color = rgb(255, 235, 150), Rate = 10, Light = true },
		},
	},
	{
		Id = "AbyssalKnight",
		DisplayName = "Abyssal Knight",
		Rarity = "Mythic",
		Tier = 8,
		Health = 480,
		Defense = 0.24,
		SetBonus = { Damage = 0.1, Defense = 0.03, Description = "+10% damage, +3% defense, void aura" },
		Names = { "Abyssal Visage", "Abyssal Carapace", "Abyssal Legguards", "Abyssal Treads" },
		Style = {
			Primary = rgb(25, 28, 62), Secondary = rgb(70, 72, 130), Accent = rgb(90, 125, 255), Cloth = rgb(18, 18, 40),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Abyssal", Pauldron = "Spiked", Emblem = "Core", Cape = true, Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Void", Color = rgb(110, 130, 255), Rate = 12, Light = true },
		},
	},
	{
		Id = "BlackDragon",
		DisplayName = "Black Dragon",
		Rarity = "Godly",
		Tier = 10,
		Source = "Crate",
		Health = 650,
		Defense = 0.3,
		SetBonus = { Health = 100, Damage = 0.15, Description = "+100 health, +15% damage, dragon fire aura" },
		Names = { "Black Dragon Helm", "Black Dragon Scalemail", "Black Dragon Legguards", "Black Dragon Talons" },
		Style = {
			Primary = rgb(28, 24, 28), Secondary = rgb(62, 50, 56), Accent = rgb(255, 50, 20),
			Material = M.Slate, TrimMaterial = M.Basalt,
			Helmet = "Dragon", Pauldron = "Dragon", Emblem = "Cracks", Wings = "Dragon", Skirt = "Scales", Boots = "Claws",
			Vfx = { Kind = "Embers", Color = rgb(255, 70, 30), Rate = 14, Light = true, Smoke = true },
		},
	},
	{
		Id = "ShogunsOath",
		DisplayName = "Shogun's Oath",
		Rarity = "Godly",
		Tier = 10,
		Source = "Crate",
		Health = 600,
		Defense = 0.28,
		SetBonus = { Health = 80, Damage = 0.1, Speed = 0.1, Description = "+80 health, +10% damage, +10% speed, sakura aura" },
		Names = { "Shogun's Kabuto", "Shogun's Do", "Shogun's Haidate", "Shogun's Tabi" },
		Style = {
			Primary = rgb(175, 28, 32), Secondary = rgb(26, 22, 24), Accent = rgb(232, 185, 60), Cloth = rgb(30, 40, 95),
			Material = M.SmoothPlastic, TrimMaterial = M.Metal,
			Helmet = "Kabuto", Pauldron = "Sode", Emblem = "Lamellar", Skirt = "Kusazuri", Boots = "Tabi",
			Vfx = { Kind = "Petals", Color = rgb(255, 175, 205), Rate = 8 },
		},
	},
}

Items.Weapons = {} :: { [string]: WeaponDef }
Items.Armors = {} :: { [string]: ArmorDef } -- every armor piece, by piece id
Items.ArmorSets = {} :: { [string]: ArmorSetDef }
Items.ArmorSetOrder = {} :: { string } -- weakest first
Items.WeaponOrder = {} :: { string }
Items.ArmorOrder = {} :: { string }

for _, entry in WEAPON_LIST do
	local base = WEAPON_TYPES[entry.Type]
	Items.Weapons[entry.Id] = {
		Id = entry.Id,
		Kind = "Weapon",
		DisplayName = entry.Name,
		Type = entry.Type,
		Tier = entry.Tier,
		Rarity = TIER_RARITY[entry.Tier],
		Damage = math.floor(TIER_DAMAGE[entry.Tier] * base.DamageMultiplier),
		Cooldown = base.Cooldown,
		Range = base.Range,
		Splash = base.Splash,
		Effect = entry.Effect,
		Model = entry.Model,
		Color = entry.Color,
		Accent = entry.Accent,
		Material = entry.Material,
		Combo = entry.Combo,
		Design = entry.Design,
		Skill = entry.Skill,
	}
	table.insert(Items.WeaponOrder, entry.Id)
end

for _, set in ARMOR_SETS do
	local pieces = {}
	for i, slot in Items.ArmorSlots do
		local pieceId = `{set.Id}_{slot}`
		pieces[slot] = pieceId
		Items.Armors[pieceId] = {
			Id = pieceId,
			Kind = "Armor",
			DisplayName = set.Names[i],
			Set = set.Id,
			Slot = slot,
			Tier = set.Tier,
			Rarity = set.Rarity,
			Health = math.floor(set.Health * SLOT_SHARE[slot]),
			Defense = set.Defense * SLOT_SHARE[slot],
		}
		table.insert(Items.ArmorOrder, pieceId)
	end
	Items.ArmorSets[set.Id] = {
		Id = set.Id,
		DisplayName = set.DisplayName,
		Rarity = set.Rarity,
		Tier = set.Tier,
		Source = set.Source or "Loot",
		Health = set.Health,
		Defense = set.Defense,
		SetBonus = set.SetBonus,
		Pieces = pieces,
		Style = set.Style,
	}
	table.insert(Items.ArmorSetOrder, set.Id)
end

function Items.WeaponsOfType(weaponType: string, tier: number): { WeaponDef }
	local found = {}
	for _, id in Items.WeaponOrder do
		local weapon = Items.Weapons[id]
		if weapon.Type == weaponType and weapon.Tier == tier then
			table.insert(found, weapon)
		end
	end
	return found
end

-- Armor pieces that drop from dungeons at this tier (crate-only sets are excluded).
function Items.ArmorsOfTier(tier: number): { ArmorDef }
	local found = {}
	for _, id in Items.ArmorOrder do
		local piece = Items.Armors[id]
		if piece.Tier == tier and Items.ArmorSets[piece.Set].Source == "Loot" then
			table.insert(found, piece)
		end
	end
	return found
end

-- Armor pieces of a rarity that can drop from dungeons (used for crate filler rolls).
function Items.LootArmorsOfRarity(rarity: string): { ArmorDef }
	local found = {}
	for _, id in Items.ArmorOrder do
		local piece = Items.Armors[id]
		if piece.Rarity == rarity and Items.ArmorSets[piece.Set].Source == "Loot" then
			table.insert(found, piece)
		end
	end
	return found
end

-- Short description of an item's special effect, for UI.
function Items.DescribeEffect(effect: Effect?): string?
	if not effect then
		return nil
	end
	if effect.Type == "Burn" then
		return `Burn {math.floor(effect.Amount * 100)}%/s`
	elseif effect.Type == "Frost" then
		return `Frost: slows {math.floor(effect.Amount * 100)}%`
	elseif effect.Type == "Lifesteal" then
		return `Lifesteal {math.floor(effect.Amount * 100)}%`
	end
	return nil
end

return Items
