--!strict
-- Builds a creature's model from its species' Appearance config: a body shape, eyes and
-- a set of named features (leaf sprout, ember tail, crystal spikes, ...). Every part is
-- welded to an anchored "Root", so moving Root.CFrame moves the whole creature in one
-- write. Parts never collide, never block raycasts and cast no shadow (cheap to render).
--
-- To use hand-made art instead, put a Model named after the species in
-- ReplicatedStorage/Assets/Creatures with a PrimaryPart "Root"; it is used automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MutationConfig = require(Shared.Config.MutationConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local AssetConfig = require(Shared.Config.AssetConfig)
local Types = require(Shared.Types)

local CreatureModels = {}

type Ctx = {
	Model: Model,
	Root: BasePart,
	S: number, -- body size (studs)
	Look: Types.AppearanceDef,
	HeadCF: CFrame, -- centre of the head, relative to Root
	HeadSize: number,
}

local function weld(root: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function add(ctx: Ctx, props: { [string]: any }, offset: CFrame): BasePart
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.CFrame = ctx.Root.CFrame * offset
	part.Parent = ctx.Model
	weld(ctx.Root, part)
	return part
end

local function ball(ctx: Ctx, diameter: number, offset: CFrame, color: Color3, material: Enum.Material?): BasePart
	return add(ctx, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, offset)
end

local function block(ctx: Ctx, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): BasePart
	return add(ctx, { Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic }, offset)
end

local function wedge(ctx: Ctx, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): BasePart
	local part = Instance.new("WedgePart")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CFrame = ctx.Root.CFrame * offset
	part.Parent = ctx.Model
	weld(ctx.Root, part)
	return part
end

local function cylinder(
	ctx: Ctx,
	length: number,
	diameter: number,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return add(ctx, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, offset)
end

-- Body shapes. Each sets ctx.HeadCF / HeadSize (where eyes and head features go).
-- Forward is -Z; Root sits at the centre of the body.
local bodies: { [string]: (Ctx) -> () } = {}

bodies.Round = function(ctx)
	local s = ctx.S
	ball(ctx, s, CFrame.new(), ctx.Look.Primary)
	-- Lighter belly
	ball(ctx, s * 0.7, CFrame.new(0, -s * 0.1, -s * 0.18), ctx.Look.Secondary)
	ctx.HeadCF = CFrame.new(0, s * 0.12, 0)
	ctx.HeadSize = s
end

bodies.Pear = function(ctx)
	local s = ctx.S
	ball(ctx, s * 0.95, CFrame.new(0, -s * 0.12, 0), ctx.Look.Primary)
	ball(ctx, s * 0.62, CFrame.new(0, -s * 0.18, -s * 0.2), ctx.Look.Secondary)
	local head = s * 0.72
	ball(ctx, head, CFrame.new(0, s * 0.42, -s * 0.08), ctx.Look.Primary)
	ctx.HeadCF = CFrame.new(0, s * 0.42, -s * 0.08)
	ctx.HeadSize = head
end

bodies.Block = function(ctx)
	local s = ctx.S
	block(ctx, Vector3.new(s, s * 0.8, s * 0.95), CFrame.new(0, -s * 0.05, 0), ctx.Look.Primary)
	ball(ctx, s * 0.55, CFrame.new(0, s * 0.3, 0), ctx.Look.Primary) -- rounded top
	block(ctx, Vector3.new(s * 0.7, s * 0.4, 0.1), CFrame.new(0, -s * 0.12, -s * 0.48), ctx.Look.Secondary)
	ctx.HeadCF = CFrame.new(0, s * 0.12, 0)
	ctx.HeadSize = s * 0.95
end

bodies.Long = function(ctx)
	local s = ctx.S
	cylinder(ctx, s * 1.1, s * 0.7, CFrame.Angles(0, math.rad(90), 0), ctx.Look.Primary)
	ball(ctx, s * 0.7, CFrame.new(0, 0, s * 0.55), ctx.Look.Primary)
	local head = s * 0.68
	ball(ctx, head, CFrame.new(0, s * 0.3, -s * 0.62), ctx.Look.Primary)
	ball(ctx, head * 0.55, CFrame.new(0, s * 0.18, -s * 0.9), ctx.Look.Secondary) -- snout
	ctx.HeadCF = CFrame.new(0, s * 0.3, -s * 0.62)
	ctx.HeadSize = head
end

local function eyes(ctx: Ctx)
	local h = ctx.HeadSize
	local style = ctx.Look.Eyes
	local size = h * (if style == "Bright" then 0.2 else 0.17)
	for _, side in { -1, 1 } do
		local offset = ctx.HeadCF * CFrame.new(side * h * 0.2, h * 0.08, -h * 0.44)
		if style == "Sleepy" then
			block(ctx, Vector3.new(size * 1.1, size * 0.3, size * 0.4), offset, Color3.fromRGB(25, 20, 30))
		else
			ball(ctx, size, offset, Color3.fromRGB(25, 20, 30))
			ball(
				ctx,
				size * 0.35,
				offset * CFrame.new(size * 0.15, size * 0.18, -size * 0.35),
				Color3.new(1, 1, 1),
				Enum.Material.Neon
			)
		end
	end
end

-- Features. Unknown names are skipped, so new species can list art that does not exist yet.
local features: { [string]: (Ctx) -> () } = {}

features.Cheeks = function(ctx)
	local h = ctx.HeadSize
	for _, side in { -1, 1 } do
		ball(
			ctx,
			h * 0.14,
			ctx.HeadCF * CFrame.new(side * h * 0.32, -h * 0.06, -h * 0.36),
			Color3.fromRGB(255, 150, 160)
		)
	end
end

features.Stubs = function(ctx)
	local s = ctx.S
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			ball(
				ctx,
				s * 0.24,
				CFrame.new(x * s * 0.25, -s * 0.46, z * s * 0.2),
				ctx.Look.Primary:Lerp(Color3.new(0, 0, 0), 0.15)
			)
		end
	end
end

features.Legs = function(ctx)
	local s = ctx.S
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			cylinder(
				ctx,
				s * 0.5,
				s * 0.16,
				CFrame.new(x * s * 0.25, -s * 0.48, z * s * 0.35) * CFrame.Angles(0, 0, math.rad(90)),
				ctx.Look.Secondary
			)
		end
	end
end

features.LeafSprout = function(ctx)
	local h = ctx.HeadSize
	local top = ctx.HeadCF * CFrame.new(0, h * 0.48, 0)
	cylinder(
		ctx,
		h * 0.35,
		h * 0.07,
		top * CFrame.new(0, h * 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(70, 140, 60)
	)
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			Vector3.new(h * 0.06, h * 0.22, h * 0.45),
			top * CFrame.new(side * h * 0.2, h * 0.35, 0) * CFrame.Angles(0, math.rad(90 * side), math.rad(-60 * side)),
			Color3.fromRGB(110, 220, 90),
			Enum.Material.Grass
		)
	end
end

features.LeafCrown = function(ctx)
	local h = ctx.HeadSize
	for i = 0, 4 do
		local a = math.rad(i * 72)
		ball(
			ctx,
			h * 0.3,
			ctx.HeadCF * CFrame.new(math.cos(a) * h * 0.3, h * 0.5, math.sin(a) * h * 0.3),
			ctx.Look.Secondary,
			Enum.Material.Grass
		)
	end
end

features.Moss = function(ctx)
	local s = ctx.S
	for i = 0, 3 do
		local a = math.rad(i * 90 + 20)
		ball(
			ctx,
			s * 0.35,
			CFrame.new(math.cos(a) * s * 0.25, s * 0.42, math.sin(a) * s * 0.25),
			Color3.fromRGB(90, 160, 70),
			Enum.Material.Grass
		)
	end
end

features.PointedEars = function(ctx)
	local h = ctx.HeadSize
	for _, side in { -1, 1 } do
		local ear = ctx.HeadCF * CFrame.new(side * h * 0.28, h * 0.48, 0) * CFrame.Angles(0, 0, math.rad(-18 * side))
		wedge(
			ctx,
			Vector3.new(h * 0.12, h * 0.38, h * 0.28),
			ear * CFrame.Angles(0, math.rad(180), 0),
			ctx.Look.Primary
		)
		wedge(
			ctx,
			Vector3.new(h * 0.06, h * 0.24, h * 0.16),
			ear * CFrame.new(0, -h * 0.03, -h * 0.05) * CFrame.Angles(0, math.rad(180), 0),
			ctx.Look.Secondary
		)
	end
end

local function flame(ctx: Ctx, offset: CFrame, size: number)
	local core = ball(ctx, size, offset, ctx.Look.Glow or Color3.fromRGB(255, 160, 60), Enum.Material.Neon)
	core.Name = "Flame"
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = AssetConfig.Particles.Fire
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new(size * 0.7, 0)
	fire.Lifetime = NumberRange.new(0.3, 0.55)
	fire.Speed = NumberRange.new(1.5, 2.5)
	fire.Rate = 14
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.Transparency = NumberSequence.new(0.2, 1)
	fire.Name = "FeatureParticles"
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 6
	light.Brightness = 0.8
	light.Parent = core
end

features.EmberTail = function(ctx)
	local s = ctx.S
	cylinder(
		ctx,
		s * 0.5,
		s * 0.16,
		CFrame.new(0, -s * 0.05, s * 0.5) * CFrame.Angles(0, math.rad(90), math.rad(35)),
		ctx.Look.Primary
	)
	flame(ctx, CFrame.new(0, s * 0.18, s * 0.72), s * 0.32)
end

features.FlameTuft = function(ctx)
	flame(ctx, ctx.HeadCF * CFrame.new(0, ctx.HeadSize * 0.5, 0), ctx.HeadSize * 0.35)
end

features.LavaCracks = function(ctx)
	local s = ctx.S
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		block(
			ctx,
			Vector3.new(s * 0.05, s * 0.5, s * 0.05),
			CFrame.new(math.cos(a) * s * 0.5, 0, math.sin(a) * s * 0.48) * CFrame.Angles(0, -a, 0.3),
			ctx.Look.Secondary,
			Enum.Material.Neon
		)
	end
end

features.CrystalSpikes = function(ctx)
	local s = ctx.S
	local color = ctx.Look.Secondary
	for i, spike in
		{ { 0, 0.5, 0.1, 0.55 }, { -0.25, 0.4, 0.2, 0.42 }, { 0.25, 0.4, 0.2, 0.42 }, { 0, 0.35, 0.38, 0.36 } }
	do
		local part = block(
			ctx,
			Vector3.new(s * 0.18, s * spike[4], s * 0.18),
			CFrame.new(s * spike[1], s * spike[2], s * spike[3])
				* CFrame.Angles(math.rad(20), math.rad(45), math.rad(spike[1] * 60)),
			color,
			if i == 1 then Enum.Material.Neon else Enum.Material.Glass
		)
		part.Transparency = if i == 1 then 0.1 else 0.15
	end
end

features.CrystalBack = function(ctx)
	local s = ctx.S
	for i = -1, 1 do
		local part = block(
			ctx,
			Vector3.new(s * 0.3, s * 0.3, s * 0.3),
			CFrame.new(i * s * 0.25, s * 0.42, s * 0.1) * CFrame.Angles(0.5, 0.7, 0),
			ctx.Look.Secondary,
			Enum.Material.Glass
		)
		part.Transparency = 0.2
	end
end

features.GemCore = function(ctx)
	local s = ctx.S
	ball(ctx, s * 0.32, CFrame.new(0, 0, -s * 0.42), ctx.Look.Secondary, Enum.Material.Neon)
end

features.Wings = function(ctx)
	local s = ctx.S
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			Vector3.new(s * 0.06, s * 0.5, s * 0.8),
			CFrame.new(side * s * 0.5, s * 0.1, s * 0.1) * CFrame.Angles(0, 0, math.rad(-30 * side)),
			ctx.Look.Secondary
		)
	end
end

features.MothWings = features.Wings

features.BoltEars = function(ctx)
	local h = ctx.HeadSize
	for _, side in { -1, 1 } do
		block(
			ctx,
			Vector3.new(h * 0.1, h * 0.4, h * 0.1),
			ctx.HeadCF * CFrame.new(side * h * 0.3, h * 0.55, 0) * CFrame.Angles(0, 0, math.rad(-25 * side)),
			ctx.Look.Primary,
			Enum.Material.Neon
		)
	end
end

features.ZigTail = function(ctx)
	local s = ctx.S
	for i = 0, 2 do
		block(
			ctx,
			Vector3.new(s * 0.1, s * 0.3, s * 0.1),
			CFrame.new(0, s * (0.05 + i * 0.2), s * (0.5 + i * 0.05))
				* CFrame.Angles(math.rad(if i % 2 == 0 then 30 else -30), 0, 0),
			ctx.Look.Primary,
			Enum.Material.Neon
		)
	end
end

features.CoilHorns = function(ctx)
	local h = ctx.HeadSize
	for _, side in { -1, 1 } do
		cylinder(
			ctx,
			h * 0.45,
			h * 0.12,
			ctx.HeadCF * CFrame.new(side * h * 0.3, h * 0.45, h * 0.05) * CFrame.Angles(0, 0, math.rad(60 * side)),
			ctx.Look.Secondary,
			Enum.Material.Metal
		)
	end
end

features.Antennae = function(ctx)
	local h = ctx.HeadSize
	for _, side in { -1, 1 } do
		cylinder(
			ctx,
			h * 0.5,
			h * 0.05,
			ctx.HeadCF * CFrame.new(side * h * 0.15, h * 0.65, 0) * CFrame.Angles(0, 0, math.rad(80 * side)),
			ctx.Look.Secondary
		)
		ball(ctx, h * 0.12, ctx.HeadCF * CFrame.new(side * h * 0.2, h * 0.9, 0), ctx.Look.Secondary, Enum.Material.Neon)
	end
end

features.Antenna = function(ctx)
	local h = ctx.HeadSize
	cylinder(
		ctx,
		h * 0.5,
		h * 0.06,
		ctx.HeadCF * CFrame.new(0, h * 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		ctx.Look.Secondary,
		Enum.Material.Metal
	)
	ball(ctx, h * 0.15, ctx.HeadCF * CFrame.new(0, h * 0.97, 0), Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
end

features.GearBack = function(ctx)
	local s = ctx.S
	cylinder(
		ctx,
		s * 0.12,
		s * 0.6,
		CFrame.new(0, s * 0.2, s * 0.48) * CFrame.Angles(0, math.rad(90), 0),
		ctx.Look.Secondary,
		Enum.Material.Metal
	)
end

features.VisorEye = function(ctx)
	local h = ctx.HeadSize
	block(
		ctx,
		Vector3.new(h * 0.7, h * 0.15, h * 0.1),
		ctx.HeadCF * CFrame.new(0, h * 0.1, -h * 0.48),
		ctx.Look.Secondary,
		Enum.Material.Neon
	)
end

features.Halo = function(ctx)
	local h = ctx.HeadSize
	cylinder(
		ctx,
		h * 0.05,
		h * 0.7,
		ctx.HeadCF * CFrame.new(0, h * 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 240, 160),
		Enum.Material.Neon
	).Transparency =
		0.3
end

features.Fins = function(ctx)
	local s = ctx.S
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			Vector3.new(s * 0.05, s * 0.3, s * 0.4),
			CFrame.new(side * s * 0.5, 0, 0) * CFrame.Angles(0, 0, math.rad(-50 * side)),
			ctx.Look.Secondary
		)
	end
	wedge(ctx, Vector3.new(s * 0.05, s * 0.35, s * 0.4), CFrame.new(0, s * 0.55, s * 0.05), ctx.Look.Secondary)
end

features.Tentacles = function(ctx)
	local s = ctx.S
	for i = 0, 5 do
		local a = math.rad(i * 60)
		cylinder(
			ctx,
			s * 0.5,
			s * 0.12,
			CFrame.new(math.cos(a) * s * 0.25, -s * 0.55, math.sin(a) * s * 0.25) * CFrame.Angles(0, 0, math.rad(90)),
			ctx.Look.Primary
		)
	end
end

features.BubbleShell = function(ctx)
	local s = ctx.S
	local shell = ball(ctx, s * 1.35, CFrame.new(), ctx.Look.Secondary, Enum.Material.Glass)
	shell.Transparency = 0.75
end

features.ShadowWisps = function(ctx)
	local s = ctx.S
	for i = 0, 2 do
		local wisp = ball(
			ctx,
			s * 0.25,
			CFrame.new((i - 1) * s * 0.3, s * 0.1, s * 0.55),
			ctx.Look.Secondary,
			Enum.Material.Neon
		)
		wisp.Transparency = 0.4
	end
end

features.OrbitRunes = function(ctx)
	local s = ctx.S
	for i = 0, 2 do
		local a = math.rad(i * 120)
		ball(
			ctx,
			s * 0.18,
			CFrame.new(math.cos(a) * s * 0.75, s * 0.2, math.sin(a) * s * 0.75),
			ctx.Look.Secondary,
			Enum.Material.Neon
		)
	end
end

features.FlowerAntlers = function(ctx)
	local h = ctx.HeadSize
	for _, side in { -1, 1 } do
		cylinder(
			ctx,
			h * 0.6,
			h * 0.08,
			ctx.HeadCF * CFrame.new(side * h * 0.3, h * 0.7, 0) * CFrame.Angles(0, 0, math.rad(70 * side)),
			Color3.fromRGB(150, 110, 80)
		)
		ball(ctx, h * 0.25, ctx.HeadCF * CFrame.new(side * h * 0.45, h * 0.95, 0), ctx.Look.Secondary)
	end
end

features.BarkPlates = function(ctx)
	local s = ctx.S
	for i = 0, 3 do
		local a = math.rad(i * 90)
		block(
			ctx,
			Vector3.new(s * 0.5, s * 0.6, s * 0.1),
			CFrame.new(math.cos(a) * s * 0.5, 0, math.sin(a) * s * 0.5) * CFrame.Angles(0, -a + math.rad(90), 0),
			ctx.Look.Primary:Lerp(Color3.new(0, 0, 0), 0.25),
			Enum.Material.Wood
		)
	end
end

features.FlowerCrown = function(ctx)
	local h = ctx.HeadSize
	for i = 0, 5 do
		local a = math.rad(i * 60)
		ball(
			ctx,
			h * 0.18,
			ctx.HeadCF * CFrame.new(math.cos(a) * h * 0.32, h * 0.42, math.sin(a) * h * 0.32),
			Color3.fromRGB(255, 190, 220)
		)
	end
	ball(ctx, h * 0.16, ctx.HeadCF * CFrame.new(0, h * 0.5, 0), Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
end

-- Evolved creatures shimmer: a slow ring of sparkles in the family colour.
features.Aura = function(ctx)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraAttachment"
	attachment.Parent = ctx.Root
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Texture = AssetConfig.Particles.Default
	aura.Color = ColorSequence.new(ctx.Look.Glow or ctx.Look.Secondary)
	aura.LightEmission = 0.8
	aura.Size = NumberSequence.new(ctx.S * 0.15, 0)
	aura.Lifetime = NumberRange.new(1, 1.6)
	aura.Speed = NumberRange.new(0.2, 0.5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Rate = 6
	aura.Shape = Enum.ParticleEmitterShape.Sphere
	aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	aura.Transparency = NumberSequence.new(0.2, 1)
	aura.Parent = attachment
end

features.Floating = function(_ctx)
	-- Handled by the animator (hover instead of hop); nothing to build.
end

-- Ambient particles by family (respecting the VFX setting is the animator's job).
local PARTICLE_TEXTURES = {
	Leaves = AssetConfig.Particles.Default,
	Embers = AssetConfig.Particles.Fire,
	Glints = AssetConfig.Particles.Default,
	Sparks = AssetConfig.Particles.Default,
	Mist = AssetConfig.Particles.Smoke,
	Bubbles = AssetConfig.Particles.Default,
	Bolts = AssetConfig.Particles.Default,
	Motes = AssetConfig.Particles.Default,
}

local function ambientParticles(ctx: Ctx)
	local particle = ctx.Look.Particle
	if not particle then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AmbientAttachment"
	attachment.Parent = ctx.Root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Ambient"
	emitter.Texture = PARTICLE_TEXTURES[particle.Kind] or AssetConfig.Particles.Default
	emitter.Color = ColorSequence.new(particle.Color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(ctx.S * 0.12, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(0.5, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = particle.Rate
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Acceleration = if particle.Kind == "Leaves" then Vector3.new(0, -1, 0) else Vector3.new(0, 1, 0)
	emitter.Parent = attachment

	-- Footstep puff, emitted by the animator when the creature lands a hop.
	local feet = Instance.new("Attachment")
	feet.Name = "FeetAttachment"
	feet.Position = Vector3.new(0, -ctx.S * 0.5, 0)
	feet.Parent = ctx.Root
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "Footstep"
	puff.Enabled = false
	puff.Texture = AssetConfig.Particles.Smoke
	puff.Color = ColorSequence.new(particle.Color:Lerp(Color3.new(1, 1, 1), 0.5))
	puff.Size = NumberSequence.new(ctx.S * 0.18, ctx.S * 0.4)
	puff.Lifetime = NumberRange.new(0.35, 0.5)
	puff.Speed = NumberRange.new(1, 2)
	puff.SpreadAngle = Vector2.new(80, 10)
	puff.Transparency = NumberSequence.new(0.5, 1)
	puff.Parent = feet
end

-- Builds a creature model. Returns the model (unparented); Root is anchored and the
-- model's "Height" attribute is the distance from Root to the ground.
-- Mutation looks: a recolour of the body (eyes and glowing parts keep their colour) plus a
-- subtle particle, so mutated creatures read differently at a glance.
local function applyMutation(model: Model, mutation: string, size: number)
	local def = MutationConfig.Mutations[mutation]
	if not def then
		return
	end
	local index = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Material ~= Enum.Material.Neon then
			index += 1
			if mutation == "Prismatic" then
				local hue = (index * 0.13) % 1
				part.Color = part.Color:Lerp(Color3.fromHSV(hue, 0.45, 1), 0.55)
				part.Reflectance = 0.15
			elseif mutation == "Ancient" then
				part.Color = part.Color:Lerp(Color3.fromRGB(140, 130, 115), 0.6)
				part.Material = Enum.Material.Slate
			else
				part.Color = part.Color:Lerp(def.Color, 0.65)
			end
		end
	end
	local root = model.PrimaryPart
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "MutationAttachment"
		attachment.Parent = root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Mutation"
		emitter.Texture = AssetConfig.Particles.Default
		emitter.Color = if mutation == "Prismatic"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 160)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 140, 255)),
			})
			else ColorSequence.new(def.Color)
		emitter.LightEmission = if mutation == "Shadow" then 0 else 0.8
		emitter.Size = NumberSequence.new(size * 0.12, 0)
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 4
		emitter.Parent = attachment
	end
	model:SetAttribute("Mutation", mutation)
end

function CreatureModels.Build(speciesId: string, stage: number?, mutation: string?): Model
	local species = CreatureConfig.Species[speciesId]
	assert(species, `Unknown species {speciesId}`)
	local evolution = species.Evolution[stage or 1] or species.Evolution[1]

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Creatures") and assets.Creatures:FindFirstChild(speciesId)
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		clone:ScaleTo(evolution.ScaleMultiplier)
		if mutation then
			applyMutation(clone, mutation, species.Appearance.Size)
		end
		clone:SetAttribute("Height", clone.PrimaryPart.Size.Y / 2)
		return clone
	end

	local look = species.Appearance
	local s = look.Size * evolution.ScaleMultiplier
	local model = Instance.new("Model")
	model.Name = speciesId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(s * 0.8, s * 0.8, s * 0.8)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local ctx: Ctx = { Model = model, Root = root, S = s, Look = look, HeadCF = CFrame.new(), HeadSize = s }
	local buildBody = bodies[look.Body] or bodies.Round
	buildBody(ctx)
	eyes(ctx)
	local featureList = table.clone(look.Features)
	local stageFeatures: { string } = evolution.Features or {}
	for _, name in stageFeatures do
		if not table.find(featureList, name) then
			table.insert(featureList, name)
		end
	end
	for _, name in featureList do
		local feature = features[name]
		if feature then
			feature(ctx)
		end
	end
	if look.Glow then
		local light = Instance.new("PointLight")
		light.Color = look.Glow
		light.Range = s * 2.5
		light.Brightness = 0.6
		light.Parent = root
	end
	ambientParticles(ctx)

	if mutation then
		applyMutation(model, mutation, s)
	end

	local floating = table.find(look.Features, "Floating") ~= nil
	model:SetAttribute("Height", s * 0.62 + (if floating then s * 0.5 else 0))
	model:SetAttribute("Floating", floating)
	return model
end

return CreatureModels
