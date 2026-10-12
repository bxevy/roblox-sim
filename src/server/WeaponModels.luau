-- Builds every weapon's model from parts, following its Design (Items.luau).
--
-- How tools sit in the hand: Roblox welds the Tool's Handle to the right hand's grip
-- point. While you hold a tool, the default pose raises your right arm forward, so in the
-- grip's frame +Y points up and -Z points forward. The Handle is the part your hand
-- closes around; everything else is welded relative to it.
--   Swords, daggers, maces: Handle's +Y runs along the weapon, edges face forward/back.
--   Staffs: held a third of the way up, nearly upright.  Bows: upright, string toward you.
--   Tomes: held open, tilted toward your face.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)

local WeaponModels = {}

WeaponModels.ToolAttribute = "WeaponId"

local rgb = Color3.fromRGB
local M = Enum.Material

local SWORD_TILT = math.rad(70) -- 0 = blade straight up, 90 = straight out in front
local STAFF_TILT = math.rad(10)
local LEATHER = rgb(55, 38, 26)

local TEXTURES = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- Part helpers ---------------------------------------------------------------------

type Builder = {
	Tool: Tool,
	Handle: BasePart,
	Weapon: Items.WeaponDef,
}

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Adds a part welded to the Handle at `offset` (in the Handle's space).
local function add(b: Builder, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = newPart(b.Tool, name, size, color, material or b.Weapon.Material, shape)
	p.CFrame = b.Handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = b.Handle
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function ball(b: Builder, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return add(b, name, Vector3.one * diameter, CFrame.new(position), color, material, Enum.PartType.Ball)
end

-- A cylinder whose axis runs along the Handle's Y.
local function cylinder(b: Builder, name: string, diameter: number, height: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return add(b, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- A chain of short segments that bends as it goes (horns, claws, curved blades).
-- `outward` and Y set the plane; angles in degrees from `outward` toward +Y.
local function curve(b: Builder, name: string, start: Vector3, outward: Vector3, startAngle: number, bend: number, segments: number, length: number, size: Vector2, color: Color3, material: Enum.Material?, tipColor: Color3?)
	local position = start
	for i = 1, segments do
		local theta = math.rad(startAngle + (i - 1) * bend)
		local direction = (outward.Unit * math.cos(theta) + Vector3.yAxis * math.sin(theta)).Unit
		local shrink = 1 - (i - 1) / (segments + 2)
		local tip = position + direction * length
		local center = (position + tip) / 2
		local isTip = i == segments and tipColor ~= nil
		local up = if math.abs(direction.Y) > 0.98 then outward.Unit else Vector3.yAxis -- straight up needs another "up"
		add(b, name, Vector3.new(size.X * shrink, size.Y * shrink, length), CFrame.lookAt(center, tip, up), if isTip then tipColor :: Color3 else color, if isTip then M.Neon else material)
		position += direction * length * 0.85
	end
end

local function light(part: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.2
	l.Parent = part
end

-- Particle aura on a weapon part.
local function aura(part: BasePart, kind: string, color: Color3)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Texture = TEXTURES.Sparkle
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.18, 0)
	e.Rate = 10
	e.Shape = Enum.ParticleEmitterShape.Box
	if kind == "Embers" then
		e.Texture = TEXTURES.Fire
		e.Acceleration = Vector3.new(0, 3, 0)
		e.Size = NumberSequence.new(0.22, 0)
		e.Rate = 14
	elseif kind == "Smoke" or kind == "Dust" then
		e.Texture = TEXTURES.Smoke
		e.LightEmission = if kind == "Smoke" then 0.4 else 0
		e.Size = NumberSequence.new(0.3, 0.8)
		e.Transparency = NumberSequence.new(0.6, 1)
		e.Acceleration = Vector3.new(0, 0.8, 0)
		e.Rate = 6
	elseif kind == "Snow" then
		e.Acceleration = Vector3.new(0, -1.5, 0)
		e.Size = NumberSequence.new(0.14)
		e.Lifetime = NumberRange.new(1, 1.5)
	elseif kind == "Leaves" then
		e.LightEmission = 0.2
		e.Acceleration = Vector3.new(0.5, -1.2, 0)
		e.Size = NumberSequence.new(0.2)
		e.RotSpeed = NumberRange.new(-180, 180)
		e.Lifetime = NumberRange.new(1.2, 1.8)
		e.Rate = 5
	elseif kind == "Holy" then
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Size = NumberSequence.new(0.25, 0)
	elseif kind == "Void" or kind == "Spirit" then
		e.Size = NumberSequence.new(0.3, 0)
		e.RotSpeed = NumberRange.new(-120, 120)
		e.Acceleration = Vector3.new(0, if kind == "Spirit" then 1 else -0.5, 0)
		e.Transparency = NumberSequence.new(0.2, 1)
	elseif kind == "Coins" then
		e.LightEmission = 0.4
		e.Acceleration = Vector3.new(0, -4, 0)
		e.Speed = NumberRange.new(1, 2)
		e.Size = NumberSequence.new(0.2)
		e.Rate = 6
	end
	e.Parent = part
end

-- A ribbon between two points on the weapon that draws the swing (enabled during attacks).
local function swingTrail(b: Builder, base: Vector3, tip: Vector3, color: Color3)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = base
	a0.Parent = b.Handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = tip
	a1.Parent = b.Handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 0.8
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Enabled = false
	trail.Parent = b.Handle
end

-- Finishing touches every design can ask for.
local function finish(b: Builder, main: BasePart, base: Vector3, tip: Vector3)
	local d = b.Weapon.Design
	if d.Aura then
		aura(main, d.Aura.Kind, d.Aura.Color)
	end
	if d.Glow then
		light(main, d.Glow, 10, 1.4)
	end
	swingTrail(b, base, tip, d.Trail or b.Weapon.Color)
end

-- Swords ------------------------------------------------------------------------------

local function guard(b: Builder, kind: string, y: number, width: number)
	local w = b.Weapon
	if kind == "Wings" then
		add(b, "Guard", Vector3.new(0.35, 0.3, 0.6), CFrame.new(0, y, 0), w.Accent, M.Metal)
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				add(b, "GuardWing", Vector3.new(0.18, 0.22, 0.75 - i * 0.15), CFrame.new(0, y + i * 0.12, side * (0.45 + i * 0.12)) * CFrame.Angles(math.rad(side * (25 + i * 15)), 0, 0), w.Accent, M.Metal)
			end
		end
	elseif kind == "Crescent" then
		add(b, "Guard", Vector3.new(0.35, 0.3, 1.1), CFrame.new(0, y, 0), w.Accent, M.Metal)
		for _, side in { -1, 1 } do
			curve(b, "GuardHorn", Vector3.new(0, y, side * 0.5), Vector3.new(0, 0, side), 10, 25, 4, 0.32, Vector2.new(0.16, 0.2), w.Accent, M.Metal)
		end
	elseif kind == "Disc" then
		cylinder(b, "Guard", width * 1.4, 0.22, Vector3.new(0, y, 0), w.Accent, M.Metal)
		cylinder(b, "GuardRim", width * 1.1, 0.26, Vector3.new(0, y, 0), w.Color, M.Metal)
	elseif kind == "Skull" then
		local bone = rgb(230, 225, 205)
		ball(b, "GuardSkull", 0.75, Vector3.new(0, y + 0.05, 0), bone, M.SmoothPlastic)
		for _, side in { -1, 1 } do
			add(b, "SkullEye", Vector3.new(0.4, 0.12, 0.12), CFrame.new(side * 0.02, y + 0.12, side * 0.18), w.Accent, M.Neon)
			curve(b, "SkullHorn", Vector3.new(0, y + 0.2, side * 0.3), Vector3.new(0, 0, side), 30, 25, 3, 0.25, Vector2.new(0.12, 0.12), bone, M.SmoothPlastic)
		end
	elseif kind == "Claws" then
		add(b, "Guard", Vector3.new(0.4, 0.35, 0.9), CFrame.new(0, y, 0), w.Accent, M.Metal)
		for _, side in { -1, 1 } do
			for i = 0, 1 do
				curve(b, "GuardClaw", Vector3.new((i - 0.5) * 0.2, y, side * 0.4), Vector3.new(0, 0, side), -10 + i * 20, 30, 3, 0.3, Vector2.new(0.12, 0.14), w.Accent, M.Metal, w.Color)
			end
		end
	else -- Cross
		add(b, "Guard", Vector3.new(0.35, 0.3, width * 2.4), CFrame.new(0, y, 0), w.Accent, M.Metal)
		for _, side in { -1, 1 } do
			ball(b, "GuardEnd", 0.32, Vector3.new(0, y, side * width * 1.2), w.Accent, M.Metal)
		end
	end
end

local function pommel(b: Builder, kind: string, y: number)
	local w = b.Weapon
	if kind == "Gem" then
		add(b, "Pommel", Vector3.one * 0.38, CFrame.new(0, y, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), w.Design.Glow or w.Accent, M.Neon)
	elseif kind == "Spike" then
		add(b, "Pommel", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, y - 0.15, 0) * CFrame.Angles(0, math.rad(45), 0), w.Accent, M.Metal)
		for _, side in { -1, 1 } do
			add(b, "PommelSpike", Vector3.new(0.1, 0.35, 0.1), CFrame.new(0, y, side * 0.2) * CFrame.Angles(math.rad(side * 45), 0, 0), w.Accent, M.Metal)
		end
	else
		ball(b, "Pommel", 0.4, Vector3.new(0, y, 0), w.Accent, M.Metal)
	end
end

-- Builds the blade from `base` upward. Returns the main blade part and the tip height.
local function blade(b: Builder, kind: string, base: number, length: number, width: number, thickness: number): (BasePart, number)
	local w = b.Weapon
	local color, material = w.Color, w.Material
	local main: BasePart
	if kind == "Curved" or kind == "Flame" or kind == "Wavy" or kind == "Crescent" then
		-- Built from segments that bend (or wave) along the way
		local segments = if kind == "Crescent" then 6 else 5
		local segmentLength = length / segments
		local position = Vector3.new(0, base, 0)
		local angle = 0
		for i = 1, segments do
			local t = (i - 1) / segments
			if kind == "Curved" then
				angle = -math.rad(4 + i * 4) -- bends forward, like a scimitar
			elseif kind == "Crescent" then
				angle = -math.rad(i * 14)
			else
				angle = math.rad(if i % 2 == 0 then 12 else -12) -- waves
			end
			local direction = CFrame.Angles(angle, 0, 0) * Vector3.yAxis
			local segWidth = width * (if kind == "Curved" then 0.85 + t * 0.4 else 1 - t * 0.3)
			local center = position + direction * segmentLength / 2
			local seg = add(b, "Blade", Vector3.new(thickness, segmentLength * 1.15, segWidth), CFrame.new(center) * CFrame.Angles(angle, 0, 0), color, material)
			main = main or seg
			if kind == "Flame" then
				add(b, "BladeEdge", Vector3.new(thickness + 0.02, segmentLength * 1.1, 0.08), CFrame.new(center) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 0, -segWidth / 2), w.Design.Glow or w.Accent, M.Neon)
			end
			position += direction * segmentLength
		end
		add(b, "BladeTip", Vector3.new(thickness * 0.95, width * 0.5, width * 0.5), CFrame.new(position) * CFrame.Angles(angle + math.rad(45), 0, 0), color, material)
		return main, position.Y
	end

	if kind == "Crystal" then
		main = add(b, "Blade", Vector3.new(thickness * 1.6, length, width * 0.7), CFrame.new(0, base + length / 2, 0), color, material)
		main.Transparency = 0.15
		local rng = Random.new(#w.Id)
		for i = 1, 6 do
			local y = base + length * (0.15 + i * 0.12)
			local side = if i % 2 == 0 then 1 else -1
			local shard = add(b, "Shard", Vector3.new(thickness * 1.2, 0.5 + rng:NextNumber() * 0.4, 0.25), CFrame.new(0, y, side * width * 0.35) * CFrame.Angles(math.rad(side * 40), 0, 0), w.Design.Glow or color, M.Neon)
			shard.Transparency = 0.2
		end
		add(b, "BladeTip", Vector3.new(thickness * 1.5, width * 0.5, width * 0.5), CFrame.new(0, base + length, 0) * CFrame.Angles(math.rad(45), 0, 0), color, material)
		return main, base + length + width * 0.3
	elseif kind == "Cleaver" then
		main = add(b, "Blade", Vector3.new(thickness, length, width * 1.6), CFrame.new(0, base + length / 2, width * 0.3), color, material)
		add(b, "BladeSpine", Vector3.new(thickness + 0.06, length, 0.15), CFrame.new(0, base + length / 2, width * 1.1), w.Accent, M.Metal)
		add(b, "BladeTip", Vector3.new(thickness, width * 0.9, width * 1.6), CFrame.new(0, base + length + width * 0.2, width * 0.3) * CFrame.Angles(math.rad(-25), 0, 0), color, material)
	elseif kind == "Needle" then
		main = add(b, "Blade", Vector3.new(thickness * 0.7, length, width * 0.4), CFrame.new(0, base + length / 2, 0), color, material)
		add(b, "BladeTip", Vector3.new(thickness * 0.6, width * 0.3, width * 0.3), CFrame.new(0, base + length, 0) * CFrame.Angles(math.rad(45), 0, 0), color, material)
	elseif kind == "Fang" then
		main = add(b, "Blade", Vector3.new(thickness, length * 0.7, width), CFrame.new(0, base + length * 0.35, 0), color, material)
		add(b, "FangTip", Vector3.new(thickness, length * 0.4, width * 0.6), CFrame.new(0, base + length * 0.82, -width * 0.15) * CFrame.Angles(math.rad(-20), 0, 0), color, material)
		add(b, "FangNotch", Vector3.new(thickness + 0.02, 0.2, 0.25), CFrame.new(0, base + length * 0.3, width * 0.45) * CFrame.Angles(math.rad(45), 0, 0), w.Accent, M.Metal)
	elseif kind == "Phantom" then
		main = add(b, "Blade", Vector3.new(thickness, length, width), CFrame.new(0, base + length / 2, 0), color, material)
		main.Transparency = 0.35
		for _, side in { -1, 1 } do
			add(b, "PhantomEdge", Vector3.new(thickness + 0.02, length, 0.06), CFrame.new(0, base + length / 2, side * width / 2), w.Design.Glow or color, M.Neon)
		end
		add(b, "BladeTip", Vector3.new(thickness, width * 0.7, width * 0.7), CFrame.new(0, base + length, 0) * CFrame.Angles(math.rad(45), 0, 0), color, material).Transparency = 0.35
	else -- Straight, Long, Broad
		main = add(b, "Blade", Vector3.new(thickness, length, width), CFrame.new(0, base + length / 2, 0), color, material)
		add(b, "BladeTip", Vector3.new(thickness * 0.95, width * 0.71, width * 0.71), CFrame.new(0, base + length, 0) * CFrame.Angles(math.rad(45), 0, 0), color, material)
	end

	local d = w.Design
	if d.Fuller then
		add(b, "Fuller", Vector3.new(thickness + 0.03, length * 0.75, width * 0.18), CFrame.new(0, base + length * 0.4, 0), color:Lerp(rgb(0, 0, 0), 0.35), M.Metal)
	end
	if d.Runes then
		for i = 1, 4 do
			add(b, "Rune", Vector3.new(thickness + 0.04, 0.16, 0.12), CFrame.new(0, base + length * (0.12 + i * 0.15), 0) * CFrame.Angles(math.rad(45), 0, 0), d.Runes, M.Neon)
		end
	end
	if d.Serrated then
		for i = 1, 6 do
			add(b, "Tooth", Vector3.new(thickness, 0.22, 0.22), CFrame.new(0, base + length * (0.15 + i * 0.12), -width * (if kind == "Cleaver" then 0.5 else 0.5)) * CFrame.Angles(math.rad(45), 0, 0), w.Color, w.Material)
		end
	end
	if d.Glow and kind ~= "Phantom" and kind ~= "Crystal" then
		add(b, "Edge", Vector3.new(thickness + 0.02, length * 0.85, 0.07), CFrame.new(0, base + length * 0.45, -width / 2), d.Glow, M.Neon)
	end
	return main, base + length + width * 0.35
end

local function buildSword(b: Builder)
	local w, d = b.Weapon, b.Weapon.Design
	local length = 3 + w.Tier * 0.25
	local width, thickness = 0.55, 0.2
	if d.Blade == "Long" then
		length *= 1.25
		width = 0.5
	elseif d.Blade == "Broad" then
		width = 0.85
		thickness = 0.25
	elseif d.Blade == "Cleaver" then
		width = 0.7
		thickness = 0.24
	end
	-- Wrapped grip
	for i = 0, 2 do
		add(b, "GripWrap", Vector3.new(0.34, 0.08, 0.34), CFrame.new(0, -0.35 + i * 0.35, 0) * CFrame.Angles(math.rad(20), 0, 0), w.Accent, M.Fabric)
	end
	guard(b, d.Guard or "Cross", 0.7, width)
	pommel(b, d.Pommel or "Ball", -0.75)
	local main, tipY = blade(b, d.Blade or "Straight", 0.85, length, width, thickness)
	finish(b, main, Vector3.new(0, 1.2, 0), Vector3.new(0, tipY, 0))
end

local function buildDagger(b: Builder)
	local w, d = b.Weapon, b.Weapon.Design
	local length = 1.5 + w.Tier * 0.1
	add(b, "GripWrap", Vector3.new(0.3, 0.08, 0.3), CFrame.new(0, 0.1, 0) * CFrame.Angles(math.rad(20), 0, 0), w.Accent, M.Fabric)
	add(b, "Guard", Vector3.new(0.3, 0.2, 0.75), CFrame.new(0, 0.5, 0), w.Accent, M.Metal)
	ball(b, "Pommel", 0.28, Vector3.new(0, -0.45, 0), w.Accent, M.Metal)
	local main, tipY = blade(b, d.Blade or "Straight", 0.6, length, 0.4, 0.14)
	finish(b, main, Vector3.new(0, 0.8, 0), Vector3.new(0, tipY, 0))
end

-- Maces --------------------------------------------------------------------------------

local function buildMace(b: Builder, length: number)
	local w, d = b.Weapon, b.Weapon.Design
	local top = length - 0.5 -- handle sits at the bottom of the shaft
	cylinder(b, "Shaft", 0.3, length, Vector3.new(0, length / 2 - 0.5, 0), w.Color:Lerp(rgb(60, 40, 25), 0.55), M.Wood)
	for i = 0, 2 do
		cylinder(b, "ShaftBand", 0.36, 0.12, Vector3.new(0, top * (0.3 + i * 0.25), 0), w.Accent, M.Metal)
	end
	ball(b, "Pommel", 0.42, Vector3.new(0, -0.6, 0), w.Accent, M.Metal)
	local headY = top + 0.4
	local size = 0.9 + w.Tier * 0.07
	local main: BasePart
	local head = d.Head or "Flanged"
	if head == "Club" then
		for i = 0, 3 do
			main = cylinder(b, "ClubHead", 0.55 + i * 0.15, 0.45, Vector3.new(0, headY - 0.4 + i * 0.35, 0), w.Color, w.Material)
		end
		for i = 0, 5 do
			local angle = i / 6 * math.pi * 2
			add(b, "Nail", Vector3.new(0.08, 0.08, 0.3), CFrame.new(0, headY + 0.1 + (i % 2) * 0.3, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 0.5), rgb(120, 120, 130), M.Metal)
		end
	elseif head == "SpikedBall" then
		main = ball(b, "MaceHead", size, Vector3.new(0, headY, 0), w.Color, w.Material)
		for i = 0, 9 do
			local yaw = i * 2.4
			local pitch = math.asin(-1 + 2 * (i + 0.5) / 10)
			local direction = Vector3.new(math.cos(pitch) * math.cos(yaw), math.sin(pitch), math.cos(pitch) * math.sin(yaw))
			local center = Vector3.new(0, headY, 0) + direction * size * 0.55
			add(b, "Spike", Vector3.new(0.14, 0.14, size * 0.5), CFrame.lookAt(center, center + direction), w.Accent, M.Metal)
		end
	elseif head == "Gem" then
		main = add(b, "Gem", Vector3.one * size * 0.75, CFrame.new(0, headY, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), w.Design.Glow or w.Accent, M.Neon)
		for i = 0, 3 do
			local angle = i / 4 * math.pi * 2
			curve(b, "Prong", Vector3.new(math.cos(angle) * 0.2, headY - size * 0.5, math.sin(angle) * 0.2), Vector3.new(math.cos(angle), 0, math.sin(angle)), 60, 25, 3, size * 0.4, Vector2.new(0.1, 0.1), w.Color, M.Metal)
		end
	elseif head == "Hammer" then
		main = add(b, "HammerHead", Vector3.new(size * 0.9, size * 0.9, size * 2), CFrame.new(0, headY, 0), w.Color, w.Material)
		for _, side in { -1, 1 } do
			add(b, "HammerFace", Vector3.new(size, size, 0.15), CFrame.new(0, headY, side * size), w.Accent, M.Metal)
		end
		add(b, "HammerTop", Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, headY + size * 0.6, 0), w.Accent, M.Metal)
	elseif head == "Crown" then
		main = cylinder(b, "CrownBand", size, size * 0.6, Vector3.new(0, headY, 0), w.Color, w.Material)
		for i = 0, 5 do
			local angle = i / 6 * math.pi * 2
			local p = Vector3.new(math.cos(angle) * size * 0.45, headY + size * 0.45, math.sin(angle) * size * 0.45)
			add(b, "CrownPoint", Vector3.new(0.14, size * 0.45, 0.14), CFrame.new(p), w.Color, w.Material)
			ball(b, "CrownPearl", 0.18, p + Vector3.new(0, size * 0.27, 0), w.Accent, M.Neon)
		end
		add(b, "CrownGem", Vector3.one * size * 0.35, CFrame.new(0, headY + size * 0.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), w.Design.Glow or w.Accent, M.Neon)
	else -- Flanged
		main = ball(b, "MaceHead", size * 0.8, Vector3.new(0, headY, 0), w.Color, w.Material)
		for i = 0, 5 do
			local angle = i / 6 * math.pi * 2
			add(b, "Flange", Vector3.new(0.12, size * 0.95, size * 0.45), CFrame.new(0, headY, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, size * 0.45), w.Accent, M.Metal)
		end
	end
	finish(b, main, Vector3.new(0, top * 0.6, 0), Vector3.new(0, headY + size * 0.5, 0))
end

-- Staffs -------------------------------------------------------------------------------

local function buildStaffHead(b: Builder, top: number)
	local w, d = b.Weapon, b.Weapon.Design
	local accent = w.Accent
	local glow = d.Glow or accent
	local size = 0.8 + w.Tier * 0.08
	local head = d.Head or "Orb"
	local main: BasePart
	if head == "Leaf" then
		main = ball(b, "Orb", size * 0.6, Vector3.new(0, top + size * 0.35, 0), accent, M.Neon)
		for i = 0, 3 do
			local angle = i / 4 * math.pi * 2
			add(b, "Leaf", Vector3.new(0.06, size * 0.9, size * 0.4), CFrame.new(0, top + size * 0.3, 0) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, size * 0.3, 0), rgb(90, 170, 70), M.Grass)
		end
	elseif head == "Crystals" then
		local rng = Random.new(3)
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			local tilt = if i == 0 then 0 else math.rad(25)
			local crystal = add(b, "Crystal", Vector3.new(0.3, size * (if i == 0 then 1.4 else 0.9), 0.3), CFrame.new(0, top + size * 0.5, 0) * CFrame.Angles(0, angle, 0) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 0, if i == 0 then 0 else 0.15), if i == 0 then glow else accent, M.Neon)
			crystal.Transparency = 0.1 + rng:NextNumber() * 0.15
			main = main or crystal
		end
	elseif head == "Skull" then
		local bone = rgb(220, 215, 195)
		main = ball(b, "Skull", size, Vector3.new(0, top + size * 0.5, 0), bone, M.SmoothPlastic)
		add(b, "Jaw", Vector3.new(size * 0.6, size * 0.25, size * 0.5), CFrame.new(0, top + size * 0.05, -size * 0.1), bone, M.SmoothPlastic)
		for _, side in { -1, 1 } do
			ball(b, "SkullEye", size * 0.22, Vector3.new(side * size * 0.2, top + size * 0.55, -size * 0.42), glow, M.Neon)
			curve(b, "SkullHorn", Vector3.new(side * size * 0.4, top + size * 0.8, 0), Vector3.new(side, 0, 0.3), 20, 25, 4, size * 0.3, Vector2.new(0.16, 0.16), rgb(40, 35, 40), M.Slate)
		end
	elseif head == "Brazier" then
		main = cylinder(b, "Brazier", size, size * 0.45, Vector3.new(0, top + size * 0.25, 0), w.Color, M.Metal)
		for i = 0, 3 do
			local angle = i / 4 * math.pi * 2
			curve(b, "BrazierProng", Vector3.new(math.cos(angle) * size * 0.45, top + size * 0.4, math.sin(angle) * size * 0.45), Vector3.new(math.cos(angle), 0, math.sin(angle)), 70, 15, 2, size * 0.35, Vector2.new(0.1, 0.1), w.Color, M.Metal)
		end
		local coals = ball(b, "Coals", size * 0.7, Vector3.new(0, top + size * 0.45, 0), glow, M.Neon)
		local fire = Instance.new("Fire")
		fire.Color = glow
		fire.Size = 2.5
		fire.Heat = 6
		fire.Parent = coals
	elseif head == "Sun" then
		main = add(b, "SunDisc", Vector3.new(0.2, size, size), CFrame.new(0, top + size * 0.6, 0) * CFrame.Angles(0, math.rad(90), 0), glow, M.Neon, Enum.PartType.Cylinder)
		for i = 0, 7 do
			add(b, "SunRay", Vector3.new(0.1, size * 0.35, 0.12), CFrame.new(0, top + size * 0.6, 0) * CFrame.Angles(i / 8 * math.pi * 2, 0, 0) * CFrame.new(0, size * 0.65, 0), accent, M.Metal)
		end
	elseif head == "Crescent" then
		local start = Vector3.new(0, top + 0.1, 0)
		curve(b, "Crescent", start, Vector3.new(0, 0, -1), 80, -35, 5, size * 0.35, Vector2.new(0.14, 0.3), accent, M.Ice, glow)
		curve(b, "Crescent", start, Vector3.new(0, 0, 1), 80, -35, 5, size * 0.35, Vector2.new(0.14, 0.3), accent, M.Ice, glow)
		main = ball(b, "MoonOrb", size * 0.45, Vector3.new(0, top + size * 0.55, 0), glow, M.Neon)
	elseif head == "Eye" then
		main = ball(b, "Eye", size * 0.75, Vector3.new(0, top + size * 0.7, 0), rgb(250, 240, 220), M.SmoothPlastic)
		ball(b, "Iris", size * 0.4, Vector3.new(0, top + size * 0.7, -size * 0.22), glow, M.Neon)
		ball(b, "Pupil", size * 0.18, Vector3.new(0, top + size * 0.7, -size * 0.36), rgb(10, 5, 5), M.SmoothPlastic)
		for ring = 0, 1 do
			for i = 0, 11 do
				local angle = i / 12 * math.pi * 2
				add(b, "EyeRing", Vector3.new(0.12, 0.12, size * 0.32), CFrame.new(0, top + size * 0.7, 0) * CFrame.Angles(math.rad(if ring == 0 then 70 else -40), 0, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, size * 0.75), accent, M.Neon)
			end
		end
	else -- Orb
		main = ball(b, "Orb", size, Vector3.new(0, top + size * 0.5, 0), glow, M.Neon)
		for _, side in { -1, 1 } do
			curve(b, "Prong", Vector3.new(side * 0.12, top - 0.1, 0), Vector3.new(side, 0, 0), 70, 20, 2, size * 0.45, Vector2.new(0.12, 0.12), w.Color, w.Material)
		end
	end
	light(main, glow, 10, 1.2)
	return main, top + size * 1.2
end

local function buildStaff(b: Builder, length: number)
	local w, d = b.Weapon, b.Weapon.Design
	-- The Handle is the whole shaft; its center is length/6 above the hand.
	if d.Shaft == "Twisted" then
		for i = 0, 7 do
			add(b, "Twist", Vector3.new(0.38, 0.12, 0.2), CFrame.new(0, -length / 2 + 0.4 + i * (length - 0.8) / 7, 0) * CFrame.Angles(0, i * 0.8, math.rad(30)), w.Accent:Lerp(w.Color, 0.5), w.Material)
		end
	end
	for _, y in { -length / 2 + 0.1, length / 2 - 0.2 } do
		cylinder(b, "StaffBand", 0.38, 0.18, Vector3.new(0, y, 0), w.Accent, M.Metal)
	end
	local main, tipY = buildStaffHead(b, length / 2)
	finish(b, main, Vector3.new(0, length / 2 - 0.4, 0), Vector3.new(0, tipY, 0))
end

-- Bows ---------------------------------------------------------------------------------

local function buildBow(b: Builder)
	local w, d = b.Weapon, b.Weapon.Design
	local limbs = d.Limbs or "Recurve"
	local limbLength = 2 + w.Tier * 0.08
	if limbs == "Long" then
		limbLength *= 1.3
	end
	local bend = math.rad(if limbs == "Long" then 12 else 20)
	local material = if limbs == "Bone" then M.Marble elseif limbs == "Crystal" then M.Ice else w.Material
	local tipY, tipZ = 0, 0
	for _, side in { -1, 1 } do
		-- Each limb: an inner segment bending back toward you, and for recurves a tip flicking forward
		local innerLength = if limbs == "Recurve" then limbLength * 0.75 else limbLength
		local center = Vector3.new(0, side * (0.6 + math.cos(bend) * innerLength / 2), 0.15 + math.sin(bend) * innerLength / 2)
		add(b, "Limb", Vector3.new(0.24, innerLength, 0.3), CFrame.new(center) * CFrame.Angles(side * bend, 0, 0), w.Color, material)
		local endY = side * (0.6 + math.cos(bend) * innerLength)
		local endZ = 0.15 + math.sin(bend) * innerLength
		if limbs == "Recurve" then
			local flick = math.rad(-25)
			local tipLength = limbLength * 0.3
			local tipCenter = Vector3.new(0, endY + side * math.cos(flick) * tipLength / 2, endZ + math.sin(flick) * tipLength / 2)
			add(b, "LimbTip", Vector3.new(0.2, tipLength, 0.24), CFrame.new(tipCenter) * CFrame.Angles(side * flick, 0, 0), w.Color, material)
			endY += side * math.cos(flick) * tipLength
			endZ += math.sin(flick) * tipLength
		end
		tipY, tipZ = math.abs(endY), endZ

		local limbMid = CFrame.new(center) * CFrame.Angles(side * bend, 0, 0)
		if limbs == "Bone" then
			for i = -1, 1 do
				add(b, "BoneSpike", Vector3.new(0.1, 0.1, 0.4), limbMid * CFrame.new(0, i * innerLength * 0.3, -0.25) * CFrame.Angles(math.rad(-30), 0, 0), rgb(235, 230, 210), M.Marble)
			end
		elseif limbs == "Wing" or limbs == "Flame" then
			for i = 0, 3 do
				local feather = add(b, "Feather", Vector3.new(0.06, 0.25, 0.9 - i * 0.12), limbMid * CFrame.new(0, side * (i - 1.5) * innerLength * 0.25, -0.45) * CFrame.Angles(math.rad(side * (20 + i * 12)), 0, 0), if limbs == "Flame" then w.Accent else w.Color:Lerp(rgb(255, 255, 255), 0.3), if limbs == "Flame" then M.Neon else M.Fabric)
				feather.Transparency = if limbs == "Flame" then 0.15 else 0
			end
		elseif limbs == "Serpent" then
			local headPos = Vector3.new(0, endY + side * 0.15, endZ - 0.1)
			ball(b, "SnakeHead", 0.42, headPos, w.Color, M.Metal)
			add(b, "SnakeEye", Vector3.new(0.3, 0.08, 0.08), CFrame.new(headPos + Vector3.new(0, 0.05, -0.18)), w.Accent, M.Neon)
			add(b, "Fang", Vector3.new(0.05, 0.2, 0.05), CFrame.new(headPos + Vector3.new(0, -side * 0.2, -0.15)), rgb(240, 240, 230), M.SmoothPlastic)
		elseif limbs == "Crystal" then
			for i = -1, 1 do
				local shard = add(b, "Shard", Vector3.new(0.18, 0.5, 0.18), limbMid * CFrame.new(0, i * innerLength * 0.3, -0.2) * CFrame.Angles(math.rad(-35), 0, 0), w.Design.Glow or w.Accent, M.Neon)
				shard.Transparency = 0.2
			end
		end
	end
	-- Grip wrap and string
	add(b, "BowGrip", Vector3.new(0.34, 0.6, 0.44), CFrame.new(), LEATHER, M.Leather)
	local stringColor = w.Design.Glow or w.Accent
	add(b, "String", Vector3.new(0.05, tipY * 2, 0.05), CFrame.new(0, 0, tipZ), stringColor, M.Neon)
	if limbs == "Flame" then
		local fire = Instance.new("Fire")
		fire.Color = w.Color
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = b.Handle
	end
	finish(b, b.Handle, Vector3.new(0, -tipY, tipZ * 0.5), Vector3.new(0, tipY, tipZ * 0.5))
end

-- Tomes --------------------------------------------------------------------------------

local function buildTome(b: Builder)
	local w, d = b.Weapon, b.Weapon.Design
	local cover = d.Cover or "Plain"
	-- The Handle is the book itself, lying in the palm.
	local pages = add(b, "Pages", Vector3.new(1.25, 0.12, 0.95), CFrame.new(0, 0.18, 0), rgb(250, 240, 215), M.SmoothPlastic)
	add(b, "Spine", Vector3.new(0.14, 0.38, 1.12), CFrame.new(-0.68, 0.06, 0), w.Color:Lerp(rgb(0, 0, 0), 0.25), w.Material)
	local glow = d.Glow or w.Accent
	local text = add(b, "Text", Vector3.new(1, 0.02, 0.75), CFrame.new(0, 0.25, 0), glow, M.Neon)
	text.Transparency = 0.4
	if cover == "Clasped" or cover == "Jeweled" or cover == "Gilded" then
		for _, x in { -0.62, 0.62 } do
			for _, z in { -0.5, 0.5 } do
				add(b, "Corner", Vector3.new(0.18, 0.3, 0.18), CFrame.new(x, 0.02, z), w.Accent, M.Metal)
			end
		end
		add(b, "Clasp", Vector3.new(0.3, 0.3, 0.12), CFrame.new(0.7, 0.04, 0), w.Accent, M.Metal)
	end
	if cover == "Jeweled" or cover == "Gilded" or cover == "Radiant" then
		add(b, "CoverGem", Vector3.new(0.3, 0.06, 0.3), CFrame.new(0, -0.15, 0) * CFrame.Angles(0, math.rad(45), 0), glow, M.Neon)
	end
	if cover == "Vine" then
		for i = 0, 3 do
			add(b, "Vine", Vector3.new(1.5, 0.06, 0.08), CFrame.new(0, 0.02, -0.45 + i * 0.3) * CFrame.Angles(0, math.rad(15 - i * 10), 0), rgb(70, 140, 60), M.Grass)
		end
		ball(b, "Bloom", 0.25, Vector3.new(0.55, 0.2, -0.45), rgb(255, 200, 220), M.Fabric)
	elseif cover == "Winged" then
		for _, z in { -1, 1 } do
			for i = 0, 2 do
				add(b, "Wing", Vector3.new(0.06, 0.2, 0.7 - i * 0.15), CFrame.new(-0.75, 0.15 + i * 0.12, z * (0.55 + i * 0.1)) * CFrame.Angles(math.rad(z * (30 + i * 15)), 0, 0), rgb(245, 245, 255), M.Fabric)
			end
		end
	elseif cover == "Starry" then
		local rng = Random.new(9)
		for _ = 1, 8 do
			add(b, "Star", Vector3.new(0.08, 0.04, 0.08), CFrame.new(rng:NextNumber(-0.55, 0.55), -0.14, rng:NextNumber(-0.45, 0.45)) * CFrame.Angles(0, math.rad(45), 0), rgb(255, 245, 190), M.Neon)
		end
	elseif cover == "Radiant" then
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			add(b, "Halo", Vector3.new(0.1, 0.06, 0.28), CFrame.new(0, 1.3, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 0.75), glow, M.Neon)
		end
	end
	-- Runes floating above the pages
	local orbit = d.Orbit or 0
	for i = 1, orbit do
		local angle = i / orbit * math.pi * 2
		add(b, "Rune", Vector3.new(0.2, 0.2, 0.06), CFrame.new(math.cos(angle) * 0.9, 0.9 + math.sin(i) * 0.15, math.sin(angle) * 0.9) * CFrame.Angles(0, -angle, math.rad(45)), glow, M.Neon)
	end
	light(pages, glow, 9, 1)
	finish(b, pages, Vector3.new(-0.5, 0.3, 0), Vector3.new(0.5, 0.3, 0))
end

-- Voidlight Greatsword (Mythic) ----------------------------------------------------------

local function buildVoidlight(b: Builder)
	local w = b.Weapon
	local white, navy = w.Color, w.Accent
	local darkNavy = rgb(16, 18, 50)
	local lightBlue = rgb(125, 150, 255)
	local glow = rgb(90, 125, 255)
	for i = 0, 4 do
		add(b, "Wrap", Vector3.new(0.4, 0.1, 0.4), CFrame.new(0, -0.6 + i * 0.3, 0) * CFrame.Angles(math.rad(25), 0, 0), lightBlue, M.Fabric)
	end
	ball(b, "Pommel", 0.55, Vector3.new(0, -1.05, 0), darkNavy, M.Metal)
	add(b, "PommelSpike", Vector3.new(0.14, 0.5, 0.14), CFrame.new(0, -1.45, 0), navy, M.Metal)
	for k = 0, 4 do
		add(b, "PommelSpike", Vector3.new(0.12, 0.5, 0.12), CFrame.new(0, -1.15, 0) * CFrame.Angles(0, math.rad(k * 72), 0) * CFrame.Angles(math.rad(140), 0, 0) * CFrame.new(0, 0.3, 0), navy, M.Metal)
	end
	local guardY = 1
	add(b, "Guard", Vector3.new(0.55, 0.55, 1.5), CFrame.new(0, guardY, 0), navy, M.Metal)
	for _, y in { -0.2, 0.2 } do
		add(b, "GuardTrim", Vector3.new(0.58, 0.07, 1.53), CFrame.new(0, guardY + y, 0), lightBlue, M.Metal)
	end
	add(b, "GuardKnot", Vector3.new(0.62, 0.28, 0.28), CFrame.new(0, guardY, 0), lightBlue, M.Neon)
	for _, side in { -1, 1 } do
		curve(b, "Horn", Vector3.new(0, guardY, side * 0.7), Vector3.new(0, 0, side), 10, 22, 4, 0.55, Vector2.new(0.16, 0.22), navy, M.Metal, lightBlue)
		curve(b, "Horn", Vector3.new(0, guardY - 0.1, side * 0.6), Vector3.new(0, 0, side), -15, -25, 3, 0.4, Vector2.new(0.12, 0.17), navy, M.Metal, lightBlue)
		curve(b, "Horn", Vector3.new(side * 0.25, guardY + 0.1, 0), Vector3.new(side, 0, 0), 20, 25, 3, 0.4, Vector2.new(0.12, 0.17), navy, M.Metal, lightBlue)
	end
	local base = guardY + 0.3
	local lowerLength, upperLength = 4.2, 2.1
	local lowerWidth, upperWidth = 1.15, 0.85
	local main = add(b, "Blade", Vector3.new(0.24, lowerLength, lowerWidth), CFrame.new(0, base + lowerLength / 2, 0), white, M.Metal)
	local upperY = base + lowerLength + upperLength / 2
	add(b, "Blade", Vector3.new(0.24, upperLength, upperWidth), CFrame.new(0, upperY, 0), white, M.Metal)
	local tipBase = base + lowerLength + upperLength
	for _, side in { -1, 1 } do
		add(b, "BladeTip", Vector3.new(0.22, 1.7, upperWidth / 2 + 0.05), CFrame.new(0, tipBase + 0.6, side * upperWidth / 4) * CFrame.Angles(-side * math.rad(15), 0, 0), white, M.Metal)
		add(b, "EdgeTrim", Vector3.new(0.26, lowerLength, 0.07), CFrame.new(0, base + lowerLength / 2, side * (lowerWidth / 2 - 0.02)), navy, M.Metal)
		add(b, "EdgeTrim", Vector3.new(0.26, upperLength, 0.07), CFrame.new(0, upperY, side * (upperWidth / 2 - 0.02)), navy, M.Metal)
		for k = 1, 6 do
			local y = base + 2.6 + k * 0.6
			local width = if y < base + lowerLength then lowerWidth else upperWidth
			add(b, "Shard", Vector3.new(0.2, 0.45 - k * 0.03, 0.2), CFrame.new(0, y, side * (width / 2 + 0.06)) * CFrame.Angles(side * math.rad(35), 0, 0), white, M.Metal)
		end
	end
	local fullerLength = lowerLength + upperLength - 0.3
	add(b, "Fuller", Vector3.new(0.27, fullerLength, 0.22), CFrame.new(0, base + fullerLength / 2 + 0.1, 0), darkNavy, M.Metal)
	local line = add(b, "FullerGlow", Vector3.new(0.29, fullerLength - 0.2, 0.06), CFrame.new(0, base + fullerLength / 2 + 0.1, 0), glow, M.Neon)
	light(line, glow, 10, 1.5)
	finish(b, main, Vector3.new(0, base + 0.5, 0), Vector3.new(0, tipBase + 1.4, 0))
end

-- Axes (Berserker) -----------------------------------------------------------------------
-- Held like a mace (handle at the bottom of the haft). The bit faces the Handle's -Z.

local function buildAxe(b: Builder)
	local w, d = b.Weapon, b.Weapon.Design
	local length = 3 + w.Tier * 0.12
	local top = length - 0.5
	cylinder(b, "Haft", 0.3, length, Vector3.new(0, length / 2 - 0.5, 0), rgb(80, 55, 36):Lerp(w.Accent, 0.2), M.Wood)
	for i = 0, 2 do
		add(b, "GripWrap", Vector3.new(0.36, 0.08, 0.36), CFrame.new(0, -0.3 + i * 0.3, 0) * CFrame.Angles(math.rad(20), 0, 0), LEATHER, M.Fabric)
	end
	ball(b, "Pommel", 0.4, Vector3.new(0, -0.6, 0), w.Accent, M.Metal)
	local s = 1.3 + w.Tier * 0.07
	local headY = top - 0.35
	local main = add(b, "AxeSocket", Vector3.new(0.42, 0.75 * s, 0.5), CFrame.new(0, headY, 0), w.Accent, M.Metal)
	local head = d.Head or "Hatchet"
	local edgeZ = -(0.25 + 0.85 * s)

	local function bit(side: number, height: number, depth: number, yOffset: number)
		local z = side * (0.25 + depth / 2)
		local blade = add(b, "AxeBlade", Vector3.new(0.16, height, depth), CFrame.new(0, headY + yOffset, z), w.Color, w.Material)
		add(b, "AxeEdge", Vector3.new(0.18, height * 1.08, 0.14), CFrame.new(0, headY + yOffset, side * (0.25 + depth)), if d.Glow then d.Glow else w.Color:Lerp(rgb(255, 255, 255), 0.4), if d.Glow then M.Neon else M.Metal)
		return blade
	end

	if head == "Bearded" then
		main = bit(-1, 0.75 * s, 0.75 * s, 0.1 * s)
		add(b, "Beard", Vector3.new(0.16, 0.7 * s, 0.45 * s), CFrame.new(0, headY - 0.45 * s, -(0.25 + 0.6 * s)) * CFrame.Angles(math.rad(-20), 0, 0), w.Color, w.Material)
	elseif head == "Double" then
		main = bit(-1, 1.05 * s, 0.8 * s, 0)
		bit(1, 1.05 * s, 0.8 * s, 0)
		edgeZ = -(0.25 + 0.8 * s)
	elseif head == "Crescent" then
		main = bit(-1, 0.6 * s, 0.6 * s, 0)
		curve(b, "Crescent", Vector3.new(0, headY - 0.75 * s, -(0.3 + 0.4 * s)), Vector3.new(0, 0, -1), 30, 30, 5, 0.42 * s, Vector2.new(0.16, 0.22), w.Color, w.Material, d.Glow)
	elseif head == "Jagged" then
		main = bit(-1, 0.95 * s, 0.85 * s, 0)
		for i = -2, 2 do
			add(b, "Tooth", Vector3.new(0.16, 0.22, 0.22), CFrame.new(0, headY + i * 0.18 * s, edgeZ - 0.12) * CFrame.Angles(math.rad(45), 0, 0), w.Color, w.Material)
		end
	elseif head == "Demon" then
		main = bit(-1, 1.15 * s, 0.85 * s, 0)
		bit(1, 0.8 * s, 0.55 * s, 0)
		for _, side in { -1, 1 } do
			curve(b, "DemonHorn", Vector3.new(side * 0.15, headY + 0.35 * s, 0), Vector3.new(side, 0, 0), 40, 25, 4, 0.3 * s, Vector2.new(0.14, 0.14), rgb(30, 25, 30), M.Slate, d.Glow)
		end
		add(b, "DemonEye", Vector3.new(0.45, 0.22, 0.22), CFrame.new(0, headY, 0) * CFrame.Angles(math.rad(45), 0, 0), d.Glow or w.Accent, M.Neon)
	else -- Hatchet
		main = bit(-1, 0.7 * s, 0.7 * s, 0)
	end
	add(b, "TopSpike", Vector3.new(0.18, 0.45 * s, 0.18), CFrame.new(0, headY + 0.55 * s, 0) * CFrame.Angles(0, math.rad(45), 0), w.Accent, M.Metal)
	if d.Runes then
		for i = -1, 1 do
			add(b, "Rune", Vector3.new(0.2, 0.12, 0.12), CFrame.new(0, headY + i * 0.25 * s, -(0.25 + 0.35 * s)) * CFrame.Angles(math.rad(45), 0, 0), d.Runes, M.Neon)
		end
	end
	finish(b, main, Vector3.new(0, top * 0.55, 0), Vector3.new(0, headY, edgeZ))
end

-- Greatswords (Paladin) --------------------------------------------------------------------

local function buildGreatsword(b: Builder)
	local w, d = b.Weapon, b.Weapon.Design
	local length = 4.2 + w.Tier * 0.25
	local width, thickness = 0.8, 0.26
	if d.Blade == "Long" then
		length *= 1.1
		width = 0.7
	elseif d.Blade == "Broad" then
		width = 1.05
		thickness = 0.3
	end
	for i = 0, 4 do
		add(b, "GripWrap", Vector3.new(0.36, 0.08, 0.36), CFrame.new(0, -0.55 + i * 0.32, 0) * CFrame.Angles(math.rad(20), 0, 0), w.Accent, M.Fabric)
	end
	guard(b, d.Guard or "Cross", 1.2, width * 0.9)
	-- Ricasso: a short unsharpened block above the guard, like a real zweihander
	add(b, "Ricasso", Vector3.new(thickness + 0.04, 0.45, width * 0.6), CFrame.new(0, 1.55, 0), w.Accent, M.Metal)
	pommel(b, d.Pommel or "Ball", -1.05)
	local main, tipY = blade(b, d.Blade or "Straight", 1.75, length, width, thickness)
	finish(b, main, Vector3.new(0, 2.2, 0), Vector3.new(0, tipY, 0))
end

-- Katanas (Ronin) --------------------------------------------------------------------------
-- A gently curved, single-edged blade (edge toward -Z) with a round guard (tsuba).

local function buildKatana(b: Builder)
	local w, d = b.Weapon, b.Weapon.Design
	local length = 3.6 + w.Tier * 0.15
	local width, thickness = 0.36, 0.12
	-- Diamond-pattern wrap (tsuka-ito)
	for i = 0, 5 do
		add(b, "Tsuka", Vector3.new(0.3, 0.12, 0.3), CFrame.new(0, -0.55 + i * 0.22, 0) * CFrame.Angles(0, math.rad(45), math.rad(if i % 2 == 0 then 25 else -25)), w.Accent, M.Fabric)
	end
	add(b, "Kashira", Vector3.new(0.32, 0.18, 0.32), CFrame.new(0, -0.7, 0), rgb(40, 35, 30), M.Metal)
	local tsubaY = 0.75
	local tsuba = d.Tsuba or "Round"
	if tsuba == "Square" then
		add(b, "Tsuba", Vector3.new(0.75, 0.1, 0.75), CFrame.new(0, tsubaY, 0), rgb(40, 35, 30), M.Metal)
	else
		cylinder(b, "Tsuba", 0.85, 0.1, Vector3.new(0, tsubaY, 0), rgb(40, 35, 30), M.Metal)
		if tsuba == "Flower" then
			for i = 0, 3 do
				local angle = i / 4 * math.pi * 2 + math.pi / 4
				ball(b, "TsubaPetal", 0.3, Vector3.new(math.cos(angle) * 0.38, tsubaY, math.sin(angle) * 0.38), w.Design.Glow or rgb(200, 170, 90), M.Metal)
			end
		end
	end
	add(b, "Habaki", Vector3.new(thickness + 0.06, 0.18, width + 0.04), CFrame.new(0, tsubaY + 0.14, 0), rgb(200, 170, 90), M.Metal)
	local segments = 6
	local segmentLength = length / segments
	local position = Vector3.new(0, tsubaY + 0.2, 0)
	local angle = 0
	local main: BasePart
	for i = 1, segments do
		angle = math.rad(i * 2.2) -- curves back toward the spine
		local direction = CFrame.Angles(angle, 0, 0) * Vector3.yAxis
		local center = position + direction * segmentLength / 2
		local seg = add(b, "Blade", Vector3.new(thickness, segmentLength * 1.08, width), CFrame.new(center) * CFrame.Angles(angle, 0, 0), w.Color, w.Material)
		main = main or seg
		if d.Hamon then
			add(b, "Hamon", Vector3.new(thickness + 0.02, segmentLength * 1.05, 0.06), CFrame.new(center) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 0, -width * 0.3), d.Hamon, M.Neon)
		end
		position += direction * segmentLength
	end
	-- Kissaki (tip), slanted toward the edge
	add(b, "Kissaki", Vector3.new(thickness, width * 1.1, width * 0.7), CFrame.new(position) * CFrame.Angles(angle - math.rad(40), 0, 0) * CFrame.new(0, width * 0.2, -width * 0.05), w.Color, w.Material)
	finish(b, main, Vector3.new(0, tsubaY + 0.5, 0), position)
