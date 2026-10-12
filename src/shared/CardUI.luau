-- Builds prestige emblems and player cards out of UI objects. Used by the client (card
-- window) and the server (nameplates over players' heads), so it only creates instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)

local CardUI = {}

-- Gradients with this tag are rotated slowly by the client for animated emblems/frames.
CardUI.SpinTag = "SpinGradient"

local FONT = Enum.Font.FredokaOne

local function make(className: string, parent: Instance?, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function gradient(parent: Instance, colors: { Color3 }, rotation: number, spin: boolean?)
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	local g = make("UIGradient", parent, { Color = ColorSequence.new(keypoints), Rotation = rotation })
	if spin then
		g:AddTag(CardUI.SpinTag)
	end
	return g
end

-- One layer of the emblem shape, filling `parent`.
local function shapeLayer(parent: Instance, shape: string, color: Color3, scale: number, zIndex: number, spin: boolean?)
	local function piece(rotation: number, sizeX: number, sizeY: number, round: boolean?)
		local frame = make("Frame", parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(sizeX * scale, sizeY * scale),
			Rotation = rotation,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = zIndex,
		})
		gradient(frame, { color, color:Lerp(Color3.new(0, 0, 0), 0.35) }, 90, spin)
		if round then
			make("UICorner", frame, { CornerRadius = UDim.new(0.5, 0) })
		end
	end
	if shape == "Circle" then
		piece(0, 1, 1, true)
	elseif shape == "Diamond" then
		piece(45, 0.72, 0.72)
	elseif shape == "Star" then
		piece(0, 0.7, 0.7)
		piece(45, 0.7, 0.7)
	elseif shape == "Hex" then
		for _, r in { 0, 60, 120 } do
			piece(r, 0.5, 0.86)
		end
	else -- Burst: 12 points
		for _, r in { 0, 30, 60 } do
			piece(r, 0.72, 0.72)
		end
	end
end

-- Draws prestige emblem `prestige` (1-10) into a new square frame of `size` pixels.
function CardUI.Emblem(parent: Instance, prestige: number, size: number, position: UDim2?, anchor: Vector2?): Frame?
	local def = Cosmetics.EmblemFor(prestige)
	if not def then
		return nil
	end
	local holder = make("Frame", parent, {
		Name = "Emblem",
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		BackgroundTransparency = 1,
	})
	if def.Wings then
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				local wing = make("Frame", holder, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5 + side * (0.42 + i * 0.07), 0.5 - i * 0.06),
					Size = UDim2.fromScale(0.42 - i * 0.08, 0.14),
					Rotation = side * (-20 - i * 18),
					BackgroundColor3 = def.Accent,
					BorderSizePixel = 0,
					ZIndex = 1,
				})
				make("UICorner", wing, { CornerRadius = UDim.new(0.5, 0) })
			end
		end
	end
	if def.Crown then
		for i = -1, 1 do
			make("Frame", holder, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5 + i * 0.18, 0.12),
				Size = UDim2.fromScale(0.12, if i == 0 then 0.24 else 0.17),
				Rotation = i * 15,
				BackgroundColor3 = def.Accent,
				BorderSizePixel = 0,
				ZIndex = 2,
			})
		end
	end
	shapeLayer(holder, def.Shape, def.Outer, 1, 3, def.Spin)
	shapeLayer(holder, def.Shape, def.Inner, 0.72, 4)
	make("TextLabel", holder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.42),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = def.Accent,
		TextStrokeTransparency = 0.3,
		Text = Cosmetics.Roman(prestige),
		ZIndex = 5,
	})
	return holder
end

