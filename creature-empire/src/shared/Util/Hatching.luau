--!strict
-- Egg odds and rolls. Pure (the random number source is passed in) so the published odds,
-- the pity rule and the server's rolls are the same code, and tests can check them.

local Shared = script.Parent.Parent
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local EggConfig = require(Shared.Config.EggConfig)

export type Odds = { Species: string, Rarity: string, Chance: number }

local Hatching = {}

local function rarityOrder(speciesId: string): number
	local species = CreatureConfig.Species[speciesId]
	return RarityConfig.Get(species and species.Rarity or "Common").Order
end

-- Whether a species counts for the egg's pity guarantee.
function Hatching.IsPityTier(egg: EggConfig.Egg, speciesId: string): boolean
	return rarityOrder(speciesId) >= RarityConfig.Get(egg.PityRarity).Order
end

-- Exact chances (0..1), rarest first. With `guaranteed` = true: the pity-hatch odds.
-- `luck` (default 1) multiplies the weight of every pity-tier (rare or better) creature;
-- the Spin Wheel's 2x Luck sets it to 2.
function Hatching.Odds(egg: EggConfig.Egg, guaranteed: boolean?, luck: number?): { Odds }
	local function weight(entry: EggConfig.LootEntry): number
		return if Hatching.IsPityTier(egg, entry.Species) then entry.Weight * (luck or 1) else entry.Weight
	end
	local total = 0
	for _, entry in egg.Loot do
		if not guaranteed or Hatching.IsPityTier(egg, entry.Species) then
			total += weight(entry)
		end
	end
	local list: { Odds } = {}
	for _, entry in egg.Loot do
		if not guaranteed or Hatching.IsPityTier(egg, entry.Species) then
			local species = CreatureConfig.Species[entry.Species]
			table.insert(list, {
				Species = entry.Species,
				Rarity = (if species then species.Rarity else "Common") :: string,
				Chance = weight(entry) / total,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Chance ~= b.Chance then
			return a.Chance < b.Chance
		end
		return a.Species < b.Species
	end)
	return list
end

-- Is the next hatch guaranteed by pity?
function Hatching.PityReady(egg: EggConfig.Egg, pity: number): boolean
	return pity + 1 >= egg.PityLimit
end

-- Rolls a hatch. `random` returns a number in [0, 1). Returns the species, whether pity
-- decided it, and the new pity counter.
function Hatching.Roll(egg: EggConfig.Egg, pity: number, random: () -> number, luck: number?): (string, boolean, number)
	local guaranteed = Hatching.PityReady(egg, pity)
	local odds = Hatching.Odds(egg, guaranteed, luck)
	local roll = random()
	local cumulative = 0
	local chosen = odds[#odds].Species
	for _, entry in odds do
		cumulative += entry.Chance
		if roll < cumulative then
			chosen = entry.Species
			break
		end
	end
	local newPity = if Hatching.IsPityTier(egg, chosen) then 0 else pity + 1
	return chosen, guaranteed, newPity
end

return Hatching
