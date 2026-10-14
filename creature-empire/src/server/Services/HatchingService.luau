--!strict
-- Egg hatching at the Hatchery nest in the plaza. Costs are in-game resources only. Odds and the pity rule
-- live in Shared/Util/Hatching (the same code the Hatchery panel uses to publish them),
-- and the server does every roll.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local EggConfig = require(Shared.Config.EggConfig)
local GameConfig = require(Shared.Config.GameConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Hatching = require(Shared.Util.Hatching)
local Format = require(Shared.Util.Format)
local PlazaConfig = require(Shared.Config.PlazaConfig)
local Spin = require(Shared.Util.Spin)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local BuildingService = require(script.Parent.BuildingService)
local CreatureService = require(script.Parent.CreatureService)
local PlotService = require(script.Parent.PlotService)

local HatchingService = {}

local rng = Random.new()

local function creatureCount(data: Types.PlayerData): number
	local count = 0
	for _ in data.Creatures do
		count += 1
	end
	return count
end

local function hatch(player: Player, eggId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local egg = EggConfig.Eggs[eggId]
	if not egg or egg.Phase > GameConfig.Phase then
		return false, "Unknown egg."
	end
	if not PlotService.IsNear(player, PlazaConfig.Position("Hatchery"), PlazaConfig.Range) then
		return false, "Hatch eggs at the Hatchery in the plaza."
	end
	if creatureCount(data) >= BuildingService.CreatureCapacity(data) then
		return false, "Your habitats and backpack are full. Build another Creature Habitat to make room."
	end
	if not EconomyService.Spend(player, egg.Cost, "Hatch " .. eggId) then
		return false, "You need " .. Format.Cost(egg.Cost, ResourceConfig) .. "."
	end

	local pity = data.Pity[eggId] or 0
	-- The Spin Wheel's 2x Luck makes rare-or-better creatures twice as likely.
	local luck = Spin.Multiplier(data.Boosts, "Luck", os.time())
	local speciesId, guaranteed, newPity = Hatching.Roll(egg, pity, function()
		return rng:NextNumber()
	end, luck)
	data.Pity[eggId] = newPity
	data.Stats.Hatched = (data.Stats.Hatched or 0) + 1
	PlayerDataService.MarkDirty(player)

	local record = CreatureService.Grant(player, speciesId, "Egg", true, { Egg = eggId, Pity = guaranteed })
	if not record then
		-- Should never happen (species come from config); refund rather than lose the cost.
		for id, amount in egg.Cost do
			EconomyService.Add(player, id, amount, "Refund")
		end
		data.Pity[eggId] = pity
		return false, "Something went wrong. You were refunded."
	end
	Events.Hatched:Fire(player, eggId, speciesId)
	StateService.Push(player, "Hatchery", "Empire")
	Log.Info(
		"Hatching",
		"Hatched",
		{ user = player.UserId, egg = eggId, species = speciesId, pity = pity, guaranteed = guaranteed, luck = luck }
	)
	return true, { CreatureId = record.Id, Species = speciesId, Pity = newPity }
end

function HatchingService.Start()
	StateService.Register("Hatchery", function(_player, profile)
		return { Pity = table.clone(profile.Data.Pity), Charm = profile.Data.MutationCharm }
	end)
	Net.Handle("HatchEgg", { Rate = { 3, 1 }, Args = { Net.Check.Id } }, hatch)
end

return HatchingService