-- Fills `frame` with a card background (gradient + pattern).
function CardUI.Background(frame: GuiObject, backgroundId: string)
	local def = Cosmetics.BackgroundsById[backgroundId] or Cosmetics.Backgrounds[1]
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.ClipsDescendants = true
	gradient(frame, def.Colors, def.Rotation or 90)
	local pattern = def.Pattern
	local color = def.PatternColor or Color3.new(1, 1, 1)
	local rng = Random.new(#backgroundId * 97)
	if pattern == "Stripes" then
		for i = -2, 12 do
			make("Frame", frame, {
				Position = UDim2.fromScale(i * 0.1, -0.2),
				Size = UDim2.new(0, 6, 1.6, 0),
				Rotation = 30,
				BackgroundColor3 = color,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
			})
		end
	elseif pattern == "Dots" or pattern == "Stars" then
		for _ = 1, 26 do
			local s = if pattern == "Stars" then rng:NextInteger(2, 4) else rng:NextInteger(6, 14)
			local dot = make("Frame", frame, {
				Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber()),
				Size = UDim2.fromOffset(s, s),
				Rotation = if pattern == "Stars" then 45 else 0,
				BackgroundColor3 = color,
				BackgroundTransparency = if pattern == "Stars" then 0.1 else 0.75,
				BorderSizePixel = 0,
			})
			if pattern == "Dots" then
				make("UICorner", dot, { CornerRadius = UDim.new(0.5, 0) })
			end
		end
	elseif pattern == "Rays" then
		for i = 0, 11 do
			make("Frame", frame, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.75, 0.3),
				Size = UDim2.new(2.4, 0, 0, 10),
				Rotation = i * 15,
				BackgroundColor3 = color,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
			})
		end
	end
	return def
end

export type CardData = {
	UserId: number,
	Name: string,
	Level: number,
	Prestige: number,
	Class: string?,
	Background: string,
	Title: string,
	Frame: string,
	Showcase: { { Label: string, Value: number } },
}

-- Builds a full player card (about 420 x 240) inside `parent`.
function CardUI.Card(parent: Instance, data: CardData): Frame
	local frameDef = Cosmetics.FramesById[data.Frame] or Cosmetics.Frames[1]
	local border = make("Frame", parent, {
		Name = "PlayerCard",
		Size = UDim2.fromOffset(420, 240),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	})
	make("UICorner", border, { CornerRadius = UDim.new(0, 14) })
	gradient(border, frameDef.Colors, 45, frameDef.Spin)

	local inner = make("Frame", border, {
		Position = UDim2.fromOffset(7, 7),
		Size = UDim2.new(1, -14, 1, -14),
		BorderSizePixel = 0,
	})
	make("UICorner", inner, { CornerRadius = UDim.new(0, 10) })
	local bg = CardUI.Background(inner, data.Background)
	local textColor = if bg.TextDark then Color3.fromRGB(40, 28, 18) else Color3.new(1, 1, 1)

	-- Avatar
	local avatar = make("ImageLabel", inner, {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		Image = `rbxthumb://type=AvatarHeadShot&id={data.UserId}&w=150&h=150`,
	})
	make("UICorner", avatar, { CornerRadius = UDim.new(0.5, 0) })
	make("UIStroke", avatar, { Color = frameDef.Colors[1], Thickness = 3 })

	local title = Cosmetics.TitlesById[data.Title] or Cosmetics.Titles[1]
	make("TextLabel", inner, {
		Position = UDim2.fromOffset(122, 16),
		Size = UDim2.new(1, -200, 0, 34),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = textColor,
		TextStrokeTransparency = if bg.TextDark then 1 else 0.4,
		Text = data.Name,
	})
	make("TextLabel", inner, {
		Position = UDim2.fromOffset(122, 50),
		Size = UDim2.new(1, -200, 0, 24),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = title.Color,
		TextStrokeTransparency = 0.2,
		Text = title.Name,
	})
	local class = data.Class and Config.Classes[data.Class]
	make("TextLabel", inner, {
		Position = UDim2.fromOffset(122, 78),
		Size = UDim2.new(1, -200, 0, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if class then class.Color else textColor,
		TextStrokeTransparency = 0.3,
		Text = `Level {data.Level}{if class then "  " .. class.DisplayName else ""}`,
	})

	CardUI.Emblem(inner, data.Prestige, 70, UDim2.new(1, -14, 0, 12), Vector2.new(1, 0))

	-- Showcased stats
	local statRow = make("Frame", inner, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.new(1, -28, 0, 92),
		BackgroundTransparency = 1,
	})
	make("UIListLayout", statRow, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) })
	for _, stat in data.Showcase do
		local box = make("Frame", statRow, {
			Size = UDim2.new(1 / 3, -6, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
		})
		make("UICorner", box, { CornerRadius = UDim.new(0, 8) })
		make("TextLabel", box, {
			Position = UDim2.fromOffset(6, 8),
			Size = UDim2.new(1, -12, 0, 40),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = tostring(math.floor(stat.Value)),
		})
		make("TextLabel", box, {
			Position = UDim2.fromOffset(6, 52),
			Size = UDim2.new(1, -12, 0, 30),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			Text = stat.Label,
		})
	end
	return border
end

return CardUI
