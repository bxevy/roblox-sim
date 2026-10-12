-- Class rolling window. Classes are rolled, not picked: shows every class with its odds,
-- then a reel that lands on what you rolled. First roll is free; then coins or Robux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local ClassRoller = {}

local ABILITY_KEYS = { "Q", "E" }
local TILE_WIDTH = 130
local TILE_GAP = 6
local REEL_TILES = 40
local WIN_INDEX = 34
local SPIN_TIME = 3.4

-- roll(currency) asks the server; the result arrives through ShowRoll.
function ClassRoller.new(gui: ScreenGui, roll: (currency: string) -> ())
	local self: any = {}
	local state = nil
	local spinning = false

	local window, body
	window, body = Util.window(gui, "Classes", Vector2.new(860, 580), function()
		if state and state.Class and not spinning then
			window.Visible = false
		end
	end)

	local totalWeight = 0
	for _, classId in Config.ClassOrder do
		totalWeight += Config.Classes[classId].Weight
	end

	-- Class cards
	local grid = Util.make("Frame", body, { Size = UDim2.new(1, 0, 0, 300), BackgroundTransparency = 1 })
	Util.make("UIGridLayout", grid, { CellSize = UDim2.new(1 / 3, -8, 0, 144), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local cards: { [string]: Frame } = {}
	for order, classId in Config.ClassOrder do
		local class = Config.Classes[classId]
		local card = Util.panel(grid, { LayoutOrder = order, BackgroundColor3 = Util.ButtonColor, BackgroundTransparency = 0 })
		Util.padding(card, 8)
		Util.make("UIStroke", card, { Color = class.Color, Thickness = 2 })
		Util.text(card, { Size = UDim2.new(0.6, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = class.Color, Text = class.DisplayName })
		Util.text(card, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.4, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Config.Rarities[class.Rarity],
			Text = `{class.Rarity} {string.format("%.0f", class.Weight / totalWeight * 100)}%`,
		})
		local abilities = {}
		for i, abilityId in class.Abilities do
			table.insert(abilities, `[{ABILITY_KEYS[i]}] {Config.Abilities[abilityId].DisplayName}`)
		end
		Util.text(card, {
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 1, -28),
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(215, 215, 225),
			Text = `{class.WeaponType} | {class.Passive}\n{table.concat(abilities, "   ")}\n{class.Description}`,
		})
		cards[classId] = card
	end

	-- Reel
	local reel = Util.panel(body, {
		Position = UDim2.fromOffset(0, 312),
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundColor3 = Color3.fromRGB(15, 13, 18),
		BackgroundTransparency = 0,
		ClipsDescendants = true,
	})
	local strip = Util.make("Frame", reel, {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(0, REEL_TILES * (TILE_WIDTH + TILE_GAP), 1, -16),
		BackgroundTransparency = 1,
	})
	Util.make("Frame", reel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 220, 120),
		BorderSizePixel = 0,
		ZIndex = 5,
	})
	local status = Util.text(body, { Position = UDim2.fromOffset(0, 410), Size = UDim2.new(1, 0, 0, 34), Text = "" })

	local coinButton = Util.button(body, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -6, 1, 0),
		Size = UDim2.new(0.4, 0, 0, 50),
		BackgroundColor3 = Color3.fromRGB(200, 150, 40),
		Text = "",
	})
	coinButton.Activated:Connect(function()
		if not spinning then
			roll("Coins")
		end
	end)
	local robuxButton = Util.button(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 6, 1, 0),
		Size = UDim2.new(0.4, 0, 0, 50),
		BackgroundColor3 = Color3.fromRGB(40, 160, 90),
		Text = `Roll ({Config.ClassRoll.RobuxPriceLabel})`,
	})
	robuxButton.Activated:Connect(function()
		if not spinning then
			roll("Robux")
		end
	end)

	local function randomClass(): string
		local r = math.random() * totalWeight
		for _, classId in Config.ClassOrder do
			r -= Config.Classes[classId].Weight
			if r <= 0 then
				return classId
			end
		end
		return Config.ClassOrder[1]
	end

	local function tile(index: number, classId: string)
		local class = Config.Classes[classId]
		local frame = Util.panel(strip, {
			Position = UDim2.fromOffset((index - 1) * (TILE_WIDTH + TILE_GAP), 0),
			Size = UDim2.new(0, TILE_WIDTH, 1, 0),
			BackgroundColor3 = Color3.fromRGB(40, 36, 46),
			BackgroundTransparency = 0,
		})
		Util.make("Frame", frame, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = Config.Rarities[class.Rarity],
			BorderSizePixel = 0,
		})
		Util.text(frame, { Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 32), TextColor3 = class.Color, Text = class.DisplayName })
		Util.text(frame, { Position = UDim2.fromOffset(6, 42), Size = UDim2.new(1, -12, 0, 18), TextColor3 = Config.Rarities[class.Rarity], Text = class.Rarity })
	end

	-- Called when the server says what we rolled.
	function self.ShowRoll(classId: string)
		window.Visible = true
		spinning = true
		status.Text = "Rolling..."
		Util.clear(strip)
		for i = 1, REEL_TILES do
			tile(i, if i == WIN_INDEX then classId else randomClass())
		end
		strip.Position = UDim2.fromOffset(0, 8)
		local jitter = math.random(-TILE_WIDTH * 0.3, TILE_WIDTH * 0.3)
		local target = -((WIN_INDEX - 1) * (TILE_WIDTH + TILE_GAP) + TILE_WIDTH / 2 - reel.AbsoluteSize.X / 2 + jitter)
		local tween = TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(target, 8) })
		tween:Play()
		tween.Completed:Wait()
		local class = Config.Classes[classId]
		status.TextColor3 = class.Color
		status.Text = `You rolled {class.Rarity} {class.DisplayName}!`
		spinning = false
	end

	function self.Render(newState)
		state = newState or state
		if not state then
			return
		end
		local free = state.Class == nil
		coinButton.Text = if free then "FREE ROLL!" else `Roll ({Config.ClassRoll.CoinCost} coins)`
		robuxButton.Visible = not free
		for classId, card in cards do
			card.BackgroundColor3 = if state.Class == classId then Color3.fromRGB(50, 90, 55) else Util.ButtonColor
		end
		if free then
			window.Visible = true
			if not spinning then
				status.TextColor3 = Color3.new(1, 1, 1)
				status.Text = "Roll for your class! Your first roll is free."
			end
		elseif not spinning and status.Text == "" then
			local class = Config.Classes[state.Class]
			status.TextColor3 = class.Color
			status.Text = `Your class: {class.Rarity} {class.DisplayName}. Rolling again replaces it.`
		end
	end

	function self.Open()
		window.Visible = true
	end

	return self
end

return ClassRoller
