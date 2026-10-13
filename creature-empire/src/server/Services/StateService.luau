--!strict
-- Replicates each player's own state to their client, one section at a time.
-- Services call Push(player, section) whenever something changes; pushes are coalesced
-- and flushed a few times per second, so a burst of changes sends one message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local FLUSH_INTERVAL = 0.15

type Builder = (Player, PlayerDataService.Profile) -> any

local StateService = {}

local builders: { [string]: Builder } = {}
local order: { string } = {}
local pending: { [Player]: { [string]: boolean } } = {}

function StateService.Register(section: string, builder: Builder)
	assert(builders[section] == nil, `Section {section} registered twice`)
	builders[section] = builder
	table.insert(order, section)
end

function StateService.Push(player: Player, ...: string)
	local set = pending[player]
	if not set then
		set = {}
		pending[player] = set
	end
	for _, section in { ... } do
		set[section] = true
	end
end

function StateService.PushAll(player: Player)
	StateService.Push(player, table.unpack(order))
end

-- Full state, for GetSnapshot.
function StateService.Snapshot(player: Player): { [string]: any }?
	local profile = PlayerDataService.Get(player)
	if not profile then
		return nil
	end
	local snapshot = {}
	for _, section in order do
		snapshot[section] = builders[section](player, profile)
	end
	return snapshot
end

local function flush()
	for player, sections in pending do
		pending[player] = nil
		local profile = PlayerDataService.Get(player)
		if profile and player.Parent then
			for _, section in order do
				if sections[section] then
					local ok, payload = pcall(builders[section], player, profile)
					if ok then
						Remotes.Events.State:FireClient(player, section, payload)
					else
						warn(`[CE][State] {section} failed:`, payload)
					end
				end
			end
		end
	end
end

function StateService.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= FLUSH_INTERVAL then
			elapsed = 0
			flush()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return StateService
