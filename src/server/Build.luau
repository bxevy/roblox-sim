-- Helpers for building scenery out of anchored parts.

local Build = {}

function Build.block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Upright cylinder. `cframe` is the center.
function Build.cylinder(parent: Instance, name: string, diameter: number, height: number, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Build.block(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Build.ball(parent: Instance, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material): Part
	local p = Build.block(parent, name, Vector3.one * diameter, CFrame.new(position), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A part between two points (beams, braces, poles).
function Build.beam(parent: Instance, name: string, from: Vector3, to: Vector3, thickness: number, color: Color3, material: Enum.Material): Part
	local length = (to - from).Magnitude
	return Build.block(parent, name, Vector3.new(thickness, thickness, length), CFrame.lookAt((from + to) / 2, to), color, material)
end

function Build.light(parent: BasePart, color: Color3, range: number, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Text painted on the front (-Z) face of a part.
function Build.label(part: BasePart, text: string, color: Color3, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.Fantasy
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

return Build