end

-- Polearms: scythes, spears, halberds --------------------------------------------------------
-- The Handle is the whole shaft (like a staff).

local function shaft(b: Builder, length: number, twisted: boolean?)
	local w = b.Weapon
	if twisted then
		for i = 0, 9 do
			add(b, "Twist", Vector3.new(0.36, 0.12, 0.2), CFrame.new(0, -length / 2 + 0.4 + i * (length - 0.8) / 9, 0) * CFrame.Angles(0, i * 0.8, math.rad(30)), w.Color:Lerp(w.Accent, 0.5), w.Material)
		end
	end
	for _, y in { -length / 2 + 0.1, length / 2 - 0.3 } do
		cylinder(b, "ShaftBand", 0.36, 0.18, Vector3.new(0, y, 0), w.Color, M.Metal)
	end
	if w.Design.Runes then
		for i = 1, 3 do
			cylinder(b, "ShaftRune", 0.34, 0.1, Vector3.new(0, length * (0.1 + i * 0.08), 0), w.Design.Runes, M.Neon)
		end
	end
end

local function buildScythe(b: Builder, length: number)
	local w, d = b.Weapon, b.Weapon.Design
	shaft(b, length, d.Shaft == "Twisted")
	local top = length / 2
	local kind = d.Blade or "Reaper"
	local s = 1.15 + w.Tier * 0.05
	local bladeLength = (if kind == "Farm" then 2.2 elseif kind == "Moon" then 3.2 else 2.8) * s
	local segments = 6
	local bend = if kind == "Moon" then -22 elseif kind == "Farm" then -10 else -15
	local start = Vector3.new(0, top - 0.25, -0.1)
	add(b, "BladeMount", Vector3.new(0.3, 0.45, 0.45), CFrame.new(0, top - 0.25, 0), w.Accent:Lerp(rgb(30, 30, 30), 0.3), M.Metal)
	local function scytheBlade(from: Vector3, outward: Vector3, color: Color3, material: Enum.Material, transparency: number)
		local before = #b.Tool:GetChildren()
		curve(b, "ScytheBlade", from, outward, 15, bend, segments, bladeLength / segments, Vector2.new(0.12, 0.5 * s), color, material)
		if d.Glow then
			curve(b, "ScytheEdge", from - Vector3.new(0, 0.25 * s, 0), outward, 15, bend, segments, bladeLength / segments, Vector2.new(0.14, 0.07), d.Glow, M.Neon)
		end
		local children = b.Tool:GetChildren()
		for i = before + 1, #children do
			local part = children[i]
			if part:IsA("BasePart") and part.Name == "ScytheBlade" then
				part.Transparency = transparency
			end
		end
	end
	local material = if kind == "Bone" then M.Marble else w.Material
	scytheBlade(start, Vector3.new(0, 0, -1), w.Color, material, if kind == "Spectral" then 0.35 else 0)
	if kind == "Twin" then
		scytheBlade(Vector3.new(0, top - 0.25, 0.1), Vector3.new(0, 0, 1), w.Color, material, 0)
	end
	if kind == "Bone" then
		for i = 1, 4 do
			add(b, "BoneSpur", Vector3.new(0.12, 0.35, 0.12), CFrame.new(0, top + 0.05 + i * 0.05, -0.4 * i) * CFrame.Angles(math.rad(-30), 0, 0), w.Color, M.Marble)
		end
	end
	-- Ornament at the top of the shaft
	local ornament = d.Ornament
	local main: BasePart = b.Handle
	if ornament == "Skull" then
		main = ball(b, "Skull", 0.6, Vector3.new(0, top + 0.25, 0.15), rgb(230, 225, 205), M.SmoothPlastic)
		for _, side in { -1, 1 } do
			add(b, "SkullEye", Vector3.new(0.12, 0.12, 0.1), CFrame.new(side * 0.12, top + 0.3, -0.1), d.Glow or rgb(255, 60, 60), M.Neon)
		end
	elseif ornament == "Lantern" then
		add(b, "LanternChain", Vector3.new(0.06, 0.6, 0.06), CFrame.new(0, top - 0.7, 0.3), rgb(60, 60, 65), M.Metal)
		main = add(b, "Lantern", Vector3.new(0.3, 0.4, 0.3), CFrame.new(0, top - 1.15, 0.3), d.Glow or rgb(255, 200, 100), M.Neon)
	elseif ornament == "Gem" then
		main = add(b, "Gem", Vector3.one * 0.35, CFrame.new(0, top + 0.15, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), d.Glow or w.Accent, M.Neon)
	end
	finish(b, main, Vector3.new(0, top - 0.3, -0.4), Vector3.new(0, top - 0.3 - bladeLength * 0.45, -bladeLength * 0.75))
