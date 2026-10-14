--!strict
-- The Active Team: up to Team.Size creatures that follow you around. The first one is the
-- leader (PlayerData.Companion): it's the one whose family and skills count for heat,
-- befriending, gathering and guardian fights. Team members don't work (joining the team
-- leaves a job) and must live on the plot (not in the backpack or on an expedition).
-- Pure, so the server, trades, the save repair and the tests share it.

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RarityConfig = require(Shared.Config.RarityConfig)

local Team = {}

Team.Size = 3

local function sync(data: Types.PlayerData)
	data.Companion = data.Team[1]
end

function Team.Has(data: Types.PlayerData, creatureId: string): boolean
	return table.find(data.Team, creatureId) ~= nil
end

-- Can this creature be on the team at all?
function Team.Eligible(creature: Types.CreatureRecord?): boolean
	return creature ~= nil and not creature.Stored and creature.Expedition == nil
end

-- Adds a creature (as the leader when `lead`). Returns false + reason when it can't.
function Team.Add(data: Types.PlayerData, creatureId: string, lead: boolean?): (boolean, string?)
	local creature = data.Creatures[creatureId]
	if not Team.Eligible(creature) then
		return false, "Only creatures living on your plot can join the team."
	end
	local index = table.find(data.Team, creatureId)
	if index then
		if lead and index > 1 then
			table.remove(data.Team, index)
			table.insert(data.Team, 1, creatureId)
		end
		sync(data)
		return true, nil
	end
	if #data.Team >= Team.Size then
		if not lead then
			return false, `Your team is full ({Team.Size}). Unequip one first.`
		end
		table.remove(data.Team) -- the newest leader bumps the last member
	end
	if lead then
		table.insert(data.Team, 1, creatureId)
	else
		table.insert(data.Team, creatureId)
	end
	(creature :: Types.CreatureRecord).Assignment = nil -- leaves its job to come with you
	sync(data)
	return true, nil
end

function Team.Remove(data: Types.PlayerData, creatureId: string)
	local index = table.find(data.Team, creatureId)
	if index then
		table.remove(data.Team, index)
	end
	sync(data)
end

function Team.Clear(data: Types.PlayerData)
	table.clear(data.Team)
	sync(data)
end

-- Rarest, then highest level and stage, then oldest: the strongest team you can field.
function Team.Best(data: Types.PlayerData): { string }
	local list = {}
	for id, creature in data.Creatures do
		if Team.Eligible(creature) then
			table.insert(list, id)
		end
	end
	local function rank(id: string): (number, number, number)
		local creature = data.Creatures[id]
		local species = CreatureConfig.Species[creature.Species]
		local rarity = RarityConfig.Get(species and species.Rarity or "Common").Order
		return rarity, creature.Level, creature.Stage
	end
	table.sort(list, function(a, b)
		local ra, la, sa = rank(a)
		local rb, lb, sb = rank(b)
		if ra ~= rb then
			return ra > rb
		elseif la ~= lb then
			return la > lb
		elseif sa ~= sb then
			return sa > sb
		end
		return a < b
	end)
	local best = {}
	for i = 1, math.min(Team.Size, #list) do
		best[i] = list[i]
	end
	return best
end

-- Replaces the team with these creatures (eligible ones, up to the size).
function Team.Set(data: Types.PlayerData, ids: { string })
	table.clear(data.Team)
	for _, id in ids do
		if #data.Team < Team.Size and Team.Eligible(data.Creatures[id]) and not Team.Has(data, id) then
			table.insert(data.Team, id)
			data.Creatures[id].Assignment = nil
		end
	end
	sync(data)
end

-- Save repair: drops unknown, duplicate or ineligible members and keeps the leader first.
function Team.Normalize(data: Types.PlayerData)
	local raw: { any } = if type(data.Team) == "table" then data.Team :: any else {}
	local clean = {}
	-- A save from before teams: its companion becomes the leader.
	if #raw == 0 and type(data.Companion) == "string" then
		raw = { data.Companion }
	end
	for _, id in raw do
		local creature = type(id) == "string" and data.Creatures[id] or nil
		if
			creature
			and Team.Eligible(creature)
			and creature.Assignment == nil
			and not table.find(clean, id)
			and #clean < Team.Size
		then
			table.insert(clean, id)
		end
	end
	data.Team = clean
	sync(data)
end

return Team
