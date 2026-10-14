--!strict
-- First-time choice of a starter creature. Modal: it stays until a choice is made.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local JobConfig = require(Shared.Config.JobConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local UiKit = require(Shared.Config.UiKit)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)

local StarterSelect = {}

-- Card colours and button style per family (the mockup: green, orange, crystal blue).
type Look = { Card: Color3, Button: string, ButtonColor: Color3? }
local FAMILY_LOOK: { [string]: Look } = {
	Verdant = { Card = Color3.fromRGB(38, 92, 40), Button = "Primary" },
	-- The kit's orange button is a dull brown-orange; the mockup's is bright, so these two
	-- are drawn (glossy, with a light rim) in the family colour.
	Emberkin = { Card = Color3.fromRGB(110, 46, 20), Button = "Danger", ButtonColor = Color3.fromRGB(245, 130, 25) },
	Crystalkin = {
		Card = Color3.fromRGB(24, 58, 104),
		Button = "Danger",
		ButtonColor = Color3.fromRGB(35, 185, 235),
	},
}

-- Fallback: drawn from the small kit pieces (if the starter sheet pictures can't load).
local function buildDrawn(ctx: any)
	local root = Theme.Panel(ctx.Gui, {
		Name = "StarterSelect",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.94, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 10,
	})
	Theme.Skin(root, "LargeFrame")
	Theme.Make("UISizeConstraint", { MaxSize = Vector2.new(880, 640) }, root)
	-- Inside the frame's vines (drawn near full size, like the mockup).
	local rootPad = Theme.Padding(root, 44, 40)
	rootPad.PaddingBottom = UDim.new(0, 40)
	local list = Theme.List(root, 6, nil, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Top

	-- Title on the banner
	local banner = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
	}, root)
	-- No banner picture: like the mockup, the title sits under the frame's top ornament.
	local heading = Theme.Text(banner, "Welcome to your empire!", 32, {
		FontFace = Theme.Title,
		TextColor3 = Color3.fromRGB(255, 234, 176), -- warm cream, as in the mockup
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	Theme.Make("UIStroke", { Color = Color3.fromRGB(46, 24, 8), Thickness = 2.5 }, heading)
	Theme.Text(root, "Choose a partner creature. You'll meet the other two soon.", 15, {
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	})

	local cards = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, root)
	Theme.List(cards, 12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)

	local busy = false
	for index, speciesId in CreatureConfig.Starters do
		local species = CreatureConfig.Species[speciesId]
		local family = CreatureConfig.Families[species.Family]
		local rarity = RarityConfig.Get(species.Rarity)
		local look: Look = FAMILY_LOOK[species.Family] or { Card = Theme.Colors.PanelRaised, Button = "Primary" }
		-- The kit's wooden vine card frame (as in the mockup) with the family's colour glowing
		-- inside it. The shell holds the frame and the tint; the content stacks in its own
		-- frame, so the list layout never moves them.
		local shell = Theme.Make("ImageLabel", {
			Image = "",
			BackgroundColor3 = look.Card,
			Size = UDim2.fromOffset(252, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
		}, cards)
		Theme.Corner(shell, 12)
		Theme.Stroke(shell, family.Color, 0, 3)
		Theme.Gradient(shell, 1, 0.45)
		local framed = Theme.Skin(shell, "CardFrame", 0.6) ~= nil
		if framed then
			local tint = Theme.Make("Frame", {
				Name = "Tint",
				BackgroundColor3 = look.Card,
				BackgroundTransparency = 0.15,
				Position = UDim2.fromOffset(22, 22),
				Size = UDim2.new(1, -44, 1, -44),
				ZIndex = 0,
			}, shell)
			Theme.Corner(tint, 8)
			Theme.Gradient(tint, 1, 0.35)
		end
		local card = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, shell)
		Theme.Padding(card, if framed then 28 else 10, if framed then 28 else 10)
		Theme.List(card, 5, nil, Enum.HorizontalAlignment.Center)
		-- A glow in the family colour behind the creature.
		local art = Theme.Make("Frame", {
			BackgroundColor3 = family.Color,
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 0, 124),
		}, card)
		Theme.Gradient(art, 1, 0.35)
		Theme.Corner(art, 10)
		Viewport.Creature(art, speciesId, nil, { Spin = true })
		local nameLabel = Theme.Text(card, species.Name, 25, {
			FontFace = Theme.Heavy,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Theme.Make("UIStroke", { Color = Color3.fromRGB(30, 16, 6), Thickness = 2 }, nameLabel)
		local chips = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22) }, card)
		Theme.List(chips, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		Theme.Chip(chips, family.Glyph .. " " .. family.Name, family.Color, { TextSize = 12 })
		Theme.Chip(chips, RarityConfig.Label(species.Rarity), rarity.Color, { TextSize = 12 })
		Theme.Text(card, species.Description, 12, { TextXAlignment = Enum.TextXAlignment.Center })
		local best, bestValue = nil, 0
		for jobId, value in species.JobAffinity do
			if value > bestValue then
				best, bestValue = jobId, value
			end
		end
		Theme.Text(
			card,
			`<b>Best at:</b> {best and JobConfig[best].Name or "?"} · Farming {Format.Percent(
				species.JobAffinity.Farmer or 0
			)}`,
			12
		)
		Theme.Text(card, `<b>{species.Active.Name}:</b> {species.Active.Description}`, 11, {
			TextColor3 = Theme.Colors.Muted,
		})
		local choose = Theme.Button(card, "Choose " .. species.Name, look.Button :: any, {
			Size = UDim2.new(1, 0, 0, 44),
			TextSize = 17,
			FontFace = Theme.Heavy,
		})
		if look.ButtonColor then
			-- Glossy pill: bright colour, lighter top, a pale glowing rim.
			choose:SetAttribute("BaseColor", look.ButtonColor)
			choose.BackgroundColor3 = look.ButtonColor
			local corner = choose:FindFirstChildOfClass("UICorner")
			if corner then
				corner.CornerRadius = UDim.new(0.5, 0)
			end
			local rim = choose:FindFirstChildOfClass("UIStroke")
			if rim then
				rim.Color = look.ButtonColor:Lerp(Color3.new(1, 1, 0.85), 0.6)
				rim.Transparency = 0
				rim.Thickness = 2.5
			end
			local shine = choose:FindFirstChildOfClass("UIGradient")
			if shine then
				shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.72))
			end
			choose.TextStrokeTransparency = 0.2
		end
		choose.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, result = ctx.Request("ChooseStarter", speciesId)
			busy = false
			if not ok then
				ctx.Notify(result, "Error")
			end
		end)
	end

	return {
		Root = root,
		Modal = true,
		Open = function() end,
	}
