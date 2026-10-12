-- Quests: a story chain (one at a time, in order) and 3 daily quests that refresh each
-- day. Progress counts up a lifetime stat from the moment the quest is given, so any
-- stat PlayerService.AddStat tracks can drive a quest. Rewards are claimed in the
-- quest log (J, or the Quest Board next to the spawn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local Sfx = require(script.Parent.Parent.Sfx)

local BOARD_POSITION = Vector3.new(16, 0, 2)

local QuestService = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local function today(): number
	return math.floor(os.time() / 86400)
end

local function stat(data, name: string): number
	return data.Stats[name] or 0
end

-- Picks today's daily quests for a player (same picks all day, different per player).
local function rollDailies(player: Player, data)
	local eligible = {}
	for i, quest in Config.DailyQuests do
		if data.Level >= (quest.MinLevel or 0) and data.Level <= (quest.MaxLevel or math.huge) then
			table.insert(eligible, i)
		end
	end
	local rng = Random.new(today() * 1000003 + player.UserId)
	local picks = {}
	while #picks < Config.DailyQuestCount and #eligible > 0 do
		local index = table.remove(eligible, rng:NextInteger(1, #eligible))
		local quest = Config.DailyQuests[index]
		table.insert(picks, { Id = quest.Id, Start = stat(data, quest.Stat), Claimed = false })
	end
	data.Quests.Day = today()
	data.Quests.Daily = picks
end

-- Makes sure the player's quest data is set up and today's dailies exist.
local function ensure(player: Player, data)
	local quests = data.Quests
	if not quests.Story then
		quests.Story = { Index = 1, Start = stat(data, Config.StoryQuests[1].Stat) }
	end
	if quests.Day ~= today() or not quests.Daily then
		rollDailies(player, data)
	end
end

local function dailyDef(id: string)
	for _, quest in Config.DailyQuests do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

-- Everything the quest log shows.
local function view(player: Player)
	local data = PlayerService.GetData(player)
	if not data then
		return nil
	end
	ensure(player, data)

	local story = nil
	local storyIndex = data.Quests.Story.Index
	local storyDef = Config.StoryQuests[storyIndex]
	if storyDef then
		story = {
			Index = storyIndex,
			Count = #Config.StoryQuests,
			Title = storyDef.Title,
			Description = storyDef.Description,
			Progress = math.min(stat(data, storyDef.Stat) - data.Quests.Story.Start, storyDef.Target),
			Target = storyDef.Target,
			Reward = storyDef.Reward,
		}
	end

	local reward = Config.DailyReward(data.Level)
	local dailies = {}
	for i, entry in data.Quests.Daily do
		local def = dailyDef(entry.Id)
		if def then
			table.insert(dailies, {
				Index = i,
				Title = def.Title,
				Description = def.Description,
				Progress = math.min(stat(data, def.Stat) - entry.Start, def.Target),
				Target = def.Target,
				Claimed = entry.Claimed,
				Reward = reward,
			})
		end
	end

	-- Seconds until the dailies refresh
	local resetIn = (today() + 1) * 86400 - os.time()
	return { Story = story, Daily = dailies, ResetIn = resetIn }
end

local function push(player: Player)
	local quests = view(player)
	if quests then
		Remotes.QuestsChanged:FireClient(player, quests)
	end
end

local function giveReward(player: Player, reward)
	if reward.XP then
		PlayerService.AddXP(player, reward.XP)
	end
	if reward.Gold then
		PlayerService.AddGold(player, reward.Gold, true)
	end
	if reward.SkillPoints then
		local data = PlayerService.GetData(player)
		if data then
			data.SkillPoints += reward.SkillPoints
			PlayerService.Push(player)
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Sfx.play("Coins", root, 1.5)
	end
end

local function onClaim(player: Player, kind: unknown, index: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	ensure(player, data)

	if kind == "Story" then
		local storyIndex = data.Quests.Story.Index
		local def = Config.StoryQuests[storyIndex]
		if not def then
			return false, "You've finished every story quest!"
		end
		if stat(data, def.Stat) - data.Quests.Story.Start < def.Target then
			return false, "Not finished yet"
		end
		giveReward(player, def.Reward)
		local nextDef = Config.StoryQuests[storyIndex + 1]
		data.Quests.Story = { Index = storyIndex + 1, Start = if nextDef then stat(data, nextDef.Stat) else 0 }
		PlayerService.Notify(player, `Story quest complete: {def.Title}!`, rgb(255, 220, 120))
	elseif kind == "Daily" and type(index) == "number" then
		local entry = data.Quests.Daily[index]
		local def = entry and dailyDef(entry.Id)
		if not entry or not def then
			return false, "Unknown quest"
		end
		if entry.Claimed then
			return false, "Already claimed"
		end
		if stat(data, def.Stat) - entry.Start < def.Target then
			return false, "Not finished yet"
		end
		entry.Claimed = true
		giveReward(player, Config.DailyReward(data.Level))
		PlayerService.Notify(player, `Daily quest complete: {def.Title}!`, rgb(255, 220, 120))
	else
		return false, "Unknown quest"
	end
	push(player)
	return true
end

-- Tell the player when a quest they're on just got finished.
local function onStatChanged(player: Player, statName: string)
	local data = PlayerService.GetData(player)
	if not data or not data.Quests.Story then
		return
	end
	local changed = false
	local storyDef = Config.StoryQuests[data.Quests.Story.Index]
	if storyDef and storyDef.Stat == statName then
		changed = true
		if stat(data, statName) - data.Quests.Story.Start == storyDef.Target then
			PlayerService.Notify(player, `Quest ready to claim: {storyDef.Title} (J)`, rgb(255, 220, 120))
		end
	end
	for _, entry in data.Quests.Daily or {} do
		local def = dailyDef(entry.Id)
		if def and def.Stat == statName and not entry.Claimed then
			changed = true
			if stat(data, statName) - entry.Start == def.Target then
				PlayerService.Notify(player, `Quest ready to claim: {def.Title} (J)`, rgb(255, 220, 120))
			end
		end
	end
	if changed then
		push(player)
	end
end

local function buildBoard()
	local board = Instance.new("Model")
	board.Name = "QuestBoard"
	local base = CFrame.lookAt(BOARD_POSITION, Vector3.new(0, 0, BOARD_POSITION.Z))
	local wood = rgb(62, 42, 28)
	for _, x in { -3.4, 3.4 } do
		Build.block(board, "BoardPost", Vector3.new(0.6, 8, 0.6), base * CFrame.new(x, 4, 0), wood, M.Wood)
	end
	Build.block(board, "BoardRoof", Vector3.new(8, 0.4, 2), base * CFrame.new(0, 8.2, 0) * CFrame.Angles(math.rad(10), 0, 0), wood, M.WoodPlanks)
	local panel = Build.block(board, "QuestPanel", Vector3.new(6.4, 4.6, 0.3), base * CFrame.new(0, 5, 0), rgb(130, 95, 60), M.WoodPlanks)
	-- Pinned quest notes
	local rng = Random.new(5)
	for i = 0, 5 do
		local x, y = -2.2 + (i % 3) * 2.2, 0.9 - math.floor(i / 3) * 2
		local note = Build.block(board, "Note", Vector3.new(1.5, 1.6, 0.05), panel.CFrame * CFrame.new(x, y, -0.18) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), rgb(240, 225, 185), M.SmoothPlastic)
		note.CanCollide = false
		Build.block(board, "Pin", Vector3.new(0.15, 0.15, 0.1), note.CFrame * CFrame.new(0, 0.65, -0.05), rgb(200, 40, 40), M.SmoothPlastic)
	end
	local sign = Build.block(board, "QuestSign", Vector3.new(5, 1, 0.2), base * CFrame.new(0, 9.1, -0.2), wood, M.WoodPlanks)
	Build.label(sign, "QUESTS", rgb(255, 220, 140))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "View Quests"
	prompt.ObjectText = "Quest Board"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	prompt.Triggered:Connect(function(player)
		Remotes.OpenQuests:FireClient(player)
	end)
	board.Parent = workspace
end

function QuestService.Start()
	buildBoard()
	PlayerService.OnStatChanged(onStatChanged)
	Remotes.ClaimQuest.OnServerInvoke = onClaim
	Remotes.GetQuests.OnServerInvoke = view
	PlayerService.OnCharacterReady(function(player)
		push(player)
	end)
	-- Refresh dailies for players online across midnight (UTC)
	task.spawn(function()
		while true do
			task.wait(300)
			for _, player in Players:GetPlayers() do
				push(player)
			end
		end
	end)
end

return QuestService
