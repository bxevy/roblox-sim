-- Server entry point. Starts each service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes before anything else so clients can find them.
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PlayerService = require(Services.PlayerService)
local MovementService = require(Services.MovementService)
local EnemyService = require(Services.EnemyService)
local CombatService = require(Services.CombatService)
local DungeonService = require(Services.DungeonService)
local ShopService = require(Services.ShopService)
local CrateService = require(Services.CrateService)
local LeaderboardService = require(Services.LeaderboardService)
local ProgressionService = require(Services.ProgressionService)
local QuestService = require(Services.QuestService)
local CardService = require(Services.CardService)
local ClassService = require(Services.ClassService)
local AdminService = require(Services.AdminService)
local HubService = require(Services.HubService)
local TrainingService = require(Services.TrainingService)
local TownsfolkService = require(Services.TownsfolkService)

HubService.Start()
TrainingService.Start()
PlayerService.Start()
MovementService.Start()
CombatService.Start()
EnemyService.Start()
DungeonService.Start()
ShopService.Start()
CrateService.Start()
LeaderboardService.Start()
ProgressionService.Start()
QuestService.Start()
CardService.Start()
ClassService.Start()
AdminService.Start()
TownsfolkService.Start()
DataService.Start() -- last, so every service is listening before player data loads

print("[Server] Started")
