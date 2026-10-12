-- Player card window (H): preview and customize your card, prestige, and look at other
-- players' cards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardUI = require(ReplicatedStorage.Shared.CardUI)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Util = require(script.Parent.Util)

local CardWindow = {}

local TABS = { "Backgrounds", "Titles", "Frames", "Showcase", "Prestige", "Players" }
local LOCKED = Color3.fromRGB(150, 150, 160)

export type Actions = {
	Set: (field: string, value: any) -> (),
	Prestige: () -> (),
	GetCard: (userId: number) -> any,
}

function CardWindow.new(gui: ScreenGui, actions: Actions)
	local self: any = {}
	local state = nil
	local tab = "Backgrounds"
	local viewing: any = nil -- another player's card data, or nil for your own
	local prestigeArmedAt = 0

	local window, body
	window, body = Util.window(gui, "Player Card", Vector2.new(900, 540), function()
		window.Visible = false
	end)

	local preview = Util.make("Frame", body, { Size = UDim2.fromOffset(430, 250), BackgroundTransparency = 1 })
	local backButton = Util.button(body, {
		Position = UDim2.fromOffset(0, 258),
		Size = UDim2.fromOffset(200, 34),
		Text = "Back to my card",
		Visible = false,
	})
	backButton.Activated:Connect(function()
		viewing = nil
		self.Render(nil)
	end)
	local info = Util.text(body, {
		Position = UDim2.fromOffset(0, 300),
		Size = UDim2.fromOffset(430, 200),
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(210, 210, 220),
	})

	local right = Util.make("Frame", body, {
		Position = UDim2.fromOffset(444, 0),
		Size = UDim2.new(1, -444, 1, 0),
		BackgroundTransparency = 1,
	})
	local tabBar = Util.make("Frame", right, { Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1 })
	Util.make("UIGridLayout", tabBar, { CellSize = UDim2.new(1 / 3, -6, 0, 30), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local list = Util.list(right, { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -76) })

	local tabButtons = {}
	for order, name in TABS do
		local button = Util.button(tabBar, { LayoutOrder = order, TextScaled = false, TextSize = 16, Text = name })
		button.Activated:Connect(function()
			tab = name
			self.Render(nil)
		end)
		tabButtons[name] = button
	end

	local function profile(): Cosmetics.Profile
		return { Level = state.Level, Prestige = state.Prestige, Stats = state.Lifetime, Weapons = state.Weapons, Armors = state.Armors }
	end

	local function myCard()
		local labels = {}
		for _, entry in Config.StatNames do
			labels[entry[1]] = entry[2]
		end
		local showcase = {}
		for _, statId in state.Card.Showcase do
			table.insert(showcase, { Label = labels[statId] or statId, Value = state.Lifetime[statId] or 0 })
		end
		return {
			UserId = Players.LocalPlayer.UserId,
			Name = Players.LocalPlayer.DisplayName,
			Level = state.Level,
			Prestige = state.Prestige,
			Class = state.Class,
			Background = state.Card.Background,
			Title = state.Card.Title,
			Frame = state.Card.Frame,
			Showcase = showcase,
		}
	end

	-- A selectable row with an optional swatch on the left.
	local function optionRow(order: number, name: string, color: Color3, unlocked: boolean, selected: boolean, unlockText: string, onPick: () -> (), swatch: ((Frame) -> ())?)
		local row = Util.button(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 50),
			BackgroundColor3 = if selected then Color3.fromRGB(60, 110, 65) else Util.ButtonColor,
			Text = "",
			AutoButtonColor = unlocked,
		})
		local left = 10
		if swatch then
			local box = Util.make("Frame", row, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(64, 38), BorderSizePixel = 0 })
			Util.corner(box, 6)
			swatch(box)
			left = 80
		end
		Util.text(row, {
			Position = UDim2.fromOffset(left, 4),
			Size = UDim2.new(1, -left - 10, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if unlocked then color else LOCKED,
			Text = `{name}{if selected then "  (equipped)" else ""}`,
		})
		Util.text(row, {
			Position = UDim2.fromOffset(left, 28),
			Size = UDim2.new(1, -left - 10, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if unlocked then Color3.fromRGB(150, 220, 150) else LOCKED,
			Text = if unlocked then "Unlocked" else `Locked - {unlockText}`,
		})
		row.Activated:Connect(function()
			if unlocked and not selected then
				onPick()
			end
		end)
	end

	local function renderList()
		Util.clear(list)
		local p = profile()
		if tab == "Backgrounds" then
			for order, def in Cosmetics.Backgrounds do
				optionRow(order, def.Name, Color3.new(1, 1, 1), Cosmetics.IsUnlocked(p, def.Unlock), state.Card.Background == def.Id, Cosmetics.Describe(def.Unlock), function()
					actions.Set("Background", def.Id)
				end, function(box)
					CardUI.Background(box, def.Id)
				end)
			end
		elseif tab == "Titles" then
			for order, def in Cosmetics.Titles do
				optionRow(order, def.Name, def.Color, Cosmetics.IsUnlocked(p, def.Unlock), state.Card.Title == def.Id, Cosmetics.Describe(def.Unlock), function()
					actions.Set("Title", def.Id)
				end)
			end
		elseif tab == "Frames" then
			for order, def in Cosmetics.Frames do
				optionRow(order, def.Name, def.Colors[1], Cosmetics.IsUnlocked(p, def.Unlock), state.Card.Frame == def.Id, Cosmetics.Describe(def.Unlock), function()
					actions.Set("Frame", def.Id)
				end, function(box)
					box.BackgroundColor3 = Color3.new(1, 1, 1)
					local keypoints = {}
					for i, c in def.Colors do
						table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(#def.Colors - 1, 1), c))
					end
					Util.make("UIGradient", box, { Color = ColorSequence.new(keypoints), Rotation = 45 })
				end)
			end
		elseif tab == "Showcase" then
			Util.text(list, { LayoutOrder = 0, Size = UDim2.new(1, -10, 0, 22), TextColor3 = Color3.fromRGB(200, 200, 210), Text = "Pick the 3 stats shown on your card" })
			for slot = 1, 3 do
				local current = state.Card.Showcase[slot]
				local label = current
				for _, entry in Config.StatNames do
					if entry[1] == current then
						label = entry[2]
					end
				end
				local button = Util.button(list, {
					LayoutOrder = slot,
					Size = UDim2.new(1, -10, 0, 44),
					TextScaled = false,
					TextSize = 17,
					Text = `Slot {slot}: {label}   (click to change)`,
				})
				button.Activated:Connect(function()
					-- Cycle to the next stat in the list
					local index = 1
					for i, entry in Config.StatNames do
						if entry[1] == current then
							index = i
						end
					end
					local nextStat = Config.StatNames[index % #Config.StatNames + 1][1]
					actions.Set("Showcase", { slot, nextStat })
				end)
			end
		elseif tab == "Prestige" then
			local maxed = state.Prestige >= Config.Prestige.Max
			local ready = state.Level >= Config.MaxLevel and not maxed
			Util.text(list, {
				LayoutOrder = 0,
				Size = UDim2.new(1, -10, 0, 70),
				TextScaled = false,
				TextSize = 16,
				TextWrapped = true,
				TextColor3 = Color3.fromRGB(220, 220, 230),
				Text = `Reach level {Config.MaxLevel} to prestige: you go back to level 1 but keep your gear, coins and skills, and earn +{Config.Prestige.XPBonus * 100}% XP, +{Config.Prestige.GoldBonus * 100}% coins and {Config.Prestige.SkillPoints} skill points per prestige, plus a new emblem.`,
			})
			local button = Util.button(list, {
				LayoutOrder = 1,
				Size = UDim2.new(1, -10, 0, 50),
				BackgroundColor3 = if ready then Color3.fromRGB(200, 60, 120) else Color3.fromRGB(70, 65, 80),
				AutoButtonColor = ready,
				Text = if maxed then "Max prestige reached!" elseif ready then "PRESTIGE" else `Level {state.Level} / {Config.MaxLevel}`,
			})
			button.Activated:Connect(function()
				if not ready then
					return
				end
				if os.clock() - prestigeArmedAt < 4 then
					prestigeArmedAt = 0
					actions.Prestige()
				else
					prestigeArmedAt = os.clock()
					button.Text = "Click again to confirm"
				end
			end)
			-- Emblem gallery
			local gallery = Util.make("Frame", list, { LayoutOrder = 2, Size = UDim2.new(1, -10, 0, 220), BackgroundTransparency = 1 })
			Util.make("UIGridLayout", gallery, { CellSize = UDim2.fromOffset(76, 100), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
			for i, emblem in Cosmetics.Emblems do
				local cell = Util.make("Frame", gallery, { LayoutOrder = i, BackgroundTransparency = 1 })
				local holder = Util.make("Frame", cell, { Size = UDim2.fromOffset(76, 76), BackgroundTransparency = if i <= state.Prestige then 1 else 0.5, BackgroundColor3 = Color3.new(0, 0, 0) })
				CardUI.Emblem(holder, i, 60, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
				Util.text(cell, {
					Position = UDim2.fromOffset(0, 78),
					Size = UDim2.new(1, 0, 0, 20),
					TextColor3 = if i <= state.Prestige then emblem.Outer else LOCKED,
					Text = emblem.Name,
				})
			end
		elseif tab == "Players" then
			for order, other in Players:GetPlayers() do
				local button = Util.button(list, {
					LayoutOrder = order,
					Size = UDim2.new(1, -10, 0, 40),
					TextScaled = false,
					TextSize = 17,
					Text = if other == Players.LocalPlayer then `{other.DisplayName} (you)` else other.DisplayName,
				})
				button.Activated:Connect(function()
					local data = actions.GetCard(other.UserId)
					if data then
						viewing = if other == Players.LocalPlayer then nil else data
						self.Render(nil)
					end
				end)
			end
		end
	end

	function self.Render(newState)
		state = newState or state
		if not state or not window.Visible then
			return
		end
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == tab then Color3.fromRGB(110, 75, 40) else Util.ButtonColor
		end
		Util.clear(preview)
		CardUI.Card(preview, viewing or myCard())
		backButton.Visible = viewing ~= nil
		if viewing then
			info.Text = `Viewing {viewing.Name}'s card`
		else
			local emblem = Cosmetics.Emblems[state.Prestige]
			info.Text = if emblem
				then `Prestige {Cosmetics.Roman(state.Prestige)} - {emblem.Name}\n+{math.floor(state.Prestige * Config.Prestige.XPBonus * 100)}% XP, +{math.floor(state.Prestige * Config.Prestige.GoldBonus * 100)}% coins`
				else "No prestige yet. Reach max level and prestige to earn your first emblem!"
		end
		renderList()
	end

	function self.Toggle()
		window.Visible = not window.Visible
		self.Render(nil)
	end

	return self
end

return CardWindow
