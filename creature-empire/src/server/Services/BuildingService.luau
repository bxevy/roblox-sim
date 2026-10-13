--!strict
-- Placing, upgrading and collecting from buildings, plus selling at the Trading Post.
-- Everything is checked on the server: ownership (a player can only touch buildings in
-- their own profile), placement bounds and collisions, limits from the Empire Core,
-- prerequisites, cost, distance where the action is physical, and request rate.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local Grid = require(Shared.Util.Grid)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local BuildingModels = require(script.Parent.Parent.World.BuildingModels)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local ProductionService = require(script.Parent.ProductionService)

local BuildingService = {}

local footprints: { [string]: Grid.Footprint } = {}
for id, def in BuildingConfig do
	footprints[id] = def.Footprint
end

local function notify(player: Player, message: string, kind: string?)
	Remotes.Events.Notify:FireClient(player, message, kind or "Info")
end

local function countOf(data: Types.PlayerData, typeId: string): number
	local count = 0
	for _, b in data.Buildings do
		if b.Type == typeId then
			count += 1
		end
	end
	return count
end

local function coreTier(data: Types.PlayerData): number
	local core = data.Buildings.core
	return if core then core.Level else 1
end

function BuildingService.Limit(data: Types.PlayerData, typeId: string): number
	local level = BuildingConfig.EmpireCore.Levels[coreTier(data)]
	return level and level.BuildingLimits and level.BuildingLimits[typeId] or 0
end

-- The first Empire Core tier that allows at least one of a building type.
function BuildingService.UnlockTier(typeId: string): number?
	for tier, level in BuildingConfig.EmpireCore.Levels do
		if level.BuildingLimits and (level.BuildingLimits[typeId] or 0) > 0 then
			return tier
		end
	end
	return nil
end

-- How many creatures the habitat holds.
function BuildingService.CreatureCapacity(data: Types.PlayerData): number
	local habitat = data.Buildings.habitat
	local level = habitat and BuildingConfig.Habitat.Levels[habitat.Level]
	return level and level.CreatureCapacity or 6
end

-- Why a building cannot be upgraded right now (nil = it can, cost permitting).
function BuildingService.UpgradeBlocker(data: Types.PlayerData, record: Types.BuildingRecord): string?
	local def = BuildingConfig[record.Type]
	if not def then
		return "Unknown building."
	end
	if def.Locked then
		return def.Locked
	end
	local nextLevel = def.Levels[record.Level + 1]
	if not nextLevel then
		return "Fully upgraded."
	end
	if record.Type ~= "EmpireCore" and record.Level + 1 > coreTier(data) + GameConfig.MaxLevelAboveCore then
		return `Upgrade the Empire Core to tier {record.Level + 1 - GameConfig.MaxLevelAboveCore} first.`
	end
	return nil
end

-- Models ------------------------------------------------------------------------------------

local function spawnModel(player: Player, record: Types.BuildingRecord)
	local plot = PlotService.Get(player)
	if not plot or not BuildingConfig[record.Type] then
		return
	end
	local folder = plot.Folder:FindFirstChild("Buildings") :: Folder
	local old = folder:FindFirstChild(record.Id)
	if old then
		old:Destroy()
	end
	local cf = PlotService.BuildingCFrame(plot, record.Type, record.X, record.Z, record.Rot)
	local model = BuildingModels.Build(record.Type, record.Level, cf)
	model.Name = record.Id
	model:SetAttribute("BuildingId", record.Id)
	model:SetAttribute("BuildingType", record.Type)
	model:SetAttribute("Level", record.Level)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = folder
end

function BuildingService.GetModel(player: Player, buildingId: string): Model?
	local plot = PlotService.Get(player)
	local folder = plot and plot.Folder:FindFirstChild("Buildings")
	return folder and folder:FindFirstChild(buildingId) :: Model?
end

local function isNearBuilding(player: Player, buildingId: string, extra: number?): boolean
	local model = BuildingService.GetModel(player, buildingId)
	if not model or not model.PrimaryPart then
		return false
	end
	return PlotService.IsNear(player, model.PrimaryPart.Position, PlotConfig.InteractRange + (extra or 0))
end

-- Requests -----------------------------------------------------------------------------------

local function place(player: Player, typeId: string, x: number, z: number, rot: number): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local def = BuildingConfig[typeId]
	if not def or not def.Placeable or def.Phase > GameConfig.Phase then
		return false, "You can't build that yet."
	end
	local owned = countOf(data, typeId)
	local limit = BuildingService.Limit(data, typeId)
	if owned >= limit then
		return false, `Your Empire Core allows {limit} of these. Upgrade it to build more.`
	end
	local occupancy = Grid.Occupancy(data.Buildings, footprints)
	local ok, reason = Grid.CanPlace(occupancy, def.Footprint, x, z, rot, data.Expansions)
	if not ok then
		return false, reason
	end
	local cost = Formulas.PlaceCost(def, owned)
	if not EconomyService.Spend(player, cost, "Place " .. typeId) then
		return false, "You need " .. Format.Cost(cost, ResourceConfig) .. "."
	end

	local id = HttpService:GenerateGUID(false)
	local record: Types.BuildingRecord = { Id = id, Type = typeId, Level = 1, X = x, Z = z, Rot = rot, Stored = {} }
	data.Buildings[id] = record
	PlayerDataService.MarkDirty(player)
	spawnModel(player, record)
	ProductionService.Invalidate(player)
	StateService.Push(player, "Buildings")
	Remotes.Events.GameEvent:FireClient(player, "BuildingPlaced", { Id = id, Type = typeId })
	Events.BuildingChanged:Fire(player, id, "Placed")
	Log.Info("Building", "Placed", { user = player.UserId, type = typeId, x = x, z = z, rot = rot })
	return true, id
