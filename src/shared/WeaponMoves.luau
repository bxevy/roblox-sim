-- Combo styles and code-driven animations for weapons.
--
-- Combos: each weapon uses one combo style. Clicking again within the combo window moves
-- to the next step; the last step is a finisher. The server uses Damage, Hit, Range and
-- Cooldown; the client plays Anim.
--
-- Animations are keyframed rotations (degrees) added on top of the character's joints,
-- so they need no uploaded animation assets. Joints: RS/LS (shoulders), RE/LE (elbows),
-- W (waist), N (neck), R (whole-body root rotation) and RP (root offset, studs).
-- Base pose: holding a tool raises the right arm straight forward.

local WeaponMoves = {}

export type Pose = { [string]: Vector3 }
export type Keyframe = { T: number, Pose: Pose }
export type Animation = { Duration: number, Keys: { Keyframe } }

local v = Vector3.new

-- Animations ----------------------------------------------------------------------

WeaponMoves.Animations = {
	-- Swords
	SlashRight = { Duration = 0.32, Keys = {
		{ T = 0, Pose = { RS = v(25, -75, 0), W = v(0, -35, 0) } },
		{ T = 0.55, Pose = { RS = v(5, 55, 0), W = v(0, 25, 0) } },
		{ T = 1, Pose = { RS = v(0, 45, 0), W = v(0, 15, 0) } },
	} },
	SlashLeft = { Duration = 0.32, Keys = {
		{ T = 0, Pose = { RS = v(30, 55, 0), W = v(0, 30, 0) } },
		{ T = 0.55, Pose = { RS = v(0, -70, 0), W = v(0, -30, 0) } },
		{ T = 1, Pose = { RS = v(-5, -55, 0), W = v(0, -20, 0) } },
	} },
	Overhead = { Duration = 0.4, Keys = {
		{ T = 0, Pose = { RS = v(110, 0, 0), W = v(12, 0, 0), N = v(10, 0, 0) } },
		{ T = 0.5, Pose = { RS = v(-55, 0, 0), W = v(-18, 0, 0), N = v(-5, 0, 0) } },
		{ T = 1, Pose = { RS = v(-45, 0, 0), W = v(-12, 0, 0) } },
	} },
	Thrust = { Duration = 0.3, Keys = {
		{ T = 0, Pose = { RS = v(0, -10, 0), W = v(0, -35, 0), RP = v(0, 0, 0.4) } },
		{ T = 0.45, Pose = { RS = v(0, 5, 0), W = v(-8, 18, 0), RP = v(0, 0, -1.2) } },
		{ T = 1, Pose = { RS = v(0, 0, 0), W = v(0, 10, 0), RP = v(0, 0, -0.6) } },
	} },
	Spin = { Duration = 0.45, Keys = {
		{ T = 0, Pose = { R = v(0, 0, 0), RS = v(0, -55, 0) } },
		{ T = 1, Pose = { R = v(0, -360, 0), RS = v(0, -55, 0) } },
	} },
	Uppercut = { Duration = 0.42, Keys = {
		{ T = 0, Pose = { RS = v(-70, 0, 0), W = v(-18, 0, 0), RP = v(0, -0.3, 0) } },
		{ T = 0.5, Pose = { RS = v(120, 0, 0), W = v(12, 0, 0), RP = v(0, 1, 0) } },
		{ T = 1, Pose = { RS = v(90, 0, 0), W = v(5, 0, 0), RP = v(0, 0, 0) } },
	} },
	LeapSlam = { Duration = 0.65, Keys = {
		{ T = 0, Pose = { RS = v(60, 0, 0), RP = v(0, 0, 0) } },
		{ T = 0.4, Pose = { RS = v(140, 0, 0), W = v(15, 0, 0), RP = v(0, 3, -1) } },
		{ T = 0.75, Pose = { RS = v(-70, 0, 0), W = v(-25, 0, 0), RP = v(0, -0.4, -1.5) } },
		{ T = 1, Pose = { RS = v(-50, 0, 0), W = v(-15, 0, 0), RP = v(0, 0, -0.8) } },
	} },
	-- Daggers (right hand holds the weapon, left hand stabs too)
	StabRight = { Duration = 0.2, Keys = {
		{ T = 0, Pose = { RS = v(5, -20, 0), W = v(0, -25, 0), RP = v(0, 0, 0.3) } },
		{ T = 0.5, Pose = { RS = v(0, 5, 0), W = v(0, 12, 0), RP = v(0, 0, -0.7) } },
		{ T = 1, Pose = { RS = v(0, 0, 0), W = v(0, 5, 0) } },
	} },
	StabLeft = { Duration = 0.2, Keys = {
		{ T = 0, Pose = { LS = v(60, 20, 0), W = v(0, 25, 0), RP = v(0, 0, 0.3) } },
		{ T = 0.5, Pose = { LS = v(95, -5, 0), W = v(0, -12, 0), RP = v(0, 0, -0.7) } },
		{ T = 1, Pose = { LS = v(80, 0, 0), W = v(0, -5, 0) } },
	} },
	CrossSlash = { Duration = 0.32, Keys = {
		{ T = 0, Pose = { RS = v(40, -70, 0), LS = v(130, 60, 0), W = v(10, 0, 0) } },
		{ T = 0.5, Pose = { RS = v(-20, 45, 0), LS = v(60, -50, 0), W = v(-12, 0, 0) } },
		{ T = 1, Pose = { RS = v(-10, 35, 0), LS = v(50, -40, 0), W = v(-6, 0, 0) } },
	} },
	Backflip = { Duration = 0.55, Keys = {
		{ T = 0, Pose = { R = v(0, 0, 0), RP = v(0, 0, 0) } },
		{ T = 0.5, Pose = { R = v(-200, 0, 0), RP = v(0, 2.2, 1.5) } },
		{ T = 1, Pose = { R = v(-360, 0, 0), RP = v(0, 0, 2) } },
	} },
	-- Maces
	HeavySwing = { Duration = 0.5, Keys = {
		{ T = 0, Pose = { RS = v(35, -95, 0), W = v(0, -50, 0) } },
		{ T = 0.6, Pose = { RS = v(10, 80, 0), W = v(-5, 40, 0) } },
		{ T = 1, Pose = { RS = v(0, 65, 0), W = v(0, 30, 0) } },
	} },
	HeavyBackswing = { Duration = 0.5, Keys = {
		{ T = 0, Pose = { RS = v(35, 80, 0), W = v(0, 40, 0) } },
		{ T = 0.6, Pose = { RS = v(10, -95, 0), W = v(-5, -45, 0) } },
		{ T = 1, Pose = { RS = v(0, -80, 0), W = v(0, -35, 0) } },
	} },
	Smash = { Duration = 0.5, Keys = {
		{ T = 0, Pose = { RS = v(140, 0, 0), W = v(18, 0, 0), N = v(12, 0, 0) } },
		{ T = 0.55, Pose = { RS = v(-75, 0, 0), W = v(-30, 0, 0), RP = v(0, -0.4, 0) } },
		{ T = 1, Pose = { RS = v(-60, 0, 0), W = v(-20, 0, 0) } },
	} },
	GroundPound = { Duration = 0.7, Keys = {
		{ T = 0, Pose = { RS = v(80, 0, 0) } },
		{ T = 0.45, Pose = { RS = v(150, 0, 0), W = v(15, 0, 0), RP = v(0, 2.5, 0) } },
		{ T = 0.75, Pose = { RS = v(-80, 0, 0), W = v(-30, 0, 0), RP = v(0, -0.6, 0) } },
		{ T = 1, Pose = { RS = v(-60, 0, 0), W = v(-20, 0, 0) } },
	} },
	Twirl = { Duration = 0.5, Keys = {
		{ T = 0, Pose = { R = v(0, 0, 0), RS = v(10, -70, 0) } },
		{ T = 1, Pose = { R = v(0, 360, 0), RS = v(10, -70, 0) } },
	} },
	-- Staffs
	CastForward = { Duration = 0.3, Keys = {
		{ T = 0, Pose = { RS = v(45, 0, 0), W = v(6, 0, 0) } },
		{ T = 0.5, Pose = { RS = v(-15, 0, 0), W = v(-10, 0, 0), RP = v(0, 0, -0.4) } },
		{ T = 1, Pose = { RS = v(-5, 0, 0), W = v(-4, 0, 0) } },
	} },
	CastSweep = { Duration = 0.35, Keys = {
		{ T = 0, Pose = { RS = v(20, -55, 0), LS = v(70, 30, 0), W = v(0, -25, 0) } },
		{ T = 0.6, Pose = { RS = v(0, 50, 0), LS = v(90, -20, 0), W = v(0, 25, 0) } },
		{ T = 1, Pose = { RS = v(0, 35, 0), LS = v(60, 0, 0), W = v(0, 15, 0) } },
	} },
	CastHigh = { Duration = 0.55, Keys = {
		{ T = 0, Pose = { RS = v(0, 0, 0), LS = v(0, 0, 0) } },
		{ T = 0.5, Pose = { RS = v(95, 0, 0), LS = v(165, 0, 0), N = v(18, 0, 0), RP = v(0, 0.5, 0) } },
		{ T = 0.8, Pose = { RS = v(-20, 0, 0), LS = v(90, 0, 0), W = v(-12, 0, 0) } },
		{ T = 1, Pose = { RS = v(-10, 0, 0), LS = v(40, 0, 0) } },
	} },
	-- Bows (bow in the right hand; left hand draws the string)
	Draw = { Duration = 0.32, Keys = {
		{ T = 0, Pose = { LS = v(85, -45, 0), LE = v(0, 0, 0), W = v(0, -20, 0) } },
		{ T = 0.6, Pose = { LS = v(80, -75, 0), LE = v(0, 0, 0), W = v(0, -25, 0) } },
		{ T = 1, Pose = { LS = v(60, -30, 0), W = v(0, -10, 0) } },
	} },
	QuickDraw = { Duration = 0.22, Keys = {
		{ T = 0, Pose = { LS = v(85, -60, 0), W = v(0, -15, 0) } },
		{ T = 1, Pose = { LS = v(60, -30, 0), W = v(0, -8, 0) } },
	} },
	SkyShot = { Duration = 0.5, Keys = {
		{ T = 0, Pose = { RS = v(0, 0, 0), LS = v(85, -50, 0) } },
		{ T = 0.6, Pose = { RS = v(60, 0, 0), LS = v(140, -50, 0), W = v(15, 0, 0), N = v(25, 0, 0) } },
		{ T = 1, Pose = { RS = v(40, 0, 0), LS = v(100, -30, 0), W = v(10, 0, 0) } },
	} },
	-- Tomes (book in the right hand; left hand gestures)
	PageFlick = { Duration = 0.32, Keys = {
		{ T = 0, Pose = { LS = v(40, 0, 0) } },
		{ T = 0.5, Pose = { LS = v(110, -30, 0), W = v(0, 10, 0) } },
		{ T = 1, Pose = { LS = v(70, -10, 0) } },
	} },
	Proclaim = { Duration = 0.55, Keys = {
		{ T = 0, Pose = { RS = v(0, 0, 0), LS = v(0, 0, 0) } },
		{ T = 0.5, Pose = { RS = v(70, 0, 0), LS = v(150, 0, 0), N = v(20, 0, 0), RP = v(0, 0.4, 0) } },
		{ T = 1, Pose = { RS = v(30, 0, 0), LS = v(80, 0, 0) } },
	} },
	Bless = { Duration = 0.4, Keys = {
		{ T = 0, Pose = { LS = v(90, 50, 0), W = v(0, 20, 0) } },
		{ T = 0.6, Pose = { LS = v(90, -50, 0), W = v(0, -20, 0) } },
		{ T = 1, Pose = { LS = v(60, -20, 0) } },
	} },
	-- Axes / greatswords (two-handed: the left arm joins the swing)
	Cleave = { Duration = 0.45, Keys = {
		{ T = 0, Pose = { RS = v(120, -40, 0), LS = v(120, 30, 0), W = v(10, -30, 0) } },
		{ T = 0.55, Pose = { RS = v(-50, 40, 0), LS = v(-10, 50, 0), W = v(-18, 25, 0) } },
		{ T = 1, Pose = { RS = v(-35, 30, 0), LS = v(0, 40, 0), W = v(-10, 15, 0) } },
	} },
	Upheaval = { Duration = 0.5, Keys = {
		{ T = 0, Pose = { RS = v(-60, 30, 0), LS = v(-20, 40, 0), W = v(-15, 20, 0), RP = v(0, -0.3, 0) } },
		{ T = 0.55, Pose = { RS = v(130, -20, 0), LS = v(130, 10, 0), W = v(12, -15, 0), RP = v(0, 0.8, 0) } },
		{ T = 1, Pose = { RS = v(100, 0, 0), LS = v(90, 0, 0), W = v(5, 0, 0) } },
	} },
	-- Scythes (wide, low sweeps)
	Reap = { Duration = 0.42, Keys = {
		{ T = 0, Pose = { RS = v(-25, -95, 0), LS = v(40, -40, 0), W = v(-10, -55, 0) } },
		{ T = 0.6, Pose = { RS = v(-30, 90, 0), LS = v(30, 60, 0), W = v(-12, 50, 0) } },
		{ T = 1, Pose = { RS = v(-20, 75, 0), LS = v(20, 45, 0), W = v(-6, 35, 0) } },
	} },
	ReapBack = { Duration = 0.42, Keys = {
		{ T = 0, Pose = { RS = v(-25, 90, 0), LS = v(40, 50, 0), W = v(-10, 50, 0) } },
		{ T = 0.6, Pose = { RS = v(-30, -95, 0), LS = v(30, -50, 0), W = v(-12, -55, 0) } },
		{ T = 1, Pose = { RS = v(-20, -80, 0), LS = v(20, -40, 0), W = v(-6, -40, 0) } },
	} },
	-- Spears / halberds
	Lunge = { Duration = 0.38, Keys = {
		{ T = 0, Pose = { RS = v(0, -15, 0), LS = v(60, 20, 0), W = v(0, -40, 0), RP = v(0, 0, 0.8) } },
		{ T = 0.45, Pose = { RS = v(5, 5, 0), LS = v(80, 0, 0), W = v(-10, 20, 0), RP = v(0, -0.3, -2.4) } },
		{ T = 1, Pose = { RS = v(0, 0, 0), LS = v(60, 0, 0), W = v(0, 10, 0), RP = v(0, 0, -1) } },
	} },
	Dive = { Duration = 0.7, Keys = {
		{ T = 0, Pose = { RS = v(60, 0, 0), LS = v(60, 0, 0) } },
		{ T = 0.4, Pose = { RS = v(170, 0, 0), LS = v(170, 0, 0), W = v(15, 0, 0), N = v(20, 0, 0) } },
		{ T = 0.75, Pose = { RS = v(-90, 0, 0), LS = v(-30, 0, 0), W = v(-35, 0, 0) } },
		{ T = 1, Pose = { RS = v(-60, 0, 0), LS = v(0, 0, 0), W = v(-20, 0, 0) } },
	} },
	-- Katanas (very fast draws)
	IaiSlash = { Duration = 0.18, Keys = {
		{ T = 0, Pose = { RS = v(-40, -100, 0), W = v(0, -40, 0) } },
		{ T = 0.5, Pose = { RS = v(10, 70, 0), W = v(0, 30, 0), RP = v(0, 0, -0.6) } },
		{ T = 1, Pose = { RS = v(5, 55, 0), W = v(0, 20, 0) } },
	} },
	IaiReturn = { Duration = 0.18, Keys = {
		{ T = 0, Pose = { RS = v(30, 70, 0), W = v(0, 30, 0) } },
		{ T = 0.5, Pose = { RS = v(-20, -80, 0), W = v(0, -35, 0), RP = v(0, 0, -0.5) } },
		{ T = 1, Pose = { RS = v(-10, -60, 0), W = v(0, -25, 0) } },
	} },
	Battojutsu = { Duration = 0.45, Keys = {
		{ T = 0, Pose = { RS = v(-50, -110, 0), LS = v(20, 30, 0), W = v(0, -50, 0), RP = v(0, -0.5, 0.5) } },
		{ T = 0.35, Pose = { RS = v(-50, -110, 0), LS = v(20, 30, 0), W = v(0, -50, 0), RP = v(0, -0.6, 0.5) } },
		{ T = 0.55, Pose = { RS = v(20, 90, 0), LS = v(-10, -20, 0), W = v(0, 40, 0), RP = v(0, 0, -3) } },
		{ T = 1, Pose = { RS = v(10, 70, 0), W = v(0, 25, 0), RP = v(0, 0, -2) } },
	} },
	Roar = { Duration = 0.6, Keys = {
		{ T = 0, Pose = { RS = v(0, 0, 0), LS = v(0, 0, 0) } },
		{ T = 0.4, Pose = { RS = v(30, 0, 60), LS = v(30, 0, -60), W = v(-15, 0, 0), N = v(25, 0, 0) } },
		{ T = 1, Pose = { RS = v(20, 0, 40), LS = v(20, 0, -40), W = v(-8, 0, 0), N = v(10, 0, 0) } },
	} },
	-- Weapon skills (longer, showier)
	Channel = { Duration = 0.8, Keys = {
		{ T = 0, Pose = { RS = v(0, 0, 0), LS = v(0, 0, 0) } },
		{ T = 0.3, Pose = { RS = v(30, 0, 0), LS = v(100, -20, 0), W = v(-8, 0, 0) } },
		{ T = 1, Pose = { RS = v(25, 0, 0), LS = v(95, -20, 0), W = v(-8, 0, 0) } },
	} },
	SkillSpin = { Duration = 0.9, Keys = {
		{ T = 0, Pose = { R = v(0, 0, 0), RS = v(0, -60, 0) } },
		{ T = 1, Pose = { R = v(0, -1080, 0), RS = v(0, -60, 0) } },
	} },
}

