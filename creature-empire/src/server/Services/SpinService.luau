--!strict
-- The Spin Wheel in the plaza: one free spin every SpinConfig.FreeEvery seconds. The
-- server picks the prize (Util/Spin, the same odds the wheel shows) and grants it before
-- the client plays the spin animation. Spins are never sold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SpinConfig = require(Shared.Config.SpinConfig)
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

function SpinService.Start()
	StateService.Register("Spin", function(_player, profile)
		local data = profile.Data
		return {
			NextFreeAt = data.Spin.NextFreeAt,
			Count = data.Spin.Count,
			Boosts = table.clone(data.Boosts),
		}
	end)
	Net.Handle("Spin", { Rate = { 3, 1 } }, spin)
end

return SpinService
