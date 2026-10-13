--!strict
-- Loads, holds and saves player profiles.
--
-- Safety rules (see Core/ProfileCore for the locking itself):
--  * A profile is only usable after it loaded successfully. If loading fails or another
--    server still holds the profile, the player is kicked with an explanation. We never
--    give them a blank profile that could later be saved over their real progress.
--  * In Studio without API access there is no DataStore at all; the game runs with a
--    fresh profile that is never saved, and the HUD says so.
--  * Saves are coalesced: services call MarkDirty and the autosave loop writes at most
--    once per AutosaveInterval per player (plus on leave and on shutdown).
--  * A save that finds another server owns the lock stops all further saves for that
--    profile and removes the player, so two servers never write the same profile.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Core = script.Parent.Parent.Core
local ProfileCore = require(Core.ProfileCore)
local Schema = require(Core.Schema)
local Log = require(Core.Log)
local Signal = require(Core.Signal)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STORE_NAME = "CreatureEmpire_Profiles_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_REFRESH = 120 -- write at least this often to keep the session lock fresh
local SIZE_WARNING = 1_000_000 -- bytes (DataStore limit is 4 MB)

export type Profile = {
	Data: Types.PlayerData,
	Key: string,
	CanSave: boolean,
	Dirty: boolean,
	LastWrite: number,
	Released: boolean,
	Saving: boolean,
	Runtime: { [string]: any }, -- per-session state services can stash (never saved)
}

local PlayerDataService = {}

PlayerDataService.Loaded = Signal.new() :: Signal.Signal<Player, Profile>
-- Fires before the final save so services can write their latest state into the profile.
PlayerDataService.BeforeRelease = Signal.new() :: Signal.Signal<Player, Profile>

local profiles: { [Player]: Profile } = {}
local core: ProfileCore.ProfileCore? = nil
local unsavedMode = false

local function keyFor(userId: number): string
	return "Player_" .. userId
end

local function makeCore()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		Log.Warn("Data", "DataStore unavailable", { error = tostring(store) })
		return
	end
	core = ProfileCore.new({
		Store = store,
		JobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false),
		Now = os.time,
		Wait = task.wait,
		Log = function(level, message, fields)
			if level == "Warn" then
				Log.Warn("Data", message, fields)
			else
				Log.Info("Data", message, fields)
			end
		end,
	})
end

