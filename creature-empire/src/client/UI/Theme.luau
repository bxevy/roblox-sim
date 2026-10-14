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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiKit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiKit"))

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

-- The creator's UI kit (Config/UiKit): a picture behind a frame or button, 9-sliced so the
-- vine corners keep their shape. Returns nil (and changes nothing) while the piece has no
-- uploaded id, so everything falls back to the drawn wood look.
local kitFailed: { [string]: boolean } = {}

function Theme.KitImage(name: string): string?
	local piece = UiKit[name]
	if not piece or piece.Id == 0 or kitFailed[name] then
		return nil
	end
	return `rbxassetid://{piece.Id}`
end

-- Loads every uploaded kit picture once, before the interface is built (behind the loading
-- screen). A picture that can't load (a Decal id instead of an Image id, or one still in
-- moderation) is skipped, so that piece keeps the drawn look instead of showing a blank.
function Theme.PreloadKit(timeout: number?)
	local ContentProvider = game:GetService("ContentProvider")
	local pending = 0
	for name, piece in UiKit do
		if piece.Id ~= 0 then
			pending += 1
			task.spawn(function()
				local ok = pcall(function()
					ContentProvider:PreloadAsync({ `rbxassetid://{piece.Id}` }, function(_, status)
						if status ~= Enum.AssetFetchStatus.Success then
							kitFailed[name] = true
						end
					end)
				end)
				if not ok then
					kitFailed[name] = true
				end
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + (timeout or 8)
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	for name in kitFailed do
		warn(
			`[UI kit] {name} (id {UiKit[name].Id}) didn't load; using the drawn look. Is it an Image id (not a Decal id)?`
		)
	end
end

function Theme.Skin(gui: GuiObject, name: string): ImageLabel?
	local image = Theme.KitImage(name)
	if not image then
		return nil
	end
	local piece = UiKit[name]
	-- Panels are ImageLabels: the picture is their own image, so it never takes a slot in
	-- their UIListLayout / UIGridLayout (a child picture would be stacked like an item).
	if gui:IsA("ImageLabel") then
		local own = gui :: ImageLabel
		own.Image = image
		own.ScaleType = if piece.SliceCenter then Enum.ScaleType.Slice else Enum.ScaleType.Fit
		if piece.SliceCenter then
			own.SliceCenter = piece.SliceCenter
		end
		own:SetAttribute("Piece", name)
		own.BackgroundTransparency = 1
		-- The drawn trim and shading switch off (kept, since other code recolours them).
		for _, child in own:GetChildren() do
			if child:IsA("UIStroke") or child:IsA("UIGradient") then
				(child :: any).Enabled = false
			end
		end
		if not own:GetAttribute("SkinScaled") then
			own:SetAttribute("SkinScaled", true)
			local function rescale()
				local kit = UiKit[own:GetAttribute("Piece") :: string]
				if kit and kit.SliceCenter then
					local fit = math.min(own.AbsoluteSize.Y / kit.Size.Y, own.AbsoluteSize.X / kit.Size.X * 2.5)
					own.SliceScale = math.clamp(fit, 0.08, 0.4)
				end
			end
			own:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
			task.defer(rescale)
		end
		return own
	end
	-- Buttons and plain frames without a layout: the picture is a child behind the rest.
	local skin = gui:FindFirstChild("Skin") :: ImageLabel?
	if not skin then
		local new = Instance.new("ImageLabel")
		new.Name = "Skin"
		new.BackgroundTransparency = 1
		new.Size = UDim2.fromScale(1, 1)
		new.ZIndex = 0 -- behind the frame's own children
		new.Parent = gui
		skin = new
		-- Keep the corners in proportion to the frame's height.
		local function rescale()
			local current = gui:FindFirstChild("Skin") :: ImageLabel?
			local kit = current and UiKit[current:GetAttribute("Piece") :: string]
			if current and kit and kit.SliceCenter then
				-- Corners in proportion to the frame, but never chunky: at most 40% of the art.
				local fit = math.min(gui.AbsoluteSize.Y / kit.Size.Y, gui.AbsoluteSize.X / kit.Size.X * 2.5)
				current.SliceScale = math.clamp(fit, 0.08, 0.4)
			end
		end
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
		task.defer(rescale)
	end
	local s = skin :: ImageLabel
	s:SetAttribute("Piece", name)
	s.Image = image
	if piece.SliceCenter then
		s.ScaleType = Enum.ScaleType.Slice
		s.SliceCenter = piece.SliceCenter
	else
		s.ScaleType = Enum.ScaleType.Fit
	end
	gui.BackgroundTransparency = 1
	for _, child in gui:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UIGradient") then
			(child :: any).Enabled = false
		end
	end
	return s
end

-- A panel is an ImageLabel (it looks and lays out exactly like a Frame) so a kit picture
-- can be its own image. Typed as Frame for the callers.
function Theme.Panel(parent: Instance?, props: { [string]: any }?): Frame
	local frame = Theme.Make("ImageLabel", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Image = "",
	})
	for key, value in props or {} :: { [string]: any } do
		(frame :: any)[key] = value
	end
	Theme.Corner(frame)
	-- A golden trim around every wooden panel.
	Theme.Stroke(frame, Theme.Colors.Border, 0.15, 2)
	Theme.Gradient(frame, 1, 0.8)
	Theme.Skin(frame, "CardFrame")
	frame.Parent = parent
	return frame
end

export type ButtonStyle = "Primary" | "Secondary" | "Gold" | "Danger" | "Ghost"

-- Kit pictures per button style (the green button has its leaf, the orange its coin).
local STYLE_KIT: { [string]: string } = {
	Primary = "ButtonGreen",
	Gold = "ButtonOrange",
	Secondary = "TabInactive",
	Ghost = "TabInactive",
}

