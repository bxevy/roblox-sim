--!strict
-- The interface's visual language and the small kit every screen is built from.
--
-- Look (the creator's mockup): warm wooden panels with a golden trim, cream text, chunky
-- rounded Fredoka One for headings and buttons, Merriweather for window titles. Buttons:
-- leaf green (primary actions), sunset orange (buy / claim), wood (everything else).
-- Rarity colours are always paired with a glyph + text label.
-- Feel: buttons lift on hover, press in on click, and windows pop in. Reduced motion
-- turns the pops into simple fades.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
Theme.Bold = Font.new("rbxasset://fonts/families/FredokaOne.json")
Theme.Heavy = Font.new("rbxasset://fonts/families/FredokaOne.json")
Theme.Title = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

Theme.Colors = {
	Panel = Color3.fromRGB(78, 48, 26), -- dark wood
	PanelRaised = Color3.fromRGB(104, 66, 36), -- lighter plank
	PanelSunken = Color3.fromRGB(50, 30, 16), -- inset / bar track
	Border = Color3.fromRGB(226, 176, 92), -- golden trim
	Text = Color3.fromRGB(255, 246, 225), -- cream
	Muted = Color3.fromRGB(222, 196, 150), -- parchment
	Primary = Color3.fromRGB(96, 186, 58), -- leaf green
	PrimaryDark = Color3.fromRGB(54, 122, 34),
	Gold = Color3.fromRGB(255, 205, 80),
	Success = Color3.fromRGB(110, 210, 120),
	Danger = Color3.fromRGB(235, 95, 95),
	Warning = Color3.fromRGB(255, 170, 70),
	Button = Color3.fromRGB(122, 80, 44), -- wood button
	TextShadow = Color3.fromRGB(46, 26, 10), -- outline behind button and title text
}

Theme.ReducedMotion = false

-- Phones and tablets: bigger tap targets and fewer things on screen at once.
function Theme.IsTouch(): boolean
	local uis = game:GetService("UserInputService")
	return uis.TouchEnabled and not uis.MouseEnabled
end

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Click sound hook (set by UIController so the kit doesn't depend on AudioController).
Theme.OnClick = function() end

function Theme.Make(className: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props or {} :: { [string]: any } do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.Corner(parent: Instance, radius: number?): UICorner
	return Theme.Make("UICorner", { CornerRadius = UDim.new(0, radius or 14) }, parent)
end

function Theme.Stroke(parent: Instance, color: Color3?, transparency: number?, thickness: number?): UIStroke
	return Theme.Make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Theme.Colors.Border,
		Transparency = transparency or 0.82,
		Thickness = thickness or 1,
	}, parent)
end

function Theme.Padding(parent: Instance, all: number, horizontal: number?): UIPadding
	return Theme.Make("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, horizontal or all),
		PaddingRight = UDim.new(0, horizontal or all),
	}, parent)
end

function Theme.List(
	parent: Instance,
	padding: number,
	direction: Enum.FillDirection?,
	align: Enum.HorizontalAlignment?
): UIListLayout
	return Theme.Make("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

function Theme.Gradient(parent: Instance, top: number?, bottom: number?): UIGradient
	local a = top or 1
	local b = bottom or 0.82
	return Theme.Make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(a, a, a), Color3.new(b, b, b)),
	}, parent)
end

-- Escapes player-chosen text (names) so it can't inject rich-text tags.
function Theme.Escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- Text label. Size defaults to automatic height at the given text size.
function Theme.Text(parent: Instance?, text: string, size: number, props: { [string]: any }?): TextLabel
	local label = Theme.Make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = text,
		TextSize = size,
		TextColor3 = Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	for key, value in props or {} :: { [string]: any } do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

