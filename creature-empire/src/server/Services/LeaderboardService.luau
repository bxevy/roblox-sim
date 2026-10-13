--!strict
-- Leaderboards on OrderedDataStores (LeaderboardConfig, Shared/Util/Leaderboard).
--   * each player's scores are written every UpdateInterval and when they leave
--   * the top 10 of every board is read every RefreshInterval and sent to all clients,
--     and drawn on the board in the plaza
-- DataStores can fail or be unavailable (Studio without API access): every call is
-- wrapped, and the board says so instead of breaking.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local LeaderboardConfig = require(Shared.Config.LeaderboardConfig)
local Leaderboard = require(Shared.Util.Leaderboard)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Parts = require(script.Parent.Parent.World.Parts)

local LeaderboardService = {}

export type Entry = { Rank: number, UserId: number, Name: string, Score: number }

local tops: { [string]: { Entry } } = {}
local status = "Loading leaderboards…"
local lastWrite: { [Player]: number } = {}
local names: { [number]: string } = {}
local boardLabels: { [string]: TextLabel } = {}

local function storeName(board: LeaderboardConfig.Board): string
	local name = `CE_LB_{board.Id}_v{LeaderboardConfig.StoreVersion}`
	if board.Weekly then
		name ..= "_w" .. Leaderboard.Week(os.time())
	end
	return name
end

local function store(board: LeaderboardConfig.Board): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName(board))
	end)
	return if ok then result else nil
end

-- Scores are read from data right away (no yields), then written in the background.
local function writeScores(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	lastWrite[player] = os.clock()
	local userId = player.UserId
	local scores = {}
	for _, board in LeaderboardConfig.Boards do
		scores[board.Id] = Leaderboard.Score(board.Id, data, os.time())
	end
	task.spawn(function()
		for _, board in LeaderboardConfig.Boards do
			local score = scores[board.Id]
			local ds = store(board)
			if ds and score > 0 then
				local ok, err = pcall(function()
					(ds :: OrderedDataStore):SetAsync(tostring(userId), score)
					return true
				end)
				if not ok then
					Log.Debug("Leaderboard", "Write failed", { board = board.Id, error = tostring(err) })
				end
			end
		end
	end)
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and type(name) == "string" then name else "Player"
	return names[userId]
end

local function render()
	for _, board in LeaderboardConfig.Boards do
		local label = boardLabels[board.Id]
		if label then
			local lines = { `<b>{board.Name}</b>` }
			local entries = tops[board.Id]
			if entries and #entries > 0 then
				for _, entry in entries do
					local score = if board.Format == "Number" then Format.Number(entry.Score) else tostring(entry.Score)
					table.insert(lines, `{entry.Rank}. {entry.Name}  <font color="#ffd56a">{score}</font>`)
				end
			else
				table.insert(lines, `<font color="#9aa6c4">{status}</font>`)
			end
			label.Text = table.concat(lines, "\n")
		end
	end
end

local function refresh()
	local anyOk = false
	for _, board in LeaderboardConfig.Boards do
		local ds = store(board)
		if ds then
			local ok, page = pcall(function()
				return (ds :: OrderedDataStore):GetSortedAsync(false, LeaderboardConfig.Size):GetCurrentPage()
			end)
			if ok then
				anyOk = true
				local entries: { Entry } = {}
				for rank, item in page do
					local userId = tonumber(item.key)
					if userId then
						table.insert(
							entries,
							{ Rank = rank, UserId = userId, Name = nameOf(userId), Score = item.value }
						)
					end
				end
				tops[board.Id] = entries
			else
				Log.Debug("Leaderboard", "Read failed", { board = board.Id, error = tostring(page) })
			end
		end
	end
	status = if anyOk
		then "No scores yet. Be the first!"
		else "Leaderboards need DataStore access (publish the game, or enable API access in Studio)."
	render()
	Remotes.Events.GameEvent:FireAllClients("Leaderboards", { Boards = tops, Status = status })
end

-- The board in the plaza, between two paths on the west side.
local function buildBoard()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = Workspace
	local origin = CFrame.new(-28, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0)
	for _, x in { -9, 9 } do
		Parts.Part(folder, {
			Size = Vector3.new(0.8, 12, 0.8),
			CFrame = origin * CFrame.new(x, 6, 0),
			Color = Color3.fromRGB(110, 80, 55),
			Material = Enum.Material.Wood,
		})
	end
	local panel = Parts.Part(folder, {
		Name = "Board",
		Size = Vector3.new(18, 9, 0.5),
		CFrame = origin * CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(35, 40, 60),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- faces +X, toward the plaza centre
	gui.CanvasSize = Vector2.new(1200, 600)
	gui.LightInfluence = 0
	gui.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -12, 1, -20)
	grid.CellPadding = UDim2.fromOffset(12, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gui
	for order, board in LeaderboardConfig.Boards do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(235, 240, 255)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 26
		label.RichText = true
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Text = `<b>{board.Name}</b>\n{status}`
		label.Parent = gui
		boardLabels[board.Id] = label
	end
	Parts.Label(panel, "LEADERBOARDS", { Offset = Vector3.new(0, 6, 0), MaxDistance = 120 })
end

function LeaderboardService.Top(): ({ [string]: { Entry } }, string)
	return tops, status
end

function LeaderboardService.Start()
	buildBoard()
	PlayerDataService.Loaded:Connect(function(player)
		Remotes.Events.GameEvent:FireClient(player, "Leaderboards", { Boards = tops, Status = status })
	end)
	PlayerDataService.BeforeRelease:Connect(function(player)
		writeScores(player)
		lastWrite[player] = nil
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				if os.clock() - (lastWrite[player] or 0) >= LeaderboardConfig.UpdateInterval then
					writeScores(player)
				end
			end
			refresh()
			task.wait(LeaderboardConfig.RefreshInterval)
		end
	end)
end

return LeaderboardService
