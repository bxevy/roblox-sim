-- Always-on screen elements:
--   top-left     player plate (level, class, XP, gold, candies) and active buffs
--   left side    menu sidebar (icons with key hints and hover labels)
--   bottom       hotbar: weapon + potions | Q / E / R abilities, with health and stamina
--   top-center   dungeon status, toasts and the boss health bar

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CardUI = require(ReplicatedStorage.Shared.CardUI)
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Util = require(script.Parent.Util)

local ABILITY_KEYS = { "Q", "E" }
local T = Util.Theme
local SLOT = 50
local ABILITY_SLOT = 60
local BAR_WIDTH = 620

local Hud = {}

export type Actions = {
	UseAbility: (abilityId: string) -> (),
	UseWeaponSkill: () -> (),
	UsePotion: (potionId: string) -> (),
	ToggleWeapon: () -> (),
	ToggleInventory: () -> (),
	OpenClassPicker: () -> (),
	OpenAdmin: () -> (),
	ToggleStats: () -> (),
	ToggleQuests: () -> (),
	ToggleSkills: () -> (),
	ToggleCard: () -> (),
	ToggleParty: () -> (),
	ToggleEvent: () -> (),
	ToggleMusic: () -> boolean, -- returns whether music is now on
	SetSprint: (on: boolean) -> (),
	Dodge: () -> (),
}

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Small key hint in the corner of a slot ("Q", "1", ...)
local function keycap(parent: Instance, key: string)
	local cap = Util.make("Frame", parent, {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 4,
	})
	Util.corner(cap, 5)
	Util.text(cap, { Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 12, Text = key, ZIndex = 5 })
end

