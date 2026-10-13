--!strict
-- Evolves creatures. Requirements come from CreatureConfig and are checked with
-- Shared/Util/Evolution (the same checklist the client shows). Costs (Essence and
-- materials) are taken only when every requirement is met.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local Evolution = require(Shared.Util.Evolution)
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

local EvolutionService = {}

local function hasChamber(data: Types.PlayerData): boolean
	for _, building in data.Buildings do
		if building.Type == "EvolutionChamber" then
			return true
		end
	end
	return false
end

local function evolve(player: Player, creatureId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local creature = data.Creatures[creatureId]
	if not creature then
		return false, "That creature isn't yours."
	end
	if not hasChamber(data) then
		return false, "Build an Evolution Chamber first."
	end
	ProductionService.Flush(player)
	local check = Evolution.Check(data, creature)
	if not check.NextStage then
		return false, "It's already in its final form."
	end
	if not check.Ready then
		return false, "Not all requirements are met yet."
	end
	local cost = Evolution.Cost(check)
	if next(cost) and not EconomyService.Spend(player, cost, "Evolve") then
		return false, "Not enough resources."
	end

	local from = creature.Stage
	creature.Stage = check.NextStage.Stage
	data.Stats.Evolved = (data.Stats.Evolved or 0) + 1
	PlayerDataService.MarkDirty(player)
	-- A new stage can change job skill; drop the assignment if it no longer fits.
	local species = CreatureConfig.Species[creature.Species]
	local building = creature.Assignment and data.Buildings[creature.Assignment]
	local def = building and BuildingConfig[building.Type]
	if species and def and def.Job and CreatureConfig.Affinity(species, creature.Stage, def.Job) <= 0 then
		creature.Assignment = nil
	end
	local entry = data.Collection[creature.Species]
	if entry then
		entry.BestStage = math.max(entry.BestStage or 1, creature.Stage)
	end
	CreatureService.RefreshAnchor(player, creature)
	ProductionService.Invalidate(player)
	StateService.Push(player, "Creatures", "Collection")
	Remotes.Events.GameEvent:FireClient(player, "CreatureEvolved", {
		Id = creatureId,
		Species = creature.Species,
		Stage = creature.Stage,
		Name = check.NextStage.Name,
		Unlocks = check.NextStage.Unlocks,
	})
	Events.Evolved:Fire(player, creatureId, creature.Stage)
	Log.Info(
		"Evolution",
		"Evolved",
		{ user = player.UserId, species = species and species.Id, from = from, to = creature.Stage }
	)
	return true, creature.Stage
end

function EvolutionService.Start()
	Net.Handle("Evolve", { Rate = { 3, 1 }, Args = { Net.Check.Id } }, evolve)
end

return EvolutionService
