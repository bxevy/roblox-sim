--!strict
-- Expedition destinations, approaches and supplies. Success depends on the team's stats
-- against the recommended ones (Shared/Util/Expedition), the chosen approach and supplies,
-- so preparation matters more than luck. Outcomes are rolled from a seed fixed when the
-- team leaves, so rejoining never re-rolls a result.

export type Reward = { Resource: string, Min: number, Max: number }
export type Event = {
	Id: string,
	Text: string,
	Chance: number, -- 0..1 per expedition
	Reward: { [string]: number }?,
	Creature: string?, -- befriends this species (needs habitat room)
	SuccessOnly: boolean?,
}
export type Destination = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number, -- seconds
	Risk: "Low" | "Medium" | "High",
	Recommended: { [string]: number }, -- effective stat per creature (team average)
	Rewards: { Reward },
	Xp: number, -- per creature on success (half on failure)
	Events: { Event },
	CoreTier: number,
	Phase: number,
}

local ExpeditionConfig = {}

ExpeditionConfig.MaxTeam = 3
ExpeditionConfig.RestFraction = 0.5 -- creatures rest for this share of the expedition's length
ExpeditionConfig.FailureRewardShare = 0.25

ExpeditionConfig.Approaches =
	{
		Cautious = {
			Id = "Cautious",
			Name = "Cautious",
			Description = "Safer, but you bring back less.",
			Chance = 0.15,
			Rewards = 0.8,
		},
		Balanced = { Id = "Balanced", Name = "Balanced", Description = "No changes.", Chance = 0, Rewards = 1 },
		Bold = {
			Id = "Bold",
			Name = "Bold",
			Description = "Riskier, but far more loot if it works.",
			Chance = -0.15,
			Rewards = 1.4,
		},
	} :: { [string]: { Id: string, Name: string, Description: string, Chance: number, Rewards: number } }

ExpeditionConfig.Supplies = {
	HeatShield = {
		Id = "HeatShield",
		Name = "Heat Shield",
		Description = "+10% success chance.",
		Cost = { Emberstone = 6 },
		Chance = 0.1,
	},
	Rations = {
		Id = "Rations",
		Name = "Rations",
		Description = "Creatures don't need to rest afterwards.",
		Cost = { Moonpetal = 25 },
		NoRest = true,
	},
} :: {
	[string]: {
		Id: string,
		Name: string,
		Description: string,
		Cost: { [string]: number },
		Chance: number?,
		NoRest: boolean?,
	},
}

ExpeditionConfig.Destinations = {
	Foothills = {
		Id = "Foothills",
		Name = "Ashen Foothills",
		Description = "Warm slopes at the edge of the basin. A gentle first trip.",
		Duration = 5 * 60,
		Risk = "Low",
		Recommended = { Exploration = 10 },
		Rewards = {
			{ Resource = "Gold", Min = 300, Max = 600 },
			{ Resource = "Emberstone", Min = 4, Max = 8 },
		},
		Xp = 40,
		Events = {
			{
				Id = "Cache",
				Text = "Found an old miner's cache.",
				Chance = 0.25,
				Reward = { Gold = 250 },
				SuccessOnly = true,
			},
			{
				Id = "Petals",
				Text = "Picked wild moonpetals on the way home.",
				Chance = 0.3,
				Reward = { Moonpetal = 20 },
			},
			{
				Id = "Stray",
				Text = "A curious Cindercub followed the team home!",
				Chance = 0.05,
				Creature = "Cindercub",
				SuccessOnly = true,
			},
		},
		CoreTier = 2,
		Phase = 3,
	},
	Tunnels = {
		Id = "Tunnels",
		Name = "Magma Tunnels",
		Description = "Hot tunnels under the basin, full of crystal and grumpy wildlife.",
		Duration = 15 * 60,
		Risk = "Medium",
		Recommended = { Exploration = 12, CombatPower = 12 },
		Rewards = {
			{ Resource = "Gold", Min = 1000, Max = 2000 },
			{ Resource = "Emberstone", Min = 12, Max = 22 },
			{ Resource = "RawCrystal", Min = 20, Max = 40 },
		},
		Xp = 120,
		Events = {
			{
				Id = "Vein",
				Text = "Struck a rich crystal vein.",
				Chance = 0.25,
				Reward = { RawCrystal = 30 },
				SuccessOnly = true,
			},
			{
				Id = "Ambush",
				Text = "Ashwhisks ambushed the team, but they scared them off.",
				Chance = 0.3,
				Reward = { Gold = 200 },
			},
			{
				Id = "Magmaul",
				Text = "A young Magmaul trapped in cooling rock was rescued and joined you!",
				Chance = 0.06,
				Creature = "Magmaul",
				SuccessOnly = true,
			},
		},
		CoreTier = 2,
		Phase = 3,
	},
	Rim = {
		Id = "Rim",
		Name = "Caldera Rim",
		Description = "The dangerous rim above the guardian's lair. Legends speak of a phoenix nest.",
		Duration = 45 * 60,
		Risk = "High",
		Recommended = { Exploration = 14, CombatPower = 14, Luck = 12 },
		Rewards = {
			{ Resource = "Essence", Min = 40, Max = 80 },
			{ Resource = "RefinedCrystal", Min = 8, Max = 16 },
			{ Resource = "Emberstone", Min = 20, Max = 35 },
		},
		Xp = 400,
		Events = {
			{
				Id = "Relic",
				Text = "Uncovered an ancient ember relic.",
				Chance = 0.2,
				Reward = { Essence = 40, Gold = 1500 },
				SuccessOnly = true,
			},
			{
				Id = "Nest",
				Text = "Found a Pyrewing nest! A chick hatched and imprinted on your team.",
				Chance = 0.04,
				Creature = "Pyrewing",
				SuccessOnly = true,
			},
			{ Id = "Storm", Text = "An ash storm forced the team to shelter for a while.", Chance = 0.3 },
		},
		CoreTier = 3,
		Phase = 3,
	},
} :: { [string]: Destination }

ExpeditionConfig.Order = { "Foothills", "Tunnels", "Rim" }

return ExpeditionConfig
