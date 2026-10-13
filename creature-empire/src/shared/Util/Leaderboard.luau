--!strict
-- Leaderboard scores from saved data (whole numbers, see LeaderboardConfig).

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local BuildingConfig = require(Shared.Config.BuildingConfig)

local Leaderboard = {}

local WEEK = 7 * 24 * 60 * 60
local MONDAY_OFFSET = 4 * 24 * 60 * 60 -- the Unix epoch was a Thursday

-- Week number (weeks start Monday 00:00 UTC).
function Leaderboard.Week(unixTime: number): number
	return math.floor((unixTime - MONDAY_OFFSET) / WEEK)
end

function Leaderboard.Score(boardId: string, data: Types.PlayerData, unixTime: number): number
	if boardId == "Empire" then
		local core = data.Buildings.core
		local score = (core and core.Level or 1) * 1000
		for _, building in data.Buildings do
			local def = BuildingConfig[building.Type]
			if def and def.Placeable then
				score += building.Level * 50
			end
		end
		for _, creature in data.Creatures do
			score += creature.Level * 5 + (creature.Stage - 1) * 100
		end
		score += (data.Ascension and data.Ascension.Count or 0) * 5000
		return math.floor(score)
	elseif boardId == "Collection" then
		local count = 0
		for _ in data.Collection do
			count += 1
		end
		return count
	elseif boardId == "Explorers" then
		local score = data.Stats.Expeditions or 0
		for _ in data.Discoveries do
			score += 1
		end
		for _, record in data.Guardians do
			score += record.Defeats
		end
		return math.floor(score)
	elseif boardId == "WeeklyGold" then
		local season = data.Season
		if season and season.Week == Leaderboard.Week(unixTime) then
			return math.floor(season.Gold)
		end
		return 0
	end
	return 0
end

return Leaderboard
