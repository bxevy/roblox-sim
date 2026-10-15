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
local kitStatus: { [string]: string } = {}
-- Pieces shown through their Roblox thumbnail, because the direct image link wouldn't load
-- (it happens in some Studio setups). The thumbnail is the picture fitted into a 420x420
-- square, so the code crops back to the picture and scales its 9-slice numbers to match.
local kitThumb: { [string]: boolean } = {}
local THUMB = 420

function Theme.KitImage(name: string): string?
	local piece = UiKit[name]
	if not piece or piece.Id == 0 or kitFailed[name] then
		return nil
	end
	if kitThumb[name] then
		return `rbxthumb://type=Asset&id={piece.Id}&w={THUMB}&h={THUMB}`
	end
	return `rbxassetid://{piece.Id}`
end

-- How many on-screen picture pixels one pixel of the original art is (1, or less for a
-- thumbnail), and where the art sits inside the picture.
local function kitGeometry(name: string): (number, Vector2)
	local piece = UiKit[name]
	if not kitThumb[name] then
		return 1, Vector2.zero
	end
	local f = THUMB / math.max(piece.Size.X, piece.Size.Y)
	local size = piece.Size * f
	return f, Vector2.new(math.floor((THUMB - size.X) / 2), math.floor((THUMB - size.Y) / 2))
end

local function scaleRect(rect: Rect, f: number): Rect
	return Rect.new(rect.Min * f, rect.Max * f)
end

-- Puts a kit piece on an image (or part of it: `part` is a rect in the original art, like
-- an icon's symbol). Returns the factor to divide SliceScale by, or nil if unavailable.
function Theme.KitApply(label: ImageLabel | ImageButton, name: string, part: Rect?): number?
	local image = Theme.KitImage(name)
	if not image then
		return nil
	end
	local piece = UiKit[name]
	local f, origin = kitGeometry(name)
	local area = part or Rect.new(Vector2.zero, piece.Size)
	local target = label :: any
	target.Image = image
	if f ~= 1 or part then
		target.ImageRectOffset = origin + area.Min * f
		target.ImageRectSize = (area.Max - area.Min) * f
	else
		target.ImageRectOffset = Vector2.zero
		target.ImageRectSize = Vector2.zero
	end
	if piece.SliceCenter and not part then
		target.ScaleType = Enum.ScaleType.Slice
		-- SliceCenter counts in the whole picture's pixels, not the cropped part's, so the
		-- art's position inside the thumbnail is added.
		local scaled = scaleRect(piece.SliceCenter, f)
		target.SliceCenter = Rect.new(scaled.Min + origin, scaled.Max + origin)
	else
		target.ScaleType = Enum.ScaleType.Fit
	end
	target:SetAttribute("KitFactor", f)
	return f
end

-- How big to draw a kit piece's corners on a gui of `size`. Wide strips (buttons, tabs,
-- badges, banner) are drawn at exactly their height, so the icon painted in the end cap
-- keeps its shape; frames keep their corners in proportion, but never chunky.
local STRIPS: { [string]: boolean } = {
	ButtonGreen = true,
	ButtonOrange = true,
	TabActive = true,
	TabInactive = true,
	BadgeGold = true,
	BadgeEssence = true,
	HeaderBanner = true,
	ProgressBar = true,
}
-- How big frame corners are drawn by default (times the art's size). The art looks right
-- near full size: smaller, the vines and flowers thin out to a plain edge.
local FRAME_SCALE: { [string]: number } = {
	LargeFrame = 0.75,
	CardFrame = 0.45,
	TileCommon = 0.6,
	TileRare = 0.6,
	TileEpic = 0.6,
	TileMythic = 0.6,
	PanelSide = 0.9,
	BarGreen = 0.85,
	BarBrown = 0.85,
}
local function kitFit(kit: UiKit.Piece, size: Vector2, wanted: number?): number
	if STRIPS[kit.Name] then
		return math.max(size.Y / kit.Size.Y, 0.05)
	end
	local s = wanted or FRAME_SCALE[kit.Name] or 0.45
	local slice = kit.SliceCenter
	if slice then
		-- The corners never take more than 80% of the box, so small boxes stay boxes.
		local edgeX = slice.Min.X + (kit.Size.X - slice.Max.X)
		local edgeY = slice.Min.Y + (kit.Size.Y - slice.Max.Y)
		s = math.min(s, size.X * 0.8 / edgeX, size.Y * 0.8 / edgeY)
	end
	return math.max(s, 0.08)
end

-- SliceScale for a kit piece drawn `wanted` times its original size.
local function sliceScale(label: GuiObject, wanted: number): number
	local f = label:GetAttribute("KitFactor")
	return wanted / (if type(f) == "number" and f > 0 then f else 1)
end

-- Checks every uploaded kit picture once, before the interface is built (behind the loading
-- screen), by showing it on a tiny, nearly invisible label and waiting for Roblox to say it
-- is on screen (ImageLabel.IsLoaded). ContentProvider:PreloadAsync can't be trusted for
-- this: in some Studio setups it reports Failure for pictures that display fine.
-- A piece whose direct link doesn't show uses its thumbnail; if neither shows, the drawn
-- look.
function Theme.PreloadKit(timeout: number?): { string }
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local probeGui = Instance.new("ScreenGui")
	probeGui.Name = "KitProbe"
	probeGui.ResetOnSpawn = false
	probeGui.Parent = playerGui
	local function shows(content: string, seconds: number): boolean
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.ImageTransparency = 0.98
		label.Size = UDim2.fromOffset(4, 4)
		label.Image = content
		label.Parent = probeGui
		local deadline = os.clock() + seconds
		while not label.IsLoaded and os.clock() < deadline do
			task.wait(0.1)
		end
		local ok = label.IsLoaded
		label:Destroy()
		return ok
	end
	-- Generous: freshly uploaded pictures can take a while to arrive the first time.
	local limit = timeout or 14
	local pending, total = 0, 0
	for name, piece in UiKit do
		if piece.Id ~= 0 then
			pending += 1
			total += 1
			task.spawn(function()
				if shows(`rbxassetid://{piece.Id}`, limit * 0.6) then
					kitStatus[name] = "direct"
				elseif shows(`rbxthumb://type=Asset&id={piece.Id}&w={THUMB}&h={THUMB}`, limit * 0.4) then
					kitThumb[name] = true
					kitStatus[name] = "thumbnail"
				else
					kitFailed[name] = true
					kitStatus[name] = "neither the picture nor its thumbnail showed"
				end
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + limit + 0.5
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	probeGui:Destroy()
	local failed = {}
	for name in kitFailed do
		table.insert(failed, name)
		warn(`[UI kit] {name} (id {UiKit[name].Id}) didn't load ({kitStatus[name]}); using the drawn look.`)
	end
	table.sort(failed)
	local thumbs = 0
	for name in kitThumb do
		thumbs += 1
		print(`[UI kit] {name} uses its thumbnail.`)
	end
	print(`[UI kit] {total - #failed} of {total} pictures loaded ({thumbs} through their thumbnail).`)
	return failed
end

function Theme.Skin(gui: GuiObject, name: string, scale: number?): ImageLabel?
	local image = Theme.KitImage(name)
	if not image then
		return nil
	end
	if scale then
		gui:SetAttribute("KitScale", scale)
	end
	-- Panels are ImageLabels: the picture is their own image, so it never takes a slot in
	-- their UIListLayout / UIGridLayout (a child picture would be stacked like an item).
	if gui:IsA("ImageLabel") then
		local own = gui :: ImageLabel
		Theme.KitApply(own, name)
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
					local wanted = own:GetAttribute("KitScale")
					own.SliceScale =
						sliceScale(own, kitFit(kit, own.AbsoluteSize, if type(wanted) == "number" then wanted else nil))
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
				local wanted = gui:GetAttribute("KitScale")
				current.SliceScale =
					sliceScale(current, kitFit(kit, gui.AbsoluteSize, if type(wanted) == "number" then wanted else nil))
			end
		end
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
		task.defer(rescale)
	end
	local s = skin :: ImageLabel
	s:SetAttribute("Piece", name)
	Theme.KitApply(s, name)
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
		Size = UDim2.new(1, 0, 0, height),
	}, parent)
	Theme.KitApply(track, "ProgressBar")
	-- The groove inside the art: x 68..478, y 38..66 of 556x110.
	local s = height / piece.Size.Y
	track.SliceScale = sliceScale(track, s)
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