end

local function move(player: Player, buildingId: string, x: number, z: number, rot: number): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local record = data.Buildings[buildingId]
	local def = record and BuildingConfig[record.Type]
	if not record or not def then
		return false, "That building isn't yours."
	end
	if not def.Placeable then
		return false, "This building can't be moved."
	end
	local occupancy = Grid.Occupancy(data.Buildings, footprints, buildingId)
	local ok, reason = Grid.CanPlace(occupancy, def.Footprint, x, z, rot, data.Expansions)
	if not ok then
		return false, reason
	end
	ProductionService.Flush(player)
	record.X, record.Z, record.Rot = x, z, rot
	PlayerDataService.MarkDirty(player)
	spawnModel(player, record)
	StateService.Push(player, "Buildings")
	Remotes.Events.GameEvent:FireClient(player, "BuildingPlaced", { Id = buildingId, Type = record.Type, Moved = true })
	Log.Info("Building", "Moved", { user = player.UserId, type = record.Type, x = x, z = z, rot = rot })
	return true, buildingId
end

local function buyExpansion(player: Player, zoneId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local zone = PlotConfig.Zone(zoneId)
	if not zone then
		return false, "Unknown land."
	end
	if data.Expansions[zoneId] then
		return false, "You already own that land."
	end
	if coreTier(data) < zone.CoreTier then
		return false, `Upgrade the Empire Core to tier {zone.CoreTier} first.`
	end
	if not EconomyService.Spend(player, zone.Cost, "Expansion " .. zoneId) then
		return false, "You need " .. Format.Cost(zone.Cost, ResourceConfig) .. "."
	end
	data.Expansions[zoneId] = true
	PlayerDataService.MarkDirty(player)
	PlotService.RefreshBounds(player)
	StateService.Push(player, "Empire")
	Remotes.Events.GameEvent:FireClient(player, "Expanded", { Zone = zoneId })
	Log.Info("Building", "Expanded", { user = player.UserId, zone = zoneId })
	return true, zoneId
end

local function upgrade(player: Player, buildingId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local record = data.Buildings[buildingId]
	if not record then
		return false, "That building isn't yours."
	end
	local blocker = BuildingService.UpgradeBlocker(data, record)
	if blocker then
		return false, blocker
	end
	local def = BuildingConfig[record.Type]
	local nextLevel = def.Levels[record.Level + 1]
	local cost = nextLevel.Cost or {}
	ProductionService.Flush(player)
	if not EconomyService.Spend(player, cost, "Upgrade " .. record.Type) then
		return false, "You need " .. Format.Cost(cost, ResourceConfig) .. "."
	end
	record.Level += 1
	PlayerDataService.MarkDirty(player)
	spawnModel(player, record)
	ProductionService.Invalidate(player)
	StateService.Push(player, "Buildings", "Wallet", "Empire")
	Remotes.Events.GameEvent:FireClient(
		player,
		"BuildingUpgraded",
		{ Id = buildingId, Type = record.Type, Level = record.Level }
	)
	Events.BuildingChanged:Fire(player, buildingId, "Upgraded")
	Log.Info("Building", "Upgraded", { user = player.UserId, type = record.Type, level = record.Level })
	return true, record.Level
end

local function collect(player: Player, buildingId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local record = data.Buildings[buildingId]
	if not record then
		return false, "That building isn't yours."
	end
	if not isNearBuilding(player, buildingId) then
		return false, "Walk closer to collect."
	end
	ProductionService.Flush(player)
	local total = 0
	local blocked = false
	for resource, amount in record.Stored do
		local whole = math.floor(amount)
		if whole > 0 then
			local added = EconomyService.Add(player, resource, whole, "Collect")
			record.Stored[resource] = amount - added
			total += added
			if added < whole then
				blocked = true
			end
			if added > 0 then
				data.Stats.Collected = (data.Stats.Collected or 0) + added
				Events.Collected:Fire(player, resource, added)
			end
		end
	end
	if total == 0 then
		return false, if blocked then "Your Resource Silo is full. Sell or upgrade it." else "Nothing to collect yet."
	end
	if blocked then
		notify(player, "Your Resource Silo is full. Sell at the Trading Post or upgrade the silo.", "Error")
	end
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Buildings")
	Remotes.Events.GameEvent:FireClient(player, "Collected", { Id = buildingId, Amount = total })
	return true, total
end

local function sell(player: Player, resourceId: string, amount: any): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local def = ResourceConfig[resourceId]
	if not def or def.Kind ~= "Material" or not def.SellPrice then
		return false, "That can't be sold."
	end
	if not isNearBuilding(player, "trading", 12) then
		return false, "Sell at your Trading Post."
	end
	local have = EconomyService.Balance(player, resourceId)
	local quantity: number
	if amount == "All" then
		quantity = have
	elseif Net.Check.Integer(amount) and amount > 0 then
		quantity = math.min(amount, have)
	else
		return false, "Invalid amount."
	end
	quantity = math.floor(quantity)
	if quantity <= 0 then
		return false, `You have no {def.Name} to sell.`
	end
	if not EconomyService.Spend(player, { [resourceId] = quantity }, "Sell") then
		return false, "Sale failed."
	end
	local gold = quantity * def.SellPrice
	EconomyService.Add(player, "Gold", gold, "Sell " .. resourceId)
	data.Stats.Sold = (data.Stats.Sold or 0) + quantity
	Events.Sold:Fire(player, resourceId, quantity, gold)
	Remotes.Events.GameEvent:FireClient(player, "Sold", { Resource = resourceId, Amount = quantity, Gold = gold })
	return true, gold
end

-- State --------------------------------------------------------------------------------------

local function buildingsState(player: Player, profile: PlayerDataService.Profile)
	local data = profile.Data
	local list = {}
	for id, record in data.Buildings do
		local def = BuildingConfig[record.Type]
		if def then
			local rate = ProductionService.GetRate(player, id)
			local nextLevel = def.Levels[record.Level + 1]
			local workers = {}
			if rate then
				for _, worker in rate.Workers do
					table.insert(
						workers,
						{ CreatureId = worker.CreatureId, PerSecond = worker.PerSecond, CycleTime = worker.CycleTime }
					)
				end
			end
			local assigned = {}
			for creatureId, creature in data.Creatures do
				if creature.Assignment == id then
					table.insert(assigned, creatureId)
				end
			end
			list[id] = {
				Id = id,
				Type = record.Type,
				Level = record.Level,
				X = record.X,
				Z = record.Z,
				Rot = record.Rot,
				Stored = table.clone(record.Stored),
				Output = rate and rate.Output,
				Capacity = rate and rate.Capacity,
				PerSecond = rate and rate.PerSecond or 0,
				Workers = workers,
				Assigned = assigned,
				Slots = rate and rate.Slots or 0,
				Buffs = ProductionService.GetBuffs(player, id),
				Starved = ProductionService.IsStarved(player, id),
				InputsPerUnit = rate and rate.InputsPerUnit,
				Job = def.Job,
				NextCost = nextLevel and nextLevel.Cost,
				UpgradeBlocker = BuildingService.UpgradeBlocker(data, record),
			}
		end
	end
	local limits = {}
	for typeId, def in BuildingConfig do
		if def.Placeable then
			local owned = countOf(data, typeId)
			limits[typeId] = {
				Owned = owned,
				Limit = BuildingService.Limit(data, typeId),
				NextCost = Formulas.PlaceCost(def, owned),
				Available = def.Phase <= GameConfig.Phase,
				UnlockTier = BuildingService.UnlockTier(typeId),
			}
		end
	end
	return { List = list, Limits = limits }
end

function BuildingService.Start()
	StateService.Register("Buildings", buildingsState)
	StateService.Register("Empire", function(_player, profile)
		local count = 0
		for _ in profile.Data.Creatures do
			count += 1
		end
		return {
			Expansions = table.clone(profile.Data.Expansions),
			CreatureCount = count,
			CreatureCapacity = BuildingService.CreatureCapacity(profile.Data),
		}
	end)

	PlotService.OnClaimed(function(player)
		local data = PlayerDataService.GetData(player)
		if not data then
			return
		end
		for _, record in data.Buildings do
			spawnModel(player, record)
		end
	end)

	local Check = Net.Check
	Net.Handle(
		"PlaceBuilding",
		{ Rate = { 3, 1 }, Args = { Check.Id, Check.Integer, Check.Integer, Check.Integer } },
		place
	)
	Net.Handle("UpgradeBuilding", { Rate = { 3, 1 }, Args = { Check.Id } }, upgrade)
	Net.Handle(
		"MoveBuilding",
		{ Rate = { 3, 1 }, Args = { Check.Id, Check.Integer, Check.Integer, Check.Integer } },
		move
	)
	Net.Handle("BuyExpansion", { Rate = { 2, 0.5 }, Args = { Check.Id } }, buyExpansion)
	Net.Handle("Collect", { Rate = { 6, 3 }, Args = { Check.Id } }, collect)
	Net.Handle("Sell", { Rate = { 4, 2 }, Args = { Check.Id, Check.Any } }, sell)
end

return BuildingService
