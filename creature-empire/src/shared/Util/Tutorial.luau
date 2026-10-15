--!strict
-- The starter part of the tutorial: you meet your three starters one by one (the one you
-- chose first, then the others in CreatureConfig.Starters order, the same order the
-- "NextStarter" quest reward gives them), and for each you build its own building (the
-- one whose OnlySpecies names it), put it to work and collect its first harvest.
--
-- Steps say which starter by number (Target "1", "2", "3") and use {Starter}, {Building}
-- and {Resource} in their text; Resolve turns them into ordinary steps for one player:
--   StarterBuild  -> BuildingCount of that starter's building
--   StarterAssign -> AssignSpecies: that starter working in its building
--   StarterCollect -> Collect of the building's output
--   StarterSell    -> Sell of the building's output

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local RecipeConfig = require(Shared.Config.RecipeConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)

local Tutorial = {}

local KINDS: { [string]: string } = {
	StarterBuild = "BuildingCount",
	StarterAssign = "AssignSpecies",
	StarterCollect = "Collect",
	StarterSell = "Sell",
}

function Tutorial.IsStarterKind(kind: string): boolean
	return KINDS[kind] ~= nil
end

-- The order you meet the starters in: your choice, then the rest.
function Tutorial.StarterOrder(chosen: string?): { string }
	local order = {}
	if chosen then
		table.insert(order, chosen)
	end
	for _, id in CreatureConfig.Starters do
		if id ~= chosen then
			table.insert(order, id)
		end
	end
	return order
end

-- The building only this species works at.
function Tutorial.BuildingFor(speciesId: string): string?
	for typeId, def in BuildingConfig do
		if def.OnlySpecies and table.find(def.OnlySpecies, speciesId) then
			return typeId
		end
	end
	return nil
end

-- What a building makes (its recipe's first output).
function Tutorial.OutputOf(typeId: string): string?
	local def = BuildingConfig[typeId]
	local recipe = def and def.Recipe and RecipeConfig[def.Recipe]
	if recipe then
		for resource in recipe.Outputs do
			return resource
		end
	end
	return nil
end

local function fill(text: string, words: { [string]: string }): string
	return (string.gsub(text, "{(%a+)}", function(key)
		return words[key]
	end))
end

-- A copy of the step for a player whose first starter is `chosen` (nil before choosing).
function Tutorial.Resolve(step: Types.QuestStep, chosen: string?): Types.QuestStep
	local kind = KINDS[step.Kind]
	if not kind then
		return step
	end
	local copy = table.clone(step) :: any
	local n = tonumber(step.Target) or 1
	local speciesId = if chosen then Tutorial.StarterOrder(chosen)[n] else nil
	local typeId = speciesId and Tutorial.BuildingFor(speciesId)
	local output = typeId and Tutorial.OutputOf(typeId)
	local words = {
		Starter = if speciesId then CreatureConfig.Species[speciesId].Name else "your starter",
		Building = if typeId then BuildingConfig[typeId].Name else "its building",
		Resource = if output and ResourceConfig[output] then ResourceConfig[output].Name else "harvest",
	}
	copy.Title = fill(step.Title, words)
	copy.Description = fill(step.Description, words)
	if not (speciesId and typeId and output) then
		copy.Kind = "Waiting" -- before a starter is chosen (never complete)
		copy.Pointer = nil
		return copy
	end
	copy.Kind = kind
	copy.Species = speciesId
	copy.Target = if kind == "BuildingCount" or kind == "AssignSpecies" then typeId else output
	if step.Pointer == "{Building}" then
		copy.Pointer = typeId
	end
	if step.Kit then
		copy.KitFor = typeId
	end
	return copy
end

-- Inputs to get a building's first harvest going (the smelter needs raw crystal before
-- its own supplier exists): enough for about 12 cycles.
function Tutorial.Kit(typeId: string): { [string]: number }
	local def = BuildingConfig[typeId]
	local recipe = def and def.Recipe and RecipeConfig[def.Recipe]
	local kit = {}
	if recipe then
		for resource, amount in recipe.Inputs do
			kit[resource] = amount * 12
		end
	end
	return kit
end

return Tutorial
