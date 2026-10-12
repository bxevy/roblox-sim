-- Builds armor onto a character from parts: helmets, chestplates (with shoulders,
-- bracers and gauntlets), leggings and boots, plus each set's particle effects and a
-- bigger aura when all 4 pieces of one set are worn.
--
-- Every set's look comes from its Style table in Items.luau. Pieces are welded to the
-- character's body parts (R15, with an R6 fallback) and rebuilt whenever armor changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)

local ArmorVisuals = {}

local FOLDER = "ArmorVisual"
local HIDDEN_ATTRIBUTE = "ArmorHiddenTransparency"
local rgb = Color3.fromRGB
local M = Enum.Material
local DARK = rgb(18, 16, 18)

local TEXTURES = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- Body parts ---------------------------------------------------------------------
-- Each "limb" is a body part plus an offset/size, so R6 bodies (one part per arm/leg)
-- can stand in for the R15 pieces.

type Limb = { Part: BasePart, Base: CFrame, Size: Vector3 }

local R6_MAP = {
	UpperTorso = { "Torso", Vector3.new(0, 0.2, 0), Vector3.new(2, 1.6, 1) },
	LowerTorso = { "Torso", Vector3.new(0, -0.8, 0), Vector3.new(2, 0.4, 1) },
	RightUpperArm = { "Right Arm", Vector3.new(0, 0.45, 0), Vector3.new(1, 1.1, 1) },
	RightLowerArm = { "Right Arm", Vector3.new(0, -0.4, 0), Vector3.new(1, 0.8, 1) },
	RightHand = { "Right Arm", Vector3.new(0, -0.85, 0), Vector3.new(1, 0.3, 1) },
	LeftUpperArm = { "Left Arm", Vector3.new(0, 0.45, 0), Vector3.new(1, 1.1, 1) },
	LeftLowerArm = { "Left Arm", Vector3.new(0, -0.4, 0), Vector3.new(1, 0.8, 1) },
	LeftHand = { "Left Arm", Vector3.new(0, -0.85, 0), Vector3.new(1, 0.3, 1) },
	RightUpperLeg = { "Right Leg", Vector3.new(0, 0.4, 0), Vector3.new(1, 1.2, 1) },
	RightLowerLeg = { "Right Leg", Vector3.new(0, -0.5, 0), Vector3.new(1, 0.8, 1) },
	RightFoot = { "Right Leg", Vector3.new(0, -0.85, 0), Vector3.new(1, 0.3, 1) },
	LeftUpperLeg = { "Left Leg", Vector3.new(0, 0.4, 0), Vector3.new(1, 1.2, 1) },
	LeftLowerLeg = { "Left Leg", Vector3.new(0, -0.5, 0), Vector3.new(1, 0.8, 1) },
	LeftFoot = { "Left Leg", Vector3.new(0, -0.85, 0), Vector3.new(1, 0.3, 1) },
}

local function limb(character: Model, name: string): Limb?
	local part = character:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return { Part = part, Base = CFrame.new(), Size = part.Size }
	end
	local r6 = R6_MAP[name]
	local r6Part = r6 and character:FindFirstChild(r6[1])
	if r6Part and r6Part:IsA("BasePart") then
		return { Part = r6Part, Base = CFrame.new(r6[2]), Size = r6[3] }
	end
	return nil
end

-- Building helpers -------------------------------------------------------------------

type Ctx = {
	Folder: Folder,
	Style: { [string]: any },
	Full: boolean, -- wearing the full set
}

