--!strict
-- Shared type definitions. Config modules, server services and client controllers all
-- describe the same data with these types, so a new creature, building or quest only
-- needs a config entry, not new code.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type FamilyId = string -- "Verdant", "Emberkin", ... (see CreatureConfig.Families)
export type JobId = string -- "Farmer", "Miner", ... (see JobConfig)
export type StatId = string -- "WorkSpeed", "Yield", ... (see CreatureConfig.Stats)

-- How a creature changes production. Category decides how bonuses combine (see
-- EconomyConfig.BonusRules): values in the same category add, categories multiply.
export type Modifier = {
	Stat: "WorkSpeed" | "Yield",
	Category: string,
	Value: number, -- 0.1 = +10%
	Job: JobId?, -- only applies while working this job
}

export type AbilityDef = {
	Id: string,
	Name: string,
	Description: string,
	Cooldown: number, -- seconds
	-- Phase 1 implements "InstantHarvest", "SpeedBurst" and "GoldFind" (CreatureService).
	-- Other kinds belong to species that are not obtainable yet.
	Kind: string,
	Power: number, -- meaning depends on Kind
	Duration: number?,
	RequiresAssignment: boolean,
}

export type PassiveDef = {
	Id: string,
	Name: string,
	Description: string,
	Modifiers: { Modifier },
}

export type AppearanceDef = {
	Body: "Round" | "Pear" | "Block" | "Long",
	Size: number, -- studs, juvenile height
	Primary: Color3,
	Secondary: Color3,
	Glow: Color3?,
	Features: { string }, -- built by Visuals/CreatureModels: "LeafSprout", "FlameTuft", ...
	Eyes: "Round" | "Sleepy" | "Bright",
	Particle: {
		Color: Color3,
		Rate: number,
		Kind: "Leaves" | "Embers" | "Glints" | "Sparks" | "Mist" | "Bubbles" | "Bolts" | "Motes",
	}?,
	Footstep: "Leaf" | "Ash" | "Dust" | "Spark" | "Splash" | "Clank" | "Shadow" | "Glimmer",
}

export type IdleBehaviour = {
	Personality: string, -- shown in the creature details
	WanderRadius: number,
	HopHeight: number,
	Speed: number, -- studs/second when walking
	IdleActions: { string }, -- "Hop", "Spin", "Sniff", "Nap", "Look"
}

export type EvolutionStage = {
	Stage: number, -- 1 Juvenile, 2 Mature, 3 Ascended
	Name: string,
	ScaleMultiplier: number,
	-- Requirements are data only in Phase 1; EvolutionService (Phase 2) reads them.
	Requirements: { { Kind: string, Target: string?, Amount: number } }?,
	Unlocks: { string }?,
}

export type SpeciesDef = {
	Id: string,
	Name: string,
	Family: FamilyId,
	Rarity: RarityId,
	Description: string,
	Discovery: string, -- how it is found, shown in the collection journal
	BaseStats: { [StatId]: number },
	JobAffinity: { [JobId]: number }, -- 1 = full efficiency, 0 or missing = cannot do the job
	Active: AbilityDef,
	Passive: PassiveDef,
	Evolution: { EvolutionStage },
	Mutations: { string }, -- mutation ids it may roll (Phase 4)
	Appearance: AppearanceDef,
	Sounds: { Idle: string, Move: string, Work: string },
	Habitat: string, -- biome id
	Idle: IdleBehaviour,
	Starter: boolean?,
	Phase: number, -- first phase in which the species can be obtained
}

export type BuildingLevel = {
	Cost: { [string]: number }?, -- nil for level 1 of a free building
	Description: string?, -- what changes at this level, shown in the upgrade panel
	-- Production buildings
	CycleTime: number?,
	YieldPerCycle: number?,
	Slots: number?,
	Storage: number?,
	-- Storage buildings
	Capacity: { [string]: number }?,
	-- Empire Core
	BuildingLimits: { [string]: number }?,
	EmpireBonus: number?,
}

export type BuildingDef = {
	Id: string,
	Name: string,
	Category: string,
	Description: string,
	Footprint: { X: number, Z: number }, -- grid cells
	Placeable: boolean,
	Fixed: boolean?, -- part of every plot, cannot be placed or removed
	Job: JobId?, -- creatures assigned here do this job
	Recipe: string?, -- RecipeConfig id
	Levels: { BuildingLevel },
	-- Placement price: PlaceCost * PlaceGrowth^(owned - free)
	PlaceCost: { [string]: number }?,
	PlaceGrowth: number?,
	FreeCount: number?, -- how many every plot starts with (they are pre-placed)
	Locked: string?, -- reason shown when a fixed building is not usable yet
	Phase: number,
}

export type RecipeDef = {
	Id: string,
	Name: string,
	Inputs: { [string]: number },
	Outputs: { [string]: number },
	Power: number,
	RequiresJob: JobId?,
}

export type ResourceDef = {
	Id: string,
	Name: string,
	Kind: "Currency" | "Material",
	Description: string,
	Icon: string, -- short glyph used until an image asset is configured
	Color: Color3,
	SellPrice: number?, -- Gold per unit at the Trading Post
	Image: string?, -- rbxassetid, see AssetConfig
}

export type QuestReward = {
	Gold: number?,
	Essence: number?,
	Shards: number?,
	Creature: "NextStarter" | string | nil, -- species id, or the next starter the player lacks
}

export type QuestStep = {
	Id: string,
	Title: string,
	Description: string,
	Kind: string, -- see QuestService.Evaluators
	Target: string?,
	Amount: number,
	Reward: QuestReward,
	Pointer: string?, -- building id/type the tutorial arrow points at
}

-- Saved data ---------------------------------------------------------------------------

export type CreatureRecord = {
	Id: string, -- server generated GUID
	Species: string,
	Nickname: string?,
	Level: number,
	Xp: number,
	Stage: number,
	Mutation: string?,
	Assignment: string?, -- building id
	Source: string,
	ObtainedAt: number,
	Tradable: boolean,
	WorkCycles: number, -- lifetime count, used by evolution requirements
	AbilityReadyAt: number, -- os.time when the active ability can be used again (saved so rejoining does not reset it)
}

export type BuildingRecord = {
	Id: string,
	Type: string,
	Level: number,
	X: number, -- grid cell of the footprint's minimum corner
	Z: number,
	Rot: number, -- 0..3 quarter turns
	Stored: { [string]: number },
}

export type QuestState = {
	Tutorial: number, -- index of the current tutorial step (past the end = finished)
	Progress: number, -- counter for counter-based steps
	Claimable: boolean,
}

export type Settings = {
	Music: number,
	Sfx: number,
	Vfx: "Full" | "Reduced" | "Off",
	ReducedMotion: boolean,
	CameraShake: boolean,
	FastOpen: boolean,
}

export type PlayerData = {
	Version: number,
	Currencies: { [string]: number },
	Resources: { [string]: number },
	Creatures: { [string]: CreatureRecord },
	Buildings: { [string]: BuildingRecord },
	StarterChosen: string?,
	Quests: QuestState,
	Collection: { [string]: { FirstAt: number, Count: number } },
	Settings: Settings,
	Stats: { [string]: number },
	LastOnline: number,
	Ascension: { Count: number, Shards: number },
	Receipts: { [string]: number },
}

return nil
