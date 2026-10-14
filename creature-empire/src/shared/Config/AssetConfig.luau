--!strict
-- Every external asset the game can use, in one place. Ids are left empty until a
-- licensed or original asset is uploaded: an empty id simply plays or shows nothing, and
-- the game falls back to code-built visuals. See docs/ASSETS.md for what each one should be.
--
-- Do not paste ids you have not uploaded or verified yourself.

export type SoundDef = {
	Id: string,
	Volume: number,
	Pitch: { number }, -- random playback speed range { min, max }
	Category: "Ui" | "Creature" | "Building" | "Reward" | "Music" | "Ambience",
}

local CreatureConfig = require(script.Parent.CreatureConfig)

local AssetConfig = {}

local function sound(category: any, volume: number, minPitch: number?, maxPitch: number?): SoundDef
	return { Id = "", Volume = volume, Pitch = { minPitch or 1, maxPitch or minPitch or 1 }, Category = category }
end

AssetConfig.Sounds = {
	-- Interface. The click falls back to a sound that ships with the Roblox client.
	UiClick = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Pitch = { 1.4, 1.6 }, Category = "Ui" },
	UiOpen = sound("Ui", 0.35, 0.95, 1.05),
	UiClose = sound("Ui", 0.3, 0.95, 1.05),
	UiError = sound("Ui", 0.4),
	Notify = sound("Ui", 0.4),
	QuestComplete = sound("Reward", 0.6),

	-- Economy
	Collect = sound("Building", 0.5, 0.9, 1.15),
	Sell = sound("Building", 0.5, 0.95, 1.05),
	Place = sound("Building", 0.6, 0.95, 1.05),
	Upgrade = sound("Building", 0.7),
	Harvest = sound("Building", 0.25, 0.85, 1.2),

	-- Creatures (per-species keys from CreatureConfig resolve here; missing = silent)
	CreatureObtain = sound("Reward", 0.8),
	AbilityCast = sound("Creature", 0.6, 0.95, 1.05),
	Hatch = sound("Reward", 0.7),
	Evolve = sound("Reward", 0.8),

	-- Music and ambience
	MusicEmpire = sound("Music", 0.35),
	AmbienceVerdant = sound("Ambience", 0.3),
} :: { [string]: SoundDef }

-- Per-species sounds: <species>_idle / _move / _work for every species. Fill in ids here
-- (e.g. AssetConfig.Sounds.sproutling_idle.Id = "rbxassetid://...") as they're uploaded.
for _, speciesId in CreatureConfig.Order do
	local key = string.lower(speciesId)
	AssetConfig.Sounds[key .. "_idle"] = AssetConfig.Sounds[key .. "_idle"] or sound("Creature", 0.35, 0.9, 1.2)
	AssetConfig.Sounds[key .. "_move"] = AssetConfig.Sounds[key .. "_move"] or sound("Creature", 0.2, 0.9, 1.2)
	AssetConfig.Sounds[key .. "_work"] = AssetConfig.Sounds[key .. "_work"] or sound("Creature", 0.25, 0.9, 1.2)
end

-- Images. Empty ids fall back to the glyphs in ResourceConfig / RarityConfig.
AssetConfig.Images = {
	Gold = "",
	Essence = "",
	EmpireShards = "",
	Moonpetal = "",
	GameIcon = "",
} :: { [string]: string }

-- Particle textures that ship with the Roblox client.
AssetConfig.Particles = {
	Default = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

-- Animations: creatures are animated procedurally (client/Visuals/CreatureAnimator) until
-- rigged models and animations are imported. Fill these in per species when they exist.
AssetConfig.Animations = {} :: { [string]: { Idle: string?, Walk: string?, Work: string? } }

-- Hand-made models loaded from Roblox by asset id when the server starts (for models too
-- big to keep as files). Each id must be a Model asset uploaded by the account or group
-- that owns the game (Toolbox → My Models → right-click → Copy Asset ID). The loaded model
-- is used exactly like one placed in ReplicatedStorage/Assets/<Category>/<Name>; a model
-- already placed there by hand wins. See docs/ASSETS.md.
AssetConfig.ModelAssets = {
	Creatures = {
		-- Supplied by the game's creator: their imported Sproutling model.
		Sproutling = 120629196068989,
	},
	Buildings = {
		-- Supplied by the game's creator: their shop model.
		TradingPost = 129682746612211,
		-- Supplied by the game's creator: their hatchery nest.
		Hatchery = 120291385949696,
		-- Supplied by the game's creator: their moonpetal farm.
		MoonpetalFarm = 134956325741614,
	},
	World = {
		-- Supplied by the game's creator: their fence section.
		FenceSegment = 103118385802066,
		-- Supplied by the game's creator: their lamp post.
		Lamp = 122745821192170,
		-- Supplied by the game's creator: their gravel path piece.
		PathSegment = 114265486516183,
		-- Supplied by the game's creator: their tree.
		Tree = 136607943988536,
	},
} :: { [string]: { [string]: number } }

-- Adjustments applied to loaded models (same as setting attributes on the model in Studio,
-- without re-uploading): Facing (degrees), HeightOffset (studs), KeepSize (boolean).
AssetConfig.ModelSettings = {
	Creatures = {
		Sproutling = { Facing = 180 },
	},
	Buildings = {},
	World = {
		-- Turned 90° left so the glowing mushrooms face the path.
		Lamp = { Facing = 90 },
	},
} :: { [string]: { [string]: { [string]: any } } }

return AssetConfig