local function add(ctx: Ctx, l: Limb, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or ctx.Style.Material
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = size.Magnitude > 1
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = l.Part.CFrame * l.Base * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = l.Part
	weld.Part1 = p
	weld.Parent = p
	p.Parent = ctx.Folder
	return p
end

-- Ball shapes must be uniform, so callers pass one diameter.
local function ball(ctx: Ctx, l: Limb, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return add(ctx, l, name, Vector3.one * diameter, CFrame.new(position), color, material, Enum.PartType.Ball)
end

-- Upright cylinder centred at `position` (cylinders point along X, so turn them).
local function cylinder(ctx: Ctx, l: Limb, name: string, diameter: number, height: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return add(ctx, l, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- A part stretched between two points (local to the limb).
local function beam(ctx: Ctx, l: Limb, name: string, from: Vector3, to: Vector3, thickness: Vector2, color: Color3, material: Enum.Material?): Part
	local length = (to - from).Magnitude
	local center = (from + to) / 2
	return add(ctx, l, name, Vector3.new(thickness.X, thickness.Y, length), CFrame.lookAt(center, to), color, material)
end

-- A curved horn / spike: short segments that bend as they go. `outward` and up (Y)
-- set the plane it curves in; angles are in degrees from `outward` toward up.
local function horn(ctx: Ctx, l: Limb, start: Vector3, outward: Vector3, startAngle: number, bend: number, segments: number, length: number, thickness: number, color: Color3, tipColor: Color3?, material: Enum.Material?)
	local position = start
	for i = 1, segments do
		local theta = math.rad(startAngle + (i - 1) * bend)
		local direction = (outward.Unit * math.cos(theta) + Vector3.yAxis * math.sin(theta)).Unit
		local shrink = 1 - (i - 1) / (segments + 1)
		local segmentLength = length * (0.6 + 0.4 * shrink)
		local tip = position + direction * segmentLength
		local isTip = i == segments and tipColor ~= nil
		beam(ctx, l, "Horn", position, tip, Vector2.new(thickness, thickness) * shrink, if isTip then tipColor :: Color3 else color, if isTip then M.Neon else material)
		position = position + direction * segmentLength * 0.85
	end
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Shadows = false
	pointLight.Parent = part
end

-- Particle effects ------------------------------------------------------------------

local function emitter(part: BasePart, kind: string, color: Color3, rate: number, volume: boolean?): ParticleEmitter?
	if rate <= 0 then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.LightEmission = 1
	e.SpreadAngle = Vector2.new(180, 180)
	e.Texture = TEXTURES.Sparkle
	e.Lifetime = NumberRange.new(0.8, 1.2)
	e.Speed = NumberRange.new(0.5, 1)
	e.Size = NumberSequence.new(0.25, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	if volume then
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end

	if kind == "Dust" then
		e.Texture = TEXTURES.Smoke
		e.LightEmission = 0
		e.Size = NumberSequence.new(0.4, 1)
		e.Transparency = NumberSequence.new(0.75, 1)
		e.Acceleration = Vector3.new(0, 0.5, 0)
	elseif kind == "Glint" then
		e.Lifetime = NumberRange.new(0.3, 0.5)
		e.Speed = NumberRange.new(0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	elseif kind == "Motes" or kind == "Holy" then
		e.Lifetime = NumberRange.new(1.2, 1.8)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Size = NumberSequence.new(if kind == "Holy" then 0.35 else 0.22, 0)
	elseif kind == "Sparkles" then
		e.Speed = NumberRange.new(1, 2)
		e.Size = NumberSequence.new(0.3, 0)
	elseif kind == "Embers" then
		e.Texture = TEXTURES.Fire
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(1, 2.5)
		e.Acceleration = Vector3.new(0, 3, 0)
		e.Size = NumberSequence.new(0.3, 0)
	elseif kind == "Void" then
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Size = NumberSequence.new(0.45, 0)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Acceleration = Vector3.new(0, -0.6, 0)
		e.Transparency = NumberSequence.new(0.3, 1)
	elseif kind == "Petals" then
		e.LightEmission = 0.2
		e.Lifetime = NumberRange.new(2.5, 3.5)
		e.Speed = NumberRange.new(0.8, 1.6)
		e.Acceleration = Vector3.new(0.4, -1.2, 0)
		e.Size = NumberSequence.new(0.28)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-180, 180)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	elseif kind == "Smoke" then
		e.Texture = TEXTURES.Smoke
		e.LightEmission = 0
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Size = NumberSequence.new(0.3, 1.2)
		e.Transparency = NumberSequence.new(0.5, 1)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.SpreadAngle = Vector2.new(15, 15)
		e.EmissionDirection = Enum.NormalId.Front
	end
	e.Parent = part
	return e
end

-- Each piece carries the set's effect at a share of the full rate.
local function pieceVfx(ctx: Ctx, part: BasePart, share: number)
	local vfx = ctx.Style.Vfx
	if vfx then
		emitter(part, vfx.Kind, vfx.Color, vfx.Rate * share)
	end
end

-- Helmets ----------------------------------------------------------------------------

local function greatHelm(ctx: Ctx, head: Limb, primary: Color3): (Part, number)
	local s = ctx.Style
	local H = head.Size
	local front = -(H.Z + 0.25) / 2
	local shell = add(ctx, head, "Helmet", Vector3.new(H.X + 0.25, H.Y + 0.25, H.Z + 0.25), CFrame.new(0, 0.08, 0), primary)
	add(ctx, head, "HelmetTrim", Vector3.new(H.X + 0.32, 0.12, H.Z + 0.32), CFrame.new(0, -H.Y / 2 + 0.02, 0), s.Secondary, s.TrimMaterial)
	add(ctx, head, "HelmetTop", Vector3.new(H.X + 0.1, 0.15, H.Z + 0.1), CFrame.new(0, H.Y / 2 + 0.25, 0), primary)
	return shell, front - 0.01
end

local HELMETS: { [string]: (Ctx, Limb) -> Part } = {}

HELMETS.Coif = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local cap = add(ctx, head, "Helmet", Vector3.new(H.X + 0.15, H.Y * 0.5, H.Z + 0.15), CFrame.new(0, H.Y * 0.28, 0), s.Primary)
	add(ctx, head, "CoifBack", Vector3.new(H.X + 0.15, H.Y * 0.75, 0.12), CFrame.new(0, -0.05, H.Z / 2 + 0.08), s.Primary)
	for _, side in { -1, 1 } do
		add(ctx, head, "CoifSide", Vector3.new(0.12, H.Y * 0.75, H.Z * 0.85), CFrame.new(side * (H.X / 2 + 0.08), -0.05, 0.05), s.Primary)
	end
	add(ctx, head, "BrowBand", Vector3.new(H.X + 0.2, 0.12, H.Z + 0.2), CFrame.new(0, H.Y * 0.05, 0), s.Secondary)
	return cap
end

HELMETS.Kettle = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local dome = cylinder(ctx, head, "Helmet", H.X * 1.08, H.Y * 0.4, Vector3.new(0, H.Y * 0.32, 0), s.Secondary, s.TrimMaterial)
	ball(ctx, head, "HelmetDome", H.X * 1.05, Vector3.new(0, H.Y * 0.45, 0), s.Secondary, s.TrimMaterial)
	cylinder(ctx, head, "Brim", H.X * 1.75, 0.1, Vector3.new(0, H.Y * 0.14, 0), s.Secondary, s.TrimMaterial)
	add(ctx, head, "ChainBack", Vector3.new(H.X + 0.2, H.Y * 0.75, 0.12), CFrame.new(0, -0.1, H.Z / 2 + 0.08), s.Primary)
	for _, side in { -1, 1 } do
		add(ctx, head, "ChainSide", Vector3.new(0.12, H.Y * 0.75, H.Z * 0.9), CFrame.new(side * (H.X / 2 + 0.08), -0.1, 0.05), s.Primary)
	end
	return dome
end

HELMETS.GreatHelm = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local shell, front = greatHelm(ctx, head, s.Primary)
	add(ctx, head, "EyeSlit", Vector3.new(H.X * 0.85, 0.08, 0.06), CFrame.new(0, H.Y * 0.14, front), DARK, M.SmoothPlastic)
	add(ctx, head, "Ridge", Vector3.new(0.14, H.Y + 0.25, 0.06), CFrame.new(0, 0.08, front - 0.01), s.Secondary, s.TrimMaterial)
	for row = 0, 1 do
		for col = 0, 2 do
			add(ctx, head, "BreathHole", Vector3.new(0.06, 0.06, 0.04), CFrame.new(0.22 + col * 0.13, -H.Y * 0.12 - row * 0.14, front - 0.01), DARK, M.SmoothPlastic)
		end
	end
	if s.Plume then
		for i = 0, 3 do
			ball(ctx, head, "Plume", 0.5 - i * 0.07, Vector3.new(0, H.Y * 0.72 + math.sin(i * 0.6) * 0.15, -0.1 + i * 0.3), s.Plume, M.Fabric)
		end
	end
	return shell
end

HELMETS.Crusader = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local shell, front = greatHelm(ctx, head, s.Primary)
	add(ctx, head, "CrossV", Vector3.new(0.16, H.Y * 0.75, 0.05), CFrame.new(0, -0.02, front), s.Accent, M.SmoothPlastic)
	add(ctx, head, "CrossH", Vector3.new(H.X * 0.8, 0.16, 0.05), CFrame.new(0, H.Y * 0.14, front), s.Accent, M.SmoothPlastic)
	add(ctx, head, "EyeSlit", Vector3.new(H.X * 0.7, 0.06, 0.07), CFrame.new(0, H.Y * 0.14, front - 0.01), DARK, M.SmoothPlastic)
	ball(ctx, head, "Finial", 0.3, Vector3.new(0, H.Y / 2 + 0.42, 0), s.Secondary, M.Metal)
	return shell
end

local function roundHelm(ctx: Ctx, head: Limb, color: Color3): Part
	local H = head.Size
	local shell = cylinder(ctx, head, "Helmet", H.X * 1.12, H.Y * 0.8, Vector3.new(0, H.Y * 0.1, 0.02), color)
	ball(ctx, head, "HelmetDome", H.X * 1.12, Vector3.new(0, H.Y * 0.42, 0.02), color)
	return shell
end

HELMETS.Crowned = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local shell = roundHelm(ctx, head, s.Primary)
	local front = -H.X * 0.56
	for _, side in { -1, 1 } do
		add(ctx, head, "CheekGuard", Vector3.new(0.12, H.Y * 0.6, H.Z * 0.5), CFrame.new(side * H.X * 0.5, -H.Y * 0.12, -H.Z * 0.2), s.Primary)
	end
	add(ctx, head, "Nasal", Vector3.new(0.12, H.Y * 0.45, 0.08), CFrame.new(0, H.Y * 0.05, front - 0.02), s.Secondary, s.TrimMaterial)
	cylinder(ctx, head, "Crown", H.X * 1.2, 0.25, Vector3.new(0, H.Y * 0.48, 0.02), s.Secondary, s.TrimMaterial)
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		local p = Vector3.new(math.sin(angle) * H.X * 0.58, H.Y * 0.7, -math.cos(angle) * H.X * 0.58 + 0.02)
		add(ctx, head, "CrownPoint", Vector3.new(0.14, 0.35, 0.14), CFrame.new(p) * CFrame.Angles(0, angle, 0), s.Secondary, s.TrimMaterial)
		ball(ctx, head, "CrownTip", 0.16, p + Vector3.new(0, 0.22, 0), s.Secondary, s.TrimMaterial)
	end
	local gem = add(ctx, head, "CrownGem", Vector3.new(0.22, 0.22, 0.08), CFrame.new(0, H.Y * 0.48, front - 0.04) * CFrame.Angles(0, 0, math.rad(45)), s.Accent, M.Neon)
	light(gem, s.Accent, 6, 0.6)
	return shell
end

HELMETS.Horned = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local shell, front = greatHelm(ctx, head, s.Primary)
	add(ctx, head, "VisorH", Vector3.new(H.X * 0.75, 0.08, 0.06), CFrame.new(0, H.Y * 0.14, front), s.Accent, M.Neon)
	add(ctx, head, "VisorV", Vector3.new(0.08, H.Y * 0.4, 0.06), CFrame.new(0, -H.Y * 0.06, front), s.Accent, M.Neon)
	local bone = rgb(220, 210, 188)
	for _, side in { -1, 1 } do
		horn(ctx, head, Vector3.new(side * H.X * 0.55, H.Y * 0.25, 0), Vector3.new(side, 0, 0), 5, 22, 5, 0.42, 0.24, bone, nil, M.SmoothPlastic)
	end
	for i = 0, 2 do
		add(ctx, head, "Spike", Vector3.new(0.12, 0.32 - i * 0.05, 0.12), CFrame.new(0, H.Y / 2 + 0.42, -0.25 + i * 0.25), s.Secondary, s.TrimMaterial)
	end
	return shell
end

HELMETS.Halo = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local shell = roundHelm(ctx, head, s.Primary)
	local front = -H.X * 0.56
	add(ctx, head, "VisorH", Vector3.new(H.X * 0.7, 0.1, 0.06), CFrame.new(0, H.Y * 0.08, front - 0.02), s.Accent, M.Neon)
	add(ctx, head, "VisorV", Vector3.new(0.1, H.Y * 0.4, 0.06), CFrame.new(0, -H.Y * 0.12, front - 0.02), s.Accent, M.Neon)
	add(ctx, head, "Crest", Vector3.new(0.1, 0.35, H.Z * 0.9), CFrame.new(0, H.Y * 0.62, 0.05), s.Secondary, s.TrimMaterial)
	-- Feathered wing fins on both sides
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			add(ctx, head, "WingFin", Vector3.new(0.08, 0.28, 0.75 - i * 0.15), CFrame.new(side * (H.X * 0.58 + 0.04), H.Y * 0.1 + i * 0.17, 0.2 + i * 0.08) * CFrame.Angles(math.rad(-30 - i * 12), 0, 0), s.Secondary, s.TrimMaterial)
		end
	end
	-- Floating halo
	local radius = H.X * 0.55
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		add(ctx, head, "Halo", Vector3.new(0.3, 0.1, 0.12), CFrame.new(0, H.Y * 0.95, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, radius), s.Accent, M.Neon)
	end
	return shell
end

HELMETS.Abyssal = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local shell, front = greatHelm(ctx, head, s.Primary)
	for _, side in { -1, 1 } do
		add(ctx, head, "Visor", Vector3.new(H.X * 0.42, 0.09, 0.06), CFrame.new(side * H.X * 0.18, H.Y * 0.1, front) * CFrame.Angles(0, 0, math.rad(side * -15)), s.Accent, M.Neon)
		horn(ctx, head, Vector3.new(side * H.X * 0.45, H.Y * 0.35, 0.1), Vector3.new(side * 0.4, 0, 0.9), 20, 5, 4, 0.45, 0.16, s.Primary, s.Accent)
	end
	for i = 0, 2 do
		add(ctx, head, "Crest", Vector3.new(0.12, 0.35 + i * 0.12, 0.14), CFrame.new(0, H.Y / 2 + 0.4 + i * 0.05, -0.2 + i * 0.25) * CFrame.Angles(math.rad(-25), 0, 0), s.Secondary)
	end
	return shell
end

HELMETS.Dragon = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local front = -(H.Z + 0.3) / 2
	local shell = add(ctx, head, "Helmet", Vector3.new(H.X + 0.25, H.Y + 0.2, H.Z + 0.3), CFrame.new(0, 0.06, 0.03), s.Primary)
	-- Snout with a ridge, glowing nostrils and teeth
	local snoutZ = front - 0.4
	local snout = add(ctx, head, "Snout", Vector3.new(H.X * 0.7, H.Y * 0.35, 0.9), CFrame.new(0, -H.Y * 0.15, snoutZ), s.Primary)
	add(ctx, head, "SnoutRidge", Vector3.new(0.25, 0.12, 0.9), CFrame.new(0, -H.Y * 0.15 + H.Y * 0.18, snoutZ), s.Secondary, s.TrimMaterial)
	for _, side in { -1, 1 } do
		add(ctx, head, "Nostril", Vector3.new(0.12, 0.08, 0.05), CFrame.new(side * 0.15, -H.Y * 0.08, snoutZ - 0.46), s.Accent, M.Neon)
		add(ctx, head, "Eye", Vector3.new(0.35, 0.1, 0.05), CFrame.new(side * H.X * 0.25, H.Y * 0.12, front - 0.01) * CFrame.Angles(0, 0, math.rad(-side * 18)), s.Accent, M.Neon)
		add(ctx, head, "Brow", Vector3.new(0.45, 0.14, 0.2), CFrame.new(side * H.X * 0.25, H.Y * 0.26, front - 0.05) * CFrame.Angles(0, 0, math.rad(-side * 22)), s.Secondary, s.TrimMaterial)
		add(ctx, head, "Jaw", Vector3.new(0.12, H.Y * 0.5, H.Z * 0.8), CFrame.new(side * (H.X / 2 + 0.16), -H.Y * 0.1, 0), s.Secondary, s.TrimMaterial)
		horn(ctx, head, Vector3.new(side * H.X * 0.4, H.Y * 0.42, 0.1), Vector3.new(side * 0.5, 0, 0.85), 50, -12, 5, 0.5, 0.24, s.Secondary, s.Accent, s.TrimMaterial)
		horn(ctx, head, Vector3.new(side * (H.X / 2 + 0.2), -H.Y * 0.1, 0.25), Vector3.new(side * 0.4, 0, 1), -10, 8, 2, 0.35, 0.1, s.Secondary, nil, s.TrimMaterial)
	end
	for i = -1, 2 do
		add(ctx, head, "Tooth", Vector3.new(0.08, 0.15, 0.08), CFrame.new(i * 0.14 - 0.07, -H.Y * 0.36, snoutZ - 0.3), rgb(235, 230, 215), M.SmoothPlastic)
	end
	for i = 0, 2 do
		add(ctx, head, "Spine", Vector3.new(0.15, 0.4 - i * 0.06, 0.15), CFrame.new(0, H.Y * 0.62 - i * 0.12, -0.05 + i * 0.32) * CFrame.Angles(math.rad(-30), 0, 0), s.Secondary, s.TrimMaterial)
	end
	emitter(snout, "Smoke", rgb(60, 50, 50), 3)
	return shell
end

-- A carved jack-o'-lantern with a flickering glow inside.
HELMETS.Pumpkin = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local size = H.X * 1.55
	local shell = ball(ctx, head, "Helmet", size, Vector3.new(0, H.Y * 0.08, 0), s.Secondary, M.SmoothPlastic)
	-- Ribs around the pumpkin
	for i = 0, 5 do
		local angle = i / 6 * math.pi
		add(ctx, head, "PumpkinRib", Vector3.new(0.12, size * 1.03, size * 1.03), CFrame.new(0, H.Y * 0.08, 0) * CFrame.Angles(0, angle, 0), s.Secondary:Lerp(rgb(150, 60, 10), 0.35), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	add(ctx, head, "Stem", Vector3.new(0.22, 0.45, 0.22), CFrame.new(0.05, H.Y * 0.08 + size * 0.52, 0.05) * CFrame.Angles(0, 0, math.rad(12)), rgb(70, 100, 40), M.Wood)
	local front = -size / 2 + 0.02
	local glow = s.Accent
	-- Triangle eyes, a nose and a jagged grin
	for _, side in { -1, 1 } do
		add(ctx, head, "PumpkinEye", Vector3.new(0.32, 0.26, 0.08), CFrame.new(side * size * 0.2, H.Y * 0.3, front) * CFrame.Angles(0, 0, math.rad(side * 15)), glow, M.Neon)
	end
	add(ctx, head, "PumpkinNose", Vector3.new(0.16, 0.16, 0.08), CFrame.new(0, H.Y * 0.1, front - 0.02) * CFrame.Angles(0, 0, math.rad(45)), glow, M.Neon)
	add(ctx, head, "PumpkinMouth", Vector3.new(size * 0.55, 0.14, 0.08), CFrame.new(0, -H.Y * 0.18, front + 0.03), glow, M.Neon)
	for i = -2, 2 do
		add(ctx, head, "PumpkinTooth", Vector3.new(0.12, 0.12, 0.09), CFrame.new(i * size * 0.11, -H.Y * 0.1 + (i % 2) * 0.05, front + 0.02) * CFrame.Angles(0, 0, math.rad(45)), glow, M.Neon)
	end
	light(shell, glow, 10, 1.4)
	emitter(shell, "Embers", glow, 4)
	return shell
end

-- A vampire's high collar and a circlet with a blood-red gem.
HELMETS.Vampire = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local circlet = cylinder(ctx, head, "Circlet", H.X * 1.08, 0.14, Vector3.new(0, H.Y * 0.32, 0), s.Secondary, s.TrimMaterial)
	local gem = add(ctx, head, "CircletGem", Vector3.new(0.2, 0.2, 0.08), CFrame.new(0, H.Y * 0.32, -H.Z * 0.55) * CFrame.Angles(0, 0, math.rad(45)), s.Accent, M.Neon)
	light(gem, s.Accent, 6, 0.8)
	-- Slicked hair
	add(ctx, head, "Hair", Vector3.new(H.X * 1.04, H.Y * 0.3, H.Z * 1.04), CFrame.new(0, H.Y * 0.4, 0.04), rgb(15, 12, 15), M.SmoothPlastic)
	add(ctx, head, "WidowsPeak", Vector3.new(0.25, 0.25, 0.06), CFrame.new(0, H.Y * 0.28, -H.Z * 0.52) * CFrame.Angles(0, 0, math.rad(45)), rgb(15, 12, 15), M.SmoothPlastic)
	-- The famous standing collar, lined in red
	for _, side in { -1, 1 } do
		add(ctx, head, "Collar", Vector3.new(H.X * 0.75, H.Y * 1.3, 0.1), CFrame.new(side * H.X * 0.45, -H.Y * 0.05, H.Z * 0.35) * CFrame.Angles(math.rad(-12), math.rad(side * 35), math.rad(side * -10)), s.Primary, s.Material)
		add(ctx, head, "CollarLining", Vector3.new(H.X * 0.7, H.Y * 1.22, 0.04), CFrame.new(side * H.X * 0.43, -H.Y * 0.05, H.Z * 0.3) * CFrame.Angles(math.rad(-12), math.rad(side * 35), math.rad(side * -10)), s.Secondary, M.Fabric)
		add(ctx, head, "Eye", Vector3.new(0.14, 0.06, 0.04), CFrame.new(side * H.X * 0.18, H.Y * 0.08, -H.Z * 0.51), s.Accent, M.Neon)
	end
	return circlet
end

HELMETS.Kabuto = function(ctx, head)
	local s, H = ctx.Style, head.Size
	local bowlY = H.Y * 0.2
	local shell = ball(ctx, head, "Helmet", H.X * 1.3, Vector3.new(0, bowlY, 0.05), s.Secondary)
	cylinder(ctx, head, "Tehen", 0.3, 0.12, Vector3.new(0, bowlY + H.X * 0.65, 0.05), s.Accent, s.TrimMaterial)
	-- Brim
	add(ctx, head, "Brim", Vector3.new(H.X * 1.1, 0.1, 0.45), CFrame.new(0, bowlY - 0.05, -H.Z / 2 - 0.15) * CFrame.Angles(math.rad(15), 0, 0), s.Secondary)
	-- Flared, layered neck guard (shikoro)
	for i = 0, 2 do
		local y = bowlY - 0.15 - i * 0.28
		add(ctx, head, "Shikoro", Vector3.new(H.X + 0.6 + i * 0.3, 0.28, 0.14), CFrame.new(0, y, H.Z / 2 + 0.18 + i * 0.1) * CFrame.Angles(math.rad(-20), 0, 0), s.Primary)
		add(ctx, head, "Lacing", Vector3.new(H.X + 0.62 + i * 0.3, 0.04, 0.16), CFrame.new(0, y - 0.14, H.Z / 2 + 0.18 + i * 0.1) * CFrame.Angles(math.rad(-20), 0, 0), s.Cloth, M.Fabric)
		for _, side in { -1, 1 } do
			add(ctx, head, "Shikoro", Vector3.new(0.14, 0.28, H.Z * 0.75 + i * 0.15), CFrame.new(side * (H.X / 2 + 0.25 + i * 0.1), y, 0.2) * CFrame.Angles(0, 0, math.rad(side * 20)), s.Primary)
		end
	end
	-- Turned-back wings at the front (fukigaeshi)
	for _, side in { -1, 1 } do
		add(ctx, head, "Fukigaeshi", Vector3.new(0.1, 0.45, 0.5), CFrame.new(side * (H.X / 2 + 0.38), bowlY - 0.1, -H.Z / 2 + 0.05) * CFrame.Angles(0, math.rad(side * 35), 0), s.Primary)
		add(ctx, head, "FukigaeshiTrim", Vector3.new(0.12, 0.47, 0.06), CFrame.new(side * (H.X / 2 + 0.38), bowlY - 0.1, -H.Z / 2 - 0.2) * CFrame.Angles(0, math.rad(side * 35), 0), s.Accent, s.TrimMaterial)
	end
	-- Golden crescent crest (maedate)
	local crestBase = Vector3.new(0, bowlY + 0.25, -H.Z / 2 - 0.3)
	ball(ctx, head, "CrestMon", 0.28, crestBase, s.Accent, s.TrimMaterial)
	for _, side in { -1, 1 } do
		horn(ctx, head, crestBase, Vector3.new(side, 0, -0.15), 12, 13, 6, 0.42, 0.16, s.Accent, nil, s.TrimMaterial)
	end
	-- Face mask (menpo) and throat guard
	add(ctx, head, "Menpo", Vector3.new(H.X * 0.85, H.Y * 0.38, 0.15), CFrame.new(0, -H.Y * 0.28, -H.Z / 2 - 0.06), s.Primary)
	add(ctx, head, "MenpoNose", Vector3.new(0.2, 0.22, 0.14), CFrame.new(0, -H.Y * 0.12, -H.Z / 2 - 0.16), s.Primary)
	for _, side in { -1, 1 } do
		add(ctx, head, "Moustache", Vector3.new(0.32, 0.05, 0.05), CFrame.new(side * 0.18, -H.Y * 0.2, -H.Z / 2 - 0.15) * CFrame.Angles(0, 0, math.rad(side * -20)), DARK, M.SmoothPlastic)
	end
	for i = 0, 1 do
		add(ctx, head, "ThroatGuard", Vector3.new(H.X * 0.9 + i * 0.1, 0.16, 0.55), CFrame.new(0, -H.Y / 2 - 0.08 - i * 0.18, -0.1), s.Primary)
		add(ctx, head, "Lacing", Vector3.new(H.X * 0.92 + i * 0.1, 0.03, 0.57), CFrame.new(0, -H.Y / 2 - 0.16 - i * 0.18, -0.1), s.Cloth, M.Fabric)
	end
	return shell
end

-- Hats and hair poke through helmets, so hide them while one is worn.
local function setHeadAccessoriesHidden(character: Model, hidden: boolean)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle") :: BasePart?
			local attachment = handle and handle:FindFirstChildOfClass("Attachment")
			local onHead = attachment and (attachment.Name:find("Hat") or attachment.Name:find("Hair") or attachment.Name:find("Face"))
			if handle and onHead then
				local original = handle:GetAttribute(HIDDEN_ATTRIBUTE)
				if hidden and original == nil then
					handle:SetAttribute(HIDDEN_ATTRIBUTE, handle.Transparency)
					handle.Transparency = 1
				elseif not hidden and original ~= nil then
					handle.Transparency = original
					handle:SetAttribute(HIDDEN_ATTRIBUTE, nil)
				end
			end
		end
	end
end

-- Chest -------------------------------------------------------------------------------

local function emblem(ctx: Ctx, torso: Limb, front: number)
	local s, T = ctx.Style, torso.Size
	local kind = s.Emblem
	if kind == "Cross" then
		add(ctx, torso, "Emblem", Vector3.new(0.22, T.Y * 0.75, 0.05), CFrame.new(0, 0.05, front), s.Accent, M.Fabric)
		add(ctx, torso, "Emblem", Vector3.new(T.X * 0.5, 0.22, 0.05), CFrame.new(0, 0.2, front), s.Accent, M.Fabric)
	elseif kind == "Crest" then
		add(ctx, torso, "Emblem", Vector3.new(0.6, 0.6, 0.05), CFrame.new(0, 0.1, front) * CFrame.Angles(0, 0, math.rad(45)), s.Secondary, s.TrimMaterial)
		local gem = add(ctx, torso, "EmblemGem", Vector3.new(0.3, 0.3, 0.06), CFrame.new(0, 0.1, front - 0.02) * CFrame.Angles(0, 0, math.rad(45)), s.Accent, M.Neon)
		light(gem, s.Accent, 6, 0.6)
	elseif kind == "Sun" then
		add(ctx, torso, "Emblem", Vector3.new(0.06, 0.55, 0.55), CFrame.new(0, 0.12, front - 0.01) * CFrame.Angles(0, math.rad(90), 0), s.Accent, M.Neon, Enum.PartType.Cylinder)
		for i = 0, 7 do
			add(ctx, torso, "SunRay", Vector3.new(0.08, 0.32, 0.04), CFrame.new(0, 0.12, front) * CFrame.Angles(0, 0, i / 8 * math.pi * 2) * CFrame.new(0, 0.42, 0), s.Secondary, s.TrimMaterial)
		end
	elseif kind == "Core" then
		add(ctx, torso, "Emblem", Vector3.new(0.6, 0.6, 0.05), CFrame.new(0, 0.1, front) * CFrame.Angles(0, 0, math.rad(45)), s.Secondary)
		local core = add(ctx, torso, "Core", Vector3.new(0.34, 0.34, 0.07), CFrame.new(0, 0.1, front - 0.02) * CFrame.Angles(0, 0, math.rad(45)), s.Accent, M.Neon)
		light(core, s.Accent, 8, 1)
	elseif kind == "Skull" then
		local bone = rgb(225, 215, 195)
		ball(ctx, torso, "Skull", 0.5, Vector3.new(0, 0.18, front - 0.15), bone, M.SmoothPlastic)
		add(ctx, torso, "SkullJaw", Vector3.new(0.3, 0.14, 0.2), CFrame.new(0, -0.06, front - 0.12), bone, M.SmoothPlastic)
		for _, side in { -1, 1 } do
			add(ctx, torso, "SkullEye", Vector3.new(0.1, 0.1, 0.05), CFrame.new(side * 0.1, 0.2, front - 0.39), s.Accent, M.Neon)
		end
	elseif kind == "Cracks" then
		local rng = Random.new(7)
		for _ = 1, 6 do
			local x, y = rng:NextNumber(-T.X * 0.35, T.X * 0.35), rng:NextNumber(-T.Y * 0.35, T.Y * 0.35)
			add(ctx, torso, "Crack", Vector3.new(rng:NextNumber(0.3, 0.6), 0.05, 0.04), CFrame.new(x, y, front) * CFrame.Angles(0, 0, rng:NextNumber(-1.2, 1.2)), s.Accent, M.Neon)
		end
		for i = 0, 2 do
			add(ctx, torso, "BellyScale", Vector3.new(T.X * 0.5, 0.18, 0.06), CFrame.new(0, -T.Y * 0.3 + i * 0.22, front - 0.01), s.Secondary, s.TrimMaterial)
		end
	elseif kind == "Lamellar" then
		ball(ctx, torso, "Mon", 0.4, Vector3.new(0, T.Y * 0.3, front - 0.12), s.Accent, s.TrimMaterial)
	end
end

local function pauldron(ctx: Ctx, arm: Limb, side: number)
	local s, U = ctx.Style, arm.Size
	local kind = s.Pauldron
	local top = U.Y / 2
	if kind == "Leather" then
		add(ctx, arm, "Pauldron", Vector3.new(U.X + 0.25, U.Y * 0.42, U.Z + 0.25), CFrame.new(side * 0.05, top - U.Y * 0.2, 0), s.Primary)
		add(ctx, arm, "PauldronStrap", Vector3.new(U.X + 0.3, 0.08, U.Z + 0.3), CFrame.new(side * 0.05, top - U.Y * 0.38, 0), s.Secondary)
		return
	elseif kind == "Round" then
		ball(ctx, arm, "Pauldron", U.X * 1.45, Vector3.new(side * 0.12, top - U.Y * 0.18, 0), s.Primary)
		cylinder(ctx, arm, "PauldronTrim", U.X * 1.3, 0.1, Vector3.new(side * 0.12, top - U.Y * 0.42, 0), s.Secondary, s.TrimMaterial)
		return
	elseif kind == "Sode" then
		local plate = CFrame.new(side * (U.X / 2 + 0.18), top - U.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(side * 8))
		add(ctx, arm, "Sode", Vector3.new(0.12, U.Y * 1.15, U.Z * 1.3), plate, s.Primary)
		for i = 0, 3 do
			add(ctx, arm, "Lacing", Vector3.new(0.14, 0.04, U.Z * 1.32), plate * CFrame.new(0, U.Y * 0.4 - i * U.Y * 0.27, 0), s.Cloth, M.Fabric)
		end
		add(ctx, arm, "SodeTop", Vector3.new(0.16, 0.12, U.Z * 1.36), plate * CFrame.new(0, U.Y * 0.58, 0), s.Accent, s.TrimMaterial)
		return
	end
	-- Layered plates (also the base for Spiked, Winged and Dragon)
	for i = 0, 2 do
		local plateColor = if i % 2 == 0 then s.Primary else s.Secondary
		local material = if i % 2 == 0 then s.Material else s.TrimMaterial
		add(ctx, arm, "Pauldron", Vector3.new(U.X + 0.42 - i * 0.1, 0.22, U.Z + 0.4 - i * 0.1), CFrame.new(side * (0.1 + i * 0.05), top - 0.05 - i * 0.2, 0) * CFrame.Angles(0, 0, math.rad(-side * 15)), plateColor, material)
	end
	if kind == "Spiked" then
		for _, z in { -0.2, 0.2 } do
			horn(ctx, arm, Vector3.new(side * 0.3, top + 0.05, z), Vector3.new(side, 0, 0), 60, 0, 2, 0.32, 0.14, s.Secondary, s.Accent, s.TrimMaterial)
		end
	elseif kind == "Winged" then
		add(ctx, arm, "PauldronFin", Vector3.new(0.08, 0.6, 0.7), CFrame.new(side * (U.X / 2 + 0.28), top + 0.2, 0.1) * CFrame.Angles(math.rad(-25), 0, 0), s.Secondary, s.TrimMaterial)
		add(ctx, arm, "PauldronGem", Vector3.new(0.16, 0.16, 0.16), CFrame.new(side * (U.X / 2 + 0.3), top - 0.1, -0.2), s.Accent, M.Neon)
	elseif kind == "Dragon" then
		for i = 0, 2 do
			horn(ctx, arm, Vector3.new(side * 0.3, top + 0.02, -0.25 + i * 0.25), Vector3.new(side * 0.3, 0, 0.95), 55, -10, 3, 0.3, 0.13, s.Secondary, s.Accent, s.TrimMaterial)
		end
		add(ctx, arm, "PauldronGlow", Vector3.new(U.X + 0.44, 0.05, U.Z + 0.42), CFrame.new(side * 0.1, top - 0.17, 0) * CFrame.Angles(0, 0, math.rad(-side * 15)), s.Accent, M.Neon)
	end
end

local function arms(ctx: Ctx, character: Model)
	local s = ctx.Style
	for _, sideName in { "Left", "Right" } do
		local side = if sideName == "Right" then 1 else -1
		local upper = limb(character, `{sideName}UpperArm`)
		local lower = limb(character, `{sideName}LowerArm`)
		local hand = limb(character, `{sideName}Hand`)
		if upper then
			-- Sleeve (rerebrace) under the shoulder plate so the upper arm isn't bare
			local U = upper.Size
			local sleeveColor = if s.Pauldron == "Leather" or s.Pauldron == "Sode" then s.Secondary else s.Primary
			add(ctx, upper, "Rerebrace", Vector3.new(U.X + 0.1, U.Y * 0.7, U.Z + 0.1), CFrame.new(0, -U.Y * 0.12, 0), sleeveColor)
			pauldron(ctx, upper, side)
		end
		if lower then
			local A = lower.Size
			local bracerColor = if s.Pauldron == "Leather" or s.Pauldron == "Sode" then s.Secondary else s.Primary
			add(ctx, lower, "Bracer", Vector3.new(A.X + 0.16, A.Y * 0.75, A.Z + 0.16), CFrame.new(0, -0.02, 0), bracerColor)
			add(ctx, lower, "BracerCuff", Vector3.new(A.X + 0.22, 0.1, A.Z + 0.22), CFrame.new(0, -A.Y * 0.38, 0), if s.Pauldron == "Sode" then s.Accent else s.Secondary, s.TrimMaterial)
		end
		if hand then
			local G = hand.Size
			add(ctx, hand, "Gauntlet", Vector3.new(G.X + 0.12, G.Y + 0.12, G.Z + 0.12), CFrame.new(), if s.Pauldron == "Leather" then s.Secondary else s.Primary)
			if s.Pauldron == "Dragon" then
				for i = -1, 1 do
					add(ctx, hand, "Claw", Vector3.new(0.08, 0.32, 0.08), CFrame.new(i * 0.25, -G.Y / 2 - 0.14, -G.Z / 2 + 0.1) * CFrame.Angles(math.rad(-25), 0, 0), s.Accent, M.Neon)
				end
			end
		end
	end
end

local function wings(ctx: Ctx, torso: Limb)
	local s, T = ctx.Style, torso.Size
	local back = T.Z / 2 + 0.2
	if s.Wings == "Angel" then
		for _, side in { -1, 1 } do
			local base = Vector3.new(side * 0.35, T.Y * 0.3, back)
			for i = 0, 3 do
				local direction = Vector3.new(side * 0.85, 0.5 - i * 0.22, 0.45).Unit
				local length = 2.3 - i * 0.35
				local start = base - Vector3.new(0, i * 0.12, 0)
				local feather = beam(ctx, torso, "Feather", start, start + direction * length, Vector2.new(0.07, 0.42), if i == 0 then s.Secondary else s.Primary, if ctx.Full then M.Neon else s.Material)
				if ctx.Full and i == 0 then
					light(feather, s.Accent, 10, 1)
				end
			end
		end
	elseif s.Wings == "Dragon" then
		for _, side in { -1, 1 } do
			local base = Vector3.new(side * 0.45, T.Y * 0.25, back)
			local elbow = base + Vector3.new(side * 1.2, 1, 0.6)
			local tip = elbow + Vector3.new(side * 1.5, -0.3, 0.4)
			beam(ctx, torso, "WingBone", base, elbow, Vector2.new(0.16, 0.16), s.Secondary, s.TrimMaterial)
			beam(ctx, torso, "WingBone", elbow, tip, Vector2.new(0.12, 0.12), s.Secondary, s.TrimMaterial)
			-- Membranes hang below each bone
			local function membrane(from: Vector3, to: Vector3, height: number)
				local center = (from + to) / 2 - Vector3.new(0, height / 2, 0)
				add(ctx, torso, "WingMembrane", Vector3.new(0.05, height, (to - from).Magnitude), CFrame.lookAt(center, center + (to - from) * Vector3.new(1, 0, 1)), s.Primary)
			end
			membrane(base, elbow, 1.2)
			membrane(elbow, tip, 1)
			add(ctx, torso, "WingClaw", Vector3.new(0.1, 0.35, 0.1), CFrame.new(elbow + Vector3.new(0, 0.2, 0)), s.Accent, M.Neon)
			if ctx.Full then
				beam(ctx, torso, "WingGlow", elbow - Vector3.new(0, 0.05, 0), tip - Vector3.new(0, 0.05, 0), Vector2.new(0.05, 0.05), s.Accent, M.Neon)
			end
		end
	end
end

local function buildChest(ctx: Ctx, character: Model): BasePart?
	local s = ctx.Style
	local torso = limb(character, "UpperTorso")
	if not torso then
		return nil
	end
	local T = torso.Size
	local front = -(T.Z + 0.25) / 2 - 0.02
	local plate
	if s.Emblem == "Lamellar" then
		-- Rows of laced plates
		plate = add(ctx, torso, "Chestplate", Vector3.new(T.X + 0.18, T.Y + 0.05, T.Z + 0.22), CFrame.new(), s.Secondary)
		for i = 0, 3 do
			local y = T.Y * 0.3 - i * T.Y * 0.24
			add(ctx, torso, "Lamella", Vector3.new(T.X + 0.24, T.Y * 0.21, T.Z + 0.28), CFrame.new(0, y, 0), s.Primary)
			add(ctx, torso, "Lacing", Vector3.new(T.X + 0.26, 0.04, T.Z + 0.3), CFrame.new(0, y - T.Y * 0.11, 0), s.Cloth, M.Fabric)
		end
		add(ctx, torso, "Munaita", Vector3.new(T.X * 0.7, 0.2, T.Z + 0.32), CFrame.new(0, T.Y / 2 - 0.05, 0), s.Accent, s.TrimMaterial)
	else
		plate = add(ctx, torso, "Chestplate", Vector3.new(T.X + 0.2, T.Y + 0.08, T.Z + 0.25), CFrame.new(), s.Primary)
		add(ctx, torso, "ChestTrim", Vector3.new(T.X + 0.26, 0.14, T.Z + 0.3), CFrame.new(0, -T.Y / 2 + 0.05, 0), s.Secondary, s.TrimMaterial)
		add(ctx, torso, "Gorget", Vector3.new(T.X * 0.65, 0.22, T.Z + 0.32), CFrame.new(0, T.Y / 2 - 0.02, 0), s.Secondary, s.TrimMaterial)
		if s.Pauldron == "Leather" then
			add(ctx, torso, "Laces", Vector3.new(0.08, T.Y * 0.7, 0.05), CFrame.new(0, 0.05, front), s.Secondary)
			for i = 0, 2 do
				add(ctx, torso, "Lace", Vector3.new(0.35, 0.05, 0.05), CFrame.new(0, T.Y * 0.2 - i * 0.25, front - 0.01), s.Accent, M.Fabric)
			end
		elseif not s.Tabard then
			add(ctx, torso, "ChestRidge", Vector3.new(0.1, T.Y * 0.85, 0.06), CFrame.new(0, 0, front), s.Secondary, s.TrimMaterial)
		end
	end

	local emblemZ = front
	if s.Tabard then
		add(ctx, torso, "Tabard", Vector3.new(T.X * 0.62, T.Y + 1.5, 0.06), CFrame.new(0, -0.75, front - 0.02), s.Cloth, M.Fabric)
		emblemZ = front - 0.07
	end
	if s.Emblem then
		emblem(ctx, torso, emblemZ)
	end
	if s.Cape then
		local capeFrame = CFrame.new(0, -0.95, T.Z / 2 + 0.2) * CFrame.Angles(math.rad(-7), 0, 0)
		add(ctx, torso, "Cape", Vector3.new(T.X * 0.95, T.Y + 2.3, 0.08), capeFrame, s.Cloth, M.Fabric)
		add(ctx, torso, "CapeTrim", Vector3.new(T.X * 0.97, 0.15, 0.1), capeFrame * CFrame.new(0, -(T.Y + 2.3) / 2 + 0.07, 0.01), s.Secondary, s.TrimMaterial)
	end
	if s.Fur then
		for i = 0, 6 do
			local angle = math.rad(-90 + i * 30)
			ball(ctx, torso, "Fur", 0.65, Vector3.new(math.sin(angle) * T.X * 0.42, T.Y / 2 + 0.05, math.cos(angle) * 0.35 + 0.15), s.Fur, M.Fabric)
		end
	end
	if s.Wings then
		wings(ctx, torso)
	end
	arms(ctx, character)

	pieceVfx(ctx, plate, 1)
	if s.Vfx and s.Vfx.Light then
		light(plate, s.Vfx.Color, 10, 0.8)
	end
	if s.Vfx and s.Vfx.Smoke then
		emitter(plate, "Smoke", rgb(50, 40, 40), 2)
	end
	return plate
end

-- Legs ---------------------------------------------------------------------------------

local function buildLegs(ctx: Ctx, character: Model): BasePart?
	local s = ctx.Style
	local hips = limb(character, "LowerTorso")
	if not hips then
		return nil
	end
	local W = hips.Size
	local belt = add(ctx, hips, "Belt", Vector3.new(W.X + 0.25, W.Y + 0.12, W.Z + 0.25), CFrame.new(), s.Secondary, s.TrimMaterial)
	add(ctx, hips, "Buckle", Vector3.new(0.32, 0.26, 0.06), CFrame.new(0, 0, -(W.Z + 0.25) / 2 - 0.02), s.Accent, if s.Skirt == "Scales" then M.Neon else M.Metal)

	local skirt = s.Skirt
	if skirt == "Loincloth" then
		add(ctx, hips, "Loincloth", Vector3.new(W.X * 0.45, 1, 0.06), CFrame.new(0, -0.55, -(W.Z / 2 + 0.14)), s.Cloth, M.Fabric)
		add(ctx, hips, "Loincloth", Vector3.new(W.X * 0.45, 1, 0.06), CFrame.new(0, -0.55, W.Z / 2 + 0.14), s.Cloth, M.Fabric)
	elseif skirt == "Fauld" or skirt == "Scales" then
		for i = 0, 1 do
			local hoop = add(ctx, hips, "Fauld", Vector3.new(W.X + 0.3 + i * 0.06, 0.24, W.Z + 0.3 + i * 0.06), CFrame.new(0, -W.Y / 2 - 0.12 - i * 0.22, 0), if i == 0 then s.Primary else s.Secondary)
			if skirt == "Scales" then
				hoop.Material = s.TrimMaterial
				add(ctx, hips, "ScaleGlow", Vector3.new(W.X + 0.34 + i * 0.06, 0.04, W.Z + 0.34 + i * 0.06), CFrame.new(0, -W.Y / 2 - 0.23 - i * 0.22, 0), s.Accent, M.Neon)
			end
		end
		if skirt == "Scales" then
			-- A spiked dragon tail
			horn(ctx, hips, Vector3.new(0, -0.1, W.Z / 2 + 0.1), Vector3.new(0, 0, 1), -45, 14, 6, 0.55, 0.38, s.Primary, s.Accent, s.Material)
		end
	elseif skirt == "Kusazuri" then
		for row = 0, 2 do
			local y = -W.Y / 2 - 0.12 - row * 0.3
			for _, z in { -1, 1 } do
				for _, x in { -1, 1 } do
					add(ctx, hips, "Kusazuri", Vector3.new(W.X * 0.48, 0.3, 0.1), CFrame.new(x * W.X * 0.25, y, z * (W.Z / 2 + 0.14 + row * 0.05)) * CFrame.Angles(math.rad(z * -10), 0, 0), s.Primary)
					add(ctx, hips, "Lacing", Vector3.new(W.X * 0.5, 0.04, 0.12), CFrame.new(x * W.X * 0.25, y - 0.15, z * (W.Z / 2 + 0.14 + row * 0.05)) * CFrame.Angles(math.rad(z * -10), 0, 0), s.Cloth, M.Fabric)
				end
			end
		end
	end

	for _, sideName in { "Left", "Right" } do
		local upper = limb(character, `{sideName}UpperLeg`)
		local lower = limb(character, `{sideName}LowerLeg`)
		if upper then
			local U = upper.Size
			if skirt == "Kusazuri" then
				-- Haidate: armored thigh apron with gold studs
				add(ctx, upper, "Haidate", Vector3.new(U.X + 0.1, U.Y * 0.7, 0.1), CFrame.new(0, 0, -(U.Z / 2 + 0.08)), s.Secondary)
				for row = 0, 2 do
					for col = -1, 1 do
						add(ctx, upper, "Stud", Vector3.new(0.1, 0.1, 0.06), CFrame.new(col * 0.25, U.Y * 0.2 - row * 0.25, -(U.Z / 2 + 0.15)), s.Accent, M.Metal)
					end
				end
			else
				add(ctx, upper, "Cuisse", Vector3.new(U.X + 0.15, U.Y * 0.62, U.Z + 0.15), CFrame.new(0, U.Y * 0.12, 0), if s.Pauldron == "Leather" then s.Secondary else s.Primary)
				if s.Pauldron ~= "Leather" then
					ball(ctx, upper, "KneeCop", 0.55, Vector3.new(0, -U.Y / 2 + 0.05, -(U.Z / 2 + 0.05)), s.Secondary, s.TrimMaterial)
				end
				if skirt == "Tassets" then
					add(ctx, upper, "Tasset", Vector3.new(U.X + 0.2, U.Y * 0.4, 0.12), CFrame.new(0, U.Y * 0.28, -(U.Z / 2 + 0.1)) * CFrame.Angles(math.rad(8), 0, 0), s.Primary)
					add(ctx, upper, "TassetTrim", Vector3.new(U.X + 0.22, 0.06, 0.14), CFrame.new(0, U.Y * 0.08, -(U.Z / 2 + 0.12)), s.Secondary, s.TrimMaterial)
				end
				if skirt == "Scales" then
					horn(ctx, upper, Vector3.new(0, -U.Y / 2 + 0.1, -(U.Z / 2 + 0.2)), Vector3.new(0, 0, -1), 60, 0, 2, 0.3, 0.14, s.Secondary, s.Accent, s.TrimMaterial)
				end
			end
		end
		if lower then
			local L = lower.Size
			if skirt == "Kusazuri" then
				add(ctx, lower, "Suneate", Vector3.new(L.X + 0.14, L.Y * 0.8, L.Z + 0.14), CFrame.new(0, 0.05, 0), s.Secondary)
				for _, x in { -0.25, 0, 0.25 } do
					add(ctx, lower, "Splint", Vector3.new(0.1, L.Y * 0.7, 0.05), CFrame.new(x, 0.05, -(L.Z / 2 + 0.1)), s.Accent, s.TrimMaterial)
				end
			elseif s.Pauldron == "Leather" then
				add(ctx, lower, "Wrap", Vector3.new(L.X + 0.1, L.Y * 0.8, L.Z + 0.1), CFrame.new(0, 0.05, 0), s.Primary)
				for i = 0, 2 do
					add(ctx, lower, "WrapBand", Vector3.new(L.X + 0.14, 0.06, L.Z + 0.14), CFrame.new(0, L.Y * 0.25 - i * L.Y * 0.25, 0), s.Secondary)
				end
			else
				add(ctx, lower, "Greave", Vector3.new(L.X + 0.14, L.Y * 0.78, L.Z + 0.14), CFrame.new(0, 0.05, 0), s.Primary)
				add(ctx, lower, "GreaveRidge", Vector3.new(0.1, L.Y * 0.7, 0.06), CFrame.new(0, 0.05, -(L.Z / 2 + 0.1)), s.Secondary, s.TrimMaterial)
			end
		end
	end
	pieceVfx(ctx, belt, 0.4)
	return belt
end

-- Boots --------------------------------------------------------------------------------

local function buildBoots(ctx: Ctx, character: Model): BasePart?
	local s = ctx.Style
	local first: BasePart? = nil
	for _, sideName in { "Left", "Right" } do
		local foot = limb(character, `{sideName}Foot`)
		local lower = limb(character, `{sideName}LowerLeg`)
		if foot then
			local F = foot.Size
			local kind = s.Boots
			local bootColor = if kind == "Tabi" then s.Secondary else s.Primary
			local boot = add(ctx, foot, "Boot", Vector3.new(F.X + 0.16, F.Y + 0.18, F.Z + 0.3), CFrame.new(0, 0.05, -0.12), bootColor)
			first = first or boot
			if kind == "Plate" or kind == "Claws" then
				add(ctx, foot, "ToeCap", Vector3.new(F.X + 0.12, F.Y + 0.1, 0.3), CFrame.new(0, 0.03, -(F.Z / 2 + 0.25)), s.Secondary, s.TrimMaterial)
			end
			if kind == "Claws" then
				for i = -1, 1 do
					add(ctx, foot, "Talon", Vector3.new(0.1, 0.1, 0.4), CFrame.new(i * 0.28, -0.05, -(F.Z / 2 + 0.5)) * CFrame.Angles(math.rad(25), 0, 0), s.Accent, M.Neon)
				end
				add(ctx, foot, "HeelSpike", Vector3.new(0.12, 0.12, 0.4), CFrame.new(0, 0.05, F.Z / 2 + 0.2) * CFrame.Angles(math.rad(-20), 0, 0), s.Secondary, s.TrimMaterial)
			elseif kind == "Tabi" then
				add(ctx, foot, "Strap", Vector3.new(F.X + 0.2, 0.08, 0.2), CFrame.new(0, 0.1, -0.1), s.Accent, s.TrimMaterial)
			end
			pieceVfx(ctx, boot, if s.Vfx and s.Vfx.Kind == "Dust" then 1 else 0.3)
		end
		if lower then
			local L = lower.Size
			local cuffColor = if s.Boots == "Tabi" then s.Primary else s.Secondary
			add(ctx, lower, "BootCuff", Vector3.new(L.X + 0.22, 0.32, L.Z + 0.22), CFrame.new(0, -L.Y / 2 + 0.16, 0), cuffColor, if s.Boots == "Leather" then s.Material else s.TrimMaterial)
		end
	end
	return first
end

-- Full-set aura -------------------------------------------------------------------------

local function aura(ctx: Ctx, character: Model, setId: string)
	local torso = limb(character, "UpperTorso")
	local vfx = ctx.Style.Vfx
	if not torso or not vfx then
		return
	end
	local field = add(ctx, torso, "SetAura", Vector3.new(3, 5, 3), CFrame.new(0, -0.8, 0), Color3.new(1, 1, 1), M.SmoothPlastic)
	field.Transparency = 1
	field.CastShadow = false
	emitter(field, vfx.Kind, vfx.Color, vfx.Rate * 2.5, true)
	light(field, vfx.Color, 14, 1.2)
	if setId == "BlackDragon" then
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 4
		fire.Color = rgb(200, 30, 10)
		fire.SecondaryColor = rgb(40, 0, 0)
		fire.Parent = field
	elseif setId == "ShogunsOath" then
		emitter(field, "Sparkles", ctx.Style.Accent, 6, true)
	end
end

-- Public -------------------------------------------------------------------------------

local BUILDERS = {
	Helmet = function(ctx: Ctx, character: Model): BasePart?
		local head = limb(character, "Head")
		if not head then
			return nil
		end
		local build = HELMETS[ctx.Style.Helmet] or HELMETS.GreatHelm
		local shell = build(ctx, head)
		pieceVfx(ctx, shell, 0.4)
		return shell
	end,
	Chest = buildChest,
	Legs = buildLegs,
	Boots = buildBoots,
}

-- Rebuilds all armor on a character. `pieces` maps slot -> piece def; `fullSet` is the set
-- id when all 4 pieces come from one set.
function ArmorVisuals.apply(character: Model, pieces: { [string]: Items.ArmorDef }, fullSet: string?)
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER

	for _, slot in Items.ArmorSlots do
		local piece = pieces[slot]
		if piece then
			local set = Items.ArmorSets[piece.Set]
			local ctx: Ctx = { Folder = folder, Style = set.Style, Full = fullSet == piece.Set }
			local ok, err = pcall(BUILDERS[slot], ctx, character)
			if not ok then
				warn(`[ArmorVisuals] {piece.Id}: {err}`)
			end
		end
	end
	if fullSet then
		local set = Items.ArmorSets[fullSet]
		aura({ Folder = folder, Style = set.Style, Full = true }, character, fullSet)
	end

	setHeadAccessoriesHidden(character, pieces.Helmet ~= nil)
	folder.Parent = character
end

return ArmorVisuals
