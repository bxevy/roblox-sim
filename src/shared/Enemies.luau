-- Enemy stats. Health, Damage, XP and Gold are multiplied by the dungeon's Power.
--
-- Body: "Humanoid" (default) | "Beast" (four legs) | "Floating" (no legs, hovers) | "Totem"
-- Ranged: shoots dodgeable projectiles instead of hitting in melee.
-- Static: never moves (totems, crystals).
--
-- Bosses (and mini-bosses) have mechanics: a list of telegraphed attacks they rotate
-- through, and phases that trigger at health thresholds. Attack types (EnemyService):
--   Slam     red circle around the boss                        (Radius, Windup, Damage)
--   Donut    everything far from the boss gets hit - get close (Radius = safe zone, Range = outer edge)
--   Charge   a lane toward a player, then the boss rushes down it (Range, Width)
--   Barrage  a circle under every player - keep moving          (Radius)
--   Meteors  circles rain across the arena                       (Count, Radius)
--   Cross    beams in a + (or x) from the boss - stand between them (Range, Width)
--   Wave     a ring expands from the boss - dodge [C] through it  (Range)
--   Summon   calls adds                                          (Adds = { EnemyId = count })
-- Phases (At = health fraction):
--   Summon   calls adds once
--   Shield   the boss is immune until the totems it summons are destroyed
--   Enrage   faster, harder hits, attacks come quicker (Speed, Damage)
-- Damage numbers are base values, multiplied like normal attacks.

export type BossAttack = {
	Type: string,
	Cooldown: number,
	Windup: number?,
	Damage: number?,
	Radius: number?,
	Range: number?,
	Width: number?,
	Count: number?,
	Adds: { [string]: number }?,
	Phase: number?, -- only used from this phase on (phases start at 1)
	Message: string?, -- announced to the party
}

export type BossPhase = {
	At: number,
	Type: string,
	Adds: { [string]: number }?,
	Speed: number?,
	Damage: number?,
	Message: string,
}

export type BossDef = {
	Color: Color3, -- telegraph / effect color
	Gap: number, -- seconds between mechanics
	Attacks: { BossAttack },
	Phases: { BossPhase }?,
}

