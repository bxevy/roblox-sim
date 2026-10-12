-- Parties: invite players in the server (or invite Roblox friends to the game) and go
-- into dungeons together. When anyone in a party starts a dungeon from a portal, the rest
-- of the party in town comes with them (see DungeonService).
--
-- Friends invited with the "Invite Friends" button join straight into the inviter's
-- party: the invite carries "party:<userId>" as launch data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local INVITE_TIMEOUT = 60

local PartyService = {}

type Party = { Leader: Player, Members: { Player } }

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { [Player]: number } } = {} -- target -> inviter -> sent at

local function info(party: Party?)
	if not party then
		return nil
	end
	local members = {}
	for _, member in party.Members do
		local class = PlayerService.GetClass(member)
		table.insert(members, {
			UserId = member.UserId,
			Name = member.DisplayName,
			Level = PlayerService.GetLevel(member),
			Class = if class then class.DisplayName else "No class",
			Leader = member == party.Leader,
			InDungeon = member:GetAttribute("InDungeon") == true,
		})
	end
	return { Leader = party.Leader.UserId, Members = members, MaxSize = Config.Party.MaxSize }
end

local function broadcast(party: Party)
	local data = info(party)
	for _, member in party.Members do
		Remotes.PartyChanged:FireClient(member, data)
		member:SetAttribute("PartyLeader", party.Leader.UserId)
	end
end

local function leave(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	player:SetAttribute("PartyLeader", nil)
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	if player.Parent then
		Remotes.PartyChanged:FireClient(player, nil)
	end
	if #party.Members <= 1 then
		-- A party of one is no party
		for _, member in party.Members do
			partyOf[member] = nil
			member:SetAttribute("PartyLeader", nil)
			Remotes.PartyChanged:FireClient(member, nil)
			PlayerService.Notify(member, "Your party disbanded")
		end
		return
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
		PlayerService.Notify(party.Leader, "You are now the party leader")
	end
	for _, member in party.Members do
		PlayerService.Notify(member, `{player.DisplayName} left the party`)
	end
	broadcast(party)
end

local function join(player: Player, leader: Player): (boolean, string?)
	local party = partyOf[leader]
	if party and #party.Members >= Config.Party.MaxSize then
		return false, "That party is full"
	end
	if partyOf[player] then
		leave(player)
	end
	if not party then
		party = { Leader = leader, Members = { leader } }
		partyOf[leader] = party
	end
	table.insert(party.Members, player)
	partyOf[player] = party
	for _, member in party.Members do
		PlayerService.Notify(member, `{player.DisplayName} joined the party!`, Color3.fromRGB(120, 230, 140))
	end
	broadcast(party)
	return true
end

local function findPlayer(userId: unknown): Player?
	return if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local ACTIONS: { [string]: (Player, any) -> (boolean, string?) } = {
	Invite = function(player, userId)
		local target = findPlayer(userId)
		if not target or target == player then
			return false, "Player not found"
		end
		local party = partyOf[player]
		if party and #party.Members >= Config.Party.MaxSize then
			return false, "Your party is full"
		end
		if party and partyOf[target] == party then
			return false, `{target.DisplayName} is already in your party`
		end
		invites[target] = invites[target] or {}
		invites[target][player] = os.clock()
		Remotes.PartyInvite:FireClient(target, player.UserId, player.DisplayName)
		return true, `Invited {target.DisplayName}`
	end,

	Accept = function(player, userId)
		local inviter = findPlayer(userId)
		local sentAt = inviter and invites[player] and invites[player][inviter]
		if not inviter or not sentAt or os.clock() - sentAt > INVITE_TIMEOUT then
			return false, "That invite expired"
		end
		invites[player][inviter] = nil
		local leader = if partyOf[inviter] then partyOf[inviter].Leader else inviter
		return join(player, leader)
	end,

	Decline = function(player, userId)
		local inviter = findPlayer(userId)
		if inviter and invites[player] then
			invites[player][inviter] = nil
			PlayerService.Notify(inviter, `{player.DisplayName} declined your party invite`)
		end
		return true
	end,

	Leave = function(player)
		if not partyOf[player] then
			return false, "You're not in a party"
		end
		leave(player)
		return true, "You left the party"
	end,

	Kick = function(player, userId)
		local party = partyOf[player]
		local target = findPlayer(userId)
		if not party or party.Leader ~= player then
			return false, "Only the party leader can kick"
		end
		if not target or partyOf[target] ~= party or target == player then
			return false, "Player not in your party"
		end
		leave(target)
		PlayerService.Notify(target, "You were removed from the party")
		return true
	end,
}

-- Everyone else in `player`'s party (for DungeonService).
function PartyService.GetPartyMembers(player: Player): { Player }
	local party = partyOf[player]
	local others = {}
	if party then
		for _, member in party.Members do
			if member ~= player then
				table.insert(others, member)
			end
		end
	end
	return others
end

function PartyService.Refresh(player: Player)
	local party = partyOf[player]
	if party then
		broadcast(party)
	end
end

function PartyService.Start()
	Remotes.PartyAction.OnServerInvoke = function(player: Player, action: unknown, arg: unknown)
		local handler = type(action) == "string" and ACTIONS[action]
		if not handler then
			return false, "Unknown action"
		end
		return handler(player, arg)
	end
	Remotes.GetParty.OnServerInvoke = function(player: Player)
		return info(partyOf[player])
	end

	Players.PlayerAdded:Connect(function(player)
		-- Joined from a friend's party invite?
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		local launch = ok and joinData and joinData.LaunchData
		local inviterId = type(launch) == "string" and tonumber(launch:match("^party:(%d+)$"))
		if inviterId then
			task.delay(5, function()
				local inviter = Players:GetPlayerByUserId(inviterId)
				if inviter and player.Parent then
					local leader = if partyOf[inviter] then partyOf[inviter].Leader else inviter
					join(player, leader)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
		for _, sent in invites do
			sent[player] = nil
		end
	end)
	-- Keep levels/classes in the party list fresh
	PlayerService.OnPush(function(player)
		local party = partyOf[player]
		if party then
			broadcast(party)
		end
	end)
end

return PartyService