local function isStudioAccessError(err: any): boolean
	local text = tostring(err)
	return string.find(text, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(text, "API access", 1, true) ~= nil
		or string.find(text, "publish", 1, true) ~= nil
end

local function kick(player: Player, reason: string)
	Remotes.Events.DataStatus:FireClient(player, "Failed", reason)
	task.delay(1, function()
		if player.Parent then
			player:Kick(reason)
		end
	end)
end

local function finishLoad(player: Player, data: Types.PlayerData, canSave: boolean)
	if not player.Parent then
		return
	end
	local profile: Profile = {
		Data = data,
		Key = keyFor(player.UserId),
		CanSave = canSave,
		Dirty = false,
		LastWrite = os.clock(),
		Released = false,
		Saving = false,
		Runtime = {},
	}
	profiles[player] = profile
	data.Stats.Sessions = (data.Stats.Sessions or 0) + 1
	profile.Dirty = true
	Remotes.Events.DataStatus:FireClient(player, if canSave then "Ready" else "Unsaved")
	PlayerDataService.Loaded:Fire(player, profile)
end

local function load(player: Player)
	Remotes.Events.DataStatus:FireClient(player, "Loading")
	local now = os.time()

	if unsavedMode or not core then
		if RunService:IsStudio() then
			Log.Info("Data", "Studio without DataStore: progress will not be saved", { user = player.UserId })
			finishLoad(player, Schema.Default(now), false)
		else
			kick(player, "Creature Empire could not reach Roblox's save servers. Please rejoin in a moment.")
		end
		return
	end

	local key = keyFor(player.UserId)
	local status, result = (core :: ProfileCore.ProfileCore):Load(key)

	if status == "Error" and RunService:IsStudio() then
		-- Studio without API access, or an unpublished place. Never saved, so this can't
		-- overwrite anything.
		unsavedMode = isStudioAccessError(result)
		Log.Info("Data", "Studio: DataStore unavailable, progress will not be saved", { error = tostring(result) })
		finishLoad(player, Schema.Default(now), false)
		return
	end
	if status == "Locked" then
		kick(player, "Your empire is still being saved by another server. Please rejoin in a minute.")
		return
	elseif status == "Error" then
		Log.Warn("Data", "Load failed", { user = player.UserId, error = tostring(result) })
		kick(player, "We couldn't load your empire safely, so nothing was changed. Please rejoin.")
		return
	end

	local data: any = result
	if data == nil then
		data = Schema.Default(now)
		Log.Info("Data", "New profile", { user = player.UserId })
	elseif type(data) ~= "table" then
		Log.Warn("Data", "Profile is not a table; refusing to load", { user = player.UserId })
		kick(player, "Your save data needs attention. Nothing was changed. Please contact the developers.")
		return
	end

	local migrated, reason = Schema.Migrate(data)
	if not migrated then
		-- Newer data than this server understands: release our lock untouched and stop.
		Log.Warn("Data", "Refusing newer profile", { user = player.UserId, reason = reason })
		kick(player, "This server is out of date. Please rejoin to get the newest version.")
		return
	end
	local fixes = Schema.Sanitize(data, now)
	if #fixes > 0 then
		Log.Warn("Data", "Profile repaired", { user = player.UserId, fixes = table.concat(fixes, "; ") })
	end

	if not player.Parent then
		-- Left while loading: release the lock without changing anything else.
		core:Save(key, data, true)
		return
	end
	finishLoad(player, data, true)
end

local function save(player: Player, profile: Profile, release: boolean): boolean
	if not profile.CanSave or not core or profile.Released then
		return true
	end
	while profile.Saving do
		task.wait()
	end
	profile.Saving = true
	local data = profile.Data
	data.LastOnline = os.time()
	local shift = profile.Runtime.OfflineOverride
	if release and type(shift) == "number" then
		data.LastOnline -= shift -- DevService "offline" test command
	end
	Schema.Sanitize(data :: any, os.time())

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	if ok and #encoded > SIZE_WARNING then
		Log.Warn("Data", "Large profile", { user = player.UserId, bytes = #encoded })
	end

	profile.Dirty = false
	local status, err = (core :: ProfileCore.ProfileCore):Save(profile.Key, data, release)
	profile.Saving = false

	if status == "Ok" then
		profile.LastWrite = os.clock()
		if release then
			profile.Released = true
		end
		Log.Debug("Data", "Saved", { user = player.UserId, release = release })
		return true
	elseif status == "LockLost" then
		profile.CanSave = false
		profile.Released = true
		Log.Warn("Data", "Lock lost; this server stops saving", { user = player.UserId })
		if player.Parent then
			player:Kick("Your empire was opened on another server.")
		end
		return false
	end
	profile.Dirty = true -- retry on the next autosave
	Log.Warn("Data", "Save failed", { user = player.UserId, error = tostring(err) })
	return false
end

-- Public API ------------------------------------------------------------------------------

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

function PlayerDataService.GetData(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return profile and profile.Data
end

function PlayerDataService.IsReady(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataService.MarkDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

-- Saves right away (after important events such as a purchase). Still lock-checked.
function PlayerDataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	return if profile then save(player, profile, false) else false
end

function PlayerDataService.All(): { [Player]: Profile }
	return profiles
end

-- Developer use (Studio): wipes the in-memory profile back to defaults.
function PlayerDataService.ResetForTesting(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Data = Schema.Default(os.time())
		profile.Dirty = true
	end
end

function PlayerDataService.Start()
	makeCore()

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if not profile then
			return
		end
		PlayerDataService.BeforeRelease:Fire(player, profile)
		save(player, profile, true)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				if profile.Dirty or os.clock() - profile.LastWrite > LOCK_REFRESH then
					task.spawn(save, player, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				PlayerDataService.BeforeRelease:Fire(player, profile)
				save(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

return PlayerDataService