end

-- The creator's starter sheet (art/ui-starter): every piece is shown at its real shape and
-- the text is laid on top at fixed spots, measured against the mockup. Sizes are in design
-- pixels; the whole stage is scaled to fit the screen.
local STAGE = Vector2.new(1100, 749) -- the window frame picture (662x451) at this size
local K = STAGE.X / 662
-- The frame's open middle, in the picture's pixels: x 75..586, y 78..377.
local INNER_X, INNER_Y = 75 * K, 78 * K
local INNER_W, INNER_H = (586 - 75) * K, (377 - 78) * K
local CARD = Vector2.new(270, 416)
local CARD_GAP = 14

type Art = { Frame: string, Button: string, Badge: string, Portrait: string, Tint: Color3 }
local ART: { [string]: Art } = {
	Sproutling = {
		Frame = "CardFrameGreen",
		Button = "ButtonSproutling",
		Badge = "BadgeVerdants",
		Portrait = "PortraitSproutling",
		Tint = Color3.fromRGB(30, 80, 32),
	},
	Cindercub = {
		Frame = "CardFrameOrange",
		Button = "ButtonCindercub",
		Badge = "BadgeEmberkin",
		Portrait = "PortraitCindercub",
		Tint = Color3.fromRGB(100, 40, 16),
	},
	Pebblit = {
		Frame = "CardFrameBlue",
		Button = "ButtonPebblit",
		Badge = "BadgeCrystalkin",
		Portrait = "PortraitPebblit",
		Tint = Color3.fromRGB(20, 48, 92),
	},
}

local CREAM = Color3.fromRGB(255, 236, 180)
local OUTLINE = Color3.fromRGB(40, 20, 8)

