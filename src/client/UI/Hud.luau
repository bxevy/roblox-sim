-- Always-on screen elements: stats, health/XP bars, ability + potion hotbars,
-- active buffs, dungeon status and toast messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local ABILITY_KEYS = { "Q", "E" }

local Hud = {}

export type Actions = {
	UseAbility: (abilityId: string) -> (),
	UsePotion: (potionId: string) -> (),
	ToggleWeapon: () -> (),
	ToggleInventory: () -> (),
	OpenClassPicker: () -> (),
	OpenAdmin: () -> (),
	ToggleMusic: () -> boolean, -- returns whether music is now on
	SetSprint: (on: boolean) -> (),
	Dodge: () -> (),
}

function Hud.new(gui: ScreenGui, actions: Actions)
	local self = {}

	-- Stats (top-left) -------------------------------------------------------
	local stats = Util.panel(gui, { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(220, 100) })
	local classLabel = Util.text(stats, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Level 1",
	})
	local goldLabel = Util.text(stats, {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 210, 80),
		Text = "Gold: 0",
	})
	local defenseLabel = Util.text(stats, {
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(180, 190, 210),
		Text = "",
	})

	local inventoryButton = Util.button(gui, {
		Position = UDim2.fromOffset(16, 124),
		Size = UDim2.fromOffset(106, 40),
		BackgroundColor3 = Color3.fromRGB(110, 75, 40),
		Text = "Gear [G]",
	})
	inventoryButton.Activated:Connect(actions.ToggleInventory)

	local classButton = Util.button(gui, {
		Position = UDim2.fromOffset(130, 124),
		Size = UDim2.fromOffset(106, 40),
		BackgroundColor3 = Color3.fromRGB(70, 60, 120),
		Text = "Class",
	})
	classButton.Activated:Connect(actions.OpenClassPicker)

	-- Admin button, only for admins
	local player = Players.LocalPlayer
	local adminButton = Util.button(gui, {
		Position = UDim2.fromOffset(16, 172),
		Size = UDim2.fromOffset(220, 34),
		BackgroundColor3 = Color3.fromRGB(170, 40, 40),
		Text = "Admin Menu [P]",
		Visible = player:GetAttribute("IsAdmin") == true,
	})
	adminButton.Activated:Connect(actions.OpenAdmin)
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		adminButton.Visible = player:GetAttribute("IsAdmin") == true
	end)

	-- Music toggle (top-right)
	local musicButton = Util.button(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(110, 34),
		Text = "Music: On",
	})
	musicButton.Activated:Connect(function()
		musicButton.Text = if actions.ToggleMusic() then "Music: On" else "Music: Off"
	end)

	-- Buff list (under the buttons)
	local buffList = Util.make("Frame", gui, {
		Position = UDim2.fromOffset(16, 214),
		Size = UDim2.fromOffset(220, 200),
		BackgroundTransparency = 1,
	})
	Util.make("UIListLayout", buffList, { Padding = UDim.new(0, 4) })

	-- Health + XP (bottom-center) --------------------------------------------
	local function bar(y: number, height: number, color: Color3): (Frame, TextLabel)
		local back = Util.panel(gui, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, y),
			Size = UDim2.fromOffset(380, height),
		})
		local fill = Util.make("Frame", back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 })
		Util.corner(fill)
		local label = Util.text(back, { Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), ZIndex = 2 })
		return fill, label
	end
	local healthFill, healthLabel = bar(-40, 28, Color3.fromRGB(200, 50, 50))
	local xpFill, xpLabel = bar(-14, 20, Color3.fromRGB(70, 140, 255))
	local staminaFill, staminaLabel = bar(-74, 12, Color3.fromRGB(240, 200, 60))
	staminaLabel.Visible = false

	local function updateStamina()
		local stamina = player:GetAttribute("Stamina") or Config.Movement.MaxStamina
		staminaFill.Size = UDim2.fromScale(math.clamp(stamina / Config.Movement.MaxStamina, 0, 1), 1)
		staminaFill.BackgroundColor3 = if stamina < Config.Movement.DodgeCost then Color3.fromRGB(200, 110, 50) else Color3.fromRGB(240, 200, 60)
	end
	player:GetAttributeChangedSignal("Stamina"):Connect(updateStamina)
	updateStamina()

	-- Ability buttons (above the bars, right of center) -----------------------
	local abilityFrame = Util.make("Frame", gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 10, 1, -94),
		Size = UDim2.fromOffset(180, 64),
		BackgroundTransparency = 1,
	})
	local abilityButtons: { [string]: { Button: TextButton, Cover: Frame, Timer: TextLabel } } = {}
	local shownClass: string? = nil

	local function buildAbilities(classId: string?)
		Util.clear(abilityFrame)
		table.clear(abilityButtons)
		local class = classId and Config.Classes[classId]
		if not class then
			return
		end
		for i, abilityId in class.Abilities do
			local ability = Config.Abilities[abilityId]
			local button = Util.button(abilityFrame, {
				Position = UDim2.fromOffset((i - 1) * 90, 0),
				Size = UDim2.fromOffset(84, 64),
				BackgroundColor3 = ability.Color,
				TextStrokeTransparency = 0.3,
				Text = `{ability.DisplayName}\n[{ABILITY_KEYS[i]}]`,
			})
			Util.padding(button, 6)
			local cover = Util.make("Frame", button, {
				Size = UDim2.new(1, 12, 1, 12),
				Position = UDim2.fromOffset(-6, -6),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.35,
				Visible = false,
				ZIndex = 2,
			})
			Util.corner(cover, 8)
			local timer = Util.text(cover, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
			button.Activated:Connect(function()
				actions.UseAbility(abilityId)
			end)
			abilityButtons[abilityId] = { Button = button, Cover = cover, Timer = timer }
		end
	end

	-- Potion hotbar (above the bars, left of center) --------------------------
	local potionFrame = Util.make("Frame", gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -10, 1, -94),
		Size = UDim2.fromOffset((#Config.PotionOrder + 1) * 48 - 4, 44),
		BackgroundTransparency = 1,
	})

	-- Slot 1: draw / put away your weapon
	local weaponButton = Util.button(potionFrame, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Util.ButtonColor,
		Text = "",
	})
	Util.padding(weaponButton, 4)
	Util.text(weaponButton, {
		Size = UDim2.fromScale(0.45, 0.45),
		Text = "1",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local weaponLabel = Util.text(weaponButton, {
		Position = UDim2.fromScale(0, 0.45),
		Size = UDim2.fromScale(1, 0.55),
		Text = "",
	})
	weaponButton.Activated:Connect(actions.ToggleWeapon)
	local weaponStroke = Util.make("UIStroke", weaponButton, {
		Color = Color3.fromRGB(255, 220, 120),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Enabled = false,
	})

	local potionButtons: { [string]: TextButton } = {}
	for i, potionId in Config.PotionOrder do
		local potion = Config.Potions[potionId]
		local button = Util.button(potionFrame, {
			Position = UDim2.fromOffset(i * 48, 0),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = potion.Color,
			TextStrokeTransparency = 0.2,
			Text = "",
		})
		Util.padding(button, 4)
		Util.text(button, {
			Size = UDim2.fromScale(0.45, 0.45),
			Text = tostring(i + 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		button.Activated:Connect(function()
			actions.UsePotion(potionId)
		end)
		potionButtons[potionId] = button
	end

	-- Dungeon status + toasts (top-center) ------------------------------------
	local statusLabel = Util.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(520, 34),
		TextColor3 = Color3.fromRGB(255, 220, 150),
		Visible = false,
	})
	local toast = Util.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(560, 36),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 10,
	})

	-- Public -------------------------------------------------------------------

	local toastToken = 0
	function self.Toast(message: string, color: Color3?)
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

	function self.SetStatus(status: string?)
		statusLabel.Visible = status ~= nil
		statusLabel.Text = status or ""
	end

	function self.IsOnCooldown(abilityId: string): boolean
		local entry = abilityButtons[abilityId]
		return entry ~= nil and entry.Cover.Visible
	end

	function self.StartCooldown(abilityId: string, seconds: number)
		local entry = abilityButtons[abilityId]
		if not entry then
			return
		end
		local endsAt = os.clock() + seconds
		entry.Cover.Visible = true
		task.spawn(function()
			while os.clock() < endsAt and entry.Cover.Parent do
				entry.Timer.Text = tostring(math.ceil(endsAt - os.clock()))
				task.wait(0.1)
			end
			entry.Cover.Visible = false
		end)
	end

	function self.Render(state)
		local class = state.Class and Config.Classes[state.Class]
		classLabel.Text = if class then `Lv {state.Level} {class.DisplayName}` else `Level {state.Level}`
		classLabel.TextColor3 = if class then class.Color else Color3.new(1, 1, 1)
		goldLabel.Text = `Gold: {state.Gold}`
		defenseLabel.Text = `Defense {math.floor(state.Stats.Defense * 100)}%  |  Dmg x{string.format("%.2f", state.Stats.Damage)}`
		xpFill.Size = UDim2.fromScale(math.clamp(state.XP / state.XPNeeded, 0, 1), 1)
		xpLabel.Text = `XP {state.XP} / {state.XPNeeded}`

		weaponLabel.Text = if class then class.WeaponType else ""

		if state.Class ~= shownClass then
			shownClass = state.Class
			buildAbilities(state.Class)
		end

		for potionId, button in potionButtons do
			local count = state.Potions[potionId] or 0
			button.Text = if count > 0 then `\n{count}` else ""
			button.BackgroundTransparency = if count > 0 then 0 else 0.6
		end

		Util.clear(buffList)
		for buffId, remaining in state.Buffs do
			local buff = Config.Buffs[buffId]
			local label = Util.text(buffList, {
				Size = UDim2.new(1, 0, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(150, 255, 170),
				Text = `{buff.DisplayName} ({math.ceil(remaining)}s)`,
			})
			-- Count down locally until the next state update replaces it.
			local endsAt = os.clock() + remaining
			task.spawn(function()
				while label.Parent and os.clock() < endsAt do
					label.Text = `{buff.DisplayName} ({math.ceil(endsAt - os.clock())}s)`
					task.wait(0.5)
				end
			end)
		end
	end

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
	local function trackWeapon(character: Model)
		local function update()
			weaponStroke.Enabled = character:FindFirstChildOfClass("Tool") ~= nil
		end
		character.ChildAdded:Connect(update)
		character.ChildRemoved:Connect(update)
		update()
	end

	player.CharacterAdded:Connect(trackWeapon)
	if player.Character then
		trackWeapon(player.Character)
	end
	player.CharacterAdded:Connect(trackCharacter)
	if player.Character then
		task.spawn(trackCharacter, player.Character)
	end

	-- Touch screens get Sprint and Dodge buttons (keyboard uses Shift and C)
	if UserInputService.TouchEnabled then
		local sprinting = false
		local sprintButton = Util.button(gui, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -110, 1, -170),
			Size = UDim2.fromOffset(80, 50),
			BackgroundColor3 = Color3.fromRGB(200, 160, 40),
			Text = "Sprint",
		})
		sprintButton.Activated:Connect(function()
			sprinting = not sprinting
			sprintButton.BackgroundColor3 = if sprinting then Color3.fromRGB(240, 210, 80) else Color3.fromRGB(200, 160, 40)
			actions.SetSprint(sprinting)
		end)
		local dodgeButton = Util.button(gui, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -170),
			Size = UDim2.fromOffset(80, 50),
			BackgroundColor3 = Color3.fromRGB(80, 160, 200),
			Text = "Dodge",
		})
		dodgeButton.Activated:Connect(actions.Dodge)
	end

	return self
end

return Hud
