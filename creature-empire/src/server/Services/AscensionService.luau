--!strict
-- Ascension: the optional fresh start (AscensionConfig, Shared/Util/Ascension). The reset
-- itself is a pure function on saved data; this service checks the request, applies it,
-- rebuilds the plot and saves straight away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AscensionConfig = require(Shared.Config.AscensionConfig)
local Ascension = require(Shared.Util.Ascension)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local ProductionService = require(script.Parent.ProductionService)
local BuildingService = require(script.Parent.BuildingService)
local CreatureService = require(script.Parent.CreatureService)
local PlotService = require(script.Parent.PlotService)

local AscensionService = {}

local busy: { [Player]: boolean } = {}

local function ascend(player: Player): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	if busy[player] then
		return false, "Already ascending."
	end
	local ok, reason = Ascension.Check(data)
	if not ok then
		return false, reason
	end
	busy[player] = true
	ProductionService.Flush(player)
	local count = data.Ascension.Count + 1
	local shards = Ascension.Apply(data, os.time())
	PlayerDataService.MarkDirty(player)

	-- Rebuild the world around the reset data. The data is already reset, so a failure
	-- here is logged and the rest still runs (a rejoin rebuilds everything from data).
	local steps: { () -> () } = {
		function()
			ProductionService.Reset(player)
		end,
		function()
			BuildingService.RebuildAll(player)
		end,
		function()
			PlotService.RefreshBounds(player)
		end,
		function()
			CreatureService.RefreshAll(player)
		end,
		function()
			-- Back to the plot: regions need Empire Core tiers you no longer have.
			PlotService.SendHome(player)
		end,
		function()
			if count == 1 then
				CreatureService.Grant(player, AscensionConfig.FirstAscensionCreature, "Ascension", false)
			end
		end,
	}
	for index, step in steps do
		local stepOk, err = pcall(function()
			step()
			return true
		end)
		if not stepOk then
			Log.Warn("Ascension", "Rebuild step failed", { user = player.UserId, step = index, error = tostring(err) })
		end
	end
	StateService.Push(
		player,
		"Wallet",
		"Buildings",
		"Creatures",
		"Empire",
		"Research",
		"Ascension",
		"Quests",
		"Expeditions"
	)
	Events.Ascended:Fire(player, count)
	Remotes.Events.GameEvent:FireClient(player, "Ascended", { Count = count, Shards = shards })
	Log.Info("Ascension", "Ascended", { user = player.UserId, count = count, shards = shards })
	PlayerDataService.SaveNow(player)
	busy[player] = nil
	return true, shards
end

local function buyPerk(player: Player, perkId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local perk = AscensionConfig.Perks[perkId]
	if not perk then
		return false, "Unknown perk."
	end
	local cost = Ascension.PerkCost(data, perkId)
	if not cost then
		return false, "That perk is maxed out."
	end
	ProductionService.Flush(player)
	if not EconomyService.Spend(player, { EmpireShards = cost }, "Perk " .. perkId) then
		return false, `You need {cost} Empire Shards.`
	end
	data.Ascension.Perks[perkId] = (data.Ascension.Perks[perkId] or 0) + 1
	PlayerDataService.MarkDirty(player)
	ProductionService.Invalidate(player)
	StateService.Push(player, "Ascension", "Wallet")
	Log.Info("Ascension", "Perk", { user = player.UserId, perk = perkId, rank = data.Ascension.Perks[perkId] })
	return true, data.Ascension.Perks[perkId]
end

function AscensionService.Start()
	StateService.Register("Ascension", function(_player, profile)
		local data = profile.Data
		local can, reason = Ascension.Check(data)
		return {
			Count = data.Ascension.Count,
			Earned = data.Ascension.Shards,
			Perks = table.clone(data.Ascension.Perks),
			RunGold = data.Ascension.RunGold,
			Payout = Ascension.Shards(data),
			CanAscend = can,
			Reason = reason,
		}
	end)
	-- The payout grows with gold earned; refresh it now and then rather than on every coin.
	Events.CurrencyEarned:Connect(function(player, id)
		if id == "Gold" then
			StateService.Push(player, "Ascension")
		end
	end)
	Net.Handle("Ascend", { Rate = { 1, 0.1 }, Args = {} }, ascend)
	Net.Handle("BuyPerk", { Rate = { 4, 1 }, Args = { Net.Check.Id } }, buyPerk)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return AscensionService