end

local function spearhead(b: Builder, kind: string, y: number, s: number): (BasePart, number)
	local w, d = b.Weapon, b.Weapon.Design
	local glow = d.Glow
	local main: BasePart
	local tip = y
	if kind == "Pike" then
		main = add(b, "Spearhead", Vector3.new(0.18, 1.1 * s, 0.22), CFrame.new(0, y + 0.55 * s, 0), w.Color, w.Material)
		add(b, "SpearTip", Vector3.new(0.17, 0.2, 0.2), CFrame.new(0, y + 1.1 * s, 0) * CFrame.Angles(math.rad(45), 0, 0), w.Color, w.Material)
		tip = y + 1.2 * s
	elseif kind == "Trident" then
		add(b, "TridentBar", Vector3.new(0.18, 0.18, 1.1 * s), CFrame.new(0, y + 0.1, 0), w.Accent, M.Metal)
		for _, z in { -0.5 * s, 0, 0.5 * s } do
			local height = if z == 0 then 1.2 * s else 0.85 * s
			local prong = add(b, "Prong", Vector3.new(0.14, height, 0.14), CFrame.new(0, y + 0.1 + height / 2, z), w.Color, w.Material)
			main = main or prong
			add(b, "ProngTip", Vector3.new(0.13, 0.22, 0.22), CFrame.new(0, y + 0.1 + height, z) * CFrame.Angles(math.rad(45), 0, 0), w.Color, w.Material)
		end
		tip = y + 1.3 * s
	elseif kind == "Crystal" then
		main = add(b, "Spearhead", Vector3.new(0.3, 1.4 * s, 0.3), CFrame.new(0, y + 0.7 * s, 0) * CFrame.Angles(0, math.rad(45), 0), glow or w.Color, M.Neon)
		main.Transparency = 0.15
		for _, z in { -1, 1 } do
			add(b, "Shard", Vector3.new(0.16, 0.6 * s, 0.16), CFrame.new(0, y + 0.3 * s, z * 0.2) * CFrame.Angles(math.rad(z * 25), 0, 0), w.Color, M.Glass).Transparency = 0.2
		end
		tip = y + 1.5 * s
	else -- Leaf, Winged, Dragon
		main = add(b, "Spearhead", Vector3.new(0.14, 1.1 * s, 0.42 * s), CFrame.new(0, y + 0.6 * s, 0), w.Color, w.Material)
		add(b, "SpearTip", Vector3.new(0.13, 0.42 * s, 0.42 * s), CFrame.new(0, y + 1.15 * s, 0) * CFrame.Angles(math.rad(45), 0, 0), w.Color, w.Material)
		add(b, "SpearBase", Vector3.new(0.13, 0.3 * s, 0.3 * s), CFrame.new(0, y + 0.08, 0) * CFrame.Angles(math.rad(45), 0, 0), w.Color, w.Material)
		if glow then
			add(b, "SpearEdge", Vector3.new(0.16, 1 * s, 0.06), CFrame.new(0, y + 0.6 * s, 0), glow, M.Neon)
		end
		if kind == "Winged" then
			for _, side in { -1, 1 } do
				add(b, "Lug", Vector3.new(0.12, 0.18, 0.45), CFrame.new(0, y - 0.05, side * 0.32) * CFrame.Angles(math.rad(side * 30), 0, 0), w.Color, w.Material)
			end
		elseif kind == "Dragon" then
			for _, side in { -1, 1 } do
				curve(b, "DragonHorn", Vector3.new(0, y + 0.05, side * 0.18), Vector3.new(0, 0, side), -20, 30, 4, 0.28 * s, Vector2.new(0.12, 0.14), w.Accent, M.Metal, glow)
			end
			ball(b, "DragonEye", 0.24, Vector3.new(0, y + 0.05, 0), glow or w.Accent, M.Neon)
		end
		tip = y + 1.4 * s
	end
	return main, tip
