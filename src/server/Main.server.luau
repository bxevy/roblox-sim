--!strict
-- Server entry point. Starts each service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remotes before anything else so clients can find them.
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local GameService = require(Services.GameService)
local WorldService = require(Services.WorldService)

GameService.Start()
WorldService.Start()
DataService.Start()

print("[Server] Started")
