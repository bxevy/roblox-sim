-- Global leaderboards: saves each player's stats to OrderedDataStores, reads the top 10,
-- and shows them on the boards in the Hall of Heroes (near the south gate) and in the
-- Stats window. Without DataStore access (e.g. unpublished Studio places) the boards
-- rank the players in the current server instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local TOP_COUNT = 10
local STORE_VERSION = "v1"
-- Hall of Heroes: two boards each side of the south gate, facing into town.
local BOARD_SPOTS = { Vector3.new(-47, 0, 50), Vector3.new(-36, 0, 50), Vector3.new(36, 0, 50), Vector3.new(47, 0, 50) }

local LeaderboardService = {}

type Entry = { Name: string, Value: number }

local stores: { [string]: OrderedDataStore } = {}
local tops: { [string]: { Entry } } = {}
local lastSaved: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}
local boardLists: { [string]: Frame } = {}

local rgb = Color3.fromRGB
local M = Enum.Material

-- The number stored for a board. Level boards rank by level, then XP.
local function scoreFor(data, boardId: string): number
	if boardId == "Level" then
		return data.Level * 1000000 + math.min(data.XP, 999999)
	end
	return math.floor(data.Stats[boardId] or 0)
end

local function displayValue(boardId: string, score: number): string
	if boardId == "Level" then
		return `Lv {math.floor(score / 1000000)}`
	end
	-- 12345 -> 12,345
	local text = tostring(math.floor(score))
	while true do
		local replaced, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return text
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else `Player {userId}`
	return names[userId]
end

-- Saving & loading ----------------------------------------------------------------------

local function saveScores()
	for _, player in Players:GetPlayers() do
		local data = PlayerService.GetData(player)
		if data then
			local saved = lastSaved[player] or {}
			lastSaved[player] = saved
			for _, board in Config.Leaderboards do
				local store = stores[board.Id]
				local score = scoreFor(data, board.Id)
				if store and saved[board.Id] ~= score and score > 0 then
					local ok = pcall(store.SetAsync, store, tostring(player.UserId), score)
					if ok then
						saved[board.Id] = score
					end
				end
			end
		end
	end
end

-- Top players in this server only (used when DataStores aren't available).
local function serverTop(boardId: string): { Entry }
	local entries = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerService.GetData(player)
		if data then
			table.insert(entries, { Name = player.Name, Score = scoreFor(data, boardId) })
		end
	end
	table.sort(entries, function(a, b)
		return a.Score > b.Score
	end)
	local top = {}
	for i = 1, math.min(TOP_COUNT, #entries) do
		table.insert(top, { Name = entries[i].Name, Value = entries[i].Score })
	end
	return top
end

local function loadTop(boardId: string): { Entry }
	local store = stores[boardId]
	if store then
		local ok, pages = pcall(store.GetSortedAsync, store, false, TOP_COUNT)
		if ok then
			local top = {}
			for _, item in pages:GetCurrentPage() do
				table.insert(top, { Name = nameOf(tonumber(item.key) or 0), Value = item.value })
			end
			if #top > 0 then
				return top
			end
		end
	end
	return serverTop(boardId)
end

-- Boards ------------------------------------------------------------------------------

local function renderBoard(boardId: string)
	local list = boardLists[boardId]
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local top = tops[boardId] or {}
	for rank = 1, TOP_COUNT do
		local entry = top[rank]
		local row = Instance.new("Frame")
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 1 / TOP_COUNT, -4)
		row.BackgroundColor3 = if rank % 2 == 0 then rgb(45, 34, 26) else rgb(55, 42, 32)
		row.BorderSizePixel = 0
		row.Parent = list
		local rankColor = ({ rgb(255, 215, 80), rgb(210, 210, 220), rgb(215, 140, 80) })[rank] or rgb(230, 220, 200)
		for i, info in {
			{ `#{rank}`, 0, 0.14, Enum.TextXAlignment.Center, rankColor },
			{ if entry then entry.Name else "-", 0.15, 0.5, Enum.TextXAlignment.Left, rgb(240, 230, 210) },
			{ if entry then displayValue(boardId, entry.Value) else "", 0.65, 0.33, Enum.TextXAlignment.Right, rgb(240, 230, 210) },
		} do
			local label = Instance.new("TextLabel")
			label.Name = `Col{i}`
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(info[2], 0)
			label.Size = UDim2.fromScale(info[3], 1)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextXAlignment = info[4]
			label.TextColor3 = info[5]
			label.Text = info[1]
			label.Parent = row
		end
	end
end

local function buildBoard(parent: Instance, position: Vector3, board)
	local base = CFrame.lookAt(position, position - Vector3.zAxis) -- face north, into town
	local wood = rgb(90, 60, 38)
	Build.block(parent, "BoardBase", Vector3.new(10, 1, 3), base * CFrame.new(0, 0.5, 0), rgb(85, 80, 76), M.Slate)
	for _, x in { -4.6, 4.6 } do
		Build.block(parent, "BoardPost", Vector3.new(0.8, 12, 0.8), base * CFrame.new(x, 6.5, 0.3), wood, M.Wood)
	end
	Build.block(parent, "BoardRoof", Vector3.new(10.6, 0.5, 2.4), base * CFrame.new(0, 12.6, 0.1), wood, M.WoodPlanks)
	local crest = Build.block(parent, "BoardCrest", Vector3.new(1.2, 1.2, 0.3), base * CFrame.new(0, 13.4, -0.4) * CFrame.Angles(0, 0, math.rad(45)), board.Color, M.Neon)
	Build.light(crest, board.Color, 12, 1)
	local panel = Build.block(parent, "BoardPanel", Vector3.new(8.4, 10, 0.3), base * CFrame.new(0, 6.6, 0.2), rgb(40, 30, 22), M.WoodPlanks)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = panel
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.12)
	title.Font = Enum.Font.Fantasy
	title.TextScaled = true
	title.TextColor3 = board.Color
	title.Text = board.DisplayName
	title.Parent = gui
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.14)
	list.Size = UDim2.fromScale(0.92, 0.84)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	boardLists[board.Id] = list
end

local function buildHall()
	local hall = Instance.new("Model")
	hall.Name = "HallOfHeroes"
	for i, board in Config.Leaderboards do
		local spot = BOARD_SPOTS[i]
		if spot then
			buildBoard(hall, spot, board)
		end
	end
	-- A sign between each pair of boards
	for _, x in { -41.5, 41.5 } do
		local sign = Build.block(hall, "HallSign", Vector3.new(4, 1.2, 0.3), CFrame.lookAt(Vector3.new(x, 11, 49.2), Vector3.new(x, 11, 0)), rgb(60, 42, 28), M.WoodPlanks)
		Build.label(sign, "HALL OF HEROES", rgb(255, 215, 120))
	end
	hall.Parent = workspace
end

local function refresh()
	saveScores()
	for _, board in Config.Leaderboards do
		tops[board.Id] = loadTop(board.Id)
		renderBoard(board.Id)
	end
end

function LeaderboardService.Start()
	for _, board in Config.Leaderboards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(`LB_{board.Id}_{STORE_VERSION}`)
		end)
		if ok then
			stores[board.Id] = store
		end
	end
	buildHall()

	Remotes.GetLeaderboards.OnServerInvoke = function()
		return tops
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSaved[player] = nil
	end)

	-- Count minutes played
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				PlayerService.AddStat(player, "MinutesPlayed")
			end
		end
	end)

	task.spawn(function()
		task.wait(10) -- let the first players' data load
		while true do
			refresh()
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return LeaderboardService
