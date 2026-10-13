--!strict
-- Expedition maths. The success chance is shown before launch; the outcome is resolved
-- from the seed stored at launch, so it's fixed the moment the team leaves.

local Shared = script.Parent.Parent
local CreatureConfig = require(Shared.Config.CreatureConfig)
local ExpeditionConfig = require(Shared.Config.ExpeditionConfig)
local Stats = require(script.Parent.Stats)
local Rng = require(script.Parent.Rng)

export type Member = { Species: string, Level: number, Stage: number }
export type Outcome = {
	Success: boolean,
	Chance: number,
	Rewards: { [string]: number },
	Events: { string },
	Creatures: { string }, -- species that joined
}

local Expedition = {}

-- How well the team matches the recommended stats: 1 = exactly recommended.
function Expedition.Score(destination: ExpeditionConfig.Destination, team: { Member }): number
	if #team == 0 then
		return 0
	end
	local total, count = 0, 0
	for stat, recommended in destination.Recommended do
		local sum = 0
		for _, member in team do
			local species = CreatureConfig.Species[member.Species]
			if species then
				sum += Stats.Effective(species, member.Level, member.Stage, stat)
			end
		end
		-- Team average, plus a little for every extra member.
		local average = sum / #team * (1 + 0.1 * (#team - 1))
		total += math.min(average / recommended, 1.5)
		count += 1
	end
	return if count > 0 then total / count else 1
end

function Expedition.Chance(
	destination: ExpeditionConfig.Destination,
	team: { Member },
	approach: string,
	supplies: { string }
): number
	local chance = 0.15 + 0.6 * Expedition.Score(destination, team)
	local a = ExpeditionConfig.Approaches[approach]
	chance += if a then a.Chance else 0
	for _, id in supplies do
		local supply = ExpeditionConfig.Supplies[id]
		chance += supply and supply.Chance or 0
	end
	return math.clamp(chance, 0.05, 0.97)
end

function Expedition.Resolve(
	destination: ExpeditionConfig.Destination,
	team: { Member },
	approach: string,
	supplies: { string },
	seed: number
): Outcome
	local rng = Rng.new(seed)
	local chance = Expedition.Chance(destination, team, approach, supplies)
	local success = rng:Next() < chance
	local a = ExpeditionConfig.Approaches[approach]
	local multiplier = (if a then a.Rewards else 1) * (if success then 1 else ExpeditionConfig.FailureRewardShare)
	local rewards: { [string]: number } = {}
	for _, reward in destination.Rewards do
		local amount = math.floor(rng:Int(reward.Min, reward.Max) * multiplier)
		if amount > 0 then
			rewards[reward.Resource] = (rewards[reward.Resource] or 0) + amount
		end
	end
	local events, creatures = {}, {}
	for _, event in destination.Events do
		local roll = rng:Next() -- always rolled, so later events don't depend on earlier ones
		if roll < event.Chance and (success or not event.SuccessOnly) then
			table.insert(events, event.Text)
			local eventReward: { [string]: number } = event.Reward or {}
			for resource, amount in eventReward do
				rewards[resource] = (rewards[resource] or 0) + amount
			end
			if event.Creature then
				table.insert(creatures, event.Creature)
			end
		end
	end
	if not success then
		table.insert(events, 1, "The team had to turn back early.")
	end
	return { Success = success, Chance = chance, Rewards = rewards, Events = events, Creatures = creatures }
end

function Expedition.RestSeconds(destination: ExpeditionConfig.Destination, supplies: { string }): number
	for _, id in supplies do
		local supply = ExpeditionConfig.Supplies[id]
		if supply and supply.NoRest then
			return 0
		end
	end
	return math.floor(destination.Duration * ExpeditionConfig.RestFraction)
end

return Expedition
