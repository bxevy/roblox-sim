-- Server entry point. Starts each service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes before anything else so clients can find them.
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PlayerService = require(Services.PlayerService)
local EnemyService = require(Services.EnemyService)
local CombatService = require(Services.CombatService)
local DungeonService = require(Services.DungeonService)

PlayerService.Start()
CombatService.Start()
EnemyService.Start()
DungeonService.Start()
DataService.Start() -- last, so every service is listening before player data loads

print("[Server] Started")
