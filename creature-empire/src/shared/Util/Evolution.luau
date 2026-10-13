--!strict
-- Evolution requirements, checked the same way by the server (to allow an evolution) and
-- the client (to show a checklist). Pure: reads saved data only.

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local JobConfig = require(Shared.Config.JobConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)

export type RequirementStatus = {
	Kind: string,
	Target: string?,
	Amount: number,
	Have: number,
	Met: boolean,
	Label: string,
	Cost: boolean, -- consumed when evolving
}

export type Check = {
	NextStage: Types.EvolutionStage?,
	Requirements: { RequirementStatus },
	Ready: boolean,
}

local Evolution = {}

local function have(data: any, creature: Types.CreatureRecord, kind: string, target: string?): (number?, boolean)
	if kind == "Level" then
		return creature.Level, false
	elseif kind == "WorkCycles" then
		local cycles = creature.JobCycles or {}
		return if target then cycles[target] or 0 else creature.WorkCycles, false
	elseif kind == "Essence" then
		return data.Currencies.Essence or 0, true
	elseif kind == "Resource" and target then
		return data.Resources[target] or data.Currencies[target] or 0, true
	end
	return nil, false -- requirement kinds from later updates
end

local function label(kind: string, target: string?, amount: number): string
	if kind == "Level" then
		return `Reach level {amount}`
	elseif kind == "WorkCycles" then
		local job = target and JobConfig[target]
		return `Work {amount} cycles as a {job and job.Name or target or "worker"}`
	elseif kind == "Essence" then
		return `{amount} Essence`
	elseif kind == "Resource" then
		local def = target and ResourceConfig[target]
		return `{amount} {def and def.Name or target}`
	end
	return `{kind} ×{amount} (arrives in a later update)`
end

function Evolution.Check(data: any, creature: Types.CreatureRecord): Check
	local species = CreatureConfig.Species[creature.Species]
	local nextStage = species and species.Evolution[creature.Stage + 1]
	if not nextStage then
		return { NextStage = nil, Requirements = {}, Ready = false }
	end
	local list: { RequirementStatus } = {}
	local ready = true
	local requirements: { { Kind: string, Target: string?, Amount: number } } = nextStage.Requirements or {}
	for _, requirement in requirements do
		local amount, isCost = have(data, creature, requirement.Kind, requirement.Target)
		local met = amount ~= nil and amount >= requirement.Amount
		ready = ready and met
		table.insert(list, {
			Kind = requirement.Kind,
			Target = requirement.Target,
			Amount = requirement.Amount,
			Have = math.floor(amount or 0),
			Met = met,
			Label = label(requirement.Kind, requirement.Target, requirement.Amount),
			Cost = isCost,
		})
	end
	return { NextStage = nextStage, Requirements = list, Ready = ready }
end

-- What evolving costs: { Essence = n, RefinedCrystal = n, ... }.
function Evolution.Cost(check: Check): { [string]: number }
	local cost = {}
	for _, requirement in check.Requirements do
		if requirement.Cost then
			local id = if requirement.Kind == "Essence" then "Essence" else requirement.Target :: string
			cost[id] = (cost[id] or 0) + requirement.Amount
		end
	end
	return cost
end

return Evolution
