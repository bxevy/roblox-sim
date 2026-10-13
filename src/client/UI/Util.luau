-- Small helpers for building UI from code, and the shared look of every window.
--
-- Theme: deep slate panels with a soft border, rounded corners, Builder Sans text, and
-- buttons that lift on hover and press in when clicked. Windows open with a quick pop,
-- shrink to fit small screens, and only one is open at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Util = {}

local clickSound = Instance.new("Sound")
clickSound.SoundId = Config.Audio.Sfx.Click[1]
clickSound.Volume = Config.Audio.Sfx.Click[2]
clickSound.Parent = SoundService

-- Plays a sound effect from Config.Audio.Sfx for this player only.
function Util.playSfx(name: string)
	local def = Config.Audio.Sfx[name]
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def[1]
	sound.Volume = def[2]
	sound.PlaybackSpeed = def[3]
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Theme ---------------------------------------------------------------------------

Util.Font = Enum.Font.BuilderSansBold
Util.TitleFont = Enum.Font.BuilderSansExtraBold
Util.PanelColor = Color3.fromRGB(20, 18, 28)
Util.ButtonColor = Color3.fromRGB(46, 42, 60)
Util.Theme = {
	Panel = Color3.fromRGB(20, 18, 28),
	PanelLight = Color3.fromRGB(32, 29, 44),
	Header = Color3.fromRGB(30, 26, 44),
	Border = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(240, 236, 248),
	Muted = Color3.fromRGB(165, 158, 185),
	Gold = Color3.fromRGB(255, 205, 80),
	Accent = Color3.fromRGB(255, 170, 60),
	Danger = Color3.fromRGB(215, 70, 70),
	Success = Color3.fromRGB(80, 190, 110),
}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Util.corner(parent: Instance, radius: number?)
	local c = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

function Util.padding(parent: Instance, pixels: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, pixels)
	p.PaddingRight = UDim.new(0, pixels)
	p.PaddingTop = UDim.new(0, pixels)
	p.PaddingBottom = UDim.new(0, pixels)
	p.Parent = parent
end

-- A thin light border (or any stroke) around a frame. A frame only shows one stroke, so
-- this restyles the existing one if there is one.
function Util.stroke(parent: Instance, color: Color3?, transparency: number?, thickness: number?): UIStroke
	local s = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or Util.Theme.Border
	s.Transparency = transparency or 0.86
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

-- Creates an instance, sets properties, then parents it.
function Util.make(className: string, parent: Instance?, props: { [string]: any }?): any
	local inst = Instance.new(className)
	for k, v in props or {} :: { [string]: any } do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

-- Scaled text never grows past this, so labels in big boxes stay tidy.
local DEFAULT_MAX_TEXT = 26

-- Text label. Extra option: MaxText = largest text size when TextScaled (default 26).
function Util.text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Util.make("TextLabel", nil, {
		BackgroundTransparency = 1,
		Font = Util.Font,
		TextColor3 = Util.Theme.Text,
		TextStrokeTransparency = 1,
		TextScaled = true,
	})
	local maxText = DEFAULT_MAX_TEXT
	for k, v in props do
		if k == "MaxText" then
			maxText = v
		else
			(label :: any)[k] = v
		end
	end
	Util.make("UITextSizeConstraint", label, { MaxTextSize = maxText, MinTextSize = 8 })
	label.Parent = parent
	return label
end

function Util.panel(parent: Instance, props: { [string]: any }): Frame
	local frame = Util.make("Frame", nil, {
		BackgroundColor3 = Util.PanelColor,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	})
	for k, v in props do
		(frame :: any)[k] = v
	end
	Util.corner(frame)
	Util.stroke(frame)
	frame.Parent = parent
	return frame
end