function Theme.Panel(parent: Instance?, props: { [string]: any }?): Frame
	local frame = Theme.Make("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	})
	for key, value in props or {} :: { [string]: any } do
		(frame :: any)[key] = value
	end
	Theme.Corner(frame)
	-- A golden trim around every wooden panel.
	Theme.Stroke(frame, Theme.Colors.Border, 0.15, 2)
	Theme.Gradient(frame, 1, 0.8)
	frame.Parent = parent
	return frame
end

export type ButtonStyle = "Primary" | "Secondary" | "Gold" | "Danger" | "Ghost"

local STYLE_COLORS: { [string]: Color3 } = {
	Primary = Theme.Colors.Primary,
	Secondary = Theme.Colors.Button,
	Gold = Color3.fromRGB(240, 146, 34), -- sunset orange
	Danger = Theme.Colors.Danger,
	Ghost = Theme.Colors.PanelRaised,
}

-- Button with hover lift, press feedback and disabled state.
-- Returns the button and a setter for enabled/disabled.
function Theme.Button(parent: Instance?, text: string, style: ButtonStyle?, props: { [string]: any }?): TextButton
	local color = STYLE_COLORS[style or "Secondary"]
	local button = Theme.Make("TextButton", {
		BackgroundColor3 = color,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		FontFace = Theme.Bold,
		Text = text,
		TextSize = 17,
		TextColor3 = Theme.Colors.Text,
		-- Cream letters with a dark outline read on every button colour.
		TextStrokeColor3 = Theme.Colors.TextShadow,
		TextStrokeTransparency = 0.25,
		Size = UDim2.new(0, 120, 0, 40),
		Selectable = true,
	})
	for key, value in props or {} :: { [string]: any } do
		(button :: any)[key] = value
	end
	Theme.Corner(button, 10)
	Theme.Gradient(button, 1, 0.72)
	Theme.Stroke(button, Theme.Colors.TextShadow, 0.2, 2)
	local scale = Theme.Make("UIScale", { Scale = 1 }, button)

	button:SetAttribute("BaseColor", color)
	local function hover(on: boolean)
		if button:GetAttribute("Disabled") then
			return
		end
		local base = button:GetAttribute("BaseColor") :: Color3
		TweenService
			:Create(button, FAST, { BackgroundColor3 = if on then base:Lerp(Color3.new(1, 1, 1), 0.12) else base })
			:Play()
		if not Theme.ReducedMotion then
			TweenService:Create(scale, FAST, { Scale = if on then 1.04 else 1 }):Play()
		end
	end
	button.MouseEnter:Connect(function()
		hover(true)
	end)
	button.MouseLeave:Connect(function()
		hover(false)
	end)
	button.SelectionGained:Connect(function()
		hover(true)
	end)
	button.SelectionLost:Connect(function()
		hover(false)
	end)
	button.MouseButton1Down:Connect(function()
		if not Theme.ReducedMotion and not button:GetAttribute("Disabled") then
			TweenService:Create(scale, FAST, { Scale = 0.95 }):Play()
		end
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if not button:GetAttribute("Disabled") then
			Theme.OnClick()
		end
	end)
	button.Parent = parent
	return button
end

function Theme.SetEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	local base = button:GetAttribute("BaseColor") :: Color3
	button.BackgroundColor3 = if enabled then base else base:Lerp(Color3.fromRGB(40, 44, 56), 0.7)
	button.TextTransparency = if enabled then 0 else 0.45
end

function Theme.SetStyle(button: TextButton, style: ButtonStyle)
	local color = STYLE_COLORS[style]
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
	button.TextColor3 = Theme.Colors.Text
end

-- Horizontal progress bar. Returns the frame and a setter (0..1).
function Theme.Bar(parent: Instance?, color: Color3, height: number?): (Frame, (number) -> ())
	local back = Theme.Make("Frame", {
		BackgroundColor3 = Theme.Colors.PanelSunken,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 8),
	}, parent)
	Theme.Corner(back, 99)
	local fill = Theme.Make("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, back)
	Theme.Corner(fill, 99)
	Theme.Gradient(fill, 1, 0.75)
	local last = -1
	local function setValue(alpha: number)
		alpha = math.clamp(alpha, 0, 1)
		if math.abs(alpha - last) < 0.001 then
			return
		end
		last = alpha
		fill.Size = UDim2.fromScale(alpha, 1)
	end
	return back, setValue
end

-- Pops an element in (scale + fade). Respects reduced motion.
function Theme.PopIn(frame: GuiObject)
	local scale = frame:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = Theme.Make("UIScale", { Name = "PopScale", Scale = 1 }, frame)
	end
	local s = scale :: UIScale
	if Theme.ReducedMotion then
		s.Scale = 1
		return
	end
	s.Scale = 0.86
	TweenService:Create(s, POP, { Scale = 1 }):Play()
end

-- Points gamepad selection at the first selectable button inside a container.
function Theme.FocusFirst(container: Instance)
	if not GuiService:IsTenFootInterface() and not game:GetService("UserInputService").GamepadEnabled then
		return
	end
	for _, child in container:GetDescendants() do
		if child:IsA("GuiButton") and child.Selectable and child.Visible then
			GuiService.SelectedObject = child
			return
		end
	end
end

-- A small rounded tag: "◆ Rare" style labels, job chips, etc.
function Theme.Chip(parent: Instance?, text: string, color: Color3, props: { [string]: any }?): TextLabel
	local chip = Theme.Make("TextLabel", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.75,
		FontFace = Theme.Bold,
		Text = text,
		TextSize = 14,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 22),
	})
	for key, value in props or {} :: { [string]: any } do
		(chip :: any)[key] = value
	end
	Theme.Corner(chip, 99)
	Theme.Padding(chip, 0, 9)
	Theme.Stroke(chip, color, 0.5)
	chip.Parent = parent
	return chip
end

return Theme
