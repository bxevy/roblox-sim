--!strict
-- Mutation rolls. Deterministic for a given seed string (creature id + event), so a roll
-- can be checked in tests and can't be re-rolled by retrying.

local Shared = script.Parent.Parent
local CreatureConfig = require(Shared.Config.CreatureConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local Rng = require(script.Parent.Rng)

local Mutation = {}

-- A small, stable string hash (djb2) for seeding.
function Mutation.Hash(text: string): number
	local hash = 5381
	for i = 1, #text do
		hash = (hash * 33 + string.byte(text, i)) % 2147483647
	end
	return hash
end

-- The species' possible mutations with their chances (after the multiplier), rarest last.
function Mutation.Odds(speciesId: string, multiplier: number): { { Id: string, Chance: number } }
	local species = CreatureConfig.Species[speciesId]
	local odds = {}
	local ids: { string } = if species then species.Mutations else {}
	for _, id in ids do
		local def = MutationConfig.Mutations[id]
		if def then
			table.insert(odds, { Id = id, Chance = def.Chance * multiplier })
		end
	end
	table.sort(odds, function(a, b)
		return a.Chance > b.Chance
	end)
	return odds
end

-- Returns a mutation id or nil. `multiplier` comes from research (1 = base chances).
function Mutation.Roll(speciesId: string, seed: string, multiplier: number): string?
	local rng = Rng.new(Mutation.Hash(seed))
	rng:Next() -- the first value follows the seed too closely
	local roll = rng:Next()
	local cumulative = 0
	for _, entry in Mutation.Odds(speciesId, multiplier) do
		cumulative += entry.Chance
		if roll < cumulative then
			return entry.Id
		end
	end
	return nil
end

-- Production bonus for a mutated creature.
function Mutation.Bonuses(mutation: string?): { { Stat: string, Category: string, Value: number } }
	local def = mutation and MutationConfig.Mutations[mutation]
	if not def then
		return {}
	end
	local bonuses: { { Stat: string, Category: string, Value: number } } = {}
	for _, bonus in def.Bonuses do
		table.insert(bonuses, { Stat = bonus.Stat :: string, Category = "Mutation", Value = bonus.Value })
	end
	return bonuses
end

return Mutation