export type EnemyDef = {
	DisplayName: string,
	Health: number,
	Damage: number,
	Speed: number,
	AttackRange: number,
	AttackCooldown: number,
	Scale: number,
	BodyColor: Color3,
	HeadColor: Color3,
	EyeColor: Color3,
	Material: Enum.Material?,
	XP: number,
	Gold: number,
	Body: string?,
	HeadShape: string?, -- "Pumpkin" (glowing jack-o'-lantern) | "Headless"
	Ranged: { Projectile: string, Color: Color3 }?,
	Static: boolean?,
	Crown: Color3?,
	Horns: Color3?,
	Weapon: { Kind: string, Color: Color3 }?, -- "Sword" | "Axe" | "Staff" | "Hammer" | "Scythe"
	Boss: BossDef?,
	MiniBoss: boolean?,
}

local rgb = Color3.fromRGB
local M = Enum.Material

local Enemies = {
	-- Crypt of Bones -------------------------------------------------------------------
	Skeleton = {
		DisplayName = "Skeleton", Health = 45, Damage = 7, Speed = 13, AttackRange = 4, AttackCooldown = 1.2, Scale = 1,
		BodyColor = rgb(220, 215, 200), HeadColor = rgb(235, 230, 215), EyeColor = rgb(255, 60, 60), XP = 12, Gold = 2,
		Weapon = { Kind = "Sword", Color = rgb(150, 150, 155) },
	},
	Zombie = {
		DisplayName = "Zombie", Health = 90, Damage = 12, Speed = 9, AttackRange = 4, AttackCooldown = 1.6, Scale = 1.15,
		BodyColor = rgb(80, 120, 75), HeadColor = rgb(110, 150, 95), EyeColor = rgb(255, 230, 80), XP = 18, Gold = 3,
	},
	SkeletonArcher = {
		DisplayName = "Skeleton Archer", Health = 35, Damage = 8, Speed = 11, AttackRange = 34, AttackCooldown = 2.2, Scale = 0.95,
		BodyColor = rgb(210, 205, 190), HeadColor = rgb(230, 225, 210), EyeColor = rgb(120, 255, 120), XP = 14, Gold = 2,
		Ranged = { Projectile = "Arrow", Color = rgb(200, 255, 200) },
	},
	GraveWarden = {
		DisplayName = "Grave Warden", Health = 420, Damage = 14, Speed = 11, AttackRange = 5, AttackCooldown = 1.5, Scale = 1.7,
		BodyColor = rgb(70, 70, 80), HeadColor = rgb(220, 215, 200), EyeColor = rgb(120, 255, 140), Material = M.Slate, XP = 60, Gold = 15,
		Weapon = { Kind = "Scythe", Color = rgb(120, 125, 130) }, MiniBoss = true,
		Boss = {
			Color = rgb(120, 255, 140), Gap = 3.5,
			Attacks = {
				{ Type = "Slam", Radius = 12, Windup = 1.1, Damage = 25, Cooldown = 6 },
				{ Type = "Charge", Range = 34, Width = 6, Windup = 1, Damage = 25, Cooldown = 8, Message = "The Warden lowers its scythe..." },
			},
		},
	},
	BoneKing = {
		DisplayName = "The Bone King", Health = 1400, Damage = 18, Speed = 11, AttackRange = 5, AttackCooldown = 1.5, Scale = 2.2,
		BodyColor = rgb(200, 195, 180), HeadColor = rgb(240, 235, 220), EyeColor = rgb(170, 70, 255), XP = 120, Gold = 30,
		Crown = rgb(170, 90, 255), Weapon = { Kind = "Sword", Color = rgb(170, 90, 255) },
		Boss = {
			Color = rgb(170, 70, 255), Gap = 3,
			Attacks = {
				{ Type = "Slam", Radius = 16, Windup = 1.2, Damage = 35, Cooldown = 7 },
				{ Type = "Barrage", Radius = 5, Windup = 1.2, Damage = 25, Cooldown = 9, Message = "Bone spears rise beneath you!" },
				{ Type = "Cross", Range = 45, Width = 6, Windup = 1.5, Damage = 40, Cooldown = 12, Phase = 2, Message = "The Bone King raises his blade - get between the lines!" },
				{ Type = "Summon", Adds = { Skeleton = 2, SkeletonArcher = 1 }, Cooldown = 22, Phase = 2 },
			},
			Phases = {
				{ At = 0.6, Type = "Summon", Adds = { Skeleton = 3, SkeletonArcher = 2 }, Message = "\"RISE, MY SERVANTS!\"" },
				{ At = 0.3, Type = "Enrage", Speed = 1.3, Damage = 1.25, Message = "The Bone King is ENRAGED!" },
			},
		},
	},

	-- Witchwood Hollow ------------------------------------------------------------------
	Wolf = {
		DisplayName = "Dire Wolf", Health = 55, Damage = 9, Speed = 19, AttackRange = 4, AttackCooldown = 1, Scale = 1,
		BodyColor = rgb(90, 85, 80), HeadColor = rgb(110, 105, 100), EyeColor = rgb(255, 200, 60), Material = M.Fabric, XP = 14, Gold = 2,
		Body = "Beast",
	},
	Treant = {
		DisplayName = "Treant", Health = 150, Damage = 15, Speed = 8, AttackRange = 5, AttackCooldown = 1.8, Scale = 1.5,
		BodyColor = rgb(95, 70, 45), HeadColor = rgb(70, 120, 50), EyeColor = rgb(200, 255, 120), Material = M.Wood, XP = 24, Gold = 4,
		Horns = rgb(95, 70, 45),
	},
	Witch = {
		DisplayName = "Bog Witch", Health = 50, Damage = 10, Speed = 11, AttackRange = 32, AttackCooldown = 2.2, Scale = 1,
		BodyColor = rgb(60, 40, 80), HeadColor = rgb(120, 170, 100), EyeColor = rgb(200, 80, 255), Material = M.Fabric, XP = 16, Gold = 3,
		Ranged = { Projectile = "Orb", Color = rgb(180, 80, 255) }, Weapon = { Kind = "Staff", Color = rgb(90, 60, 40) },
	},
	HexTotem = {
		DisplayName = "Hex Totem", Health = 160, Damage = 8, Speed = 0, AttackRange = 40, AttackCooldown = 2.5, Scale = 1.2,
		BodyColor = rgb(80, 60, 40), HeadColor = rgb(80, 60, 40), EyeColor = rgb(200, 80, 255), Material = M.Wood, XP = 10, Gold = 2,
		Body = "Totem", Static = true, Ranged = { Projectile = "Orb", Color = rgb(200, 80, 255) },
	},
	AlphaWolf = {
		DisplayName = "Alpha Wolf", Health = 500, Damage = 15, Speed = 18, AttackRange = 5, AttackCooldown = 1.2, Scale = 1.8,
		BodyColor = rgb(50, 50, 55), HeadColor = rgb(70, 70, 75), EyeColor = rgb(255, 60, 60), Material = M.Fabric, XP = 70, Gold = 18,
		Body = "Beast", MiniBoss = true,
		Boss = {
			Color = rgb(255, 80, 60), Gap = 3,
			Attacks = {
				{ Type = "Charge", Range = 38, Width = 6, Windup = 0.9, Damage = 28, Cooldown = 6, Message = "The Alpha prepares to pounce!" },
				{ Type = "Summon", Adds = { Wolf = 2 }, Cooldown = 18, Message = "The Alpha howls for its pack!" },
			},
		},
	},
	HagQueen = {
		DisplayName = "The Hag Queen", Health = 1500, Damage = 19, Speed = 12, AttackRange = 5, AttackCooldown = 1.5, Scale = 2.3,
		BodyColor = rgb(50, 30, 70), HeadColor = rgb(120, 170, 100), EyeColor = rgb(220, 90, 255), Material = M.Fabric, XP = 130, Gold = 32,
		Crown = rgb(60, 140, 50), Weapon = { Kind = "Staff", Color = rgb(70, 50, 35) },
		Boss = {
			Color = rgb(200, 80, 255), Gap = 3,
			Attacks = {
				{ Type = "Meteors", Count = 7, Radius = 6, Windup = 1.4, Damage = 30, Cooldown = 9, Message = "Hexes rain from the canopy!" },
				{ Type = "Donut", Radius = 9, Range = 40, Windup = 1.8, Damage = 40, Cooldown = 12, Message = "Thorns erupt - get CLOSE to her!" },
				{ Type = "Slam", Radius = 14, Windup = 1.1, Damage = 32, Cooldown = 7 },
				{ Type = "Summon", Adds = { Wolf = 3 }, Cooldown = 20 },
			},
			Phases = {
				{ At = 0.5, Type = "Shield", Adds = { HexTotem = 3 }, Message = "The Hag Queen shields herself - destroy the Hex Totems!" },
				{ At = 0.25, Type = "Enrage", Speed = 1.3, Damage = 1.3, Message = "The Hag Queen shrieks in fury!" },
			},
		},
	},

	-- Sunken Temple ---------------------------------------------------------------------
	Mummy = {
		DisplayName = "Mummy", Health = 80, Damage = 10, Speed = 11, AttackRange = 4, AttackCooldown = 1.3, Scale = 1.1,
		BodyColor = rgb(215, 200, 160), HeadColor = rgb(225, 210, 170), EyeColor = rgb(80, 255, 160), Material = M.Fabric, XP = 16, Gold = 3,
	},
	Scarab = {
		DisplayName = "Scarab", Health = 35, Damage = 6, Speed = 18, AttackRange = 3, AttackCooldown = 0.8, Scale = 0.7,
		BodyColor = rgb(30, 80, 100), HeadColor = rgb(40, 100, 120), EyeColor = rgb(255, 200, 40), XP = 8, Gold = 1,
		Body = "Beast",
	},
	CobraPriest = {
		DisplayName = "Cobra Priest", Health = 55, Damage = 10, Speed = 12, AttackRange = 32, AttackCooldown = 2.2, Scale = 1,
		BodyColor = rgb(40, 60, 130), HeadColor = rgb(60, 140, 80), EyeColor = rgb(255, 220, 60), Material = M.Fabric, XP = 18, Gold = 3,
		Ranged = { Projectile = "Bolt", Color = rgb(80, 255, 160) }, Weapon = { Kind = "Staff", Color = rgb(220, 180, 60) },
	},
	CanopicJar = {
		DisplayName = "Canopic Jar", Health = 180, Damage = 0, Speed = 0, AttackRange = 0, AttackCooldown = 99, Scale = 1.1,
		BodyColor = rgb(210, 180, 110), HeadColor = rgb(40, 60, 140), EyeColor = rgb(80, 255, 160), Material = M.Sandstone, XP = 10, Gold = 2,
		Body = "Totem", Static = true,
	},
	AnubisSentinel = {
		DisplayName = "Anubis Sentinel", Health = 520, Damage = 16, Speed = 12, AttackRange = 5.5, AttackCooldown = 1.4, Scale = 1.8,
		BodyColor = rgb(30, 30, 35), HeadColor = rgb(30, 30, 35), EyeColor = rgb(80, 255, 160), Material = M.Basalt, XP = 75, Gold = 18,
		Horns = rgb(220, 180, 60), Weapon = { Kind = "Hammer", Color = rgb(220, 180, 60) }, MiniBoss = true,
		Boss = {
			Color = rgb(80, 255, 160), Gap = 3,
			Attacks = {
				{ Type = "Slam", Radius = 13, Windup = 1, Damage = 28, Cooldown = 6 },
				{ Type = "Cross", Range = 36, Width = 5, Windup = 1.3, Damage = 30, Cooldown = 10, Message = "The Sentinel's eyes blaze..." },
			},
		},
	},
	Pharaoh = {
		DisplayName = "The Cursed Pharaoh", Health = 1700, Damage = 20, Speed = 12, AttackRange = 5, AttackCooldown = 1.4, Scale = 2.3,
		BodyColor = rgb(230, 185, 60), HeadColor = rgb(40, 60, 140), EyeColor = rgb(80, 255, 160), XP = 140, Gold = 35,
		Crown = rgb(230, 185, 60), Weapon = { Kind = "Staff", Color = rgb(230, 185, 60) },
		Boss = {
			Color = rgb(80, 255, 160), Gap = 2.8,
			Attacks = {
				{ Type = "Charge", Range = 45, Width = 7, Windup = 1.1, Damage = 35, Cooldown = 8, Message = "The Pharaoh summons a sandstorm charge!" },
				{ Type = "Barrage", Radius = 6, Windup = 1.1, Damage = 28, Cooldown = 9, Message = "A curse marks you - MOVE!" },
				{ Type = "Donut", Radius = 10, Range = 42, Windup = 1.7, Damage = 42, Cooldown = 12 },
				{ Type = "Cross", Range = 50, Width = 6, Windup = 1.4, Damage = 42, Cooldown = 11, Phase = 2, Message = "Beams of the sun god!" },
			},
			Phases = {
				{ At = 0.5, Type = "Shield", Adds = { CanopicJar = 3, Scarab = 4 }, Message = "The Pharaoh is protected by his canopic jars - smash them!" },
				{ At = 0.25, Type = "Enrage", Speed = 1.3, Damage = 1.3, Message = "The Pharaoh's curse grows stronger!" },
			},
		},
	},

	-- Frozen Keep -----------------------------------------------------------------------
	Yeti = {
		DisplayName = "Yeti", Health = 120, Damage = 14, Speed = 10, AttackRange = 4.5, AttackCooldown = 1.5, Scale = 1.4,
		BodyColor = rgb(235, 240, 245), HeadColor = rgb(200, 215, 230), EyeColor = rgb(80, 160, 255), Material = M.Fabric, XP = 22, Gold = 4,
		Horns = rgb(200, 210, 220),
	},
	FrostWraith = {
		DisplayName = "Frost Wraith", Health = 60, Damage = 11, Speed = 16, AttackRange = 4, AttackCooldown = 1, Scale = 1,
		BodyColor = rgb(120, 180, 230), HeadColor = rgb(170, 215, 255), EyeColor = rgb(255, 255, 255), Material = M.Ice, XP = 15, Gold = 3,
		Body = "Floating",
	},
	FrostMage = {
		DisplayName = "Frost Mage", Health = 60, Damage = 12, Speed = 11, AttackRange = 34, AttackCooldown = 2, Scale = 1,
		BodyColor = rgb(60, 90, 150), HeadColor = rgb(200, 220, 240), EyeColor = rgb(140, 220, 255), Material = M.Fabric, XP = 18, Gold = 3,
		Ranged = { Projectile = "Bolt", Color = rgb(150, 220, 255) }, Weapon = { Kind = "Staff", Color = rgb(160, 210, 245) },
	},
	IceCrystal = {
		DisplayName = "Ice Crystal", Health = 200, Damage = 9, Speed = 0, AttackRange = 40, AttackCooldown = 2.4, Scale = 1.3,
		BodyColor = rgb(150, 210, 245), HeadColor = rgb(150, 210, 245), EyeColor = rgb(255, 255, 255), Material = M.Ice, XP = 10, Gold = 2,
		Body = "Totem", Static = true, Ranged = { Projectile = "Bolt", Color = rgb(170, 230, 255) },
	},
	FrostGiant = {
		DisplayName = "Frost Giant", Health = 600, Damage = 18, Speed = 10, AttackRange = 6, AttackCooldown = 1.6, Scale = 2,
		BodyColor = rgb(140, 180, 220), HeadColor = rgb(200, 225, 245), EyeColor = rgb(80, 200, 255), Material = M.Glacier, XP = 85, Gold = 20,
		Weapon = { Kind = "Axe", Color = rgb(160, 210, 245) }, MiniBoss = true,
		Boss = {
			Color = rgb(120, 220, 255), Gap = 3.2,
			Attacks = {
				{ Type = "Slam", Radius = 15, Windup = 1.1, Damage = 30, Cooldown = 6 },
				{ Type = "Meteors", Count = 6, Radius = 6, Windup = 1.3, Damage = 25, Cooldown = 9, Message = "Hailstones fall!" },
			},
		},
	},
	FrostLord = {
		DisplayName = "The Frost Lord", Health = 1900, Damage = 22, Speed = 12, AttackRange = 5.5, AttackCooldown = 1.4, Scale = 2.5,
		BodyColor = rgb(90, 140, 200), HeadColor = rgb(190, 230, 255), EyeColor = rgb(120, 230, 255), Material = M.Ice, XP = 160, Gold = 40,
		Crown = rgb(170, 230, 255), Weapon = { Kind = "Sword", Color = rgb(170, 230, 255) },
		Boss = {
			Color = rgb(120, 220, 255), Gap = 2.6,
			Attacks = {
				{ Type = "Slam", Radius = 18, Windup = 1, Damage = 40, Cooldown = 7 },
				{ Type = "Meteors", Count = 9, Radius = 6, Windup = 1.3, Damage = 32, Cooldown = 9, Message = "A blizzard of hail!" },
				{ Type = "Wave", Range = 45, Windup = 1, Damage = 38, Cooldown = 11, Message = "A frost wave - DODGE [C] through it!" },
				{ Type = "Cross", Range = 50, Width = 6, Windup = 1.3, Damage = 45, Cooldown = 10, Phase = 2, Message = "Ice lances!" },
			},
			Phases = {
				{ At = 0.66, Type = "Summon", Adds = { FrostWraith = 3, FrostMage = 1 }, Message = "\"Freeze them, my wraiths!\"" },
				{ At = 0.4, Type = "Shield", Adds = { IceCrystal = 3 }, Message = "The Frost Lord encases himself in ice - shatter the crystals!" },
				{ At = 0.2, Type = "Enrage", Speed = 1.35, Damage = 1.3, Message = "The Frost Lord's fury freezes the air!" },
			},
		},
	},

	-- Infernal Forge --------------------------------------------------------------------
	MagmaImp = {
		DisplayName = "Magma Imp", Health = 50, Damage = 10, Speed = 19, AttackRange = 3.5, AttackCooldown = 0.9, Scale = 0.8,
		BodyColor = rgb(200, 60, 30), HeadColor = rgb(240, 90, 40), EyeColor = rgb(255, 230, 60), Material = M.CrackedLava, XP = 14, Gold = 3,
		Horns = rgb(40, 30, 30),
	},
	ObsidianGolem = {
		DisplayName = "Obsidian Golem", Health = 180, Damage = 18, Speed = 8, AttackRange = 5, AttackCooldown = 1.9, Scale = 1.6,
		BodyColor = rgb(30, 25, 35), HeadColor = rgb(45, 40, 50), EyeColor = rgb(255, 120, 30), Material = M.Basalt, XP = 28, Gold = 5,
	},
	FireCaster = {
		DisplayName = "Fire Caster", Health = 60, Damage = 13, Speed = 11, AttackRange = 34, AttackCooldown = 2, Scale = 1,
		BodyColor = rgb(120, 30, 20), HeadColor = rgb(60, 40, 40), EyeColor = rgb(255, 160, 40), Material = M.Fabric, XP = 18, Gold = 3,
		Ranged = { Projectile = "Fireball", Color = rgb(255, 120, 30) }, Weapon = { Kind = "Staff", Color = rgb(40, 30, 30) },
	},
	FlameBrazier = {
		DisplayName = "Flame Brazier", Health = 220, Damage = 10, Speed = 0, AttackRange = 40, AttackCooldown = 2.2, Scale = 1.3,
		BodyColor = rgb(50, 45, 45), HeadColor = rgb(255, 110, 30), EyeColor = rgb(255, 220, 60), Material = M.Metal, XP = 10, Gold = 2,
		Body = "Totem", Static = true, Ranged = { Projectile = "Fireball", Color = rgb(255, 120, 30) },
	},
	Forgemaster = {
		DisplayName = "The Forgemaster", Health = 650, Damage = 19, Speed = 11, AttackRange = 6, AttackCooldown = 1.5, Scale = 2,
		BodyColor = rgb(70, 50, 45), HeadColor = rgb(50, 40, 40), EyeColor = rgb(255, 150, 40), Material = M.Metal, XP = 90, Gold = 22,
		Weapon = { Kind = "Hammer", Color = rgb(255, 120, 40) }, MiniBoss = true,
		Boss = {
			Color = rgb(255, 120, 30), Gap = 3,
			Attacks = {
				{ Type = "Slam", Radius = 14, Windup = 1, Damage = 30, Cooldown = 6 },
				{ Type = "Barrage", Radius = 5, Windup = 1, Damage = 25, Cooldown = 8, Message = "Molten metal splashes down!" },
			},
		},
	},
	Infernus = {
		DisplayName = "Infernus, the Molten King", Health = 2100, Damage = 24, Speed = 12, AttackRange = 6, AttackCooldown = 1.3, Scale = 2.7,
		BodyColor = rgb(60, 30, 25), HeadColor = rgb(40, 25, 25), EyeColor = rgb(255, 200, 40), Material = M.CrackedLava, XP = 180, Gold = 45,
		Crown = rgb(255, 120, 30), Horns = rgb(30, 25, 25), Weapon = { Kind = "Axe", Color = rgb(255, 110, 30) },
		Boss = {
			Color = rgb(255, 110, 30), Gap = 2.5,
			Attacks = {
				{ Type = "Meteors", Count = 10, Radius = 6, Windup = 1.3, Damage = 35, Cooldown = 8, Message = "Meteors fall from the forge!" },
				{ Type = "Charge", Range = 48, Width = 8, Windup = 1, Damage = 40, Cooldown = 8 },
				{ Type = "Donut", Radius = 10, Range = 45, Windup = 1.6, Damage = 45, Cooldown = 12, Message = "A ring of fire - get close to him!" },
				{ Type = "Wave", Range = 45, Windup = 0.9, Damage = 40, Cooldown = 10, Phase = 2, Message = "A lava wave - DODGE [C] through it!" },
				{ Type = "Barrage", Radius = 6, Windup = 1, Damage = 30, Cooldown = 9, Phase = 2 },
			},
			Phases = {
				{ At = 0.6, Type = "Shield", Adds = { FlameBrazier = 4 }, Message = "Infernus draws power from the braziers - put them out!" },
				{ At = 0.3, Type = "Enrage", Speed = 1.35, Damage = 1.35, Message = "Infernus erupts!" },
				{ At = 0.29, Type = "Summon", Adds = { MagmaImp = 4 }, Message = "Imps pour out of the lava!" },
			},
		},
	},

	-- Abyssal Rift ------------------------------------------------------------------------
	VoidStalker = {
		DisplayName = "Void Stalker", Health = 70, Damage = 13, Speed = 18, AttackRange = 4, AttackCooldown = 1, Scale = 1.1,
		BodyColor = rgb(30, 20, 50), HeadColor = rgb(50, 30, 80), EyeColor = rgb(200, 120, 255), Material = M.Glass, XP = 18, Gold = 3,
		Body = "Beast",
	},
	Shade = {
		DisplayName = "Shade", Health = 65, Damage = 14, Speed = 13, AttackRange = 34, AttackCooldown = 2, Scale = 1,
		BodyColor = rgb(20, 15, 35), HeadColor = rgb(40, 30, 70), EyeColor = rgb(170, 100, 255), Material = M.Glass, XP = 20, Gold = 4,
		Body = "Floating", Ranged = { Projectile = "Orb", Color = rgb(170, 100, 255) },
	},
	AbyssalHorror = {
		DisplayName = "Abyssal Horror", Health = 220, Damage = 20, Speed = 9, AttackRange = 5.5, AttackCooldown = 1.8, Scale = 1.7,
		BodyColor = rgb(40, 20, 60), HeadColor = rgb(60, 30, 90), EyeColor = rgb(255, 80, 200), Material = M.Slate, XP = 32, Gold = 6,
		Horns = rgb(20, 10, 30),
	},
	VoidRift = {
		DisplayName = "Void Rift", Health = 260, Damage = 12, Speed = 0, AttackRange = 40, AttackCooldown = 2.2, Scale = 1.3,
		BodyColor = rgb(20, 10, 30), HeadColor = rgb(150, 80, 255), EyeColor = rgb(255, 255, 255), Material = M.Glass, XP = 12, Gold = 3,
		Body = "Totem", Static = true, Ranged = { Projectile = "Orb", Color = rgb(170, 100, 255) },
	},
	VoidHerald = {
		DisplayName = "Herald of the Void", Health = 720, Damage = 21, Speed = 12, AttackRange = 5.5, AttackCooldown = 1.4, Scale = 2,
		BodyColor = rgb(30, 15, 50), HeadColor = rgb(20, 10, 30), EyeColor = rgb(200, 120, 255), Material = M.Glass, XP = 100, Gold = 25,
		Body = "Floating", Weapon = { Kind = "Scythe", Color = rgb(170, 100, 255) }, MiniBoss = true,
		Boss = {
			Color = rgb(170, 100, 255), Gap = 3,
			Attacks = {
				{ Type = "Cross", Range = 40, Width = 6, Windup = 1.2, Damage = 32, Cooldown = 8 },
				{ Type = "Barrage", Radius = 6, Windup = 1, Damage = 28, Cooldown = 8, Message = "The void reaches for you!" },
			},
		},
	},
	VoidEmperor = {
		DisplayName = "The Void Emperor", Health = 2500, Damage = 26, Speed = 13, AttackRange = 6, AttackCooldown = 1.3, Scale = 2.8,
		BodyColor = rgb(25, 15, 45), HeadColor = rgb(15, 10, 25), EyeColor = rgb(220, 140, 255), Material = M.Glass, XP = 220, Gold = 55,
		Crown = rgb(200, 120, 255), Horns = rgb(60, 30, 100), Weapon = { Kind = "Scythe", Color = rgb(200, 120, 255) },
		Boss = {
			Color = rgb(190, 110, 255), Gap = 2.3,
			Attacks = {
				{ Type = "Cross", Range = 55, Width = 7, Windup = 1.3, Damage = 48, Cooldown = 9, Message = "The Emperor splits reality!" },
				{ Type = "Donut", Radius = 10, Range = 48, Windup = 1.5, Damage = 50, Cooldown = 12, Message = "The void collapses - get close!" },
				{ Type = "Meteors", Count = 12, Radius = 6, Windup = 1.2, Damage = 38, Cooldown = 9 },
				{ Type = "Wave", Range = 48, Windup = 0.9, Damage = 45, Cooldown = 10, Message = "A void wave - DODGE [C] through it!" },
				{ Type = "Charge", Range = 50, Width = 8, Windup = 0.9, Damage = 45, Cooldown = 9, Phase = 2 },
				{ Type = "Barrage", Radius = 6, Windup = 0.9, Damage = 35, Cooldown = 8, Phase = 3 },
			},
			Phases = {
				{ At = 0.75, Type = "Summon", Adds = { Shade = 3, VoidStalker = 2 }, Message = "\"Kneel before the void.\"" },
				{ At = 0.5, Type = "Shield", Adds = { VoidRift = 4 }, Message = "The Emperor feeds on the rifts - close them!" },
				{ At = 0.25, Type = "Enrage", Speed = 1.4, Damage = 1.4, Message = "THE VOID EMPEROR UNLEASHES HIS TRUE POWER!" },
			},
		},
	},

	-- Haunted Manor (Halloween event) ------------------------------------------------------
	JackOLantern = {
		DisplayName = "Jack-o'-Lantern", Health = 140, Damage = 16, Speed = 13, AttackRange = 4.5, AttackCooldown = 1.2, Scale = 1.2,
		BodyColor = rgb(40, 35, 45), HeadColor = rgb(240, 120, 20), EyeColor = rgb(255, 200, 60), Material = M.Fabric, XP = 30, Gold = 6,
		HeadShape = "Pumpkin", Weapon = { Kind = "Scythe", Color = rgb(255, 140, 30) },
	},
	Phantom = {
		DisplayName = "Phantom", Health = 90, Damage = 15, Speed = 20, AttackRange = 4, AttackCooldown = 0.9, Scale = 1.1,
		BodyColor = rgb(220, 225, 240), HeadColor = rgb(240, 245, 255), EyeColor = rgb(20, 20, 30), Material = M.Glass, XP = 26, Gold = 5,
		Body = "Floating",
	},
	VampireBat = {
		DisplayName = "Vampire Bat", Health = 60, Damage = 12, Speed = 24, AttackRange = 3.5, AttackCooldown = 0.7, Scale = 0.75,
		BodyColor = rgb(35, 25, 40), HeadColor = rgb(50, 35, 55), EyeColor = rgb(255, 40, 60), Material = M.Fabric, XP = 18, Gold = 4,
		Body = "Beast",
	},
	Banshee = {
		DisplayName = "Banshee", Health = 85, Damage = 17, Speed = 14, AttackRange = 36, AttackCooldown = 1.8, Scale = 1.1,
		BodyColor = rgb(120, 90, 160), HeadColor = rgb(200, 190, 220), EyeColor = rgb(150, 255, 200), Material = M.Glass, XP = 28, Gold = 5,
		Body = "Floating", Ranged = { Projectile = "Orb", Color = rgb(150, 255, 200) },
	},
	CursedPumpkin = {
		DisplayName = "Cursed Pumpkin", Health = 320, Damage = 14, Speed = 0, AttackRange = 42, AttackCooldown = 2, Scale = 1.4,
		BodyColor = rgb(50, 40, 40), HeadColor = rgb(240, 120, 20), EyeColor = rgb(160, 80, 255), Material = M.Wood, XP = 15, Gold = 4,
		Body = "Totem", Static = true, HeadShape = "Pumpkin", Ranged = { Projectile = "Pumpkin", Color = rgb(255, 140, 30) },
	},
	HeadlessHorseman = {
		DisplayName = "The Headless Horseman", Health = 900, Damage = 24, Speed = 16, AttackRange = 6, AttackCooldown = 1.2, Scale = 2.1,
		BodyColor = rgb(30, 25, 35), HeadColor = rgb(30, 25, 35), EyeColor = rgb(255, 120, 20), Material = M.Fabric, XP = 140, Gold = 35,
		HeadShape = "Headless", Weapon = { Kind = "Sword", Color = rgb(255, 120, 30) }, MiniBoss = true,
		Boss = {
			Color = rgb(255, 120, 30), Gap = 2.4,
			Attacks = {
				{ Type = "Charge", Range = 45, Width = 7, Windup = 0.8, Damage = 40, Cooldown = 6, Message = "The Horseman charges!" },
				{ Type = "Barrage", Radius = 6, Windup = 0.9, Damage = 32, Cooldown = 8, Message = "Flaming pumpkins rain down - MOVE!" },
				{ Type = "Slam", Radius = 14, Windup = 0.9, Damage = 38, Cooldown = 6 },
			},
		},
	},
	PumpkinKing = {
		DisplayName = "The Pumpkin King", Health = 3200, Damage = 30, Speed = 14, AttackRange = 6.5, AttackCooldown = 1.1, Scale = 3,
		BodyColor = rgb(30, 20, 35), HeadColor = rgb(240, 120, 20), EyeColor = rgb(170, 90, 255), Material = M.Fabric, XP = 300, Gold = 80,
		HeadShape = "Pumpkin", Crown = rgb(150, 70, 220), Weapon = { Kind = "Scythe", Color = rgb(170, 90, 255) },
		Boss = {
			Color = rgb(255, 130, 30), Gap = 2,
			Attacks = {
				{ Type = "Meteors", Count = 14, Radius = 6, Windup = 1.1, Damage = 45, Cooldown = 8, Message = "Jack-o'-lanterns fall from the sky!" },
				{ Type = "Cross", Range = 55, Width = 7, Windup = 1.1, Damage = 55, Cooldown = 9, Message = "The King's scythes sweep the hall!" },
				{ Type = "Donut", Radius = 10, Range = 50, Windup = 1.4, Damage = 60, Cooldown = 11, Message = "Thorny vines erupt - get CLOSE!" },
				{ Type = "Wave", Range = 50, Windup = 0.8, Damage = 50, Cooldown = 9, Message = "A wave of ghostfire - DODGE [C] through it!" },
				{ Type = "Charge", Range = 55, Width = 9, Windup = 0.8, Damage = 55, Cooldown = 8 },
				{ Type = "Barrage", Radius = 6, Windup = 0.8, Damage = 45, Cooldown = 7, Phase = 2 },
				{ Type = "Summon", Adds = { VampireBat = 3, Phantom = 2 }, Cooldown = 18, Phase = 2 },
			},
			Phases = {
				{ At = 0.75, Type = "Summon", Adds = { JackOLantern = 3, Banshee = 2 }, Message = "\"RISE, MY PUMPKIN PATCH!\"" },
				{ At = 0.5, Type = "Shield", Adds = { CursedPumpkin = 4 }, Message = "The Pumpkin King draws power from the cursed pumpkins - smash them!" },
				{ At = 0.3, Type = "Shield", Adds = { CursedPumpkin = 5, Phantom = 2 }, Message = "He shields himself AGAIN! Smash the pumpkins!" },
				{ At = 0.15, Type = "Enrage", Speed = 1.5, Damage = 1.5, Message = "THE PUMPKIN KING IS ENRAGED!" },
			},
		},
	},
} :: { [string]: EnemyDef }

return Enemies
