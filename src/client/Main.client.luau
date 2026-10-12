-- Client entry point. Builds the HUD in code and talks to the server via Remotes.
-- The server owns all game state; the client only displays it and sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local PANEL_COLOR = Color3.fromRGB(25, 22, 30)

-- Your sword is always out, and we draw our own health bar.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- UI helpers -------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function make(className: string, parent: Instance?, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		TextScaled = true,
	})
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

local function panel(parent: Instance, props: { [string]: any }): Frame
	local frame = make("Frame", parent, {
		BackgroundColor3 = PANEL_COLOR,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	})
	for k, v in props do
		(frame :: any)[k] = v
	end
	corner(frame, 10)
	return frame
end

-- Bar with a fill frame and a centered label. Returns (fill, label).
local function bar(parent: Instance, position: UDim2, size: UDim2, color: Color3): (Frame, TextLabel)
	local back = panel(parent, { Position = position, Size = size, AnchorPoint = Vector2.new(0.5, 1) })
	local fill = make("Frame", back, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
	corner(fill, 10)
	local label = text(back, { Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), ZIndex = 2 })
	return fill, label
end

-- HUD ----------------------------------------------------------------------------

local gui = make("ScreenGui", playerGui, {
	Name = "HUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
})

-- Stats (top-left)
local stats = panel(gui, { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(200, 74) })
local levelLabel = text(stats, {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Level 1",
})
local goldLabel = text(stats, {
	Position = UDim2.fromOffset(12, 38),
	Size = UDim2.new(1, -24, 0, 28),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 210, 80),
	Text = "Gold: 0",
})

-- Health + XP (bottom-center)
local healthFill, healthLabel = bar(gui, UDim2.new(0.5, 0, 1, -44), UDim2.fromOffset(360, 28), Color3.fromRGB(200, 50, 50))
local xpFill, xpLabel = bar(gui, UDim2.new(0.5, 0, 1, -16), UDim2.fromOffset(360, 20), Color3.fromRGB(70, 140, 255))

-- Ability buttons (above the bars)
local abilityButtons: { [string]: { Button: TextButton, Cover: Frame, Timer: TextLabel } } = {}
local abilityCount = #Config.AbilityOrder
for i, abilityId in Config.AbilityOrder do
	local ability = Config.Abilities[abilityId]
	local button = make("TextButton", gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, (i - (abilityCount + 1) / 2) * 90, 1, -84),
		Size = UDim2.fromOffset(80, 64),
		BackgroundColor3 = ability.Color,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		Text = `{ability.DisplayName}\n[{ability.Key.Name}]`,
		AutoButtonColor = true,
	})
	corner(button, 10)
	make("UIPadding", button, {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	})
	local cover = make("Frame", button, {
		Size = UDim2.new(1, 12, 1, 12),
		Position = UDim2.fromOffset(-6, -6),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 2,
	})
	corner(cover, 10)
	local timer = text(cover, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	abilityButtons[abilityId] = { Button = button, Cover = cover, Timer = timer }
end

-- Dungeon status + toasts (top-center)
local statusLabel = text(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(460, 34),
	TextColor3 = Color3.fromRGB(255, 220, 150),
	Visible = false,
})
local toast = text(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(520, 36),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})

-- Inventory (left side)
local inventoryButton = make("TextButton", gui, {
	Position = UDim2.fromOffset(16, 100),
	Size = UDim2.fromOffset(200, 40),
	BackgroundColor3 = Color3.fromRGB(110, 75, 40),
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Weapons",
})
corner(inventoryButton, 10)

local inventory = panel(gui, {
	Position = UDim2.fromOffset(16, 150),
	Size = UDim2.fromOffset(280, 320),
	Visible = false,
})
local inventoryList = make("ScrollingFrame", inventory, {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 1, -16),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
make("UIListLayout", inventoryList, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

inventoryButton.Activated:Connect(function()
	inventory.Visible = not inventory.Visible
end)

-- Toasts -----------------------------------------------------------------------

local toastToken = 0
local function showToast(message: string, color: Color3?)
	toastToken += 1
	local myToken = toastToken
	toast.Text = message
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	task.delay(2.5, function()
		if toastToken == myToken then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- State -> UI ------------------------------------------------------------------

local function renderInventory(state)
	for _, child in inventoryList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for order, weaponId in Weapons.Order do
		if state.Inventory[weaponId] then
			local weapon = Weapons.Defs[weaponId]
			local equipped = state.Equipped == weaponId
			local button = make("TextButton", inventoryList, {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 52),
				BackgroundColor3 = if equipped then Color3.fromRGB(60, 110, 60) else Color3.fromRGB(45, 40, 55),
				Font = FONT,
				TextSize = 16,
				TextWrapped = true,
				TextColor3 = Config.Rarities[weapon.Rarity],
				Text = `{weapon.DisplayName}{if equipped then " (equipped)" else ""}\n{weapon.Rarity} | {weapon.Damage} dmg`,
			})
			corner(button, 8)
			button.Activated:Connect(function()
				if not equipped then
					local ok, err = Remotes.EquipWeapon:InvokeServer(weaponId)
					if not ok and err then
						showToast(err, Color3.fromRGB(255, 90, 90))
					end
				end
			end)
		end
	end
end

local function render(state)
	if not state then
		return
	end
	levelLabel.Text = `Level {state.Level}`
	goldLabel.Text = `Gold: {state.Gold}`
	xpFill.Size = UDim2.fromScale(math.clamp(state.XP / state.XPNeeded, 0, 1), 1)
	xpLabel.Text = `XP {state.XP} / {state.XPNeeded}`
	renderInventory(state)
end

Remotes.StateChanged.OnClientEvent:Connect(render)
Remotes.Notify.OnClientEvent:Connect(showToast)
Remotes.DungeonStatus.OnClientEvent:Connect(function(status: string?)
	statusLabel.Visible = status ~= nil
	statusLabel.Text = status or ""
end)

-- Health bar follows whatever character we currently have.
local function trackCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local function update()
		local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
		healthFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		healthLabel.Text = `{math.ceil(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end
player.CharacterAdded:Connect(trackCharacter)
if player.Character then
	task.spawn(trackCharacter, player.Character)
end

-- Abilities --------------------------------------------------------------------

local function showCooldown(abilityId: string, seconds: number)
	local entry = abilityButtons[abilityId]
	local endsAt = os.clock() + seconds
	entry.Cover.Visible = true
	task.spawn(function()
		while os.clock() < endsAt do
			entry.Timer.Text = tostring(math.ceil(endsAt - os.clock()))
			task.wait(0.1)
		end
		entry.Cover.Visible = false
	end)
end

local function useAbility(abilityId: string)
	if abilityButtons[abilityId].Cover.Visible then
		return
	end
	local ok, cooldown = Remotes.UseAbility:InvokeServer(abilityId)
	if cooldown and cooldown > 0 then
		showCooldown(abilityId, cooldown)
	end
	if not ok and cooldown == 0 then
		showToast("Can't use that right now")
	end
end

for abilityId, entry in abilityButtons do
	entry.Button.Activated:Connect(function()
		useAbility(abilityId)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	for abilityId, ability in Config.Abilities do
		if input.KeyCode == ability.Key then
			useAbility(abilityId)
		end
	end
end)

-- Data may have loaded before this script started listening.
render(Remotes.GetState:InvokeServer())
