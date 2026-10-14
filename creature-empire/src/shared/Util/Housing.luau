--!strict
-- Where creatures live. Each Creature Habitat on the plot houses HabitatSize creatures;
-- any more wait in the backpack (BackpackSize), where they don't show on the plot, work,
-- follow you or go on expeditions until you take them out. Pure, so the server, the save
-- repair and the tests share it.

local Shared = script.Parent.Parent
local Types = require(Shared.Types)

local Housing = {}

Housing.HabitatSize = 5 -- creatures per Creature Habitat
Housing.BackpackSize = 40 -- creatures the backpack holds

function Housing.Habitats(buildings: { [string]: Types.BuildingRecord }): number
	local count = 0
	for _, record in buildings do
		if record.Type == "Habitat" then
			count += 1
		end
	end
	return count
end

-- How many creatures can live on the plot.
function Housing.PlotCapacity(buildings: { [string]: Types.BuildingRecord }): number
	return Housing.Habitats(buildings) * Housing.HabitatSize
end

-- Every creature you can keep: habitats plus backpack.
function Housing.TotalCapacity(buildings: { [string]: Types.BuildingRecord }): number
	return Housing.PlotCapacity(buildings) + Housing.BackpackSize
end

-- Creatures on the plot (including ones away on expeditions) and in the backpack.
function Housing.Counts(data: Types.PlayerData): (number, number)
	local plot, backpack = 0, 0
	for _, creature in data.Creatures do
		if creature.Stored then
			backpack += 1
		else
			plot += 1
		end
	end
	return plot, backpack
end

-- Is there room on the plot for one more creature?
function Housing.PlotHasRoom(data: Types.PlayerData): boolean
	local plot = Housing.Counts(data)
	return plot < Housing.PlotCapacity(data.Buildings)
end

-- Puts a creature in the backpack: it stops working and following.
function Housing.Store(data: Types.PlayerData, creatureId: string)
	local creature = data.Creatures[creatureId]
	if not creature then
		return
	end
	creature.Stored = true
	creature.Assignment = nil
	-- Off the Active Team (Util/Team keeps the leader in PlayerData.Companion).
	local team = data.Team
	if type(team) == "table" then
		local index = table.find(team, creatureId)
		if index then
			table.remove(team, index)
		end
		data.Companion = team[1]
	elseif data.Companion == creatureId then
		data.Companion = nil
	end
end

-- When more creatures live on the plot than the habitats hold (after an Ascension resets
-- the buildings, or a trade), moves the extras to the backpack: idle ones first, then the
-- lowest level. Creatures away on expeditions stay put. Returns the ids moved.
function Housing.Fit(data: Types.PlayerData): { string }
	local capacity = Housing.PlotCapacity(data.Buildings)
	local plot = Housing.Counts(data)
	local moved = {}
	if plot <= capacity then
		return moved
	end
	local candidates = {}
	for id, creature in data.Creatures do
		if not creature.Stored and not creature.Expedition then
			table.insert(candidates, creature)
		end
	end
	local function busy(creature: Types.CreatureRecord): number
		local onTeam = data.Companion == creature.Id
			or (type(data.Team) == "table" and table.find(data.Team, creature.Id) ~= nil)
		return if creature.Assignment ~= nil or onTeam then 1 else 0
	end
	table.sort(candidates, function(a, b)
		if busy(a) ~= busy(b) then
			return busy(a) < busy(b)
		end
		if a.Level ~= b.Level then
			return a.Level < b.Level
		end
		return a.Id < b.Id
	end)
	for _, creature in candidates do
		if plot <= capacity then
			break
		end
		Housing.Store(data, creature.Id)
		table.insert(moved, creature.Id)
		plot -= 1
	end
	return moved
end

return Housing