end

local function tassel(b: Builder, y: number, color: Color3)
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		add(b, "Tassel", Vector3.new(0.08, 0.6, 0.08), CFrame.new(math.cos(angle) * 0.12, y - 0.35, math.sin(angle) * 0.12) * CFrame.Angles(math.rad(math.cos(angle) * 8), 0, math.rad(math.sin(angle) * 8)), color, M.Fabric)
	end
	cylinder(b, "TasselRing", 0.38, 0.12, Vector3.new(0, y, 0), color, M.Fabric)
end

local function buildSpear(b: Builder, length: number)
	local w, d = b.Weapon, b.Weapon.Design
	shaft(b, length, false)
	local top = length / 2
	add(b, "ButtSpike", Vector3.new(0.2, 0.4, 0.2), CFrame.new(0, -top - 0.15, 0) * CFrame.Angles(0, math.rad(45), 0), w.Color, M.Metal)
	local main, tipY = spearhead(b, d.Head or "Leaf", top, 1.35 + w.Tier * 0.06)
	if d.Tassel then
		tassel(b, top - 0.2, d.Tassel)
	end
	finish(b, main, Vector3.new(0, top - 1, 0), Vector3.new(0, tipY, 0))
end

local function buildHalberd(b: Builder, length: number)
	local w, d = b.Weapon, b.Weapon.Design
	shaft(b, length, false)
	local top = length / 2
	local s = 1.35 + w.Tier * 0.06
	add(b, "ButtCap", Vector3.new(0.34, 0.3, 0.34), CFrame.new(0, -top - 0.1, 0), w.Accent, M.Metal)
	-- Spike on top
	local _, tipY = spearhead(b, "Leaf", top + 0.2, s * 0.9)
	-- Axe blade forward (-Z), hook/spike back (+Z)
	local bladeY = top - 0.2
	local main: BasePart
	if d.Head == "Crescent" then
		main = add(b, "HalberdBlade", Vector3.new(0.14, 0.9 * s, 0.6 * s), CFrame.new(0, bladeY, -0.45 * s), w.Color, w.Material)
		curve(b, "HalberdCrescent", Vector3.new(0, bladeY - 0.9 * s, -0.35 * s), Vector3.new(0, 0, -1), 35, 28, 5, 0.42 * s, Vector2.new(0.14, 0.22), w.Color, w.Material, d.Glow)
	else
		main = add(b, "HalberdBlade", Vector3.new(0.14, 1.3 * s, 0.9 * s), CFrame.new(0, bladeY, -0.6 * s), w.Color, w.Material)
		add(b, "HalberdEdge", Vector3.new(0.16, 1.38 * s, 0.12), CFrame.new(0, bladeY, -1.05 * s), d.Glow or w.Color:Lerp(rgb(255, 255, 255), 0.4), if d.Glow then M.Neon else M.Metal)
	end
	add(b, "BackSpike", Vector3.new(0.14, 0.24, 0.8 * s), CFrame.new(0, bladeY + 0.1, 0.5 * s) * CFrame.Angles(math.rad(-12), 0, 0), w.Color, w.Material)
	add(b, "Langet", Vector3.new(0.34, 1, 0.34), CFrame.new(0, top - 0.7, 0), w.Accent, M.Metal)
	if d.Wings then
		for _, side in { -1, 1 } do
			for i = 0, 3 do
				local feather = add(b, "Feather", Vector3.new(0.5 - i * 0.06, 0.12, 0.9 - i * 0.12), CFrame.new(side * (0.35 + i * 0.22), top - 0.9 + i * 0.25, 0.25) * CFrame.Angles(0, 0, math.rad(side * (30 + i * 12))), rgb(255, 255, 255), M.SmoothPlastic)
				feather.Transparency = 0.05
			end
		end
	end
	if d.Halo then
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			add(b, "Halo", Vector3.new(0.12, 0.08, 0.32), CFrame.new(0, top + 1.6 * s, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0.55, 0, 0), d.Glow or rgb(255, 230, 140), M.Neon)
		end
	end
	if d.Tassel then
		tassel(b, top - 1.3, d.Tassel)
	end
	finish(b, main, Vector3.new(0, top - 1.2, 0), Vector3.new(0, tipY, 0))
