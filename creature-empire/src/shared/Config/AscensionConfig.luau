--!strict
-- Ascension: an optional fresh start that makes the next run faster.
--
-- What resets: Gold, Essence, silo materials, every building (back to the
-- starting layout), land expansions and research.
-- What stays: every creature (levels, stages, mutations), your collection, discoveries,
-- guardian records, quests, eggs' pity, settings and Ascension perks.
--
-- Shards earned = floor(ShardBase * sqrt(gold earned this run / ShardGoldUnit)), at least
-- MinShards. The amount is shown before you confirm.

export type Perk = {
	Id: string,
	Name: string,
	Description: string, -- per rank
	MaxRank: number,
	Cost: number, -- Empire Shards per rank (rank n costs Cost * n)
	Kind: string, -- "StartGold" | "Modifier" | "Silo" | "Offline"
	Stat: string?,
	Value: number,
}

local AscensionConfig = {}

AscensionConfig.RequiredCoreTier = 5
AscensionConfig.ShardBase = 10
AscensionConfig.ShardGoldUnit = 100000
AscensionConfig.MinShards = 10
-- Every Ascension adds this much yield (bonus category "Ascension").
AscensionConfig.YieldPerAscension = 0.1
-- Granted the first time you ascend.
AscensionConfig.FirstAscensionCreature = "Titanicore"

AscensionConfig.Perks = {
	GoldenStart = {
		Id = "GoldenStart",
		Name = "Golden Start",
		Description = "Begin each run with 2,000 more gold.",
		MaxRank = 5,
		Cost = 5,
		Kind = "StartGold",
		Value = 2000,
	},
	SwiftPaws = {
		Id = "SwiftPaws",
		Name = "Swift Paws",
		Description = "Every creature works 5% faster.",
		MaxRank = 5,
		Cost = 8,
		Kind = "Modifier",
		Stat = "WorkSpeed",
		Value = 0.05,
	},
	Bountiful = {
		Id = "Bountiful",
		Name = "Bountiful",
		Description = "Every creature yields 5% more.",
		MaxRank = 5,
		Cost = 8,
		Kind = "Modifier",
		Stat = "Yield",
		Value = 0.05,
	},
	DeepSilos = {
		Id = "DeepSilos",
		Name = "Deep Silos",
		Description = "Your silo holds 20% more.",
		MaxRank = 3,
		Cost = 6,
		Kind = "Silo",
		Value = 0.2,
	},
	LongNaps = {
		Id = "LongNaps",
		Name = "Long Naps",
		Description = "Offline production lasts 1 hour longer.",
		MaxRank = 2,
		Cost = 10,
		Kind = "Offline",
		Value = 60 * 60,
	},
} :: { [string]: Perk }

AscensionConfig.PerkOrder = { "GoldenStart", "SwiftPaws", "Bountiful", "DeepSilos", "LongNaps" }

return AscensionConfig