-- A kit button draws its text on a label above the picture (a button's own text would be
-- hidden under it), kept in sync with the button's Text, size, font and colour.
local function skinButton(button: TextButton, style: string)
	local kitName = STYLE_KIT[style]
	local skin = kitName and Theme.Skin(button, kitName)
	local label = button:FindFirstChild("SkinLabel") :: TextLabel?
	if not skin then
		local old = button:FindFirstChild("Skin")
		if old then
			old:Destroy() -- a style without kit art (Danger): back to the drawn look
			button.BackgroundTransparency = 0
			for _, child in button:GetChildren() do
				if child:IsA("UIStroke") or child:IsA("UIGradient") then
					(child :: any).Enabled = true
				end
			end
		end
		if label then
			label:Destroy()
			button.TextTransparency = (button:GetAttribute("Disabled") and 0.45) or 0
			button.TextStrokeTransparency = 0.25
		end
		return
	end
	if not label then
		local new = Instance.new("TextLabel")
		new.Name = "SkinLabel"
		new.BackgroundTransparency = 1
		new.Size = UDim2.fromScale(1, 1)
		new.ZIndex = 2
		new.TextStrokeColor3 = Theme.Colors.TextShadow
		new.TextStrokeTransparency = 0.25
		new.Parent = button
		label = new
		local function sync()
			local l = button:FindFirstChild("SkinLabel") :: TextLabel?
			if not l then
				return
			end
			l.Text = button.Text
			l.TextSize = button.TextSize
			l.FontFace = button.FontFace
			l.TextColor3 = button.TextColor3
			l.RichText = button.RichText
			l.TextWrapped = button.TextWrapped
			l.TextXAlignment = button.TextXAlignment
			-- Leave room for the icon painted on the left of the picture.
			local skinNow = button:FindFirstChild("Skin") :: ImageLabel?
			local kit = skinNow and UiKit[skinNow:GetAttribute("Piece") :: string]
			local inset = if kit and kit.SliceCenter
				then button.AbsoluteSize.Y * (kit.SliceCenter.Min.X / kit.Size.Y) * 0.8
				else 0
			l.Position = UDim2.fromOffset(inset, 0)
			l.Size = UDim2.new(1, -inset - 6, 1, 0)
			button.TextTransparency = 1
			button.TextStrokeTransparency = 1
		end
		for _, property in { "Text", "TextSize", "FontFace", "TextColor3", "RichText", "AbsoluteSize" } do
			button:GetPropertyChangedSignal(property):Connect(sync)
		end
		task.defer(sync)
	end
	local l = label :: TextLabel
	l.TextTransparency = if button:GetAttribute("Disabled") then 0.45 else 0
end

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
	skinButton(button, style or "Secondary")
	local function hover(on: boolean)
		if button:GetAttribute("Disabled") then
			return
		end
		local base = button:GetAttribute("BaseColor") :: Color3
		local skin = button:FindFirstChild("Skin") :: ImageLabel?
		if skin then
			TweenService
				:Create(skin, FAST, { ImageColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(235, 235, 235) })
				:Play()
		else
			TweenService
				:Create(button, FAST, { BackgroundColor3 = if on then base:Lerp(Color3.new(1, 1, 1), 0.12) else base })
				:Play()
		end
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
	local skin = button:FindFirstChild("Skin") :: ImageLabel?
	local label = button:FindFirstChild("SkinLabel") :: TextLabel?
	if skin then
		skin.ImageColor3 = if enabled then Color3.fromRGB(235, 235, 235) else Color3.fromRGB(110, 105, 100)
	end
	if label then
		label.TextTransparency = if enabled then 0 else 0.45
	else
		button.TextTransparency = if enabled then 0 else 0.45
	end
end

function Theme.SetStyle(button: TextButton, style: ButtonStyle)
	local color = STYLE_COLORS[style]
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
	button.TextColor3 = Theme.Colors.Text
	skinButton(button, style)
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

-- A progress bar on the kit's wooden track (vine ends), falling back to the drawn bar.
function Theme.KitBar(parent: Instance?, color: Color3, height: number): (GuiObject, (number) -> ())
	local image = Theme.KitImage("ProgressBar")
	if not image then
		return Theme.Bar(parent, color, math.floor(height / 3))
	end
	local piece = UiKit.ProgressBar
	local track = Theme.Make("ImageLabel", {
		Name = "KitBar",
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = piece.SliceCenter,
		Size = UDim2.new(1, 0, 0, height),
	}, parent)
	-- The groove inside the art: x 68..478, y 38..66 of 556x110.
	local s = height / piece.Size.Y
	track.SliceScale = s
	local groove = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(68 * s, 38 * s),
		Size = UDim2.new(1, -(68 + 78) * s, 0, 28 * s),
	}, track)
	Theme.Corner(groove, 99)
	local fill = Theme.Make("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, groove)
	Theme.Corner(fill, 99)
	Theme.Gradient(fill, 1, 0.7)
	local function setValue(alpha: number)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
	return track, setValue
end

-- Just the symbol of a kit menu icon (round, without its vine ring), or nil.
function Theme.KitIcon(parent: Instance?, name: string, props: { [string]: any }?): ImageLabel?
	local image = Theme.KitImage(name)
	local inner = UiKit[name] and UiKit[name].Inner
	if not image or not inner then
		return nil
	end
	local icon = Theme.Make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = image,
		ImageRectOffset = inner.Min,
		ImageRectSize = inner.Max - inner.Min,
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	Theme.Corner(icon, 999)
	local extra: { [string]: any } = props or {}
	for key, value in extra do
		(icon :: any)[key] = value
	end
	return icon
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
