-- Admin tools: the admin menu (client UI/AdminPanel) and chat commands.
--
-- Who is an admin: anyone testing in Roblox Studio, the game's owner (or rank 254+ in the
-- owning group), and user ids listed in Config.AdminUserIds. Every action is checked here
-- on the server, so normal players can't use them even if they find the remote.
--
-- Chat commands (admins only): /giveall, /level 20, /gold 5000, /give Dragonfang

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local DungeonService = require(script.Parent.DungeonService)
local ClassService = require(script.Parent.ClassService)
local StoreService = require(script.Parent.StoreService)

local TOWN_SPAWN = Vector3.new(0, 4, 0)

local AdminService = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
		if ok then
			for _, group in groups do
				if group.Id == game.CreatorId then
					return group.Rank >= 254
				end
			end
		end
	end
	return false
end

-- Only the game's owner (or Config.OwnerUserIds) - not every admin.
local function isOwner(player: Player): boolean
	if RunService:IsStudio() or table.find(Config.OwnerUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
		if ok then
			for _, group in groups do
				if group.Id == game.CreatorId then
					return group.Rank >= 255
				end
			end
		end
	end
	return false
end

local function teleport(player: Player, position: Vector3): (boolean, string?)
	if player:GetAttribute("InDungeon") then
		return false, "Leave the dungeon first"
	end
	local character = player.Character
	if not character then
		return false, "No character"
	end
	character:PivotTo(CFrame.new(position))
	return true, "Teleported"
end

-- Each action returns (ok, message).
local ACTIONS: { [string]: (Player, any) -> (boolean, string?) } = {
	GiveAll = function(player)
		local count = 0
		for id in Items.Weapons do
			if PlayerService.GiveItem(player, "Weapon", id) then
				count += 1
			end
		end
		for id in Items.Armors do
			if PlayerService.GiveItem(player, "Armor", id) then
				count += 1
			end
		end
		return true, `Gave every weapon and armor ({count} new)`
	end,

	GiveItem = function(player, itemId)
		if type(itemId) ~= "string" then
			return false, "Type an item id"
		end
		local kind = if Items.Weapons[itemId] then "Weapon" elseif Items.Armors[itemId] then "Armor" else nil
		if not kind then
			return false, `No item called "{itemId}"`
		end
		PlayerService.GiveItem(player, kind, itemId)
		return true, `Gave {itemId}`
	end,

	MaxPotions = function(player)
		local data = PlayerService.GetData(player)
		if not data then
			return false, "Still loading"
		end
		for potionId in Config.Potions do
			data.Potions[potionId] = Config.MaxPotionStack
		end
		PlayerService.Push(player)
		return true, "Potions refilled"
	end,

	AddGold = function(player, amount)
		amount = tonumber(amount) or 10000
		PlayerService.AddGold(player, amount)
		return true, `+{amount} Gold`
	end,

	SetLevel = function(player, level)
		level = tonumber(level)
		if not level then
			return false, "Type a level number"
		end
		PlayerService.SetLevel(player, level)
		return true, `Level set to {math.clamp(math.floor(level), 1, Config.MaxLevel)}`
	end,

	SkillPoints = function(player)
		local data = PlayerService.GetData(player)
		if not data then
			return false, "Still loading"
		end
		data.SkillPoints += 10
		PlayerService.Push(player)
		return true, "+10 skill points"
	end,

	SetPrestige = function(player, prestige)
		local data = PlayerService.GetData(player)
		prestige = tonumber(prestige)
		if not data or not prestige then
			return false, "Type a prestige number"
		end
		data.Prestige = math.clamp(math.floor(prestige), 0, Config.Prestige.Max)
		PlayerService.Push(player)
		return true, `Prestige set to {data.Prestige}`
	end,

	-- Owner only: level 999 / prestige 999 (press again to go back to 50 / 10).
	CreatorRank = function(player)
		if player:GetAttribute("IsOwner") ~= true then
			return false, "Only the game owner can use this"
		end
		local data = PlayerService.GetData(player)
		if not data then
			return false, "Still loading"
		end
		if data.CreatorRank then
			data.CreatorRank = nil
			data.Level = Config.MaxLevel
			data.Prestige = Config.Prestige.Max
		else
			data.CreatorRank = true
			data.Level = Config.CreatorRank.Level
			data.Prestige = Config.CreatorRank.Prestige
		end
		data.XP = 0
		PlayerService.RefreshStats(player, true)
		PlayerService.Push(player)
		if data.CreatorRank then
			for _, other in Players:GetPlayers() do
				PlayerService.Notify(other, `{player.DisplayName} has ascended to CREATOR RANK (Level {data.Level}, Prestige {data.Prestige})!`, Color3.fromRGB(255, 80, 200))
			end
			return true, "Creator Rank ON"
		end
		return true, "Creator Rank OFF"
	end,

	AddCandies = function(player, amount)
		amount = tonumber(amount) or 5000
		PlayerService.AddCandies(player, amount)
		return true, `+{amount} candies`
	end,

	FreeRoll = function(player)
		if player:GetAttribute("InDungeon") then
			return false, "Leave the dungeon first"
		end
		ClassService.FreeRoll(player)
		return true, "Rolling a class (free)"
	end,

	SetClass = function(player, classId)
		local match = nil
		for id in Config.Classes do
			if type(classId) == "string" and id:lower() == classId:lower() then
				match = id
			end
		end
		if not match then
			return false, `Class: {table.concat(Config.ClassOrder, ", ")}, {table.concat(Config.LimitedClassOrder, ", ")}`
		end
		if Config.Classes[match].Limited then
			-- Admins can hand themselves limited classes for testing
			local data = PlayerService.GetData(player)
			if data then
				data.LimitedClasses[match] = true
			end
		end
		PlayerService.SetClass(player, match)
		return true, `Class set to {match}`
	end,

	-- Testing the Robux Store without buying anything
	TogglePerks = function(player)
		local on = StoreService.TogglePerk(player, "Luck")
		if StoreService.TogglePerk(player, "Coins") ~= on then
			StoreService.TogglePerk(player, "Coins")
		end
		return true, if on then "2x Luck + 2x Coins ON" else "2x Luck + 2x Coins OFF"
	end,

	UnlockSlot = function(player)
		if ClassService.UnlockSlot(player) then
			return true, "Unlocked a class slot"
		end
		return false, "Every class slot is already unlocked"
	end,

	Heal = function(player)
		PlayerService.Heal(player, 1)
		return true, "Fully healed"
	end,

	God = function(player)
		local character = player.Character
		if not character then
			return false, "No character"
		end
		local on = not character:GetAttribute("God")
		character:SetAttribute("God", if on then true else nil)
		return true, if on then "God mode ON (until you respawn)" else "God mode OFF"
	end,

	KillRoom = function(player)
		if DungeonService.KillRoom(player) then
			return true, "Room cleared"
		end
		return false, "You're not in a dungeon"
	end,

	TeleportTown = function(player)
		return teleport(player, TOWN_SPAWN)
	end,

	TeleportTraining = function(player)
		return teleport(player, Config.TrainingSpawn)
	end,
}

local function runAction(player: Player, action: unknown, arg: unknown): (boolean, string?)
	if not isAdmin(player) then
		return false, "Admins only"
	end
	local handler = type(action) == "string" and ACTIONS[action]
	if not handler then
		return false, "Unknown action"
	end
	return handler(player, arg)
end

-- Chat commands map onto the same actions.
local function runChat(player: Player, message: string)
	local command, arg = message:match("^/(%w+)%s*(%S*)")
	if not command or not isAdmin(player) then
		return
	end
	local action = ({ giveall = "GiveAll", level = "SetLevel", gold = "AddGold", give = "GiveItem" })[command:lower()]
	if action then
		local _, result = runAction(player, action, if arg ~= "" then arg else nil)
		if result then
			PlayerService.Notify(player, `[Admin] {result}`)
		end
	end
end

function AdminService.Start()
	Remotes.Admin.OnServerInvoke = runAction

	local function onPlayer(player: Player)
		-- The client uses this to decide whether to show the Admin button.
		player:SetAttribute("IsAdmin", isAdmin(player))
		player:SetAttribute("IsOwner", isOwner(player))
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			player.Chatted:Connect(function(message)
				runChat(player, message)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		for _, name in { "giveall", "level", "gold", "give" } do
			local textCommand = Instance.new("TextChatCommand")
			textCommand.Name = `Admin_{name}`
			textCommand.PrimaryAlias = `/{name}`
			textCommand.Triggered:Connect(function(source, text)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					runChat(player, text)
				end
			end)
			textCommand.Parent = TextChatService
		end
	end
end

return AdminService