function Hud.new(gui: ScreenGui, actions: Actions)
	local self = {}
	local player = Players.LocalPlayer

	-- Player plate (top-left) ---------------------------------------------------------
	local plate = Util.panel(gui, { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(300, 100) })
	local levelBadge = Util.make("Frame", plate, {
		Position = UDim2.fromOffset(12, 18),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = T.PanelLight,
		BorderSizePixel = 0,
	})
	Util.corner(levelBadge, 32)
	local levelStroke = Util.stroke(levelBadge, T.Gold, 0.1, 3)
	Util.text(levelBadge, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 14), TextScaled = false, TextSize = 12, TextColor3 = T.Muted, Text = "LEVEL" })
	local levelNumber = Util.text(levelBadge, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 32), Font = Util.TitleFont, TextColor3 = T.Gold, MaxText = 30, Text = "1" })
	local emblemHolder = Util.make("Frame", plate, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
	})
	local shownPrestige = -1
	local classLabel = Util.text(plate, {
		Position = UDim2.fromOffset(88, 10),
		Size = UDim2.new(1, -130, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Util.TitleFont,
		MaxText = 24,
		Text = "Adventurer",
	})
	local xpBack, xpFill = Util.bar(plate, { Position = UDim2.fromOffset(88, 42), Size = UDim2.new(1, -100, 0, 10) }, Color3.fromRGB(110, 150, 255))
	local _ = xpBack
	local xpLabel = Util.text(plate, {
		Position = UDim2.fromOffset(88, 54),
		Size = UDim2.new(1, -100, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 12,
		TextColor3 = T.Muted,
		Text = "",
	})
	local goldLabel = Util.text(plate, {
		Position = UDim2.fromOffset(88, 72),
		Size = UDim2.fromOffset(110, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 16,
		TextColor3 = T.Gold,
		Text = "",
	})
	local candyLabel = Util.text(plate, {
		Position = UDim2.fromOffset(200, 72),
		Size = UDim2.fromOffset(90, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 150, 60),
		Text = "",
		Visible = false,
	})
	local statsLine = Util.text(plate, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, 18),
		Size = UDim2.new(1, -24, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 12,
		TextColor3 = T.Muted,
		Text = "",
	})

	-- Active buffs: little pills to the right of the plate
	local buffList = Util.make("Frame", gui, {
		Position = UDim2.fromOffset(326, 16),
		Size = UDim2.fromOffset(500, 28),
		BackgroundTransparency = 1,
	})
	Util.make("UIListLayout", buffList, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	-- Menu sidebar (left) ------------------------------------------------------------------
	local sidebar = Util.make("Frame", gui, {
		Position = UDim2.fromOffset(14, 142),
		Size = UDim2.fromOffset(56, 560),
		BackgroundTransparency = 1,
	})
	Util.make("UIListLayout", sidebar, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local tooltip = Util.panel(gui, { Size = UDim2.fromOffset(120, 30), Visible = false, ZIndex = 20, BackgroundTransparency = 0.05 })
	local tooltipText = Util.text(tooltip, { Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 15, ZIndex = 21, Text = "" })

	local function menuButton(order: number, glyph: string, name: string, key: string, color: Color3, onClick: () -> ()): TextButton
		local button = Util.button(sidebar, {
			LayoutOrder = order,
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = color,
			Text = "",
		})
		Util.text(button, { Size = UDim2.new(1, 0, 1, -8), TextScaled = false, TextSize = 24, Text = glyph, ZIndex = 3 })
		if key ~= "" then
			local cap = Util.make("Frame", button, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -3, 1, -3),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ZIndex = 4,
			})
			Util.corner(cap, 4)
			Util.text(cap, { Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 11, Text = key, ZIndex = 5 })
		end
		button.MouseEnter:Connect(function()
			tooltipText.Text = if key ~= "" then `{name}  [{key}]` else name
			tooltip.Size = UDim2.fromOffset(tooltipText.TextBounds.X + 24, 30)
			tooltip.Position = UDim2.fromOffset(button.AbsolutePosition.X + 62, button.AbsolutePosition.Y + 11)
			tooltip.Visible = true
		end)
		button.MouseLeave:Connect(function()
			tooltip.Visible = false
		end)
		button.Activated:Connect(onClick)
		return button
	end
	local menuColor = Color3.fromRGB(46, 42, 62)
	menuButton(1, "🎒", "Gear", "G", menuColor, actions.ToggleInventory)
	menuButton(2, "🎲", "Class", "", menuColor, actions.OpenClassPicker)
	menuButton(3, "📜", "Quests", "J", menuColor, actions.ToggleQuests)
	menuButton(4, "✨", "Skills", "", menuColor, actions.ToggleSkills)
	menuButton(5, "📊", "Stats & Leaderboards", "T", menuColor, actions.ToggleStats)
	menuButton(6, "🏅", "Player Card", "H", menuColor, actions.ToggleCard)
	menuButton(7, "👥", "Party", "O", menuColor, actions.ToggleParty)
	local eventButton = menuButton(8, "🎃", "Halloween Event", "K", Color3.fromRGB(200, 95, 20), actions.ToggleEvent)
	eventButton.Visible = false
	local eventIcon = Config.Events.Halloween.Icon
	if eventIcon ~= "" then
		Util.make("ImageLabel", eventButton, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = eventIcon,
			ZIndex = 3,
		})
	end
	function self.SetEventButton(visible: boolean, _text: string?)
		eventButton.Visible = visible
	end
	local adminButton = menuButton(9, "🛠", "Admin Menu", "P", Color3.fromRGB(150, 40, 45), actions.OpenAdmin)
	adminButton.Visible = player:GetAttribute("IsAdmin") == true
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		adminButton.Visible = player:GetAttribute("IsAdmin") == true
	end)

	-- Music toggle (top-right)
	local musicButton = Util.button(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(42, 42),
		Text = "🎵",
		MaxText = 20,
	})
	Util.corner(musicButton, 21)
	musicButton.Activated:Connect(function()
		musicButton.Text = if actions.ToggleMusic() then "🎵" else "🔇"
	end)

	-- Bottom: stamina, health and the hotbar ------------------------------------------------
	local bottom = Util.make("Frame", gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(BAR_WIDTH, 120),
		BackgroundTransparency = 1,
	})
	local _, staminaFill = Util.bar(bottom, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 7) }, Color3.fromRGB(245, 205, 70))
	local _, healthFill = Util.bar(bottom, { Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 22) }, Color3.fromRGB(220, 60, 70))
	local healthLabel = Util.text(bottom, {
		Position = UDim2.fromOffset(0, 13),
		Size = UDim2.new(1, 0, 0, 22),
		TextScaled = false,
		TextSize = 15,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
		Text = "",
	})

	local function updateStamina()
		local maxStamina = player:GetAttribute("MaxStamina") or Config.Movement.MaxStamina
		local stamina = player:GetAttribute("Stamina") or maxStamina
		TweenService:Create(staminaFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.clamp(stamina / maxStamina, 0, 1), 1) }):Play()
		staminaFill.BackgroundColor3 = if stamina < Config.Movement.DodgeCost then Color3.fromRGB(220, 110, 50) else Color3.fromRGB(245, 205, 70)
	end
	player:GetAttributeChangedSignal("Stamina"):Connect(updateStamina)
	updateStamina()

	-- Hotbar: weapon + potions on the left, abilities on the right
	local hotbar = Util.panel(bottom, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 76),
	})
	local slots = Util.make("Frame", hotbar, {
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromOffset((#Config.PotionOrder + 1) * (SLOT + 6), SLOT),
		BackgroundTransparency = 1,
	})
	Util.make("UIListLayout", slots, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	local weaponButton = Util.button(slots, {
		LayoutOrder = 0,
		Size = UDim2.fromOffset(SLOT, SLOT),
		BackgroundColor3 = Color3.fromRGB(56, 50, 72),
		Text = "",
	})
	keycap(weaponButton, "1")
	Util.text(weaponButton, { Size = UDim2.new(1, 0, 1, -12), TextScaled = false, TextSize = 22, Text = "⚔", ZIndex = 3 })
	local weaponLabel = Util.text(weaponButton, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, -2),
		Size = UDim2.new(1, -4, 0, 12),
		TextScaled = false,
		TextSize = 10,
		TextColor3 = T.Muted,
		ZIndex = 3,
		Text = "",
	})
	weaponButton.Activated:Connect(actions.ToggleWeapon)
	local weaponStroke = Util.stroke(weaponButton, T.Gold, 0, 2.5)
	weaponStroke.Enabled = false

	local potionButtons: { [string]: { Button: TextButton, Count: TextLabel } } = {}
	for i, potionId in Config.PotionOrder do
		local potion = Config.Potions[potionId]
		local button = Util.button(slots, {
			LayoutOrder = i,
			Size = UDim2.fromOffset(SLOT, SLOT),
			BackgroundColor3 = Color3.fromRGB(40, 36, 52),
			Text = "",
		})
		keycap(button, tostring(i + 1))
		-- Potion flask: a coloured bulb with a neck
		local bulb = Util.make("Frame", button, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.58),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = potion.Color,
			BorderSizePixel = 0,
			ZIndex = 3,
		})
		Util.corner(bulb, 12)
		Util.stroke(bulb, Color3.new(0, 0, 0), 0.3, 1.5)
		Util.make("Frame", button, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.58, -10),
			Size = UDim2.fromOffset(8, 9),
			BackgroundColor3 = Color3.fromRGB(220, 220, 230),
			BorderSizePixel = 0,
			ZIndex = 3,
		})
		local count = Util.text(button, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -2),
			Size = UDim2.fromOffset(28, 14),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = false,
			TextSize = 13,
			TextStrokeTransparency = 0.4,
			ZIndex = 5,
			Text = "",
		})
		button.Activated:Connect(function()
			actions.UsePotion(potionId)
		end)
		potionButtons[potionId] = { Button = button, Count = count }
	end

	local abilityFrame = Util.make("Frame", hotbar, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 7),
		Size = UDim2.fromOffset(3 * (ABILITY_SLOT + 6), ABILITY_SLOT),
		BackgroundTransparency = 1,
	})
	Util.make("UIListLayout", abilityFrame, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local abilityButtons: { [string]: { Button: TextButton, Cover: Frame, Timer: TextLabel } } = {}
	local shownClass: string? = nil
	local shownWeapon: string? = nil

	-- Q / E class abilities, then R for the equipped weapon's own ability
	-- (cooldown id "WeaponSkill").
	local function buildAbilities(classId: string?, weaponId: string?)
		Util.clear(abilityFrame)
		table.clear(abilityButtons)
		local class = classId and Config.Classes[classId]
		local entries = {}
		if class then
			for i, abilityId in class.Abilities do
				local ability = Config.Abilities[abilityId]
				table.insert(entries, { Id = abilityId, Color = ability.Color, Name = ability.DisplayName, Key = ABILITY_KEYS[i] })
			end
		end
		local weapon = weaponId and Items.Weapons[weaponId]
		if weapon then
			table.insert(entries, { Id = "WeaponSkill", Color = weapon.Skill.Color, Name = weapon.Skill.Name, Key = "R" })
		end
		for i, entry in entries do
			local abilityId = entry.Id
			local button = Util.button(abilityFrame, {
				LayoutOrder = i,
				Size = UDim2.fromOffset(ABILITY_SLOT, ABILITY_SLOT),
				BackgroundColor3 = entry.Color:Lerp(Color3.new(0, 0, 0), 0.35),
				Text = "",
			})
			Util.stroke(button, entry.Color, 0.2, 2)
			keycap(button, entry.Key)
			Util.text(button, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 3, 1, -3),
				Size = UDim2.new(1, -6, 0, 30),
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				TextStrokeTransparency = 0.5,
				MaxText = 13,
				ZIndex = 3,
				Text = entry.Name,
			})
			-- Cooldown: a dark sheet that drains downward, with the seconds left
			local cover = Util.make("Frame", button, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 6,
			})
			Util.corner(cover, 10)
			local timer = Util.text(button, {
				Size = UDim2.fromScale(1, 1),
				Font = Util.TitleFont,
				TextScaled = false,
				TextSize = 24,
				TextStrokeTransparency = 0.3,
				ZIndex = 7,
				Visible = false,
				Text = "",
			})
			button.Activated:Connect(function()
				if abilityId == "WeaponSkill" then
					actions.UseWeaponSkill()
				else
					actions.UseAbility(abilityId)
				end
			end)
			abilityButtons[abilityId] = { Button = button, Cover = cover, Timer = timer }
		end
	end

	-- Top-center: dungeon status, toasts and the boss bar ------------------------------------
	local function pill(y: number, textColor: Color3): (Frame, TextLabel)
		local frame = Util.panel(gui, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = false,
		})
		Util.corner(frame, 18)
		Util.make("UIPadding", frame, { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) })
		local label = Util.text(frame, {
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			TextScaled = false,
			TextSize = 18,
			TextColor3 = textColor,
			Text = "",
		})
		return frame, label
	end
	local statusFrame, statusLabel = pill(12, Color3.fromRGB(255, 220, 150))
	local toastFrame, toast = pill(56, T.Text)
	toastFrame.ZIndex = 10
	local toastStroke = toastFrame:FindFirstChildOfClass("UIStroke") :: UIStroke

	local bossFrame = Util.make("Frame", gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(520, 50),
		BackgroundTransparency = 1,
		Visible = false,
	})
	local bossName = Util.text(bossFrame, {
		Size = UDim2.new(1, 0, 0, 22),
		Font = Util.TitleFont,
		TextScaled = false,
		TextSize = 20,
		TextStrokeTransparency = 0.4,
		TextColor3 = Color3.fromRGB(255, 120, 120),
	})
	local _, bossFill = Util.bar(bossFrame, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18) }, Color3.fromRGB(210, 40, 50))
	local bossHp = Util.text(bossFrame, {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 18),
		TextScaled = false,
		TextSize = 13,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
	})

	-- Public -------------------------------------------------------------------------------

	function self.SetBossBar(info)
		bossFrame.Visible = info ~= nil
		if not info then
			return
		end
		local ratio = math.clamp(info.Health / math.max(info.MaxHealth, 1), 0, 1)
		bossName.Text = `{if info.Mini then "Mini-boss: " else ""}{info.Name}{if info.Enraged then "  •  ENRAGED" else ""}{if info.Shielded then "  •  SHIELDED" else ""}`
		bossName.TextColor3 = if info.Shielded then Color3.fromRGB(130, 210, 255) elseif info.Enraged then Color3.fromRGB(255, 90, 60) else Color3.fromRGB(255, 130, 130)
		TweenService:Create(bossFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(ratio, 1) }):Play()
		bossFill.BackgroundColor3 = if info.Shielded then Color3.fromRGB(90, 170, 255) elseif info.Enraged then Color3.fromRGB(255, 80, 30) else Color3.fromRGB(210, 40, 50)
		bossHp.Text = `{commas(math.ceil(info.Health))} / {commas(info.MaxHealth)}`
	end

	local toastToken = 0
	function self.Toast(message: string, color: Color3?)
		toastToken += 1
		local myToken = toastToken
		toast.Text = message
		toast.TextColor3 = color or T.Text
		toast.TextTransparency = 0
		toastFrame.BackgroundTransparency = 0.12
		toastStroke.Transparency = 0.86
		toastFrame.Visible = true
		task.delay(2.5, function()
			if toastToken == myToken then
				local fade = TweenInfo.new(0.4)
				TweenService:Create(toast, fade, { TextTransparency = 1 }):Play()
				TweenService:Create(toastFrame, fade, { BackgroundTransparency = 1 }):Play()
				TweenService:Create(toastStroke, fade, { Transparency = 1 }):Play()
				task.delay(0.45, function()
					if toastToken == myToken then
						toastFrame.Visible = false
					end
				end)
			end
		end)
	end

	function self.SetStatus(status: string?)
		statusFrame.Visible = status ~= nil
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
		entry.Timer.Visible = true
		entry.Cover.Size = UDim2.fromScale(1, 1)
		TweenService:Create(entry.Cover, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) }):Play()
		task.spawn(function()
			while os.clock() < endsAt and entry.Cover.Parent do
				local left = endsAt - os.clock()
				entry.Timer.Text = if left < 1 then string.format("%.1f", left) else tostring(math.ceil(left))
				task.wait(0.1)
			end
			entry.Cover.Visible = false
			entry.Timer.Visible = false
		end)
	end

	function self.Render(state)
		local class = state.Class and Config.Classes[state.Class]
		levelNumber.Text = tostring(state.Level)
		classLabel.Text = if class then class.DisplayName else "Roll a class!"
		classLabel.TextColor3 = if class then class.Color else T.Text
		levelStroke.Color = if class then class.Color else T.Gold
		goldLabel.Text = `● {commas(state.Gold)}`
		local showCandy = (state.Candies or 0) > 0 or workspace:GetAttribute("HalloweenActive") == true
		candyLabel.Visible = showCandy
		candyLabel.Text = `🍬 {commas(state.Candies or 0)}`
		statsLine.Text = `DEF {math.floor(state.Stats.Defense * 100)}%   •   DMG x{string.format("%.2f", state.Stats.Damage)}`
		TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(state.XP / state.XPNeeded, 0, 1), 1) }):Play()
		xpLabel.Text = if state.Level >= Config.MaxLevel
			then "MAX LEVEL - Prestige in your Card [H]"
			else `{commas(state.XP)} / {commas(state.XPNeeded)} XP`
		if state.Prestige ~= shownPrestige then
			shownPrestige = state.Prestige
			Util.clear(emblemHolder)
			CardUI.Emblem(emblemHolder, state.Prestige, 40)
		end

		weaponLabel.Text = if class then class.WeaponType else ""

		if state.Class ~= shownClass or state.Equipped.Weapon ~= shownWeapon then
			shownClass = state.Class
			shownWeapon = state.Equipped.Weapon
			buildAbilities(state.Class, state.Equipped.Weapon)
		end

		for potionId, slot in potionButtons do
			local count = state.Potions[potionId] or 0
			slot.Count.Text = if count > 0 then `x{count}` else ""
			slot.Button.BackgroundTransparency = if count > 0 then 0 else 0.55
		end

		Util.clear(buffList)
		for buffId, remaining in state.Buffs do
			local buff = Config.Buffs[buffId]
			local pillFrame = Util.panel(buffList, {
				Size = UDim2.fromOffset(0, 26),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(30, 60, 40),
			})
			Util.corner(pillFrame, 13)
			Util.make("UIPadding", pillFrame, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
			local label = Util.text(pillFrame, {
				Size = UDim2.fromOffset(0, 26),
				AutomaticSize = Enum.AutomaticSize.X,
				TextScaled = false,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(160, 255, 180),
				Text = `{buff.DisplayName} {math.ceil(remaining)}s`,
			})
			-- Count down locally until the next state update replaces it.
			local endsAt = os.clock() + remaining
			task.spawn(function()
				while label.Parent and os.clock() < endsAt do
					label.Text = `{buff.DisplayName} {math.ceil(endsAt - os.clock())}s`
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
			TweenService:Create(healthFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) }):Play()
			healthFill.BackgroundColor3 = if ratio < 0.3 then Color3.fromRGB(255, 70, 50) else Color3.fromRGB(220, 60, 70)
			healthLabel.Text = `{commas(math.ceil(humanoid.Health))} / {commas(humanoid.MaxHealth)}`
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

	-- Touch screens get round Sprint and Dodge buttons (keyboard uses Shift and C)
	if UserInputService.TouchEnabled then
		local sprinting = false
		local function roundButton(offsetX: number, text: string, color: Color3): TextButton
			local button = Util.button(gui, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, offsetX, 1, -190),
				Size = UDim2.fromOffset(70, 70),
				BackgroundColor3 = color,
				Text = text,
				MaxText = 16,
			})
			Util.corner(button, 35)
			return button
		end
		local sprintButton = roundButton(-104, "Sprint", Color3.fromRGB(190, 150, 40))
		sprintButton.Activated:Connect(function()
			sprinting = not sprinting
			sprintButton.BackgroundColor3 = if sprinting then Color3.fromRGB(240, 205, 80) else Color3.fromRGB(190, 150, 40)
			actions.SetSprint(sprinting)
		end)
		local dodgeButton = roundButton(-20, "Dodge", Color3.fromRGB(70, 150, 200))
		dodgeButton.Activated:Connect(actions.Dodge)
	end

	return self
end

return Hud
