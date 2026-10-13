--!strict
-- Client entry point: starts controllers, builds the interface and wires them together.
-- The server owns all game state; the client displays it and sends requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)
local ResourceConfig = require(Shared.Config.ResourceConfig)

local Controllers = script.Parent:WaitForChild("Controllers")
local UIFolder = script.Parent:WaitForChild("UI")

local StateController = require(Controllers.StateController)
local AudioController = require(Controllers.AudioController)
local EffectsController = require(Controllers.EffectsController)
local UIController = require(Controllers.UIController)
local CreatureController = require(Controllers.CreatureController)
local BuildingController = require(Controllers.BuildingController)
local PlacementController = require(Controllers.PlacementController)
local TutorialController = require(Controllers.TutorialController)
local InputController = require(Controllers.InputController)
local RegionController = require(Controllers.RegionController)
local GuardianController = require(Controllers.GuardianController)

StateController.Start()
AudioController.Start()
EffectsController.Start()
UIController.Start({
	State = StateController,
	Audio = AudioController,
	Effects = EffectsController,
	Creature = CreatureController,
	Building = BuildingController,
	Placement = PlacementController,
	UI = UIController,
	Region = RegionController,
	Guardian = GuardianController,
})
local ctx = UIController.Context()

-- Interface ------------------------------------------------------------------------------
require(UIFolder.Hud).new(ctx)
UIController.Register("Creatures", require(UIFolder.CreaturesWindow).new(ctx))
UIController.Register("Building", require(UIFolder.BuildingPanel).new(ctx))
UIController.Register("Build", require(UIFolder.BuildMenu).new(ctx))
UIController.Register("Settings", require(UIFolder.SettingsWindow).new(ctx))
UIController.Register("Quests", require(UIFolder.QuestJournal).new(ctx))
UIController.Register("Inspect", require(UIFolder.InspectWindow).new(ctx))
UIController.Register("Inventory", require(UIFolder.InventoryWindow).new(ctx))
UIController.Register("Befriend", require(UIFolder.BefriendWindow).new(ctx))
UIController.Register("Map", require(UIFolder.MapWindow).new(ctx))
UIController.Register("ExpeditionResult", require(UIFolder.ExpeditionResultWindow).new(ctx))
UIController.Register("Ascension", require(UIFolder.AscensionWindow).new(ctx))
local starter = require(UIFolder.StarterSelect).new(ctx)
UIController.Register("Starter", starter)
local reveal = require(UIFolder.RevealOverlay).new(ctx)

-- World controllers ------------------------------------------------------------------------
BuildingController.OpenPanel = function(buildingId)
	UIController.Open("Building", buildingId)
end
BuildingController.OpenInspect = function(ownerUserId)
	UIController.Open("Inspect", ownerUserId)
end
BuildingController.Notify = UIController.Notify
RegionController.Notify = UIController.Notify
GuardianController.Notify = UIController.Notify
CreatureController.OnBefriend = function(wildId, speciesId)
	UIController.Open("Befriend", { WildId = wildId, Species = speciesId })
end

CreatureController.Start()
BuildingController.Start()
PlacementController.Start()
TutorialController.Start()
RegionController.Start()
GuardianController.Start()
InputController.Start(UIController, PlacementController)

-- First-time flow: pick a starter (modal until chosen).
StateController.OnChanged("Creatures", function(creatures)
	if creatures.StarterChosen then
		if UIController.IsOpen("Starter") then
			starter.Modal = false
			UIController.Close()
		end
	elseif not UIController.IsOpen("Starter") then
		starter.Modal = false
		UIController.Close()
		starter.Modal = true
		UIController.Open("Starter")
	end
end)

-- Moments from the server ------------------------------------------------------------------
Remotes.Events.GameEvent.OnClientEvent:Connect(function(name: string, payload: any)
	if name == "CreatureObtained" then
		reveal.Show(payload)
	elseif name == "CreatureEvolved" then
		UIController.Close()
		reveal.Show({
			Kind = "Evolve",
			Species = payload.Species,
			Stage = payload.Stage,
			Name = payload.Name,
			Unlocks = payload.Unlocks,
			Mutation = payload.Mutation,
		})
	elseif name == "Expanded" then
		AudioController.Play("Upgrade")
	elseif name == "QuestReady" then
		UIController.Notify("Quest complete! Claim your reward.", "Reward")
		AudioController.Play("QuestComplete")
	elseif name == "QuestClaimed" then
		AudioController.Play("QuestComplete")
	elseif name == "OfflineReport" then
		local parts = {}
		for resource, amount in payload.Produced do
			local def = ResourceConfig[resource]
			table.insert(parts, `{Format.Number(amount)} {def and def.Name or resource}`)
		end
		UIController.Notify(
			`While you were away ({Format.Duration(payload.Seconds)}), your creatures grew {table.concat(parts, ", ")}. Collect it from your farms!`,
			"Reward"
		)
	elseif name == "Sold" then
		AudioController.Play("Sell")
	elseif name == "Discovered" then
		AudioController.Play("QuestComplete")
	elseif name == "Scorched" then
		EffectsController.Flash(Color3.fromRGB(255, 90, 30))
	elseif name == "Researched" then
		AudioController.Play("Upgrade")
	elseif name == "Ascended" then
		UIController.Close()
		AudioController.Play("Evolve")
		UIController.Notify(
			`Ascension {payload.Count}! +{payload.Shards} Empire Shards. Your creatures are ready to build again, stronger than before.`,
			"Reward"
		)
	elseif name == "ExpeditionResult" then
		UIController.Open("ExpeditionResult", payload)
		AudioController.Play(if payload.Success then "QuestComplete" else "Notify")
	end
end)