-- Combo styles --------------------------------------------------------------------
-- Hit shapes (server): Arc, Thrust, Spin, Slam, Shot, Multishot, Burst, Pierce, Nova, Smite
--   Damage: x weapon damage; Cooldown: seconds before the next step; Range: overrides the weapon's
--   Count / Spread: for Multishot; Radius: for Slam / Burst / Nova / Smite

export type Step = {
	Anim: string,
	Hit: string,
	Damage: number,
	Cooldown: number,
	Range: number?,
	Radius: number?,
	Count: number?,
	Spread: number?,
	Heal: number?, -- Nova: also heal nearby teammates by this share of max health
}

WeaponMoves.ComboWindow = 1.1 -- seconds after a hit to continue the combo

WeaponMoves.Combos = {
	-- Swords
	Blademaster = { DisplayName = "Blademaster", Steps = {
		{ Anim = "SlashRight", Hit = "Arc", Damage = 1, Cooldown = 0.42 },
		{ Anim = "SlashLeft", Hit = "Arc", Damage = 1, Cooldown = 0.42 },
		{ Anim = "Spin", Hit = "Spin", Damage = 1.7, Cooldown = 0.75 },
	} },
	Duelist = { DisplayName = "Duelist", Steps = {
		{ Anim = "Thrust", Hit = "Thrust", Damage = 1.15, Cooldown = 0.38 },
		{ Anim = "SlashRight", Hit = "Arc", Damage = 1, Cooldown = 0.38 },
		{ Anim = "Thrust", Hit = "Thrust", Damage = 1.25, Cooldown = 0.38 },
		{ Anim = "Uppercut", Hit = "Arc", Damage = 1.9, Cooldown = 0.75 },
	} },
	Executioner = { DisplayName = "Executioner", Steps = {
		{ Anim = "Overhead", Hit = "Arc", Damage = 1.35, Cooldown = 0.55 },
		{ Anim = "Overhead", Hit = "Arc", Damage = 1.35, Cooldown = 0.55 },
		{ Anim = "LeapSlam", Hit = "Slam", Damage = 2.4, Radius = 11, Cooldown = 0.95 },
	} },
	-- Daggers
	Flurry = { DisplayName = "Flurry", Steps = {
		{ Anim = "StabRight", Hit = "Thrust", Damage = 0.8, Cooldown = 0.2 },
		{ Anim = "StabLeft", Hit = "Thrust", Damage = 0.8, Cooldown = 0.2 },
		{ Anim = "StabRight", Hit = "Thrust", Damage = 0.85, Cooldown = 0.2 },
		{ Anim = "StabLeft", Hit = "Thrust", Damage = 0.85, Cooldown = 0.2 },
		{ Anim = "CrossSlash", Hit = "Arc", Damage = 1.8, Cooldown = 0.5 },
	} },
	Twinfang = { DisplayName = "Twinfang", Steps = {
		{ Anim = "CrossSlash", Hit = "Arc", Damage = 1.05, Cooldown = 0.3 },
		{ Anim = "CrossSlash", Hit = "Arc", Damage = 1.05, Cooldown = 0.3 },
		{ Anim = "Backflip", Hit = "Spin", Damage = 2, Cooldown = 0.6 },
	} },
	-- Maces
	Crusher = { DisplayName = "Crusher", Steps = {
		{ Anim = "HeavySwing", Hit = "Arc", Damage = 1, Cooldown = 0.6 },
		{ Anim = "HeavyBackswing", Hit = "Arc", Damage = 1.05, Cooldown = 0.6 },
		{ Anim = "GroundPound", Hit = "Slam", Damage = 2.3, Radius = 12, Cooldown = 1 },
	} },
	Juggernaut = { DisplayName = "Juggernaut", Steps = {
		{ Anim = "Smash", Hit = "Arc", Damage = 1.2, Cooldown = 0.6 },
		{ Anim = "Twirl", Hit = "Spin", Damage = 1.3, Cooldown = 0.6 },
		{ Anim = "Smash", Hit = "Slam", Damage = 2.1, Radius = 9, Cooldown = 0.9 },
	} },
	-- Staffs
	Arcanist = { DisplayName = "Arcanist", Steps = {
		{ Anim = "CastForward", Hit = "Shot", Damage = 0.9, Cooldown = 0.6 },
		{ Anim = "CastForward", Hit = "Shot", Damage = 0.9, Cooldown = 0.6 },
		{ Anim = "CastHigh", Hit = "Burst", Damage = 1.9, Radius = 10, Cooldown = 1 },
	} },
	Stormcaller = { DisplayName = "Stormcaller", Steps = {
		{ Anim = "CastSweep", Hit = "Multishot", Damage = 0.6, Count = 2, Spread = 12, Cooldown = 0.6 },
		{ Anim = "CastSweep", Hit = "Multishot", Damage = 0.6, Count = 2, Spread = 12, Cooldown = 0.6 },
		{ Anim = "CastHigh", Hit = "Nova", Damage = 1.6, Radius = 13, Cooldown = 1 },
	} },
	-- Bows
	Marksman = { DisplayName = "Marksman", Steps = {
		{ Anim = "Draw", Hit = "Shot", Damage = 1, Cooldown = 0.42 },
		{ Anim = "Draw", Hit = "Shot", Damage = 1, Cooldown = 0.42 },
		{ Anim = "SkyShot", Hit = "Pierce", Damage = 2, Cooldown = 0.8 },
	} },
	Hunter = { DisplayName = "Hunter", Steps = {
		{ Anim = "QuickDraw", Hit = "Shot", Damage = 0.9, Cooldown = 0.35 },
		{ Anim = "Draw", Hit = "Multishot", Damage = 0.6, Count = 3, Spread = 10, Cooldown = 0.45 },
		{ Anim = "SkyShot", Hit = "Multishot", Damage = 0.6, Count = 5, Spread = 9, Cooldown = 0.8 },
	} },
	-- Tomes
	Psalm = { DisplayName = "Psalm", Steps = {
		{ Anim = "PageFlick", Hit = "Shot", Damage = 0.9, Cooldown = 0.55 },
		{ Anim = "PageFlick", Hit = "Shot", Damage = 0.9, Cooldown = 0.55 },
		{ Anim = "Proclaim", Hit = "Nova", Damage = 1.5, Radius = 12, Heal = 0.05, Cooldown = 1 },
	} },
	Judgment = { DisplayName = "Judgment", Steps = {
		{ Anim = "Bless", Hit = "Shot", Damage = 1, Cooldown = 0.6 },
		{ Anim = "Bless", Hit = "Shot", Damage = 1, Cooldown = 0.6 },
		{ Anim = "Proclaim", Hit = "Smite", Damage = 2.2, Radius = 8, Cooldown = 1 },
	} },
	-- Axes
	Ravager = { DisplayName = "Ravager", Steps = {
		{ Anim = "HeavySwing", Hit = "Arc", Damage = 1.1, Cooldown = 0.55 },
		{ Anim = "Cleave", Hit = "Arc", Damage = 1.25, Cooldown = 0.6 },
		{ Anim = "SkillSpin", Hit = "Spin", Damage = 2.2, Range = 10, Cooldown = 1 },
	} },
	Lumberjack = { DisplayName = "Lumberjack", Steps = {
		{ Anim = "Cleave", Hit = "Arc", Damage = 1.2, Cooldown = 0.6 },
		{ Anim = "Upheaval", Hit = "Arc", Damage = 1.2, Cooldown = 0.6 },
		{ Anim = "LeapSlam", Hit = "Slam", Damage = 2.5, Radius = 12, Cooldown = 1 },
	} },
	-- Greatswords
	Crusader = { DisplayName = "Crusader", Steps = {
		{ Anim = "HeavySwing", Hit = "Arc", Damage = 1.1, Cooldown = 0.7 },
		{ Anim = "HeavyBackswing", Hit = "Arc", Damage = 1.1, Cooldown = 0.7 },
		{ Anim = "Cleave", Hit = "Slam", Damage = 2.6, Radius = 13, Cooldown = 1.1 },
	} },
	Titan = { DisplayName = "Titan", Steps = {
		{ Anim = "Upheaval", Hit = "Arc", Damage = 1.15, Cooldown = 0.7 },
		{ Anim = "Spin", Hit = "Spin", Damage = 1.3, Range = 11, Cooldown = 0.7 },
		{ Anim = "GroundPound", Hit = "Slam", Damage = 2.8, Radius = 14, Cooldown = 1.2 },
	} },
	-- Scythes
	Reaper = { DisplayName = "Reaper", Steps = {
		{ Anim = "Reap", Hit = "Arc", Damage = 1, Range = 10, Cooldown = 0.5 },
		{ Anim = "ReapBack", Hit = "Arc", Damage = 1, Range = 10, Cooldown = 0.5 },
		{ Anim = "SkillSpin", Hit = "Spin", Damage = 2, Range = 12, Cooldown = 0.95 },
	} },
	Harvester = { DisplayName = "Harvester", Steps = {
		{ Anim = "Reap", Hit = "Arc", Damage = 1, Range = 10, Cooldown = 0.5 },
		{ Anim = "Lunge", Hit = "Thrust", Damage = 1.2, Cooldown = 0.5 },
		{ Anim = "ReapBack", Hit = "Arc", Damage = 1.1, Range = 10, Cooldown = 0.5 },
		{ Anim = "Twirl", Hit = "Spin", Damage = 1.9, Range = 12, Cooldown = 0.95 },
	} },
	-- Spears
	Impaler = { DisplayName = "Impaler", Steps = {
		{ Anim = "Thrust", Hit = "Thrust", Damage = 1, Cooldown = 0.4 },
		{ Anim = "Thrust", Hit = "Thrust", Damage = 1, Cooldown = 0.4 },
		{ Anim = "Lunge", Hit = "Thrust", Damage = 2.2, Range = 15, Cooldown = 0.85 },
	} },
	Skewer = { DisplayName = "Skewer", Steps = {
		{ Anim = "Thrust", Hit = "Thrust", Damage = 1.05, Cooldown = 0.4 },
		{ Anim = "Twirl", Hit = "Spin", Damage = 1.1, Cooldown = 0.5 },
		{ Anim = "Lunge", Hit = "Thrust", Damage = 1.3, Range = 13, Cooldown = 0.45 },
		{ Anim = "Dive", Hit = "Slam", Damage = 2.3, Radius = 11, Cooldown = 1 },
	} },
	-- Katanas
	Iaijutsu = { DisplayName = "Iaijutsu", Steps = {
		{ Anim = "IaiSlash", Hit = "Arc", Damage = 0.9, Cooldown = 0.28 },
		{ Anim = "IaiReturn", Hit = "Arc", Damage = 0.9, Cooldown = 0.28 },
		{ Anim = "IaiSlash", Hit = "Arc", Damage = 0.95, Cooldown = 0.28 },
		{ Anim = "Battojutsu", Hit = "Thrust", Damage = 2.4, Range = 14, Cooldown = 0.8 },
	} },
	Kenjutsu = { DisplayName = "Kenjutsu", Steps = {
		{ Anim = "SlashRight", Hit = "Arc", Damage = 1, Cooldown = 0.35 },
		{ Anim = "SlashLeft", Hit = "Arc", Damage = 1, Cooldown = 0.35 },
		{ Anim = "Overhead", Hit = "Arc", Damage = 1.15, Cooldown = 0.4 },
		{ Anim = "Uppercut", Hit = "Arc", Damage = 1.9, Cooldown = 0.75 },
	} },
	-- Halberds
	Seraphic = { DisplayName = "Seraphic", Steps = {
		{ Anim = "HeavySwing", Hit = "Arc", Damage = 1.1, Range = 10, Cooldown = 0.55 },
		{ Anim = "Lunge", Hit = "Thrust", Damage = 1.2, Range = 13, Cooldown = 0.55 },
		{ Anim = "Twirl", Hit = "Spin", Damage = 1.3, Range = 11, Cooldown = 0.55 },
		{ Anim = "Dive", Hit = "Slam", Damage = 2.8, Radius = 14, Cooldown = 1.1 },
	} },
	Archangel = { DisplayName = "Archangel", Steps = {
		{ Anim = "Cleave", Hit = "Arc", Damage = 1.2, Range = 10, Cooldown = 0.6 },
		{ Anim = "Upheaval", Hit = "Arc", Damage = 1.2, Range = 10, Cooldown = 0.6 },
		{ Anim = "GroundPound", Hit = "Slam", Damage = 3, Radius = 15, Cooldown = 1.1 },
	} },
} :: { [string]: { DisplayName: string, Steps: { Step } } }

