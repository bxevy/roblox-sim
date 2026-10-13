--!strict
-- The only place currencies and materials change. Every change is validated (finite,
-- non-negative, capped) and spending is all-or-nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local Research = require(Shared.Util.Research)
local Leaderboard = require(Shared.Util.Leaderboard)

local Core = script.Parent.Parent.Core
local Log = require(Core.Log)
local Events = require(Core.Events)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)

local EconomyService = {}

local function validAmount(amount: number): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

local function sectionFor(id: string): ("Currencies" | "Resources")?
	local def = ResourceConfig[id]
	if not def then
		return nil
	end
	return if def.Kind == "Currency" then "Currencies" else "Resources"
end

-- Storage capacity for a material, from the Resource Silo's level. Currencies have none.
function EconomyService.Capacity(player: Player, id: string): number
	local data = PlayerDataService.GetData(player)
	if not data or sectionFor(id) ~= "Resources" then
		return EconomyConfig.MaxBalance
	end
	local resource = ResourceConfig[id]
	if resource.Kind == "Item" then
		return resource.MaxStack or 99
	end
	local capacity = 0
	for _, building in data.Buildings do
		local def = BuildingConfig[building.Type]
		local level = def and def.Levels[building.Level]
		if level and level.Capacity and level.Capacity[id] then
			capacity += level.Capacity[id]
		end
	end
	return math.floor(capacity * Research.SiloMultiplier(data))
end

function EconomyService.Balance(player: Player, id: string): number
	local data = PlayerDataService.GetData(player)
	local section = sectionFor(id)
	if not data or not section then
		return 0
	end
	return (data :: any)[section][id] or 0
end

-- Adds up to `amount` (whole units), respecting storage capacity. Returns amount added.
function EconomyService.Add(player: Player, id: string, amount: number, reason: string): number
	local data = PlayerDataService.GetData(player)
	local section = sectionFor(id)
	if not data or not section or not validAmount(amount) then
		Log.Warn("Economy", "Add rejected", { user = player.UserId, id = id, amount = amount, reason = reason })
		return 0
	end
	amount = math.floor(amount)
	local bucket = (data :: any)[section]
	local current = bucket[id] or 0
	local cap = math.min(EconomyService.Capacity(player, id), EconomyConfig.MaxBalance)
	local added = math.clamp(amount, 0, math.max(cap - current, 0))
	if added <= 0 then
		return 0
	end
	bucket[id] = current + added
	if section == "Currencies" then
		Events.CurrencyEarned:Fire(player, id, added, reason)
		if id == "Gold" then
			data.Stats.GoldEarned = (data.Stats.GoldEarned or 0) + added
			data.Ascension.RunGold = (data.Ascension.RunGold or 0) + added
			-- Weekly leaderboard: a new week starts a new count.
			local week = Leaderboard.Week(os.time())
			if data.Season.Week ~= week then
				data.Season.Week = week
				data.Season.Gold = 0
			end
			data.Season.Gold += added
		end
	end
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Wallet")
	Log.Debug("Economy", "Add", { user = player.UserId, id = id, amount = added, reason = reason })
	return added
end

function EconomyService.CanAfford(player: Player, cost: { [string]: number }): boolean
	for id, amount in cost do
		if not validAmount(amount) or EconomyService.Balance(player, id) < amount then
			return false
		end
	end
	return true
end

-- Spends the whole cost or nothing. Returns success.
function EconomyService.Spend(player: Player, cost: { [string]: number }, reason: string): boolean
	local data = PlayerDataService.GetData(player)
	if not data or not EconomyService.CanAfford(player, cost) then
		return false
	end
	for id in cost do
		if not sectionFor(id) then
			return false
		end
	end
	for id, amount in cost do
		local bucket = (data :: any)[sectionFor(id) :: any]
		bucket[id] = math.max((bucket[id] or 0) - amount, 0)
	end
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Wallet")
	Log.Debug("Economy", "Spend", { user = player.UserId, reason = reason })
	return true
end

function EconomyService.Start()
	StateService.Register("Wallet", function(player, profile)
		local capacity = {}
		for id, def in ResourceConfig do
			if def.Kind == "Material" or def.Kind == "Item" then
				capacity[id] = EconomyService.Capacity(player, id)
			end
		end
		return {
			Currencies = table.clone(profile.Data.Currencies),
			Resources = table.clone(profile.Data.Resources),
			Capacity = capacity,
		}
	end)
end

return EconomyService
