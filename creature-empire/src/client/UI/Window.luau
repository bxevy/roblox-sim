--!strict
-- The standard window: centred panel with a header (glyph, title, close button) and a
-- scrolling body. Only one window is open at a time (UIController enforces it).

local Theme = require(script.Parent.Theme)

export type Window = {
	Root: Frame,
	Body: ScrollingFrame,
	Header: Frame,
	Title: TextLabel,
	CloseButton: TextButton,
	SetTitle: (string) -> (),
}

local Window = {}

function Window.new(parent: Instance, title: string, glyph: string, size: Vector2, onClose: () -> ()): Window
	local root = Theme.Panel(parent, {
		Name = title:gsub("%s", "") .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 10,
	})
	Theme.Make("UISizeConstraint", { MaxSize = Vector2.new(size.X, size.Y) }, root)
	-- Fit inside small screens: never more than 94% of the screen.
	root.Size = UDim2.new(0.94, 0, 0.86, 0)

	local header = Theme.Make("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 52),
	}, root)
	Theme.Corner(header)
	local titleLabel = Theme.Text(header, glyph .. "  " .. title, 22, {
		FontFace = Theme.Title,
		TextStrokeColor3 = Theme.Colors.TextShadow,
		TextStrokeTransparency = 0.3,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(18, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
	})
	-- A plain "X": Builder Sans has no "✕" glyph, which showed as an empty box.
	local framed = Theme.Skin(root, "LargeFrame") ~= nil
	local bannered = Theme.Skin(header, "HeaderBanner") ~= nil
	if bannered then
		-- Like the mockup's "Empire Shop": the banner sits across the top edge of the frame,
		-- centred, with the title in the middle of it.
		header.AnchorPoint = Vector2.new(0.5, 0)
		header.Position = UDim2.new(0.5, 0, 0, -22)
		header.Size = UDim2.new(0.66, 0, 0, 62)
		header.ZIndex = 12
		titleLabel.Text = title
		titleLabel.TextSize = 26
		titleLabel.Position = UDim2.fromOffset(40, 0)
		titleLabel.Size = UDim2.new(1, -80, 1, 0)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Center
		titleLabel.ZIndex = 13
	end
	local close = Theme.Button(if bannered then root else header, "X", "Ghost", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		-- Bigger on phones so it is easy to hit with a thumb.
		Size = if Theme.IsTouch() then UDim2.fromOffset(46, 46) else UDim2.fromOffset(36, 36),
		TextSize = if Theme.IsTouch() then 22 else 18,
		FontFace = Theme.Heavy,
	})
	close.Activated:Connect(onClose)
	if bannered then
		-- In the frame's top-right corner, over the vines.
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, 6, 0, -10)
		close.Size = if Theme.IsTouch() then UDim2.fromOffset(54, 54) else UDim2.fromOffset(46, 46)
		close.ZIndex = 14
	end
	-- The kit's flower close button replaces the drawn X.
	local closeArt = Theme.KitImage("CloseButton")
	if closeArt then
		for _, child in close:GetChildren() do
			if
				child.Name == "Skin"
				or child.Name == "SkinLabel"
				or child:IsA("UIStroke")
				or child:IsA("UIGradient")
			then
				child:Destroy()
			end
		end
		close.Text = ""
		close.BackgroundTransparency = 1
		local art = Theme.Make("ImageLabel", {
			Name = "Art",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1.15, 1.15),
			Position = UDim2.fromScale(-0.075, -0.075),
		}, close)
		Theme.KitApply(art, "CloseButton")
	end

	local body = Theme.Make("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, if bannered then 48 else 56),
		Size = UDim2.new(1, 0, 1, if bannered then -52 else -60),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Colors.Border,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
	}, root)
	-- Inside the vines when the kit frame is drawn.
	if framed then
		Theme.Padding(body, 12, 32).PaddingBottom = UDim.new(0, 36)
	else
		Theme.Padding(body, 12, 16)
	end

	return {
		Root = root,
		Body = body,
		Header = header,
		Title = titleLabel,
		CloseButton = close,
		SetTitle = function(text: string)
			titleLabel.Text = if bannered then text else glyph .. "  " .. text
		end,
	}
end

-- Removes everything from a window body except its layout objects.
function Window.Clear(body: Instance)
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

-- A titled section card inside a window body.
function Window.Section(parent: Instance, title: string?, order: number?): Frame
	-- An ImageLabel so the kit's vine card frame is its own picture (outside the layout).
	local card = Theme.Make("ImageLabel", {
		Image = "",
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
	}, parent)
	Theme.Corner(card, 12)
	-- Drawn outline when the kit picture isn't available.
	Theme.Stroke(card, Theme.Colors.Border, 0.35, 2)
	local sectionFramed = Theme.Skin(card, "CardFrame", 0.55) ~= nil
	Theme.Padding(card, if sectionFramed then 22 else 12)
	Theme.List(card, 8)
	if title then
		Theme.Text(card, title, 15, { FontFace = Theme.Bold, TextColor3 = Theme.Colors.Muted, LayoutOrder = -1 })
	end
	return card
end

-- A horizontal row container.
function Window.Row(parent: Instance, height: number?, order: number?): Frame
	local row = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 40),
		LayoutOrder = order or 0,
	}, parent)
	Theme.List(row, 8, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Center
	return row
end

return Window
