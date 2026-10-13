--!strict
-- Plot permissions and friendly multiplayer actions:
--   * collaborators (saved per owner): may collect the owner's harvests into the owner's
--     silo; the owner can add or remove them at any time
--   * cheering another empire: a short production boost for them, a small gift for you
--   * visiting: jump to another player's plot entrance
-- Permission checks live here: Owner, Collaborator or Visitor (SocialConfig).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SocialConfig = require(Shared.Config.SocialConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local ProductionService = require(script.Parent.ProductionService)
local BuildingService = require(script.Parent.BuildingService)
local PlotService = require(script.Parent.PlotService)

local SocialService = {}

export type Permission = "Owner" | "Collaborator" | "Visitor"

-- cheerer userId .. ":" .. owner userId -> os.clock of the last cheer
local lastCheer: { [string]: number } = {}
local lastGift: { [number]: number } = {}

function SocialService.Permission(actor: Player, owner: Player): Permission
	if actor == owner then
		return "Owner"
	end
	local data = PlayerDataService.GetData(owner)
	if data and data.Collaborators[tostring(actor.UserId)] then
		return "Collaborator"
	end
	return "Visitor"
end

-- Shared on the plot folder so clients can show collaborator prompts.
local function publishCollaborators(owner: Player)
	local plot = PlotService.Get(owner)
	local data = PlayerDataService.GetData(owner)
	if not plot or not data then
		return
	end
	local ids = {}
	for userId in data.Collaborators do
		table.insert(ids, userId)
	end
	table.sort(ids)
	plot.Folder:SetAttribute("Collaborators", "," .. table.concat(ids, ",") .. ",")
end

local function ownerOf(userId: number): Player?
	local owner = Players:GetPlayerByUserId(userId)
	if owner and PlayerDataService.GetData(owner) then
		return owner
	end
	return nil
end

local function setCollaborator(player: Player, userId: number, allowed: boolean): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	if userId == player.UserId then
		return false, "That's you!"
	end
	local key = tostring(userId)
	if allowed then
		if data.Collaborators[key] then
			return true, nil
		end
		local count = 0
		for _ in data.Collaborators do
			count += 1
		end
		if count >= SocialConfig.MaxCollaborators then
			return false, `You can have up to {SocialConfig.MaxCollaborators} collaborators.`
		end
		-- Only players you can see right now (in this server) can be added.
		if not Players:GetPlayerByUserId(userId) then
			return false, "They need to be in this server."
		end
		data.Collaborators[key] = true
	else
		data.Collaborators[key] = nil
	end
	PlayerDataService.MarkDirty(player)
	publishCollaborators(player)
	StateService.Push(player, "Social")
	local other = Players:GetPlayerByUserId(userId)
	if other then
		StateService.Push(other, "Social")
		Remotes.Events.Notify:FireClient(
			other,
			if allowed
				then `{player.DisplayName} made you a collaborator: you can collect their harvests for them.`
				else `{player.DisplayName} removed you as a collaborator.`,
			"Info"
		)
	end
	Log.Info("Social", "Collaborator", { owner = player.UserId, user = userId, allowed = allowed })
	return true, nil
end

local function collectFor(player: Player, ownerUserId: number, buildingId: string): (boolean, any)
	local owner = ownerOf(ownerUserId)
	if not owner then
		return false, "That empire isn't here right now."
	end
	if SocialService.Permission(player, owner) == "Visitor" then
		return false, "Only the owner and their collaborators can collect here."
	end
	return BuildingService.CollectFor(owner, player, buildingId)
end

local function cheer(player: Player, ownerUserId: number): (boolean, any)
	local owner = ownerOf(ownerUserId)
	if not owner or owner == player then
		return false, if owner == player then "Cheer someone else's empire!" else "That empire isn't here right now."
	end
	local core = BuildingService.GetModel(owner, "core")
	if
		not core
		or not core.PrimaryPart
		or not PlotService.IsNear(player, core.PrimaryPart.Position, SocialConfig.Cheer.Range)
	then
		return false, "Walk up to their Empire Core to cheer."
	end
	local key = `{player.UserId}:{owner.UserId}`
	local now = os.clock()
	if lastCheer[key] and now - lastCheer[key] < SocialConfig.Cheer.Cooldown then
		return false,
			`You can cheer {owner.DisplayName} again in {math.ceil(
				(SocialConfig.Cheer.Cooldown - (now - lastCheer[key])) / 60
			)} min.`
	end
	local data = PlayerDataService.GetData(owner) :: Types.PlayerData
	if ProductionService.CountBuffs(owner, "core", "Boost") >= SocialConfig.Cheer.MaxStacks then
		return false, "Their empire is already cheered on as much as it can be. Try again later!"
	end
	lastCheer[key] = now
	-- The boost goes on every production building (and a marker on the core for stacking).
	local buff = {
		Stat = "WorkSpeed",
		Category = "Boost",
		Value = SocialConfig.Cheer.Value,
		Duration = SocialConfig.Cheer.Duration,
	}
	ProductionService.AddBuff(owner, "core", buff)
	for buildingId in data.Buildings do
		if ProductionService.GetRate(owner, buildingId) then
			ProductionService.AddBuff(owner, buildingId, buff)
		end
	end
	data.Stats.CheersReceived = (data.Stats.CheersReceived or 0) + 1
	PlayerDataService.MarkDirty(owner)
	local mine = PlayerDataService.GetData(player) :: Types.PlayerData
	mine.Stats.Cheers = (mine.Stats.Cheers or 0) + 1
	local gift = false
	if not lastGift[player.UserId] or now - lastGift[player.UserId] >= SocialConfig.Cheer.Cooldown then
		lastGift[player.UserId] = now
		gift = true
		for id, amount in SocialConfig.Cheer.Reward do
			EconomyService.Add(player, id, amount, "Cheer")
		end
	end
	Remotes.Events.Notify:FireClient(
		owner,
		`{player.DisplayName} cheered your empire! Your creatures work {math.floor(SocialConfig.Cheer.Value * 100)}% faster for {math.floor(
			SocialConfig.Cheer.Duration / 60
		)} minutes.`,
		"Reward"
	)
	Remotes.Events.GameEvent:FireAllClients("Cheered", { OwnerUserId = owner.UserId, By = player.UserId })
	Events.Cheered:Fire(player, owner.UserId)
	return true, { Gift = gift }
end

local function visit(player: Player, ownerUserId: number): (boolean, any)
	local owner = ownerOf(ownerUserId)
	if not owner then
		return false, "That empire isn't here right now."
	end
	local plot = PlotService.Get(owner)
	local character = player.Character
	if not plot or not character then
		return false, "Try again in a moment."
	end
	character:PivotTo(plot.Spawn.CFrame * CFrame.new(0, 4, -6))
	return true, nil
end

function SocialService.Start()
	StateService.Register("Social", function(player, profile)
		local collaborators = {}
		for userId in profile.Data.Collaborators do
			table.insert(collaborators, tonumber(userId))
		end
		-- Plots where this player is a collaborator (owners in this server).
		local helping = {}
		for _, other in Players:GetPlayers() do
			local data = if other ~= player then PlayerDataService.GetData(other) else nil
			if data and data.Collaborators[tostring(player.UserId)] then
				table.insert(helping, other.UserId)
			end
		end
		return { Collaborators = collaborators, Helping = helping, Max = SocialConfig.MaxCollaborators }
	end)
	PlotService.OnClaimed(function(player)
		publishCollaborators(player)
		-- Everyone's "helping" list may change when a player joins.
		for _, other in Players:GetPlayers() do
			StateService.Push(other, "Social")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastGift[player.UserId] = nil
		for _, other in Players:GetPlayers() do
			if other ~= player then
				StateService.Push(other, "Social")
			end
		end
	end)
	local Check = Net.Check
	Net.Handle("SetCollaborator", { Rate = { 4, 1 }, Args = { Check.Integer, Check.Boolean } }, setCollaborator)
	Net.Handle("CollectFor", { Rate = { 6, 2 }, Args = { Check.Integer, Check.Id } }, collectFor)
	Net.Handle("Cheer", { Rate = { 3, 0.5 }, Args = { Check.Integer } }, cheer)
	Net.Handle("VisitPlot", { Rate = { 2, 0.5 }, Args = { Check.Integer } }, visit)
end

return SocialService