end

-- Public ----------------------------------------------------------------------------------

function WeaponModels.Build(weapon: Items.WeaponDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.DisplayName
	tool.CanBeDropped = false
	tool.ToolTip = `{weapon.Rarity} {weapon.Type} - {weapon.Damage} damage - [R] {weapon.Skill.Name}`
	tool:SetAttribute(WeaponModels.ToolAttribute, weapon.Id)

	local handle: Part
	local t = weapon.Type
	if t == "Staff" then
		local length = 5 + weapon.Tier * 0.15
		handle = newPart(tool, "Handle", Vector3.new(0.3, length, 0.3), weapon.Color, weapon.Material)
		tool.Grip = CFrame.new(0, -length / 6, 0) * CFrame.Angles(STAFF_TILT, 0, 0)
		buildStaff({ Tool = tool, Handle = handle, Weapon = weapon }, length)
	elseif t == "Bow" then
		handle = newPart(tool, "Handle", Vector3.new(0.3, 1.2, 0.4), weapon.Color, weapon.Material)
		tool.Grip = CFrame.new()
		buildBow({ Tool = tool, Handle = handle, Weapon = weapon })
	elseif t == "Tome" then
		handle = newPart(tool, "Handle", Vector3.new(1.4, 0.25, 1.1), weapon.Color, weapon.Material)
		-- Lying in the palm, tilted up toward your face
		tool.Grip = CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-30), 0, 0)
		buildTome({ Tool = tool, Handle = handle, Weapon = weapon })
	elseif t == "Axe" then
		handle = newPart(tool, "Handle", Vector3.new(0.32, 1, 0.32), LEATHER, M.Leather)
		tool.Grip = CFrame.Angles(SWORD_TILT, 0, 0)
		buildAxe({ Tool = tool, Handle = handle, Weapon = weapon })
	elseif t == "Greatsword" then
		handle = newPart(tool, "Handle", Vector3.new(0.32, 1.6, 0.32), LEATHER, M.Leather)
		tool.Grip = CFrame.new(0, 0.35, 0) * CFrame.Angles(SWORD_TILT, 0, 0)
		buildGreatsword({ Tool = tool, Handle = handle, Weapon = weapon })
	elseif t == "Katana" then
		handle = newPart(tool, "Handle", Vector3.new(0.28, 1.3, 0.28), weapon.Accent, M.Fabric)
		tool.Grip = CFrame.new(0, 0.2, 0) * CFrame.Angles(SWORD_TILT, 0, 0)
		buildKatana({ Tool = tool, Handle = handle, Weapon = weapon })
	elseif t == "Scythe" or t == "Spear" or t == "Halberd" then
		local length = (if t == "Scythe" then 6 elseif t == "Spear" then 6.5 else 7) + weapon.Tier * 0.12
		local shaftColor = if t == "Scythe" then weapon.Accent:Lerp(rgb(35, 28, 24), 0.65) else rgb(90, 62, 40)
		if t == "Halberd" then
			shaftColor = weapon.Accent
		end
		handle = newPart(tool, "Handle", Vector3.new(0.28, length, 0.28), shaftColor, if t == "Halberd" then M.Metal else M.Wood)
		local b = { Tool = tool, Handle = handle, Weapon = weapon }
		if t == "Spear" then
			-- Held level and pointing forward, ready to thrust
			tool.Grip = CFrame.new(0, -length * 0.2, 0) * CFrame.Angles(math.rad(80), 0, 0)
			buildSpear(b, length)
		elseif t == "Scythe" then
			tool.Grip = CFrame.new(0, -length * 0.12, 0) * CFrame.Angles(math.rad(18), 0, 0)
			buildScythe(b, length)
		else
			tool.Grip = CFrame.new(0, -length * 0.15, 0) * CFrame.Angles(math.rad(14), 0, 0)
			buildHalberd(b, length)
		end
	elseif t == "Mace" then
		local length = 2.6 + weapon.Tier * 0.12
		handle = newPart(tool, "Handle", Vector3.new(0.32, 1, 0.32), LEATHER, M.Leather)
		tool.Grip = CFrame.Angles(SWORD_TILT, 0, 0)
		buildMace({ Tool = tool, Handle = handle, Weapon = weapon }, length)
	else -- Sword, Dagger
		local isDagger = t == "Dagger"
		handle = newPart(tool, "Handle", if isDagger then Vector3.new(0.25, 0.8, 0.25) else Vector3.new(0.3, 1.1, 0.3), LEATHER, M.Leather)
		tool.Grip = CFrame.Angles(SWORD_TILT, 0, 0)
		local b = { Tool = tool, Handle = handle, Weapon = weapon }
		if weapon.Model == "Voidlight" then
			buildVoidlight(b)
		elseif isDagger then
			buildDagger(b)
		else
			buildSword(b)
		end
	end
	handle.CanCollide = false
	handle.Massless = true
	return tool
end

return WeaponModels