-- Button with depth (top-lit gradient), a soft border, and hover / press feedback.
-- Pass AutoButtonColor = false for a button that should look inert (no hover).
function Util.button(parent: Instance, props: { [string]: any }): TextButton
	local button = Util.make("TextButton", nil, {
		BackgroundColor3 = Util.ButtonColor,
		Font = Util.Font,
		TextColor3 = Util.Theme.Text,
		TextScaled = true,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	})
	local interactive = true
	local maxText = 22
	for k, v in props do
		if k == "AutoButtonColor" then
			interactive = v
		elseif k == "MaxText" then
			maxText = v
		else
			(button :: any)[k] = v
		end
	end
	button.AutoButtonColor = false
	Util.corner(button, 10)
	Util.make("UIGradient", button, {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 186, 200)),
	})
	Util.stroke(button, Color3.new(0, 0, 0), 0.55, 1.5)
	Util.make("UITextSizeConstraint", button, { MaxTextSize = maxText, MinTextSize = 8 })
	-- Hover glow overlay + scale for press
	local hover = Util.make("Frame", button, {
		Name = "Hover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 1,
	})
	Util.corner(hover, 10)
	local scale = Util.make("UIScale", button, { Scale = 1 })
	if interactive then
		button.MouseEnter:Connect(function()
			TweenService:Create(hover, FAST, { BackgroundTransparency = 0.88 }):Play()
			TweenService:Create(scale, FAST, { Scale = 1.03 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(hover, FAST, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(scale, FAST, { Scale = 1 }):Play()
		end)
		button.MouseButton1Down:Connect(function()
			TweenService:Create(scale, FAST, { Scale = 0.95 }):Play()
		end)
		button.MouseButton1Up:Connect(function()
			TweenService:Create(scale, FAST, { Scale = 1.03 }):Play()
		end)
	end
	button.Activated:Connect(function()
		SoundService:PlayLocalSound(clickSound)
	end)
	button.Parent = parent
	return button
end

-- Windows ----------------------------------------------------------------------------

local windows: { Frame } = {}

-- Fits a window on small screens (keeps a margin around it).
local function fitScale(size: Vector2): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.min(1, (viewport.X - 24) / size.X, (viewport.Y - 24) / size.Y)
end

-- A centered pop-up window with a header bar and a close button. Returns (window, body).
function Util.window(parent: Instance, title: string, size: Vector2, onClose: (() -> ())?): (Frame, Frame)
	-- The window itself is an invisible container: a drop shadow, the panel surface, then
	-- the header and body on top.
	local window = Util.make("Frame", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
	})
	local shadow = Util.make("Frame", window, {
		Name = "Shadow",
		Position = UDim2.fromOffset(4, 8),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = -1,
	})
	Util.corner(shadow, 14)
	Util.panel(window, {
		Name = "Surface",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Util.Theme.Panel,
		BackgroundTransparency = 0.03,
		ZIndex = 0,
	})
	local scale = Util.make("UIScale", window, { Scale = fitScale(size) })

	-- Header bar
	local header = Util.make("Frame", window, {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Util.Theme.Header,
		BorderSizePixel = 0,
	})
	Util.corner(header, 12)
	Util.make("UIGradient", header, {
		Rotation = 0,
		Color = ColorSequence.new(Color3.fromRGB(70, 46, 100), Color3.fromRGB(30, 26, 44)),
	})
	-- Square off the header's bottom corners
	Util.make("Frame", header, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Util.Theme.Header,
		BorderSizePixel = 0,
	})
	Util.make("Frame", header, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Util.Theme.Accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	Util.text(header, {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -80, 1, -2),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Util.TitleFont,
		TextScaled = false,
		TextSize = 26,
		Text = title,
		Name = "Title",
		ZIndex = 2,
	})
	if onClose then
		local close = Util.button(header, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -1),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.fromRGB(60, 52, 78),
			Text = "X",
			MaxText = 16,
			ZIndex = 2,
		})
		Util.corner(close, 17)
		close.MouseEnter:Connect(function()
			TweenService:Create(close, FAST, { BackgroundColor3 = Util.Theme.Danger }):Play()
		end)
		close.MouseLeave:Connect(function()
			TweenService:Create(close, FAST, { BackgroundColor3 = Color3.fromRGB(60, 52, 78) }):Play()
		end)
		close.Activated:Connect(onClose)
	end
	local body = Util.make("Frame", window, {
		Name = "Body",
		Position = UDim2.fromOffset(14, 64),
		Size = UDim2.new(1, -28, 1, -78),
		BackgroundTransparency = 1,
	})

	-- Pop open, and close any other window
	table.insert(windows, window)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible then
			return
		end
		for _, other in windows do
			if other ~= window and other.Visible then
				other.Visible = false
			end
		end
		local target = fitScale(size)
		scale.Scale = target * 0.94
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			scale.Scale = fitScale(size)
		end)
	end
	return window, body
end

-- Vertical scrolling list. Returns the ScrollingFrame.
function Util.list(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local frame = Util.make("ScrollingFrame", parent, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(200, 190, 230),
		ScrollBarImageTransparency = 0.4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	for k, v in props or {} :: { [string]: any } do
		(frame :: any)[k] = v
	end
	Util.make("UIListLayout", frame, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	Util.make("UIPadding", frame, { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) })
	return frame
end

-- A thin horizontal bar (health, XP...). Returns (back, fill).
function Util.bar(parent: Instance, props: { [string]: any }, color: Color3): (Frame, Frame)
	local back = Util.make("Frame", parent, {
		BackgroundColor3 = Color3.fromRGB(12, 10, 18),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	})
	for k, v in props do
		(back :: any)[k] = v
	end
	Util.corner(back, 100)
	Util.stroke(back, Color3.new(0, 0, 0), 0.4, 1.5)
	local fill = Util.make("Frame", back, {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
	Util.corner(fill, 100)
	Util.make("UIGradient", fill, {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
	})
	return back, fill
end

function Util.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Util