-- Only the four corners of a square kit tile (vines and flowers), pinned to the corners of
-- `parent`, so a tall card keeps them crisp instead of stretching the whole tile. Returns
-- false if the tile isn't available.
function Theme.KitCorners(parent: GuiObject, name: string, size: number): boolean
	local piece = UiKit[name]
	if not Theme.KitImage(name) or not piece.SliceCenter then
		return false
	end
	local slice = piece.SliceCenter :: Rect
	local w, h = piece.Size.X, piece.Size.Y
	type Corner = { Rect | Vector2 }
	local corners: { Corner } = {
		{ Rect.new(0, 0, slice.Min.X, slice.Min.Y), Vector2.new(0, 0) },
		{ Rect.new(slice.Max.X, 0, w, slice.Min.Y), Vector2.new(1, 0) },
		{ Rect.new(0, slice.Max.Y, slice.Min.X, h), Vector2.new(0, 1) },
		{ Rect.new(slice.Max.X, slice.Max.Y, w, h), Vector2.new(1, 1) },
	}
	for i, corner in corners do
		local area, anchor = corner[1] :: Rect, corner[2] :: Vector2
		local label = Theme.Make("ImageLabel", {
			Name = "Corner" .. i,
			BackgroundTransparency = 1,
			AnchorPoint = anchor,
			-- Sit a little outside the card so the corner covers the rim's end.
			Position = UDim2.new(
				anchor.X,
				(anchor.X * 2 - 1) * size * 0.25,
				anchor.Y,
				(anchor.Y * 2 - 1) * size * 0.25
			),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 4,
		}, parent)
		Theme.KitApply(label, name, area)
	end
	return true
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
	}, parent)
	Theme.KitApply(icon, name, inner)
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
