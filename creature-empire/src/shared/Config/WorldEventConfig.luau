--!strict
-- Server-wide events on a fixed schedule from the shared server clock, so every client can
-- show the same timer. One event every Period seconds, rotating through Rotation.
--
--   GoldenHour  every production building in the server works faster
--   Bloom       a cooperative goal: everyone's Moonpetal collecting adds up; reach the
--               goal together and every helper is rewarded
--   EmberRift   a cooperative expedition: everyone may send a team through the rift; each
--               extra participant raises everyone's success chance

export type Event = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number,
	Color: Color3,
	Glyph: string,
}

local WorldEventConfig = {}

WorldEventConfig.Period = 15 * 60
WorldEventConfig.Rotation = { "GoldenHour", "Bloom", "EmberRift" }

WorldEventConfig.Events = {
	GoldenHour = {
		Id = "GoldenHour",
		Name = "Golden Hour",
		Description = "Every creature in the server works 25% faster.",
		Duration = 5 * 60,
		Color = Color3.fromRGB(255, 205, 90),
		Glyph = "☀",
	},
	Bloom = {
		Id = "Bloom",
		Name = "Grand Bloom",
		Description = "Collect Moonpetals together! Reach the server goal and every helper is rewarded.",
		Duration = 7 * 60,
		Color = Color3.fromRGB(150, 200, 255),
		Glyph = "✿",
	},
	EmberRift = {
		Id = "EmberRift",
		Name = "Ember Rift",
		Description = "A rift opens! Send a team from your Expedition Portal. Every extra team in the server makes everyone's trip safer.",
		Duration = 8 * 60,
		Color = Color3.fromRGB(255, 120, 60),
		Glyph = "✸",
	},
} :: { [string]: Event }

WorldEventConfig.GoldenHour = { Stat = "WorkSpeed", Value = 0.25 } -- bonus category "Boost"

WorldEventConfig.Bloom = {
	GoalPerPlayer = 200, -- moonpetals per player in the server when it starts
	MinGoal = 200,
	MinContribution = 10, -- to count as a helper
	Reward = { Gold = 1500, Essence = 25 } :: { [string]: number },
	FirstWinCreature = "Elderbark", -- joins after your first successful Grand Bloom
}

WorldEventConfig.Rift = {
	Destination = "Rift", -- ExpeditionConfig destination
	JoinCutoff = 60, -- teams can join until this many seconds before the end
	BonusPerParticipant = 0.06, -- success chance per extra team
	MaxBonus = 0.3,
}

return WorldEventConfig