local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local l = Theme.Make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = Theme.Bold,
		TextColor3 = Color3.fromRGB(245, 235, 220),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		RichText = true,
		ZIndex = 14,
	}, parent)
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function outline(l: TextLabel, thickness: number)
	Theme.Make("UIStroke", { Color = OUTLINE, Thickness = thickness }, l)
end

-- Text that shrinks to fit its box (descriptions differ in length).
local function fitText(l: TextLabel, maxSize: number)
	l.TextScaled = true
	Theme.Make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 7 }, l)
end

local function kitImage(parent: Instance, name: string, props: { [string]: any }): ImageLabel
	local image = Theme.Make("ImageLabel", { BackgroundTransparency = 1, ZIndex = 13 }, parent)
	for key, value in props do
		(image :: any)[key] = value
	end
	local f = Theme.KitApply(image, name)
	if f and image.ScaleType == Enum.ScaleType.Slice then
		image.SliceScale = 1 / f -- the frame's vines at their drawn size
	end
	return image
end

local function canUseArt(): boolean
	if not Theme.KitImage("WindowFrame") then
		return false
	end
	for _, speciesId in CreatureConfig.Starters do
		local art = ART[speciesId]
		if not art or not Theme.KitImage(art.Frame) or not Theme.KitImage(art.Button) then
			return false
		end
	end
	return true
end

