--!strict
-- Expeditions from the Expedition Portal. Launching validates the team (owned, free,
-- rested), the approach and supplies, spends the supplies and fixes a random seed; the
-- outcome is resolved from that seed when the team is claimed (Shared/Util/Expedition),
-- so nothing can be re-rolled by rejoining. Creatures are away (no work, no following)
-- until claimed, then rest before their next trip.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local ExpeditionConfig = require(Shared.Config.ExpeditionConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Research = require(Shared.Util.Research)
local WorldEvent = require(Shared.Util.WorldEvent)
local Expedition = require(Shared.Util.Expedition)
local Production = require(Shared.Util.Production)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local ProductionService = require(script.Parent.ProductionService)
local BuildingService = require(script.Parent.BuildingService)
local WorldEventService = require(script.Parent.WorldEventService)

local ExpeditionService = {}

local rng = Random.new()

local function portalSlots(data: Types.PlayerData): number
	local best = 0
	for _, building in data.Buildings do
		if building.Type == "ExpeditionPortal" then
			local level = BuildingConfig.ExpeditionPortal.Levels[building.Level]
			best = math.max(best, level and level.ExpeditionSlots or 1)
		end
	end
	return best
end

-- Portal slots in use (Ember Rift teams don't take one).
local function activeCount(data: Types.PlayerData): number
	local count = 0
	for _, record in data.Expeditions do
		if record.Party == nil then
			count += 1
		end
	end
	return count
end

local function coreTier(data: Types.PlayerData): number
	local core = data.Buildings.core
	return if core then core.Level else 1
end

local function team(data: Types.PlayerData, ids: { string }): { Expedition.Member }
	local members = {}
	for _, id in ids do
		local creature = data.Creatures[id]
		if creature then
			table.insert(members, { Species = creature.Species, Level = creature.Level, Stage = creature.Stage })
		end
	end
	return members
end

local function checkIdList(max: number): (any) -> boolean
	return function(value: any): boolean
		if type(value) ~= "table" or #value > max then
			return false
		end
		local count = 0
		for key, item in value do
			count += 1
			if type(key) ~= "number" or not Net.Check.Id(item) then
				return false
			end
		end
		return count == #value
	end
end

local function launch(
	player: Player,
	destinationId: string,
	creatureIds: { string },
	approach: string,
	supplies: { string }
): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local destination = ExpeditionConfig.Destinations[destinationId]
	if not destination or destination.Phase > GameConfig.Phase then
		return false, "Unknown destination."
	end
	if coreTier(data) < destination.CoreTier then
		return false, `Needs Empire Core tier {destination.CoreTier}.`
	end
	local slots = portalSlots(data)
	if slots == 0 then
		return false, "Build an Expedition Portal first."
	end
	-- The Ember Rift (a world event): open now, one team per player, ends with the event.
	local rift = if destination.EventOnly then WorldEventService.OpenRift() else nil
	if destination.EventOnly then
		if not rift then
			return false, "The Ember Rift isn't open right now (watch for the world event)."
		end
		for _, record in data.Expeditions do
			if record.Party == (rift :: any).Index then
				return false, "You already have a team in the rift."
			end
		end
	elseif activeCount(data) >= slots then
		return false, "All portal slots are busy. Upgrade the portal to send more teams."
	end
	if not ExpeditionConfig.Approaches[approach] then
		return false, "Pick an approach."
	end
	if #creatureIds < 1 or #creatureIds > ExpeditionConfig.MaxTeam then
		return false, `Send 1 to {ExpeditionConfig.MaxTeam} creatures.`
	end
	local now = os.time()
	local seen = {}
	for _, id in creatureIds do
		local creature = data.Creatures[id]
		if not creature or seen[id] then
			return false, "Invalid team."
		end
		seen[id] = true
		if creature.Expedition then
			return false, "One of them is already away."
		end
		if creature.RestUntil > now then
			local species = CreatureConfig.Species[creature.Species]
			return false,
				`{species and species.Name or "A creature"} is still resting ({Format.Duration(creature.RestUntil - now)}).`
		end
	end
	local cost: { [string]: number } = {}
	local chosen: { string } = {}
	for _, id in supplies do
		local supply = ExpeditionConfig.Supplies[id]
		if not supply or table.find(chosen, id) then
			return false, "Invalid supplies."
		end
		table.insert(chosen, id)
		for resource, amount in supply.Cost do
			cost[resource] = (cost[resource] or 0) + amount
		end
	end
	if next(cost) and not EconomyService.Spend(player, cost, "Expedition supplies") then
		return false, "You need " .. Format.Cost(cost, ResourceConfig) .. " for those supplies."
	end

	local id = HttpService:GenerateGUID(false)
	data.Expeditions[id] = {
		Id = id,
		Destination = destinationId,
		Creatures = table.clone(creatureIds),
		StartedAt = now,
		EndsAt = if rift
			then now + math.max(math.ceil(rift.EndsAt - Workspace:GetServerTimeNow()), 1)
			else now + destination.Duration,
		Party = if rift then rift.Index else nil,
		Approach = approach,
		Supplies = chosen,
		Seed = rng:NextInteger(1, 2 ^ 30),
		Bonus = Research.Total(data, "Expedition"),
	}
	for _, creatureId in creatureIds do
		local creature = data.Creatures[creatureId]
		creature.Expedition = id
		creature.Assignment = nil
		if data.Companion == creatureId then
			data.Companion = nil
		end
	end
	PlayerDataService.MarkDirty(player)
	if rift then
		WorldEventService.JoinRift(player)
	end
	ProductionService.Invalidate(player)
	CreatureService.RefreshAll(player)
	StateService.Push(player, "Expeditions", "Creatures", "Exploration")
	Log.Info(
		"Expedition",
		"Launched",
		{ user = player.UserId, destination = destinationId, team = #creatureIds, approach = approach }
	)
	return true, id
end

local function claim(player: Player, expeditionId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local record = data.Expeditions[expeditionId]
	if not record then
		return false, "Unknown expedition."
	end
	local now = os.time()
	if record.EndsAt > now then
		return false, `They'll be back in {Format.Duration(record.EndsAt - now)}.`
	end
	local destination = ExpeditionConfig.Destinations[record.Destination]
	-- Resolve before changing anything, from the stored seed.
	local outcome = Expedition.Resolve(
		destination,
		team(data, record.Creatures),
		record.Approach,
		record.Supplies,
		record.Seed,
		(record.Bonus or 0) + WorldEvent.RiftBonus(record.PartySize or 1)
	)
	data.Expeditions[expeditionId] = nil

	local granted: { [string]: number } = {}
	local lost = false
	for resource, amount in outcome.Rewards do
		local added = EconomyService.Add(player, resource, amount, "Expedition")
		granted[resource] = added
		lost = lost or added < amount
	end
	local joined = {}
	for _, speciesId in outcome.Creatures do
		local count = 0
		for _ in data.Creatures do
			count += 1
		end
		if count < BuildingService.CreatureCapacity(data) then
			CreatureService.Grant(player, speciesId, "Expedition", true, { Expedition = true })
			table.insert(joined, speciesId)
		else
			EconomyService.Add(player, "Gold", 500, "Expedition")
			table.insert(
				outcome.Events,
				"A creature wanted to join, but your habitat was full. It left a gift of 500 gold."
			)
		end
	end
	local rest = Expedition.RestSeconds(destination, record.Supplies)
	local xp = if outcome.Success then destination.Xp else math.floor(destination.Xp / 2)
	for _, creatureId in record.Creatures do
		local creature = data.Creatures[creatureId]
		if creature then
			creature.Expedition = nil
			creature.RestUntil = now + rest
			Production.AddXp(creature, xp)
			creature.JobCycles.Explorer = (creature.JobCycles.Explorer or 0) + math.floor(destination.Duration / 60)
		end
	end
	data.Stats.Expeditions = (data.Stats.Expeditions or 0) + 1
	PlayerDataService.MarkDirty(player)
	CreatureService.RefreshAll(player)
	ProductionService.Invalidate(player)
	StateService.Push(player, "Expeditions", "Creatures")
	Events.ExpeditionCompleted:Fire(player, record.Destination, outcome.Success)
	local result = {
		Destination = record.Destination,
		Success = outcome.Success,
		Chance = outcome.Chance,
		Rewards = granted,
		Events = outcome.Events,
		Joined = joined,
		Xp = xp,
		RestSeconds = rest,
		SiloFull = lost,
	}
	Remotes.Events.GameEvent:FireClient(player, "ExpeditionResult", result)
	Log.Info(
		"Expedition",
		"Claimed",
		{ user = player.UserId, destination = record.Destination, success = outcome.Success }
	)
	return true, result
end

-- Voidlark's Fold: running expeditions (not the rift) come back sooner. The result is
-- already fixed by the seed, so only the wait changes.
local function fold(
	player: Player,
	_creature: Types.CreatureRecord,
	power: number,
	_duration: number
): (boolean, string)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local now = os.time()
	local seconds = math.floor(power)
	local any = false
	for _, record in data.Expeditions do
		if record.Party == nil and record.EndsAt > now then
			record.EndsAt = math.max(record.EndsAt - seconds, now)
			any = true
		end
	end
	if not any then
		return false, "You have no expeditions running to fold."
	end
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Expeditions")
	return true, `Fold! Your expeditions come back {Format.Duration(seconds)} sooner.`
end

function ExpeditionService.Start()
	CreatureService.AbilityHandlers.Teleport = fold
	StateService.Register("Expeditions", function(_player, profile)
		local data = profile.Data
		local list = {}
		local now = os.time()
		for id, record in data.Expeditions do
			list[id] = {
				Id = id,
				Destination = record.Destination,
				Creatures = table.clone(record.Creatures),
				EndsIn = math.max(record.EndsAt - now, 0),
				EndsAtServer = Workspace:GetServerTimeNow() + math.max(record.EndsAt - now, 0),
				Duration = record.EndsAt - record.StartedAt,
				Approach = record.Approach,
				Supplies = table.clone(record.Supplies),
				Party = record.Party,
				PartySize = record.PartySize,
			}
		end
		return { List = list, Slots = portalSlots(data) }
	end)
	Net.Handle("LaunchExpedition", {
		Rate = { 3, 1 },
		Args = { Net.Check.Id, checkIdList(ExpeditionConfig.MaxTeam), Net.Check.Id, checkIdList(2) },
	}, launch)
	Net.Handle("ClaimExpedition", { Rate = { 4, 1 }, Args = { Net.Check.Id } }, claim)
end

return ExpeditionService
