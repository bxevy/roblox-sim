--!strict
-- Tiny helpers for building anchored geometry from code.

local Parts = {}

export type PartProps = { [string]: any }

-- Creates an anchored part. `cf` is relative to `origin` when given.
function Parts.Part(parent: Instance, props: PartProps): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = props.CastShadow ~= false
	for key, value in props do
		if key ~= "ClassName" and key ~= "CastShadow" and key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	if props.Shape and part:IsA("Part") then
		part.Shape = props.Shape
	end
	part.Parent = parent
	return part
end

-- Decorative part: no collisions, no raycast hits, no touch events.
function Parts.Decor(parent: Instance, props: PartProps): BasePart
	local part = Parts.Part(parent, props)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Vertical cylinder (Roblox cylinders lie along X, so rotate them upright).
function Parts.Cylinder(parent: Instance, cf: CFrame, height: number, diameter: number, props: PartProps): BasePart
	local merged = table.clone(props)
	merged.Shape = Enum.PartType.Cylinder
	merged.Size = Vector3.new(height, diameter, diameter)
	merged.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	return Parts.Part(parent, merged)
end

function Parts.Ball(parent: Instance, position: Vector3, diameter: number, props: PartProps): BasePart
	local merged = table.clone(props)
	merged.Shape = Enum.PartType.Ball
	merged.Size = Vector3.new(diameter, diameter, diameter)
	merged.CFrame = CFrame.new(position)
	return Parts.Decor(parent, merged)
end

function Parts.Light(parent: Instance, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Floating text on a part (signs, labels).
function Parts.Label(adornee: BasePart, text: string, options: { [string]: any }?): BillboardGui
	local opts: { [string]: any } = options or {}
	local gui = Instance.new("BillboardGui")
	gui.Size = opts.Size or UDim2.fromScale(8, 1.6)
	gui.StudsOffset = opts.Offset or Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = opts.MaxDistance or 90
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextColor3 = opts.Color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = adornee
	return gui
end

-- A wooden signboard with text on both faces.
function Parts.Sign(parent: Instance, cf: CFrame, text: string, width: number?): BasePart
	local w = width or 8
	local wood = Color3.fromRGB(120, 85, 55)
	Parts.Part(parent, {
		Size = Vector3.new(0.6, 4, 0.6),
		CFrame = cf * CFrame.new(-w / 2 + 0.6, 2, 0),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	Parts.Part(parent, {
		Size = Vector3.new(0.6, 4, 0.6),
		CFrame = cf * CFrame.new(w / 2 - 0.6, 2, 0),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	local board = Parts.Part(parent, {
		Size = Vector3.new(w, 2.2, 0.4),
		CFrame = cf * CFrame.new(0, 4.2, 0),
		Color = Color3.fromRGB(150, 110, 70),
		Material = Enum.Material.WoodPlanks,
	})
	Parts.SignText(board, text)
	return board
end

-- Writes `text` on both big faces of a part (used for signs, including hand-made ones).
function Parts.SignText(board: BasePart, text: string)
	local size = board.Size
	-- The two largest faces carry the text.
	local faces = if size.Z <= size.X and size.Z <= size.Y
		then { Enum.NormalId.Front, Enum.NormalId.Back }
		elseif size.X <= size.Y then { Enum.NormalId.Left, Enum.NormalId.Right }
		else { Enum.NormalId.Top, Enum.NormalId.Bottom }
	local w = if size.Z <= size.X and size.Z <= size.Y then size.X else math.max(size.X, size.Z)
	local h = if faces[1] == Enum.NormalId.Top then math.min(size.X, size.Z) else size.Y
	for _, face in faces do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.CanvasSize = Vector2.new(w * 40, h * 40)
		surface.LightInfluence = 0.4
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.86)
		label.Position = UDim2.fromScale(0.03, 0.07)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextColor3 = Color3.fromRGB(255, 244, 220)
		label.Parent = surface
		surface.Parent = board
	end
end

return Parts
