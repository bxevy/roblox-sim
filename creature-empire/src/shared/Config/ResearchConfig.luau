--!strict
-- The research tree, unlocked at the Research Station. Researchers turn Moonpetals into
-- Essence; Essence (plus some gold or materials) buys research. Every node has a real,
-- capped effect (bonus category "Research", see EconomyConfig.BonusRules) or unlocks
-- something specific. Research resets on Ascension.
--
-- Effect kinds:
--   Modifier   { Stat = "WorkSpeed" | "Yield", Value, Job? }  production bonus
--   Silo       { Value }    +Value share of silo capacity
--   Offline    { Value }    +Value seconds of offline production
--   Expedition { Value }    +Value expedition success chance
--   Heat       { Value }    heat builds Value share slower in hot regions
--   Mutation   { Value }    mutation chance multiplier bonus (+1 = double)
--   Synergy    { Value }    synergy bonuses are Value share stronger
--   Unlock     { Target }   a building type id that needs this research

local ResourceConfig = require(script.Parent.ResourceConfig)

export type Effect = {
	Kind: string,
	Stat: string?,
	Job: string?,
	Value: number?,
	Target: string?,
}
export type Node = {
	Id: string,
	Name: string,
	Description: string,
	Branch: "Production" | "Logistics" | "Exploration" | "Arcane",
	Tier: number, -- column in the tree (1..3)
	Cost: { [string]: number },
	Requires: { string },
	Effects: { Effect },
	Phase: number,
}

local ResearchConfig = {}

ResearchConfig.Branches = { "Production", "Logistics", "Exploration", "Arcane" }

local nodes: { Node } = {
	-- Production
	{
		Id = "FertileSoil",
		Name = "Fertile Soil",
		Description = "Farms yield 10% more.",
		Branch = "Production",
		Tier = 1,
		Cost = { Essence = 20, Gold = 1000 },
		Requires = {},
		Effects = { { Kind = "Modifier", Stat = "Yield", Value = 0.1, Job = "Farmer" } },
		Phase = 4,
	},
	{
		Id = "SharpPicks",
		Name = "Sharp Picks",
		Description = "Miners and smelters work 10% faster.",
		Branch = "Production",
		Tier = 2,
		Cost = { Essence = 60, Gold = 4000 },
		Requires = { "FertileSoil" },
		Effects = {
			{ Kind = "Modifier", Stat = "WorkSpeed", Value = 0.1, Job = "Miner" },
			{ Kind = "Modifier", Stat = "WorkSpeed", Value = 0.1, Job = "Smelter" },
		},
		Phase = 4,
	},
	{
		Id = "Distillation",
		Name = "Distillation",
		Description = "Alchemists and researchers yield 15% more.",
		Branch = "Production",
		Tier = 3,
		Cost = { Essence = 250 },
		Requires = { "SharpPicks" },
		Effects = {
			{ Kind = "Modifier", Stat = "Yield", Value = 0.15, Job = "Alchemist" },
			{ Kind = "Modifier", Stat = "Yield", Value = 0.15, Job = "Researcher" },
		},
		Phase = 4,
	},
	-- Logistics
	{
		Id = "Couriers",
		Name = "Courier Routes",
		Description = "Unlocks the Courier Post: creatures carry harvests to your silo on their own.",
		Branch = "Logistics",
		Tier = 1,
		Cost = { Essence = 30, Gold = 2500 },
		Requires = {},
		Effects = { { Kind = "Unlock", Target = "CourierPost" } },
		Phase = 4,
	},
	{
		Id = "SiloRacks",
		Name = "Silo Racks",
		Description = "Your silo holds 25% more of every material.",
		Branch = "Logistics",
		Tier = 2,
		Cost = { Essence = 50, Gold = 5000 },
		Requires = { "Couriers" },
		Effects = { { Kind = "Silo", Value = 0.25 } },
		Phase = 4,
	},
	{
		Id = "NightShift",
		Name = "Night Shift",
		Description = "Offline production lasts 2 hours longer.",
		Branch = "Logistics",
		Tier = 3,
		Cost = { Essence = 120, Gold = 15000 },
		Requires = { "SiloRacks" },
		Effects = { { Kind = "Offline", Value = 2 * 60 * 60 } },
		Phase = 4,
	},
	-- Exploration
	{
		Id = "HeatWards",
		Name = "Heat Wards",
		Description = "Heat builds 20% slower in hot regions.",
		Branch = "Exploration",
		Tier = 1,
		Cost = { Essence = 25, Emberstone = 15 },
		Requires = {},
		Effects = { { Kind = "Heat", Value = 0.2 } },
		Phase = 4,
	},
	{
		Id = "FieldKits",
		Name = "Field Kits",
		Description = "+5% success chance on every expedition.",
		Branch = "Exploration",
		Tier = 2,
		Cost = { Essence = 70, Emberstone = 30 },
		Requires = { "HeatWards" },
		Effects = { { Kind = "Expedition", Value = 0.05 } },
		Phase = 4,
	},
	-- Arcane
	{
		Id = "Harmony",
		Name = "Harmony Studies",
		Description = "Synergy bonuses are 50% stronger (still capped).",
		Branch = "Arcane",
		Tier = 1,
		Cost = { Essence = 80 },
		Requires = {},
		Effects = { { Kind = "Synergy", Value = 0.5 } },
		Phase = 4,
	},
	{
		Id = "MutationTheory",
		Name = "Mutation Theory",
		Description = "Mutations are twice as likely when hatching, befriending or evolving.",
		Branch = "Arcane",
		Tier = 2,
		Cost = { Essence = 250 },
		Requires = { "Harmony" },
		Effects = { { Kind = "Mutation", Value = 1 } },
		Phase = 4,
	},
}

ResearchConfig.Nodes = {} :: { [string]: Node }
ResearchConfig.Order = {} :: { string }
for _, node in nodes do
	-- A switched-off material isn't asked for.
	for resource in table.clone(node.Cost) do
		local def = ResourceConfig[resource]
		if def and def.Enabled == false then
			node.Cost[resource] = nil
		end
	end
	ResearchConfig.Nodes[node.Id] = node
	table.insert(ResearchConfig.Order, node.Id)
end

return ResearchConfig
