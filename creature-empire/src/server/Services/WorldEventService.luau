--!strict
-- Server-wide events on the shared schedule (Shared/Util/WorldEvent, WorldEventConfig).
-- The current event is published as attributes on ReplicatedStorage.WorldEvent so every
-- client shows the same banner, timer and progress.
--
--   GoldenHour  a server-wide production buff (ProductionService.SetGlobalBuff)
--   Bloom       counts everyone's Moonpetal collecting toward a shared goal; helpers are
--               rewarded if it's reached (first win: Elderbark)
--   EmberRift   teams join from the Expedition Portal (ExpeditionService); when the rift
--               closes, every team's record learns how many teams took part

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local WorldEventConfig = require(Shared.Config.WorldEventConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local WorldEvent = require(Shared.Util.WorldEvent)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local ProductionService = require(script.Parent.ProductionService)
local CreatureService = require(script.Parent.CreatureService)

local WorldEventService = {}

type Current = {
	Slot: WorldEvent.Slot,
	Goal: number,
	Progress: number,
	Contributions: { [number]: number }, -- userId -> amount (Bloom)
	Teams: { [number]: boolean }, -- userId -> joined (Rift)
}

local folder: Configuration
local current: Current? = nil
local forced: WorldEvent.Slot? = nil -- Studio testing (DevService)
local lastFinished: number? = nil -- an event index that already ran (never begin it twice)
local riftResults: { [number]: number } = {} -- rift index -> teams, for late claims

local function publish()
	local now = Workspace:GetServerTimeNow()
	local schedule = forced or WorldEvent.At(now)
	local active = current
	folder:SetAttribute("Kind", if active then active.Slot.Kind else "")
	folder:SetAttribute("Index", if active then active.Slot.Index else -1)
	folder:SetAttribute("EndsAt", if active then active.Slot.EndsAt else 0)
	folder:SetAttribute("NextAt", if active then active.Slot.NextAt else schedule.NextAt)
	folder:SetAttribute("NextKind", if active then active.Slot.NextKind else schedule.NextKind)
	folder:SetAttribute("Progress", if active then active.Progress else 0)
	folder:SetAttribute("Goal", if active then active.Goal else 0)
	local teams = 0
	local joined: { [number]: boolean } = if active then active.Teams else {}
	for _ in joined do
		teams += 1
	end
	folder:SetAttribute("Teams", teams)
end

local function begin(slot: WorldEvent.Slot)
	local players = #Players:GetPlayers()
	current = {
		Slot = slot,
		Goal = if slot.Kind == "Bloom" then WorldEvent.BloomGoal(players) else 0,
		Progress = 0,
		Contributions = {},
		Teams = {},
	}
	local def = WorldEventConfig.Events[slot.Kind]
	if slot.Kind == "GoldenHour" then
		local remaining = slot.EndsAt - Workspace:GetServerTimeNow()
		ProductionService.SetGlobalBuff("GoldenHour", {
			Stat = WorldEventConfig.GoldenHour.Stat,
			Category = "Boost",
			Value = WorldEventConfig.GoldenHour.Value,
			Duration = math.max(remaining, 1),
		})
	end
	Remotes.Events.GameEvent:FireAllClients("WorldEventStarted", { Kind = slot.Kind })
	Remotes.Events.Notify:FireAllClients(`{def.Glyph} {def.Name}! {def.Description}`, "Reward")
	Log.Info("WorldEvent", "Started", { kind = slot.Kind, index = slot.Index })
	publish()
end

local function finishBloom(event: Current)
	local bloom = WorldEventConfig.Bloom
	local success = event.Progress >= event.Goal
	for userId, amount in event.Contributions do
		local player = Players:GetPlayerByUserId(userId)
		local data = player and PlayerDataService.GetData(player)
		if player and data then
			if success and amount >= bloom.MinContribution then
				local parts = {}
				for id, reward in bloom.Reward do
					EconomyService.Add(player, id, reward, "WorldEvent")
					table.insert(parts, `{Format.Number(reward)} {ResourceConfig[id].Name}`)
				end
				data.WorldEvents.Bloom = (data.WorldEvents.Bloom or 0) + 1
				PlayerDataService.MarkDirty(player)
				Remotes.Events.Notify:FireClient(
					player,
					`The Grand Bloom succeeded! You helped with {Format.Number(amount)} moonpetals: +{table.concat(
						parts,
						", "
					)}.`,
					"Reward"
				)
				if data.WorldEvents.Bloom == 1 then
					CreatureService.Grant(player, bloom.FirstWinCreature, "WorldEvent", false, { WorldEvent = "Bloom" })
				end
			elseif not success then
				Remotes.Events.Notify:FireClient(
					player,
					`The Grand Bloom fell short ({Format.Number(event.Progress)} / {Format.Number(event.Goal)}). Next time!`,
					"Info"
				)
			end
		end
	end
	Log.Info("WorldEvent", "Bloom ended", { success = success, progress = event.Progress, goal = event.Goal })
end

local function finishRift(event: Current)
	local teams = 0
	for _ in event.Teams do
		teams += 1
	end
	for userId in event.Teams do
		local player = Players:GetPlayerByUserId(userId)
		local data = player and PlayerDataService.GetData(player)
		if player and data then
			for _, record in data.Expeditions do
				if record.Party == event.Slot.Index then
					record.PartySize = teams
				end
			end
			PlayerDataService.MarkDirty(player)
			StateService.Push(player, "Expeditions")
			Remotes.Events.Notify:FireClient(
				player,
				`The Ember Rift closed. {teams} team{if teams == 1 then "" else "s"} went in together: claim your team's results at your Expedition Portal.`,
				"Reward"
			)
		end
	end
	Log.Info("WorldEvent", "Rift ended", { teams = teams })
end

local function finish(event: Current)
	if event.Slot.Kind == "GoldenHour" then
		ProductionService.SetGlobalBuff("GoldenHour", nil)
	elseif event.Slot.Kind == "Bloom" then
		finishBloom(event)
	elseif event.Slot.Kind == "EmberRift" then
		finishRift(event)
	end
	Remotes.Events.GameEvent:FireAllClients("WorldEventEnded", { Kind = event.Slot.Kind })
	lastFinished = event.Slot.Index
	if event.Slot.Kind == "EmberRift" then
		local teams = 0
		for _ in event.Teams do
			teams += 1
		end
		riftResults[event.Slot.Index] = teams
	end
	current = nil
	publish()
end

local function step()
	local now = Workspace:GetServerTimeNow()
	if forced and now >= forced.EndsAt then
		forced = nil
	end
	local slot = forced or WorldEvent.At(now)
	local active = current
	if active and (not slot.Active or slot.Index ~= active.Slot.Index) then
		finish(active)
	end
	if slot.Active and not current and slot.Index ~= lastFinished then
		begin(slot)
	end
	-- More players arrived during a Bloom: the goal grows with them (never shrinks).
	local bloom = current
	if bloom and bloom.Slot.Kind == "Bloom" then
		local goal = math.max(bloom.Goal, WorldEvent.BloomGoal(#Players:GetPlayers()))
		if goal ~= bloom.Goal then
			bloom.Goal = goal
			publish()
		end
	end
end

-- Public -------------------------------------------------------------------------------------

-- The open Ember Rift, if teams can still join: its slot (index and end time).
function WorldEventService.OpenRift(): WorldEvent.Slot?
	local active = current
	if not active or active.Slot.Kind ~= "EmberRift" then
		return nil
	end
	if Workspace:GetServerTimeNow() > active.Slot.EndsAt - WorldEventConfig.Rift.JoinCutoff then
		return nil
	end
	return active.Slot
end

function WorldEventService.JoinRift(player: Player)
	local active = current
	if active and active.Slot.Kind == "EmberRift" then
		active.Teams[player.UserId] = true
		Events.WorldEventJoined:Fire(player, "EmberRift")
		publish()
	end
end

-- The rift index still running (its teams can't be resolved yet), if any.
function WorldEventService.CurrentRift(): number?
	local active = current
	return if active and active.Slot.Kind == "EmberRift" then active.Slot.Index else nil
end

-- How many teams went into a rift that closed on this server (nil if unknown).
function WorldEventService.RiftTeams(index: number): number?
	return riftResults[index]
end

-- Studio testing: start an event now (the normal schedule resumes when it ends).
function WorldEventService.Force(kind: string): boolean
	local def = WorldEventConfig.Events[kind]
	if not def then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	if current then
		finish(current)
	end
	forced = {
		Index = -math.floor(now), -- distinct from scheduled indexes
		Kind = kind,
		StartsAt = now,
		EndsAt = now + def.Duration,
		Active = true,
		NextAt = now + def.Duration + 60,
		NextKind = WorldEvent.At(now).NextKind,
	}
	step()
	return true
end

function WorldEventService.Start()
	folder = Instance.new("Configuration")
	folder.Name = "WorldEvent"
	folder.Parent = ReplicatedStorage
	publish()

	Events.Collected:Connect(function(player, resource, amount, how)
		local active = current
		-- Offline catch-up deliveries don't count: the Bloom is for people playing now.
		if active and active.Slot.Kind == "Bloom" and resource == "Moonpetal" and amount > 0 and how ~= "Offline" then
			local before = active.Contributions[player.UserId] or 0
			active.Contributions[player.UserId] = before + amount
			active.Progress += amount
			if
				before < WorldEventConfig.Bloom.MinContribution
				and before + amount >= WorldEventConfig.Bloom.MinContribution
			then
				Events.WorldEventJoined:Fire(player, "Bloom")
			end
			publish()
		end
	end)

	-- Players who rejoin while their rift team is still out count as joined again.
	PlayerDataService.Loaded:Connect(function(player)
		local active = current
		local data = PlayerDataService.GetData(player)
		if active and active.Slot.Kind == "EmberRift" and data then
			for _, record in data.Expeditions do
				if record.Party == active.Slot.Index then
					active.Teams[player.UserId] = true
					publish()
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				step()
				return true
			end)
			if not ok then
				Log.Warn("WorldEvent", "step failed", { error = tostring(err) })
			end
			task.wait(1)
		end
	end)
end

return WorldEventService
