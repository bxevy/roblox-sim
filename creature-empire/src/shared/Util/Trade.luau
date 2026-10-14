--!strict
-- Trade validation and the swap itself, as pure functions on two players' saved data, so
-- the rules are unit-tested and the server commits a trade in one step with no yields.

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local SocialConfig = require(Shared.Config.SocialConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Housing = require(script.Parent.Housing)

export type Offer = { Creatures: { string }, Resources: { [string]: number } }
-- Limits of the receiving player (from their buildings).
export type Limits = { CreatureCapacity: number, Capacity: (resource: string) -> number }

local Trade = {}

function Trade.Empty(): Offer
	return { Creatures = {}, Resources = {} }
end

-- Shape check for an offer sent by a client. Returns a clean copy or nil.
function Trade.Clean(raw: any): Offer?
	if type(raw) ~= "table" or type(raw.Creatures) ~= "table" or type(raw.Resources) ~= "table" then
		return nil
	end
	local offer = Trade.Empty()
	local seen = {}
	for key, id in raw.Creatures do
		if type(key) ~= "number" or type(id) ~= "string" or #id > 64 or seen[id] then
			return nil
		end
		seen[id] = true
		table.insert(offer.Creatures, id)
	end
	if #offer.Creatures > SocialConfig.Trade.MaxCreatures then
		return nil
	end
	for id, amount in raw.Resources do
		if
			type(id) ~= "string"
			or not table.find(SocialConfig.Trade.Resources, id)
			or type(amount) ~= "number"
			or amount ~= amount
			or amount < 0
			or amount > 1e12
			or amount % 1 ~= 0
		then
			return nil
		end
		if amount > 0 then
			offer.Resources[id] = amount
		end
	end
	return offer
end

local function balance(data: Types.PlayerData, id: string): number
	local def = ResourceConfig[id]
	if def and def.Kind == "Currency" then
		return data.Currencies[id] or 0
	end
	return data.Resources[id] or 0
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Can `from` give `offer`? (ownership, tradability, availability)
function Trade.CanGive(data: Types.PlayerData, offer: Offer): (boolean, string?)
	for _, id in offer.Creatures do
		local creature = data.Creatures[id]
		if not creature then
			return false, "A creature in the offer is no longer there."
		end
		local name = CreatureConfig.Species[creature.Species] and CreatureConfig.Species[creature.Species].Name
			or creature.Species
		if not creature.Tradable then
			return false, `{name} can't be traded (starter, quest and gift creatures stay with you).`
		end
		if creature.Expedition then
			return false, `{name} is away on an expedition.`
		end
		if data.Companion == id or (type(data.Team) == "table" and table.find(data.Team, id) ~= nil) then
			return false, `{name} is on your Active Team. Unequip it first.`
		end
	end
	for id, amount in offer.Resources do
		if balance(data, id) < amount then
			return false, `Not enough {ResourceConfig[id].Name}.`
		end
	end
	return true, nil
end

-- Can `to` receive `incoming` while giving away `outgoing`?
function Trade.CanReceive(data: Types.PlayerData, incoming: Offer, outgoing: Offer, limits: Limits): (boolean, string?)
	local creatures = count(data.Creatures) - #outgoing.Creatures + #incoming.Creatures
	if #incoming.Creatures > 0 and creatures > limits.CreatureCapacity then
		return false, "Not enough room in the habitat for those creatures."
	end
	for id, amount in incoming.Resources do
		local def = ResourceConfig[id]
		if def.Kind ~= "Currency" then
			local after = balance(data, id) - (outgoing.Resources[id] or 0) + amount
			if after > limits.Capacity(id) then
				return false, `Not enough silo room for {def.Name}.`
			end
		end
	end
	return true, nil
end

function Trade.IsEmpty(offer: Offer): boolean
	return #offer.Creatures == 0 and next(offer.Resources) == nil
end

-- Full check for both sides.
function Trade.Validate(
	dataA: Types.PlayerData,
	offerA: Offer,
	limitsA: Limits,
	dataB: Types.PlayerData,
	offerB: Offer,
	limitsB: Limits
): (boolean, string?)
	if Trade.IsEmpty(offerA) and Trade.IsEmpty(offerB) then
		return false, "Both offers are empty."
	end
	local ok, reason = Trade.CanGive(dataA, offerA)
	if not ok then
		return false, reason
	end
	ok, reason = Trade.CanGive(dataB, offerB)
	if not ok then
		return false, reason
	end
	ok, reason = Trade.CanReceive(dataB, offerA, offerB, limitsB)
	if not ok then
		return false, reason
	end
	ok, reason = Trade.CanReceive(dataA, offerB, offerA, limitsA)
	if not ok then
		return false, reason
	end
	return true, nil
end

local function move(fromData: Types.PlayerData, toData: Types.PlayerData, offer: Offer, now: number)
	for _, id in offer.Creatures do
		local creature = fromData.Creatures[id]
		fromData.Creatures[id] = nil
		creature.Assignment = nil
		creature.Stored = nil -- moves in on the plot if there's room (Housing.Fit after)
		toData.Creatures[id] = creature
		local entry = toData.Collection[creature.Species]
		if entry then
			entry.Count += 1
			entry.BestStage = math.max(entry.BestStage or 1, creature.Stage)
		else
			toData.Collection[creature.Species] = { FirstAt = now, Count = 1, BestStage = creature.Stage }
		end
	end
	for id, amount in offer.Resources do
		local section = if ResourceConfig[id].Kind == "Currency" then "Currencies" else "Resources"
		local fromBucket = (fromData :: any)[section]
		local toBucket = (toData :: any)[section]
		fromBucket[id] = (fromBucket[id] or 0) - amount
		toBucket[id] = (toBucket[id] or 0) + amount
	end
end

-- Swaps both offers. Call Validate first (in the same step, with no yields between).
function Trade.Apply(dataA: Types.PlayerData, offerA: Offer, dataB: Types.PlayerData, offerB: Offer, now: number)
	move(dataA, dataB, offerA, now)
	move(dataB, dataA, offerB, now)
	-- New arrivals live on the plot while the habitats have room; the rest wait in the backpack.
	Housing.Fit(dataA)
	Housing.Fit(dataB)
	dataA.Stats.Trades = (dataA.Stats.Trades or 0) + 1
	dataB.Stats.Trades = (dataB.Stats.Trades or 0) + 1
end

return Trade
