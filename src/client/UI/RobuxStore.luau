-- Robux Store (B): 2x Luck and 2x Coins game passes, exclusive armor sets, and class
-- slots. Every purchase is checked and granted on the server (StoreService / ClassService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Util = require(script.Parent.Util)

local RobuxStore = {}

local Store = Config.RobuxStore
local ROBUX_GREEN = Color3.fromRGB(40, 160, 90)
local OWNED = Color3.fromRGB(55, 60, 70)

export type Actions = {
	BuyPerk: (perkId: string) -> (),
	BuyArmor: (setId: string) -> (),
	BuySlot: () -> (),
}

function RobuxStore.new(gui: ScreenGui, actions: Actions)
	local self: any = {}

	local window, body
	window, body = Util.window(gui, "Robux Store", Vector2.new(800, 640), function()
		window.Visible = false
	end)

	local function heading(y: number, text: string)
		Util.text(body, {
			Position = UDim2.fromOffset(2, y),
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Util.TitleFont,
			TextScaled = false,
			TextSize = 20,
			TextColor3 = Util.Theme.Gold,
			Text = text,
		})
	end

	-- A price button that turns into an inert "Owned" tag once bought.
	local function priceButton(parent: Instance, onClick: () -> ()): TextButton
		local button = Util.button(parent, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(130, 40),
			BackgroundColor3 = ROBUX_GREEN,
			TextScaled = false,
			TextSize = 18,
			ZIndex = 3,
			Text = "",
		})
		button.Activated:Connect(function()
			if button:GetAttribute("Owned") ~= true then
				onClick()
			end
		end)
		return button
	end

	local function setOwned(button: TextButton, owned: boolean, price: string)
		button:SetAttribute("Owned", owned)
		button.Text = if owned then "Owned ✓" else price
		button.BackgroundColor3 = if owned then OWNED else ROBUX_GREEN
	end

	-- Perks --------------------------------------------------------------------------
	heading(0, "Perks  -  yours forever")
	local perkButtons: { [string]: TextButton } = {}
	for i, perkId in Store.PerkOrder do
		local perk = Store.Perks[perkId]
		local card = Util.panel(body, {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 6, 0, 30),
			Size = UDim2.new(0.5, -6, 0, 150),
			BackgroundColor3 = Util.Theme.PanelLight,
			BackgroundTransparency = 0,
		})
		Util.stroke(card, perk.Color, 0.3, 2)
		local badge = Util.make("Frame", card, {
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = perk.Color:Lerp(Color3.new(0, 0, 0), 0.55),
			BorderSizePixel = 0,
		})
		Util.corner(badge, 32)
		Util.stroke(badge, perk.Color, 0, 2)
		Util.text(badge, { Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 32, Text = perk.Glyph })
		Util.text(card, {
			Position = UDim2.fromOffset(90, 14),
			Size = UDim2.new(1, -104, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Util.TitleFont,
			TextScaled = false,
			TextSize = 26,
			TextColor3 = perk.Color,
			Text = perk.DisplayName,
		})
		Util.text(card, {
			Position = UDim2.fromOffset(90, 46),
			Size = UDim2.new(1, -104, 0, 50),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextScaled = false,
			TextSize = 14,
			TextColor3 = Util.Theme.Muted,
			Text = perk.Description,
		})
		perkButtons[perkId] = priceButton(card, function()
			actions.BuyPerk(perkId)
		end)
	end

	-- Exclusive armor -------------------------------------------------------------------
	heading(194, "Exclusive Armor  -  full 4-piece set, equipped right away")
	local armorButtons: { [string]: TextButton } = {}
	for i, setId in Store.ArmorOrder do
		local set = Items.ArmorSets[setId]
		local card = Util.panel(body, {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 6, 0, 224),
			Size = UDim2.new(0.5, -6, 0, 200),
			BackgroundColor3 = Util.Theme.PanelLight,
			BackgroundTransparency = 0,
		})
		Util.stroke(card, Config.Rarities.Exclusive, 0.3, 2)
		Util.make("UIGradient", card, {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)),
		})
		-- Colour swatches standing in for a preview of the set
		for k, key in { "Primary", "Secondary", "Accent" } do
			local swatch = Util.make("Frame", card, {
				Position = UDim2.fromOffset(14 + (k - 1) * 26, 16),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = set.Style[key],
				BorderSizePixel = 0,
			})
			Util.corner(swatch, 11)
			Util.stroke(swatch, Color3.new(0, 0, 0), 0.3, 1.5)
		end
		Util.text(card, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 16),
			Size = UDim2.fromOffset(110, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = false,
			TextSize = 14,
			TextColor3 = Config.Rarities.Exclusive,
			Text = "EXCLUSIVE",
		})
		Util.text(card, {
			Position = UDim2.fromOffset(14, 46),
			Size = UDim2.new(1, -28, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Util.TitleFont,
			TextScaled = false,
			TextSize = 24,
			TextColor3 = Config.Rarities.Exclusive,
			Text = set.DisplayName,
		})
		Util.text(card, {
			Position = UDim2.fromOffset(14, 80),
			Size = UDim2.new(1, -28, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 15,
			Text = `+{set.Health} health  |  {math.floor(set.Defense * 100 + 0.5)}% defense`,
		})
		Util.text(card, {
			Position = UDim2.fromOffset(14, 102),
			Size = UDim2.new(1, -28, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextScaled = false,
			TextSize = 14,
			TextColor3 = Util.Theme.Muted,
			Text = `Set bonus: {set.SetBonus.Description}`,
		})
		armorButtons[setId] = priceButton(card, function()
			actions.BuyArmor(setId)
		end)
	end

	-- Class slots ------------------------------------------------------------------------
	local slotCard = Util.panel(body, {
		Position = UDim2.fromOffset(0, 436),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Util.Theme.PanelLight,
		BackgroundTransparency = 0,
	})
	Util.text(slotCard, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -170, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Util.TitleFont,
		TextScaled = false,
		TextSize = 20,
		Text = "Class Slots",
	})
	local slotInfo = Util.text(slotCard, {
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -170, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 14,
		TextColor3 = Util.Theme.Muted,
		Text = "",
	})
	local slotButton = priceButton(slotCard, actions.BuySlot)
	slotButton.Size = UDim2.fromOffset(140, 40)

	Util.text(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		TextScaled = false,
		TextSize = 13,
		TextColor3 = Util.Theme.Muted,
		Text = "Purchases are tied to your account. Thank you for supporting the game!",
	})

	function self.Render(state)
		local perks = state.Perks or {}
		for perkId, button in perkButtons do
			setOwned(button, perks[perkId] == true, Store.Perks[perkId].PriceLabel)
		end
		for setId, button in armorButtons do
			local owned = true
			for _, pieceId in Items.ArmorSets[setId].Pieces do
				if not state.Armors[pieceId] then
					owned = false
				end
			end
			setOwned(button, owned, Store.Armor[setId].PriceLabel)
		end
		local unlocked = state.SlotsUnlocked or 1
		local max = Config.ClassSlots.Max
		slotInfo.Text = `{unlocked} of {max} unlocked  -  keep more classes, swap in town, free roll in each new slot`
		setOwned(slotButton, unlocked >= max, `+1 Slot  {Config.ClassSlots.RobuxPriceLabel}`)
		if unlocked >= max then
			slotButton.Text = "All unlocked ✓"
		end
	end

	function self.Toggle()
		window.Visible = not window.Visible
	end

	function self.Open()
		window.Visible = true
	end

	return self
end

return RobuxStore
