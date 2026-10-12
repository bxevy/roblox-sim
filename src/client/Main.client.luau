--!strict
-- Client entry point. Builds the HUD in code and talks to the server via Remotes.
-- The server owns all game state; the client only displays it and sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TRAIN_KEY = Enum.KeyCode.E
local FONT = Enum.Font.FredokaOne

-- UI helpers -----------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = FONT
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	corner(b, 10)
	b.Parent = parent
	return b
end

-- Build HUD ------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Stats (top-left)
local stats = Instance.new("Frame")
stats.Position = UDim2.new(0, 16, 0, 16)
stats.Size = UDim2.fromOffset(240, 90)
stats.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
stats.BackgroundTransparency = 0.3
corner(stats, 12)
stats.Parent = gui

local coinsLabel = label(stats, {
	Position = UDim2.new(0, 12, 0, 8),
	Size = UDim2.new(1, -24, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 215, 80),
	Text = "Coins: 0",
})
local powerLabel = label(stats, {
	Position = UDim2.new(0, 12, 0, 46),
	Size = UDim2.new(1, -24, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(120, 200, 255),
	Text = "Power: 0 / 0",
})

-- Train button (bottom-center)
local trainButton = button(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(220, 70),
	BackgroundColor3 = Color3.fromRGB(230, 80, 80),
	Text = "TRAIN [E]",
})

-- Shop (right side)
local shop = Instance.new("Frame")
shop.AnchorPoint = Vector2.new(1, 0.5)
shop.Position = UDim2.new(1, -16, 0.5, 0)
shop.Size = UDim2.fromOffset(260, 60 + #Config.UpgradeOrder * 80)
shop.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
shop.BackgroundTransparency = 0.3
corner(shop, 12)
shop.Parent = gui

label(shop, {
	Position = UDim2.new(0, 0, 0, 8),
	Size = UDim2.new(1, 0, 0, 40),
	Text = "UPGRADES",
})

local showToast: (message: string) -> () -- defined below with the toast label

local upgradeButtons: { [string]: TextButton } = {}
for i, upgradeId in Config.UpgradeOrder do
	local b = button(shop, {
		Position = UDim2.new(0, 12, 0, 50 + (i - 1) * 80),
		Size = UDim2.new(1, -24, 0, 70),
		BackgroundColor3 = Color3.fromRGB(70, 130, 230),
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
		Text = Config.Upgrades[upgradeId].DisplayName,
	})
	upgradeButtons[upgradeId] = b

	b.Activated:Connect(function()
		local ok, err = Remotes.BuyUpgrade:InvokeServer(upgradeId)
		if not ok and err then
			showToast(err)
		end
	end)
end

-- Toast notifications (top-center)
local toast = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.fromOffset(420, 40),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Text = "",
})

local toastToken = 0
showToast = function(message: string)
	toastToken += 1
	local myToken = toastToken
	toast.Text = message
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.5
	task.delay(2, function()
		if toastToken ~= myToken then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- State -> UI ----------------------------------------------------------------

local function render(state)
	if not state then
		return
	end
	coinsLabel.Text = `Coins: {state.Coins}`
	powerLabel.Text = `Power: {state.Power} / {state.Capacity}`

	for upgradeId, b in upgradeButtons do
		local def = Config.Upgrades[upgradeId]
		local level = state.Upgrades[upgradeId]
		local cost = state.UpgradeCosts[upgradeId]
		if cost then
			b.Text = `{def.DisplayName} (Lv {level})\n{def.Description}\nCost: {cost}`
			b.BackgroundColor3 = if state.Coins >= cost
				then Color3.fromRGB(70, 180, 100)
				else Color3.fromRGB(70, 90, 130)
		else
			b.Text = `{def.DisplayName} (MAX)`
			b.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		end
	end
end

Remotes.DataChanged.OnClientEvent:Connect(render)
Remotes.Notify.OnClientEvent:Connect(showToast)

-- Input ----------------------------------------------------------------------

local function train()
	Remotes.Train:FireServer()
	-- Little "punch" so clicks feel responsive before the server replies.
	trainButton.Size = UDim2.fromOffset(200, 64)
	TweenService:Create(trainButton, TweenInfo.new(0.1), { Size = UDim2.fromOffset(220, 70) }):Play()
end

trainButton.Activated:Connect(train)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == TRAIN_KEY then
		train()
	end
end)

-- Data may have loaded before this script started listening.
render(Remotes.GetData:InvokeServer())
