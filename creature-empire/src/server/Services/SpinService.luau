--!strict
-- The Spin Wheel in the plaza: one free spin every SpinConfig.FreeEvery seconds. The
-- server picks the prize (Util/Spin, the same odds the wheel shows) and grants it before
-- the client plays the spin animation. Extra spins can be bought for Robux
-- (MonetizationConfig.PaidSpin) only where PolicyService allows paid random items; the
-- purchase itself is granted by MonetizationService through SpinService.PaidSpin.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SpinConfig = require(Shared.Config.SpinConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local PlazaConfig = require(Shared.Config.PlazaConfig)
local Spin = require(Shared.Util.Spin)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local PlotService = require(script.Parent.PlotService)

local SpinService = {}

local rng = Random.new()

-- Whether each player may be offered paid random items (cached; unknown = not allowed).
local paidAllowed: { [Player]: boolean } = {}

local function checkPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not player.Parent then
		return
	end
	paidAllowed[player] = ok and info ~= nil and info.ArePaidRandomItemsRestricted == false
	StateService.Push(player, "Spin")
end

-- Shown and sold only when the product exists and the player's region allows it.
local function canBuy(player: Player): boolean
	return MonetizationConfig.PaidSpin.Id ~= 0 and paidAllowed[player] == true
end

local function grant(player: Player, prize: SpinConfig.Prize): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end
	if prize.Kind == "Currency" and prize.Currency and prize.Amount then
		EconomyService.Add(player, prize.Currency, prize.Amount, "Spin")
	elseif prize.Kind == "Boost" and prize.Boost then
		local now = os.time()
		data.Boosts[prize.Boost] = Spin.Extend(data.Boosts[prize.Boost] or 0, now)
		PlayerDataService.MarkDirty(player)
	elseif prize.Kind == "Creature" and prize.Species then
		-- The reveal waits for the wheel to stop on the client.
		local record =
			CreatureService.Grant(player, prize.Species, "Spin", true, { Delay = SpinConfig.AnimationSeconds })
		if not record then
			return false
		end
		-- Everyone hears about a Black Dragon.
		for _, other in Players:GetPlayers() do
			if other ~= player then
				Remotes.Events.Notify:FireClient(
					other,
					`{player.DisplayName} won the {prize.Name} on the Spin Wheel!`,
					"Reward"
				)
			end
		end
	end
	return true
end

local function spin(player: Player): (boolean, any)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Your empire is still loading."
	end
	local now = os.time()
	local wait = Spin.FreeIn(data.Spin.NextFreeAt, now)
	if wait > 0 then
		return false, `Your next free spin is ready in {Format.Duration(wait)}.`
	end
	if not PlotService.IsNear(player, PlazaConfig.Position("SpinWheel"), PlazaConfig.Range) then
		return false, "Spin at the Spin Wheel in the plaza."
	end
	local index = Spin.Roll(function()
		return rng:NextNumber()
	end)
	local prize = SpinConfig.Prizes[index]
	-- Use the spin first so a failed grant can never be retried for a better prize.
	data.Spin.NextFreeAt = now + SpinConfig.FreeEvery
	data.Spin.Count += 1
	PlayerDataService.MarkDirty(player)
	if not grant(player, prize) then
		-- Should never happen (prizes come from config); give the spin back.
		data.Spin.NextFreeAt = now
		return false, "Something went wrong. Your spin was given back."
	end
	StateService.Push(player, "Spin")
	Log.Info("Spin", "Spun", { user = player.UserId, prize = prize.Id })
	return true, { Index = index, Prize = prize.Id }
end

-- A bought spin (called by MonetizationService when the purchase arrives). Rolls and grants
-- right away; the client is told which slice to turn to. Returns false if it couldn't
-- grant (the purchase is then retried by Roblox).
function SpinService.PaidSpin(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end
	local index = Spin.Roll(function()
		return rng:NextNumber()
	end)
	local prize = SpinConfig.Prizes[index]
	if not grant(player, prize) then
		return false
	end
	data.Spin.Count += 1
	data.Stats.PaidSpins = (data.Stats.PaidSpins or 0) + 1
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Spin")
	Remotes.Events.GameEvent:FireClient(player, "SpinResult", { Index = index, Prize = prize.Id, Paid = true })
	Log.Info("Spin", "Paid spin", { user = player.UserId, prize = prize.Id })
	return true
end

local function buySpin(player: Player): (boolean, any)
	if not canBuy(player) then
		return false, "Extra spins aren't available."
	end
	MarketplaceService:PromptProductPurchase(player, MonetizationConfig.PaidSpin.Id)
	return true, nil
end

function SpinService.Start()
	StateService.Register("Spin", function(_player, profile)
		local data = profile.Data
		return {
			NextFreeAt = data.Spin.NextFreeAt,
			Count = data.Spin.Count,
			Boosts = table.clone(data.Boosts),
			CanBuy = canBuy(_player),
			Price = MonetizationConfig.PaidSpin.Price,
		}
	end)
	Net.Handle("Spin", { Rate = { 3, 1 } }, spin)
	Net.Handle("BuySpin", { Rate = { 3, 1 } }, buySpin)
	PlayerDataService.Loaded:Connect(function(player)
		task.spawn(checkPolicy, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		paidAllowed[player] = nil
	end)
end

return SpinService