local function buildArt(ctx: any)
	-- Full-screen holder (the window manager pops it in); the stage inside is scaled to fit.
	local root = Theme.Make("Frame", {
		Name = "StarterSelect",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	}, ctx.Gui)
	local stage = Theme.Make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(STAGE.X, STAGE.Y),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, root)
	local fit = Theme.Make("UIScale", { Name = "Fit" }, stage)
	local function refit()
		local screen = ctx.Gui.AbsoluteSize
		local guiScale = ctx.Gui:FindFirstChildOfClass("UIScale")
		local g = if guiScale then guiScale.Scale else 1
		if screen.X <= 0 or screen.Y <= 0 then
			return
		end
		fit.Scale = math.min(1, screen.X * 0.96 / (STAGE.X * g), screen.Y * 0.94 / (STAGE.Y * g))
	end
	ctx.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	task.defer(refit)

	-- Dark wood behind the frame's open middle, then the frame on top.
	local wood = Theme.Make("Frame", {
		BackgroundColor3 = Color3.fromRGB(56, 35, 21),
		Position = UDim2.fromOffset(INNER_X - 14, INNER_Y - 14),
		Size = UDim2.fromOffset(INNER_W + 28, INNER_H + 28),
		ZIndex = 10,
	}, stage)
	Theme.Corner(wood, 12)
	Theme.Gradient(wood, 1, 0.7)
	kitImage(stage, "WindowFrame", { Size = UDim2.fromScale(1, 1), ZIndex = 11 })

	local title = label(stage, "Welcome to your empire!", {
		FontFace = Theme.Title,
		TextColor3 = CREAM,
		TextSize = 34,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 130),
		Size = UDim2.new(1, 0, 0, 42),
	})
	outline(title, 2.5)
	local subtitle = label(stage, "Choose a partner creature. You'll meet the other two soon.", {
		TextSize = 16,
		TextWrapped = false,
		Position = UDim2.fromOffset(0, 172),
		Size = UDim2.new(1, 0, 0, 22),
	})
	outline(subtitle, 1.5)

	local count = #CreatureConfig.Starters
	local rowWidth = count * CARD.X + (count - 1) * CARD_GAP
	local x0 = INNER_X + (INNER_W - rowWidth) / 2
	local y0 = 202
	local busy = false
	for index, speciesId in CreatureConfig.Starters do
		local species = CreatureConfig.Species[speciesId]
		local art = ART[speciesId]
		local holder = Theme.Make("Frame", {
			Name = speciesId,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x0 + (index - 1) * (CARD.X + CARD_GAP), y0),
			Size = UDim2.fromOffset(CARD.X, CARD.Y),
			ZIndex = 12,
		}, stage)
		local tint = Theme.Make("Frame", {
			BackgroundColor3 = art.Tint,
			Position = UDim2.fromOffset(28, 28),
			Size = UDim2.new(1, -56, 1, -56),
			ZIndex = 12,
		}, holder)
		Theme.Corner(tint, 10)
		Theme.Gradient(tint, 1, 0.55)
		kitImage(holder, art.Frame, { Size = UDim2.fromScale(1, 1), ZIndex = 13 })

		-- The creature: the painted portrait, or the 3D model if it isn't available.
		local artBox = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(38, 36),
			Size = UDim2.fromOffset(CARD.X - 76, 112),
			ZIndex = 14,
		}, holder)
		if Theme.KitImage(art.Portrait) then
			kitImage(artBox, art.Portrait, { Size = UDim2.fromScale(1, 1), ZIndex = 14 })
		else
			Viewport.Creature(artBox, speciesId, nil, { Spin = true })
		end

		local name = label(holder, species.Name, {
			FontFace = Theme.Heavy,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 26,
			TextWrapped = false,
			Position = UDim2.fromOffset(0, 150),
			Size = UDim2.new(1, 0, 0, 30),
		})
		outline(name, 2)

		-- Family and rarity badges, side by side and centred.
		local badges = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 184),
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = 14,
		}, holder)
		Theme.List(badges, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		local function badge(piece: string, order: number)
			local size = UiKit[piece].Size
			kitImage(badges, piece, {
				Size = UDim2.fromOffset(math.floor(size.X * 26 / size.Y), 26),
				LayoutOrder = order,
				ZIndex = 14,
			})
		end
		badge(art.Badge, 1)
		if species.Rarity == "Common" and Theme.KitImage("BadgeCommon") then
			badge("BadgeCommon", 2)
		else
			local rarity = RarityConfig.Get(species.Rarity)
			Theme.Chip(badges, RarityConfig.Label(species.Rarity), rarity.Color, { TextSize = 12, LayoutOrder = 2 })
		end

		local inset = 38
		local desc = label(holder, species.Description, {
			Position = UDim2.fromOffset(inset, 214),
			Size = UDim2.new(1, -inset * 2, 0, 44),
		})
		fitText(desc, 13)
		local best, bestValue = nil, 0
		for jobId, value in species.JobAffinity do
			if value > bestValue then
				best, bestValue = jobId, value
			end
		end
		label(
			holder,
			`<b>Best at:</b> {best and JobConfig[best].Name or "?"} · Farming {Format.Percent(
				species.JobAffinity.Farmer or 0
			)}`,
			{
				TextColor3 = Color3.fromRGB(255, 215, 120),
				TextSize = 12,
				TextWrapped = false,
				Position = UDim2.fromOffset(inset, 260),
				Size = UDim2.new(1, -inset * 2, 0, 14),
			}
		)
		local ability = label(holder, `<b>{species.Active.Name}:</b> {species.Active.Description}`, {
			TextColor3 = Color3.fromRGB(225, 210, 190),
			Position = UDim2.fromOffset(inset, 276),
			Size = UDim2.new(1, -inset * 2, 0, 24),
		})
		fitText(ability, 11)

		-- The painted "Choose ..." button.
		local buttonSize = UiKit[art.Button].Size
		local bw = 196
		local bh = math.floor(buttonSize.Y * bw / buttonSize.X)
		local choose = Theme.Make("ImageButton", {
			Name = "Choose",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -34),
			Size = UDim2.fromOffset(bw, bh),
			ZIndex = 15,
		}, holder)
		Theme.KitApply(choose, art.Button)
		local pop = Theme.Make("UIScale", {}, choose)
		choose.MouseEnter:Connect(function()
			pop.Scale = 1.05
		end)
		choose.MouseLeave:Connect(function()
			pop.Scale = 1
		end)
		choose.Activated:Connect(function()
			Theme.OnClick()
			if busy then
				return
			end
			busy = true
			local ok, result = ctx.Request("ChooseStarter", speciesId)
			busy = false
			if not ok then
				ctx.Notify(result, "Error")
			end
		end)
	end

	return {
		Root = root,
		Modal = true,
		Open = function() end,
	}
end

function StarterSelect.new(ctx: any)
	if canUseArt() then
		return buildArt(ctx)
	end
	return buildDrawn(ctx)
end

return StarterSelect
