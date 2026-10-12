-- Small helpers for building UI from code.

local Util = {}

Util.Font = Enum.Font.FredokaOne
Util.PanelColor = Color3.fromRGB(25, 22, 30)
Util.ButtonColor = Color3.fromRGB(55, 48, 66)

function Util.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
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

-- Creates an instance, sets properties, then parents it.
function Util.make(className: string, parent: Instance?, props: { [string]: any }?): any
	local inst = Instance.new(className)
	for k, v in props or {} :: { [string]: any } do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

function Util.text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Util.make("TextLabel", nil, {
		BackgroundTransparency = 1,
		Font = Util.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		TextScaled = true,
	})
	for k, v in props do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

function Util.panel(parent: Instance, props: { [string]: any }): Frame
	local frame = Util.make("Frame", nil, {
		BackgroundColor3 = Util.PanelColor,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	})
	for k, v in props do
		(frame :: any)[k] = v
	end
	Util.corner(frame)
	frame.Parent = parent
	return frame
end

function Util.button(parent: Instance, props: { [string]: any }): TextButton
	local button = Util.make("TextButton", nil, {
		BackgroundColor3 = Util.ButtonColor,
		Font = Util.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	})
	for k, v in props do
		(button :: any)[k] = v
	end
	Util.corner(button, 8)
	button.Parent = parent
	return button
end

-- A centered pop-up window with a title and a close (X) button. Returns (window, body).
function Util.window(parent: Instance, title: string, size: Vector2, onClose: (() -> ())?): (Frame, Frame)
	local window = Util.panel(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	Util.make("UISizeConstraint", window, { MaxSize = Vector2.new(size.X, size.Y) })
	Util.text(window, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -70, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Name = "Title",
	})
	if onClose then
		local close = Util.button(window, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Color3.fromRGB(170, 50, 50),
			Text = "X",
		})
		close.Activated:Connect(onClose)
	end
	local body = Util.make("Frame", window, {
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 1, -66),
		BackgroundTransparency = 1,
	})
	return window, body
end

-- Vertical scrolling list. Returns the ScrollingFrame.
function Util.list(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local frame = Util.make("ScrollingFrame", parent, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	for k, v in props or {} :: { [string]: any } do
		(frame :: any)[k] = v
	end
	Util.make("UIListLayout", frame, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	return frame
end

function Util.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Util
