--!strict
-- Server entry point. Builds the world, then starts every service. PlayerDataService
-- starts last so every service is listening before the first profile loads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes) -- create remotes before clients look for them
local GameConfig = require(Shared.Config.GameConfig)

local Core = script.Parent.Core
local Net = require(Core.Net)
local Log = require(Core.Log)

local Services = script.Parent.Services
local PlayerDataService = require(Services.PlayerDataService)
local StateService = require(Services.StateService)
local EconomyService = require(Services.EconomyService)
local PlotService = require(Services.PlotService)
local ProductionService = require(Services.ProductionService)
local BuildingService = require(Services.BuildingService)
local CreatureService = require(Services.CreatureService)
local QuestService = require(Services.QuestService)
local HatchingService = require(Services.HatchingService)
local EvolutionService = require(Services.EvolutionService)
local RegionService = require(Services.RegionService)
local NodeService = require(Services.NodeService)
local WildService = require(Services.WildService)
local CraftingService = require(Services.CraftingService)
local ExpeditionService = require(Services.ExpeditionService)
local GuardianService = require(Services.GuardianService)
local ResearchService = require(Services.ResearchService)
local AscensionService = require(Services.AscensionService)
local SocialService = require(Services.SocialService)
local TradingService = require(Services.TradingService)
local WorldEventService = require(Services.WorldEventService)
local LeaderboardService = require(Services.LeaderboardService)
local MonetizationService = require(Services.MonetizationService)
local SettingsService = require(Services.SettingsService)
local AntiExploitService = require(Services.AntiExploitService)
local DevService = require(Services.DevService)

require(script.Parent.World.AssetLoader).Load() -- custom models by asset id, before building
require(script.Parent.World.WorldBuilder).Build()
require(script.Parent.World.EmberfallBuilder).Build()

Net.Configure({
	IsReady = PlayerDataService.IsReady,
	OnViolation = AntiExploitService.Report,
})

StateService.Register("Meta", function(player, profile)
	local plot = PlotService.Get(player)
	return {
		Version = GameConfig.Version,
		Phase = GameConfig.Phase,
		CanSave = profile.CanSave,
		PlotIndex = plot and plot.Index,
	}
end)

-- Snapshot for clients that (re)connect their UI.
Net.Handle("GetSnapshot", { Rate = { 4, 1 }, AllowBeforeLoad = true }, function(player)
	local snapshot = StateService.Snapshot(player)
	return snapshot ~= nil, snapshot
end)

StateService.Start()
AntiExploitService.Start()
EconomyService.Start()
PlotService.Start()
ProductionService.Start()
BuildingService.Start()
CreatureService.Start()
HatchingService.Start()
EvolutionService.Start()
RegionService.Start()
NodeService.Start()
WildService.Start()
CraftingService.Start()
ExpeditionService.Start()
GuardianService.Start()
ResearchService.Start()
AscensionService.Start()
SocialService.Start()
TradingService.Start()
WorldEventService.Start()
LeaderboardService.Start()
MonetizationService.Start()
QuestService.Start()
SettingsService.Start()
DevService.Start()

-- Push everything once a player's plot is ready (their buildings and creatures exist).
PlotService.OnClaimed(function(player)
	StateService.PushAll(player)
end)

PlayerDataService.Start()

Log.Info("Server", "Started", { version = GameConfig.Version, phase = GameConfig.Phase })
