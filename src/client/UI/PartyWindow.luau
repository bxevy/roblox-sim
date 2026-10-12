-- Party window (O): your party, invite players in this server (friends first), invite
-- Roblox friends to the game, and accept / decline invites you receive. Party members get
-- a green outline so you can find them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(script.Parent.Util)

local PartyWindow = {}

local GREEN = Color3.fromRGB(120, 230, 140)

-- toast(message, isError) shows feedback on the HUD.
function PartyWindow.new(gui: ScreenGui, toast: (string, boolean?) -> ())
	local self: any = {}
	local player = Players.LocalPlayer
	local party = nil
	local friends: { [number]: boolean } = {}

	local window, body
	window, body = Util.window(gui, "Party", Vector2.new(480, 560), function()
		window.Visible = false
	end)

	local inviteFriends = Util.button(body, {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(40, 140, 200),
		Text = "Invite Friends to the Game",
	})
	local partyTitle = Util.text(body, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GREEN,
		Text = "Your party",
	})
	local partyList = Util.make("Frame", body, {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 4 * 42),
		BackgroundTransparency = 1,
	})
	Util.make("UIListLayout", partyList, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	local leaveButton = Util.button(body, {
		Position = UDim2.fromOffset(0, 80 + 4 * 42 + 4),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(150, 50, 50),
		Text = "Leave Party",
		Visible = false,
	})
	Util.text(body, {
		Position = UDim2.fromOffset(0, 80 + 4 * 42 + 46),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Players in this server",
	})
	local serverList = Util.list(body, {
		Position = UDim2.fromOffset(0, 80 + 4 * 42 + 72),
		Size = UDim2.new(1, 0, 1, -(80 + 4 * 42 + 72)),
	})

	-- Incoming invite popup
	local popup = Util.panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(380, 100),
		Visible = false,
		ZIndex = 20,
	})
	local popupText = Util.text(popup, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 40), ZIndex = 21, Text = "" })
	local acceptButton = Util.button(popup, { Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(0.5, -15, 0, 36), BackgroundColor3 = Color3.fromRGB(60, 150, 80), Text = "Join", ZIndex = 21 })
	local declineButton = Util.button(popup, { Position = UDim2.new(0.5, 5, 1, -44), Size = UDim2.new(0.5, -15, 0, 36), BackgroundColor3 = Color3.fromRGB(150, 60, 60), Text = "Decline", ZIndex = 21 })
	local pendingInviter: number? = nil
	local inviteToken = 0

	local function action(name: string, arg: any)
		local ok, message = Remotes.PartyAction:InvokeServer(name, arg)
		if message then
			toast(message, not ok)
		end
		return ok
	end

	local function inParty(userId: number): boolean
		if not party then
			return false
		end
		for _, member in party.Members do
			if member.UserId == userId then
				return true
			end
		end
		return false
	end

	-- Green outlines on party members
	local outlines: { [number]: Highlight } = {}
	local function updateOutlines()
		for userId, highlight in outlines do
			if not inParty(userId) or not highlight.Parent then
				highlight:Destroy()
				outlines[userId] = nil
			end
		end
		if not party then
			return
		end
		for _, member in party.Members do
			local other = Players:GetPlayerByUserId(member.UserId)
			local character = other and other ~= player and other.Character
			if character and not (outlines[member.UserId] and outlines[member.UserId].Parent == character) then
				if outlines[member.UserId] then
					outlines[member.UserId]:Destroy()
				end
				local highlight = Instance.new("Highlight")
				highlight.FillTransparency = 1
				highlight.OutlineColor = GREEN
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = character
				outlines[member.UserId] = highlight
			end
		end
	end

	local function renderParty()
		Util.clear(partyList)
		local isLeader = party ~= nil and party.Leader == player.UserId
		leaveButton.Visible = party ~= nil
		if not party then
			partyTitle.Text = "You're not in a party - invite someone below!"
		else
			partyTitle.Text = `Your party ({#party.Members}/{party.MaxSize})`
			for i, member in party.Members do
				local row = Util.panel(partyList, {
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 38),
					BackgroundColor3 = Util.ButtonColor,
					BackgroundTransparency = 0,
				})
				Util.text(row, {
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -100, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = if member.Leader then Color3.fromRGB(255, 215, 90) else Color3.new(1, 1, 1),
					Text = `{if member.Leader then "[Leader] " else ""}{member.Name} - Lv {member.Level} {member.Class}{if member.InDungeon then " (in dungeon)" else ""}`,
				})
				if isLeader and member.UserId ~= player.UserId then
					local kick = Util.button(row, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -6, 0.5, 0),
						Size = UDim2.fromOffset(80, 28),
						BackgroundColor3 = Color3.fromRGB(150, 60, 60),
						Text = "Kick",
					})
					kick.Activated:Connect(function()
						action("Kick", member.UserId)
					end)
				end
			end
		end
		updateOutlines()
	end

	local function renderServer()
		Util.clear(serverList)
		local others = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(others, other)
			end
		end
		table.sort(others, function(a, b)
			local fa, fb = friends[a.UserId] == true, friends[b.UserId] == true
			if fa ~= fb then
				return fa
			end
			return a.DisplayName < b.DisplayName
		end)
		if #others == 0 then
			Util.text(serverList, { Size = UDim2.new(1, -10, 0, 40), TextColor3 = Color3.fromRGB(170, 170, 180), Text = "Nobody else here yet - invite your friends!" })
		end
		for i, other in others do
			local row = Util.panel(serverList, {
				LayoutOrder = i,
				Size = UDim2.new(1, -10, 0, 38),
				BackgroundColor3 = Util.ButtonColor,
				BackgroundTransparency = 0,
			})
			Util.text(row, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -120, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if friends[other.UserId] then Color3.fromRGB(130, 200, 255) else Color3.new(1, 1, 1),
				Text = `{if friends[other.UserId] then "[Friend] " else ""}{other.DisplayName}`,
			})
			local member = inParty(other.UserId)
			local invite = Util.button(row, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(100, 28),
				BackgroundColor3 = if member then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(60, 150, 80),
				Text = if member then "In party" else "Invite",
				AutoButtonColor = not member,
			})
			invite.Activated:Connect(function()
				if not member then
					action("Invite", other.UserId)
				end
			end)
		end
	end

	-- Friend checks yield, so do them in the background
	local function checkFriend(other: Player)
		if other == player then
			return
		end
		task.spawn(function()
			local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			friends[other.UserId] = ok and isFriend or nil
			if window.Visible then
				renderServer()
			end
		end)
	end
	for _, other in Players:GetPlayers() do
		checkFriend(other)
	end
	Players.PlayerAdded:Connect(function(other)
		checkFriend(other)
		renderServer()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(renderServer)
	end)

	inviteFriends.Activated:Connect(function()
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not ok or not canInvite then
			toast("Invites aren't available here (try the published game)", true)
			return
		end
		-- Friends who join from this invite go straight into your party
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Come delve dungeons with me!"
		options.LaunchData = `party:{player.UserId}`
		pcall(SocialService.PromptGameInvite, SocialService, player, options)
	end)
	leaveButton.Activated:Connect(function()
		action("Leave")
	end)
	acceptButton.Activated:Connect(function()
		popup.Visible = false
		if pendingInviter then
			action("Accept", pendingInviter)
			pendingInviter = nil
		end
	end)
	declineButton.Activated:Connect(function()
		popup.Visible = false
		if pendingInviter then
			Remotes.PartyAction:InvokeServer("Decline", pendingInviter)
			pendingInviter = nil
		end
	end)

	Remotes.PartyInvite.OnClientEvent:Connect(function(userId: number, name: string)
		pendingInviter = userId
		inviteToken += 1
		local token = inviteToken
		popupText.Text = `{name} invited you to their party!`
		popup.Visible = true
		Util.playSfx("Click")
		task.delay(30, function()
			if inviteToken == token then
				popup.Visible = false
			end
		end)
	end)
	Remotes.PartyChanged.OnClientEvent:Connect(function(info)
		party = info
		renderParty()
		renderServer()
	end)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		updateOutlines()
	end)
	-- Re-outline members when they respawn
	task.spawn(function()
		while true do
			task.wait(3)
			updateOutlines()
		end
	end)

	function self.Toggle()
		window.Visible = not window.Visible
		if window.Visible then
			renderServer()
		end
	end

	task.spawn(function()
		party = Remotes.GetParty:InvokeServer()
		renderParty()
	end)
	renderServer()

	return self
end

return PartyWindow
