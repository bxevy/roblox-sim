-- Stats window (T): your lifetime stats and the global leaderboards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local StatsWindow = {}

-- fetch() returns { [boardId]: { { Name, Value } } }
function StatsWindow.new(gui: ScreenGui, fetch: () -> any)
	local self: any = {}
	local selected = Config.Leaderboards[1].Id
	local boards = {}
	local lastState = nil

	local window, body
	window, body = Util.window(gui, "Stats & Leaderboards", Vector2.new(640, 460), function()
		window.Visible = false
	end)

	-- Left: your stats
	local mine = Util.panel(body, {
		Size = UDim2.new(0.4, -6, 1, 0),
		BackgroundColor3 = Util.ButtonColor,
		BackgroundTransparency = 0,
	})
	Util.padding(mine, 10)
	local mineList = Util.list(mine)

	-- Right: board tabs + top 10
	local right = Util.make("Frame", body, {
		Position = UDim2.new(0.4, 6, 0, 0),
		Size = UDim2.new(0.6, -6, 1, 0),
		BackgroundTransparency = 1,
	})
	local tabs = Util.make("Frame", right, { Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1 })
	Util.make("UIGridLayout", tabs, { CellSize = UDim2.new(0.5, -4, 0, 32), CellPadding = UDim2.fromOffset(8, 6) })
	local topList = Util.list(right, { Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -80) })

	local tabButtons = {}
	for _, board in Config.Leaderboards do
		local button = Util.button(tabs, { TextScaled = false, TextSize = 16, Text = board.DisplayName, TextColor3 = board.Color })
		button.Activated:Connect(function()
			selected = board.Id
			self.RenderBoards()
		end)
		tabButtons[board.Id] = button
	end

	local function format(boardId: string, value: number): string
		if boardId == "Level" then
			local prestige = math.floor(value / 100000000)
			local level = math.floor(value / 1000000) % 100
			return if prestige > 0 then `P{prestige} Lv {level}` else `Lv {level}`
		end
		return tostring(math.floor(value))
	end

	function self.RenderBoards()
		for id, button in tabButtons do
			button.BackgroundColor3 = if id == selected then Color3.fromRGB(90, 70, 40) else Util.ButtonColor
		end
		Util.clear(topList)
		local top = boards[selected] or {}
		if #top == 0 then
			Util.text(topList, { Size = UDim2.new(1, -10, 0, 30), Text = "No scores yet - go adventure!", TextColor3 = Color3.fromRGB(180, 180, 190) })
		end
		for rank, entry in top do
			local row = Util.panel(topList, {
				LayoutOrder = rank,
				Size = UDim2.new(1, -10, 0, 30),
				BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(45, 40, 52) else Color3.fromRGB(55, 48, 62),
				BackgroundTransparency = 0,
			})
			local rankColor = ({ Color3.fromRGB(255, 215, 80), Color3.fromRGB(210, 210, 220), Color3.fromRGB(215, 140, 80) })[rank] or Color3.new(1, 1, 1)
			Util.text(row, { Position = UDim2.fromOffset(6, 3), Size = UDim2.new(0, 36, 1, -6), Text = `#{rank}`, TextColor3 = rankColor })
			Util.text(row, { Position = UDim2.fromOffset(46, 3), Size = UDim2.new(0.55, -46, 1, -6), Text = entry.Name, TextXAlignment = Enum.TextXAlignment.Left })
			Util.text(row, { Position = UDim2.new(0.55, 0, 0, 3), Size = UDim2.new(0.45, -10, 1, -6), Text = format(selected, entry.Value), TextXAlignment = Enum.TextXAlignment.Right })
		end
	end

	function self.Render(state)
		lastState = state
		if not window.Visible then
			return
		end
		Util.clear(mineList)
		Util.text(mineList, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30), Text = "Your stats", TextColor3 = Color3.fromRGB(255, 220, 140) })
		Util.text(mineList, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Text = `Level {state.Level}` })
		for i, entry in Config.StatNames do
			Util.text(mineList, {
				LayoutOrder = i + 1,
				Size = UDim2.new(1, 0, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = `{entry[2]}: {math.floor(state.Lifetime[entry[1]] or 0)}`,
			})
		end
	end

	function self.Toggle()
		window.Visible = not window.Visible
		if window.Visible then
			if lastState then
				self.Render(lastState)
			end
			boards = fetch() or {}
			self.RenderBoards()
		end
	end

	return self
end

return StatsWindow
