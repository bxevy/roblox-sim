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
	-- Implemented: "InstantHarvest", "SpeedBurst", "GoldFind" and "Collect" (CreatureService).
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
	StatBonus: number, -- added to WorkSpeed and Yield (bonus category "Stage")
	AbilityMultiplier: number, -- active ability Power and Duration multiplier
	Affinity: { [string]: number }?, -- job skill overrides at this stage
	Features: { string }?, -- extra model features at this stage
	-- Kinds: Level, WorkCycles (Target = job), Essence, Resource (Target = resource id).
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
	-- Habitat
	CreatureCapacity: number?,
	-- Expedition Portal
	ExpeditionSlots: number?,
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
	OnlySpecies: { string }?, -- only these species can work here (Util/WorkRules)
	AnyCreature: boolean?, -- every creature can work here (Util/WorkRules)
	RequiresResearch: string?, -- ResearchConfig node needed before it can be placed
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
	Kind: "Currency" | "Material" | "Item",
	Description: string,
	Icon: string, -- short glyph used until an image asset is configured
	Color: Color3,
	SellPrice: number?, -- Gold per unit at the Trading Post
	MaxStack: number?, -- items: how many you can carry (materials use silo capacity)
	Image: string?, -- rbxassetid, see AssetConfig
	-- false: out of the game for now (not earned, not asked for, not shown); saved
	-- amounts are kept for when it comes back.
	Enabled: boolean?,
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
	Region: string?, -- needs this region: skipped while it's switched off
	Kit: boolean?, -- starter steps: grant the building's first inputs when claimed (Util/Tutorial)
	-- Filled in by Util/Tutorial.Resolve for one player:
	Species: string?,
	KitFor: string?,
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
	WorkCycles: number, -- lifetime count
	JobCycles: { [string]: number }, -- work cycles per job, used by evolution requirements
	Expedition: string?, -- id of the expedition it's on (can't work or follow meanwhile)
	Stored: boolean?, -- in the backpack (Util/Housing): not on the plot, can't work or follow
	RestUntil: number, -- os.time when it can go on another expedition
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
	Collection: { [string]: { FirstAt: number, Count: number, BestStage: number? } },
	Settings: Settings,
	Stats: { [string]: number },
	LastOnline: number,
	Ascension: AscensionRecord,
	Research: { [string]: number }, -- research node id -> os.time completed (this run)
	Collaborators: { [string]: boolean }, -- user ids (as strings) allowed to help on this plot
	WorldEvents: { [string]: number }, -- event id -> times completed (Grand Bloom wins)
	Season: { Week: number, Gold: number }, -- gold earned this week (weekly leaderboard)
	MutationCharm: number, -- Nocturnox's Dark Gift: mutation chance multiplier for the next hatch (0 = none)
	BoostUntil: number, -- os.time a purchased production boost lasts until (0 = none)
	Spin: { NextFreeAt: number, Count: number }, -- Spin Wheel: when the next free spin is ready
	Boosts: { [string]: number }, -- Spin Wheel boost id ("Coins" | "Luck") -> os.time it lasts until
	Receipts: { [string]: number },
	Pity: { [string]: number }, -- egg id -> hatches since the last Rare-or-better
	Expansions: { [string]: boolean }, -- purchased expansion zone ids
	Companion: string?, -- the team leader (Team[1]): its skills count in the wild
	Team: { string }, -- the Active Team (Util/Team): up to 3 creatures following you
	Expeditions: { [string]: ExpeditionRecord },
	Discoveries: { [string]: number }, -- landmark id -> os.time discovered
	Guardians: { [string]: { Defeats: number, LastRewardAt: number } },
}

export type AscensionRecord = {
	Count: number,
	Shards: number, -- lifetime shards earned
	Perks: { [string]: number }, -- perk id -> rank
	RunGold: number, -- gold earned since the last Ascension (sets the shard payout)
}

export type ExpeditionRecord = {
	Id: string,
	Destination: string,
	Creatures: { string },
	StartedAt: number,
	EndsAt: number,
	Approach: string,
	Supplies: { string },
	Seed: number,
	Bonus: number?, -- research chance bonus fixed at launch
	Party: number?, -- world event index for Ember Rift teams
	PartySize: number?, -- teams in the rift when it closed (set by the server at the end)
}

return nil
