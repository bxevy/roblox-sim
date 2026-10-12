--!strict
-- Loads, caches, and saves player data with DataStoreService.
-- Data is only ever written back if it loaded successfully, so a DataStore
-- outage can't wipe someone's progress.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MAX_RETRIES = 3

local DataService = {}

type Profile = {
	Data: { [string]: any },
	CanSave: boolean,
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not save:", result)
	end
end

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

-- Fills in any keys missing from saved data (e.g. after adding a new upgrade).
local function reconcile(target: { [string]: any }, template: { [string]: any })
	for key, defaultValue in template do
		if target[key] == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(target[key]) == "table" then
			reconcile(target[key], defaultValue)
		end
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function withRetries<T>(fn: () -> T): (boolean, T | string)
	local ok, result
	for attempt = 1, MAX_RETRIES do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, result
end

local function load(player: Player)
	local data: { [string]: any }
	local canSave = false

	if store then
		local ok, result = withRetries(function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			data = if type(result) == "table" then result else deepCopy(Config.DefaultData)
			canSave = true
		else
			warn(`[DataService] Failed to load {player.Name}: {result}`)
		end
	end

	if not data then
		data = deepCopy(Config.DefaultData)
	end
	reconcile(data, Config.DefaultData)

	if not player.Parent then
		return -- left while loading
	end

	profiles[player] = { Data = data, CanSave = canSave }
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return
	end
	local ok, err = withRetries(function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function()
			return profile.Data
		end)
	end)
	if not ok then
		warn(`[DataService] Failed to save {player.Name}: {err}`)
	end
end

-- Saves right away (used after Robux purchases so they're never lost).
function DataService.Save(player: Player)
	save(player)
end

function DataService.Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Runs callback for every player whose data finishes loading (including ones already loaded).
function DataService.OnLoaded(callback: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return DataService
