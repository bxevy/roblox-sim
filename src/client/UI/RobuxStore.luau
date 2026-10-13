-- Robux Store (B): 2x Luck and 2x Coins game passes, exclusive armor sets, and class
-- slots, with a turning 3D preview of each armor set. Every purchase is checked and
-- granted on the server (StoreService / ClassService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	window, body = Util.window(gui, "Robux Store", Vector2.new(900, 700), function()
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
	-- Each card shows the set on a slowly turning mannequin (built by the server in
	-- ReplicatedStorage.StorePreviews) next to its stats.
	heading(194, "Exclusive Armor  -  full 4-piece set, equipped right away")
	local armorButtons: { [string]: TextButton } = {}
	type Preview = { Camera: Camera, Center: Vector3, Distance: number }
	local previews: { Preview } = {}

	local function loadPreview(viewport: ViewportFrame, camera: Camera, setId: string)
		local folder = ReplicatedStorage:WaitForChild("StorePreviews", 60)
		local source = folder and folder:WaitForChild(setId, 60)
		if not source then
			return
		end
		local model = (source :: Model):Clone()
		model.Parent = viewport
		local boxCFrame, boxSize = model:GetBoundingBox()
		-- Frame the whole figure (wings included) with a little headroom
		local fit = math.max(boxSize.Y, boxSize.X * 1.1) / 2
		local distance = fit / math.tan(math.rad(camera.FieldOfView / 2)) * 1.12
		table.insert(previews, { Camera = camera, Center = boxCFrame.Position, Distance = distance })
	end

	for i, setId in Store.ArmorOrder do
		local set = Items.ArmorSets[setId]
		local card = Util.panel(body, {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 6, 0, 224),
			Size = UDim2.new(0.5, -6, 0, 290),
			BackgroundColor3 = Util.Theme.PanelLight,
			BackgroundTransparency = 0,
		})
		Util.stroke(card, Config.Rarities.Exclusive, 0.3, 2)

		-- 3D preview
		local viewport = Util.make("ViewportFrame", card, {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(0, 190, 1, -20),
			BackgroundColor3 = set.Style.Primary:Lerp(Color3.fromRGB(10, 10, 16), 0.75),
			BorderSizePixel = 0,
			Ambient = Color3.fromRGB(170, 170, 185),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-0.6, -1, -0.8),
		})
		Util.corner(viewport, 10)
		Util.stroke(viewport, set.Style.Accent, 0.5, 1.5)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		task.spawn(loadPreview, viewport, camera, setId)

		local textX = 214
		Util.text(card, {
			Position = UDim2.fromOffset(textX, 14),
			Size = UDim2.new(1, -textX - 12, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 13,
			TextColor3 = Config.Rarities.Exclusive,
			Text = "EXCLUSIVE ARMOR SET",
		})
		Util.text(card, {
			Position = UDim2.fromOffset(textX, 34),
			Size = UDim2.new(1, -textX - 12, 0, 58),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Font = Util.TitleFont,
			TextScaled = false,
			TextSize = 24,
			TextColor3 = Config.Rarities.Exclusive,
			Text = set.DisplayName,
		})
		Util.text(card, {
			Position = UDim2.fromOffset(textX, 96),
			Size = UDim2.new(1, -textX - 12, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextScaled = false,
			TextSize = 15,
			Text = `+{set.Health} health\n{math.floor(set.Defense * 100 + 0.5)}% defense`,
		})
		Util.text(card, {
			Position = UDim2.fromOffset(textX, 140),
			Size = UDim2.new(1, -textX - 12, 0, 70),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextScaled = false,
			TextSize = 14,
			TextColor3 = Util.Theme.Muted,
			Text = `Set bonus: {set.SetBonus.Description}`,
		})
		local button = priceButton(card, function()
			actions.BuyArmor(setId)
		end)
		button.Size = UDim2.new(1, -textX - 12, 0, 42)
		armorButtons[setId] = button
	end

	-- Turn the mannequins while the store is open
	local angle = 0
	RunService.RenderStepped:Connect(function(dt)
		if not window.Visible then
			return
		end
		angle += dt * 0.7
		for _, preview in previews do
			local offset = CFrame.Angles(0, angle, 0):VectorToWorldSpace(Vector3.new(0, 0.12, -1)) * preview.Distance
			preview.Camera.CFrame = CFrame.lookAt(preview.Center + offset, preview.Center)
		end
	end)

	-- Class slots ------------------------------------------------------------------------
	local slotCard = Util.panel(body, {
		Position = UDim2.fromOffset(0, 526),
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