-- Which animation each weapon-skill mechanic plays.
WeaponMoves.SkillAnims = {
	Cyclone = "SkillSpin",
	Empower = "Proclaim",
	Shockwave = "Smash",
	Blink = "Thrust",
	Spikes = "Smash",
	Vortex = "CastHigh",
	Rain = "SkyShot",
	Breath = "Channel",
	Collapse = "CastHigh",
	Missiles = "CastSweep",
	Root = "CastHigh",
	Beam = "Channel",
	Chain = "CastForward",
	Meteor = "CastHigh",
	Nova = "GroundPound",
	Orb = "CastForward",
	Pierce = "Draw",
	Execute = "Overhead",
	Cloud = "CastSweep",
	Bomb = "Draw",
	Summon = "Proclaim",
	Ricochet = "CrossSlash",
	Heal = "Proclaim",
	Zone = "Bless",
	Guardian = "Proclaim",
}

-- Animations for class abilities (Q / E).
WeaponMoves.AbilityAnims = {
	Whirlwind = "SkillSpin",
	ShieldWall = "Proclaim",
	Fireball = "CastHigh",
	HealingCircle = "Proclaim",
	Volley = "SkyShot",
	HolyNova = "Proclaim",
	DivineShield = "Proclaim",
	ShadowStrike = "Thrust",
	SwiftStep = "Backflip",
	Vanish = "Backflip",
	CoinBarrage = "CastSweep",
	MidasTouch = "Proclaim",
	Bloodlust = "Roar",
	LeapSmash = "Dive",
	Consecration = "Proclaim",
	Judgment = "CastHigh",
	RaiseDead = "Proclaim",
	SoulHarvest = "Reap",
	DragonDive = "Dive",
	WyvernLance = "Lunge",
	Iaido = "Battojutsu",
	ThousandCuts = "SkillSpin",
	HeavensWrath = "CastHigh",
	Ascension = "Proclaim",
}

return WeaponMoves
