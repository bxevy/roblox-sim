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
	EventOnly: boolean?, -- only during a world event (the Ember Rift); it ends with the event
}

local ResourceConfig = require(script.Parent.ResourceConfig)

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
			{
				Id = "Squid",
				Text = "An Abyssquid surfaced from a deep tunnel pool and clung to your explorer!",
				Chance = 0.03,
				Creature = "Abyssquid",
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
			{
				Id = "Thunder",
				Text = "Lightning struck the rim, and a Thundermaw stepped out of the flash to follow your team!",
				Chance = 0.03,
				Creature = "Thundermaw",
				SuccessOnly = true,
			},
		},
		CoreTier = 3,
		Phase = 3,
	},
	Rift = {
		Id = "Rift",
		Name = "Ember Rift",
		Description = "A world event: a rift torn open above the basin. Every team in the server that joins makes everyone's trip safer.",
		Duration = 8 * 60, -- the event's length; teams come back when the rift closes
		Risk = "High",
		Recommended = { Exploration = 14, CombatPower = 14 },
		Rewards = {
			{ Resource = "Gold", Min = 800, Max = 1600 },
			{ Resource = "Essence", Min = 20, Max = 45 },
			{ Resource = "Emberstone", Min = 12, Max = 25 },
		},
		Xp = 250,
		Events = {
			{
				Id = "Hound",
				Text = "A Duskfang slipped out of the rift's shadow and followed your team home!",
				Chance = 0.12,
				Creature = "Duskfang",
				SuccessOnly = true,
			},
			{
				Id = "Ox",
				Text = "Something huge and dark followed the light out of the rift: a Nocturnox!",
				Chance = 0.025,
				Creature = "Nocturnox",
				SuccessOnly = true,
			},
			{
				Id = "Lark",
				Text = "A Voidlark blinked out of the rift and landed on your explorer's head!",
				Chance = 0.06,
				Creature = "Voidlark",
				SuccessOnly = true,
			},
			{
				Id = "Shade",
				Text = "A shy Shadeling hid in your team's shadow all the way home.",
				Chance = 0.2,
				Creature = "Shadeling",
				SuccessOnly = true,
			},
			{
				Id = "Shards",
				Text = "Picked up glittering rift shards.",
				Chance = 0.25,
				Reward = { RefinedCrystal = 12 },
			},
		},
		CoreTier = 2,
		Phase = 5,
		EventOnly = true,
	},
} :: { [string]: Destination }

ExpeditionConfig.Order = { "Foothills", "Tunnels", "Rim" }

-- A switched-off material (ResourceConfig Enabled = false) isn't brought home, and supplies
-- that cost it can't be packed.
local function off(resource: string): boolean
	local def = ResourceConfig[resource]
	return def ~= nil and def.Enabled == false
end
for _, destination in ExpeditionConfig.Destinations do
	local kept = {}
	for _, reward in destination.Rewards do
		if not off(reward.Resource) then
			table.insert(kept, reward)
		end
	end
	destination.Rewards = kept
	for _, event in destination.Events do
		local reward: { [string]: number } = event.Reward or {}
		for resource: string in table.clone(reward) do
			if off(resource) then
				reward[resource] = nil
			end
		end
	end
end
for id, supply in table.clone(ExpeditionConfig.Supplies) do
	for resource in supply.Cost do
		if off(resource) then
			ExpeditionConfig.Supplies[id] = nil
		end
	end
end

return ExpeditionConfig
