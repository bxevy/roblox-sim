-- Visual effects for combat: projectiles, rings, bursts, beams, lightning, spikes, light
-- pillars, meteors and clouds. All are anchored, non-colliding parts cleaned up with Debris,
-- so they replicate to every player automatically.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local M = Enum.Material

local TEXTURES = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

function Effects.part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = M.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = workspace
	return p
end

local function fade(part: BasePart, duration: number, props: { [string]: any }?)
	local goal = props or {}
	goal.Transparency = 1
	TweenService:Create(part, TweenInfo.new(duration), goal):Play()
	Debris:AddItem(part, duration + 0.05)
end

local function light(part: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 2
	l.Parent = part
end

-- Adds a glowing ribbon behind a moving part.
local function trail(part: BasePart, color: Color3, width: number, lifetime: number?)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(color)
	t.LightEmission = 1
	t.Lifetime = lifetime or 0.25
	t.Transparency = NumberSequence.new(0.2, 1)
	t.FaceCamera = true
	t.Parent = part
end

local function particles(part: BasePart, color: Color3, kind: string?, rate: number?)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Texture = if kind == "Fire" then TEXTURES.Fire elseif kind == "Smoke" then TEXTURES.Smoke else TEXTURES.Sparkle
	e.Size = NumberSequence.new(if kind == "Smoke" then 1.2 else 0.5, 0)
	e.Transparency = NumberSequence.new(if kind == "Smoke" then 0.5 else 0, 1)
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Rate = rate or 40
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = part
	return e
end

-- Rings, bursts, warnings -------------------------------------------------------------

-- Expanding flat ring on the floor.
function Effects.ring(center: Vector3, radius: number, color: Color3, duration: number?)
	local ring = Effects.part({
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Transparency = 0.3,
		Size = Vector3.new(0.4, 2, 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local t = duration or 0.3
	TweenService:Create(ring, TweenInfo.new(t), { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, t + 0.05)
end

-- Expanding glowing sphere.
function Effects.burst(center: Vector3, radius: number, color: Color3, duration: number?)
	local ball = Effects.part({
		Shape = Enum.PartType.Ball,
		Color = color,
		Transparency = 0.25,
		Size = Vector3.one * 2,
		Position = center,
	})
	light(ball, color, radius * 1.5)
	local t = duration or 0.3
	TweenService:Create(ball, TweenInfo.new(t), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(ball, t + 0.05)
end

-- A red-ish circle on the floor that shows where something is about to hit.
function Effects.warning(center: Vector3, radius: number, color: Color3, duration: number)
	local circle = Effects.part({
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Transparency = 0.65,
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	Debris:AddItem(circle, duration)
end

-- Projectiles ---------------------------------------------------------------------------

local SPEED = { Arrow = 150, Bolt = 90, Fireball = 70, Coin = 110, Gem = 100, Star = 90, Holy = 90, Phoenix = 80, Knives = 120, Orb = 25, Pumpkin = 70 }

local function makeProjectile(kind: string, from: Vector3, to: Vector3, color: Color3): BasePart
	local facing = CFrame.lookAt(from, to)
	local p
	if kind == "Arrow" then
		p = Effects.part({ Size = Vector3.new(0.15, 0.15, 2.6), Color = color, Material = M.SmoothPlastic, CFrame = facing })
		trail(p, color, 0.25, 0.15)
	elseif kind == "Coin" then
		p = Effects.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.9, 0.9), Color = color, Material = M.Metal, CFrame = facing })
		trail(p, color, 0.4, 0.15)
	elseif kind == "Gem" or kind == "Star" then
		p = Effects.part({ Size = Vector3.one * 0.8, Color = color, CFrame = facing * CFrame.Angles(math.rad(45), 0, math.rad(45)) })
		trail(p, color, 0.6, 0.25)
		light(p, color, 8)
	elseif kind == "Knives" then
		p = Effects.part({ Size = Vector3.new(0.1, 0.25, 1.4), Color = color, Material = M.Metal, CFrame = facing })
		trail(p, color, 0.2, 0.12)
	elseif kind == "Pumpkin" then
		-- A flaming jack-o'-lantern
		p = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = Color3.fromRGB(240, 120, 20), Material = M.SmoothPlastic, CFrame = facing })
		local function attach(size: Vector3, offset: CFrame, partColor: Color3, material: Enum.Material)
			local piece = Effects.part({ Size = size, Color = partColor, Material = material, CFrame = facing * offset })
			piece.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = p
			weld.Part1 = piece
			weld.Parent = piece
			Debris:AddItem(piece, 5)
		end
		attach(Vector3.new(0.25, 0.5, 0.25), CFrame.new(0, 1.1, 0), Color3.fromRGB(70, 100, 40), M.Wood)
		attach(Vector3.new(1.1, 0.25, 0.1), CFrame.new(0, -0.3, -0.98), color, M.Neon)
		for _, side in { -1, 1 } do
			attach(Vector3.new(0.3, 0.3, 0.1), CFrame.new(side * 0.35, 0.25, -0.95) * CFrame.Angles(0, 0, math.rad(45)), color, M.Neon)
		end
		local fire = Instance.new("Fire")
		fire.Color = color
		fire.SecondaryColor = Color3.fromRGB(255, 60, 10)
		fire.Size = 3
		fire.Parent = p
		trail(p, color, 1.2, 0.3)
		light(p, color, 14)
	elseif kind == "Phoenix" then
		p = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, Color = color, CFrame = facing })
		for _, side in { -1, 1 } do
			local wing = Effects.part({ Size = Vector3.new(2.6, 0.15, 1.2), Color = color, CFrame = facing * CFrame.new(side * 1.6, 0.3, 0.4) * CFrame.Angles(0, 0, math.rad(side * 20)) })
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = p
			weld.Part1 = wing
			weld.Parent = wing
			wing.Anchored = false
			Debris:AddItem(wing, 3)
		end
		local fire = Instance.new("Fire")
		fire.Color = color
		fire.Size = 5
		fire.Parent = p
		trail(p, color, 1.5, 0.4)
		light(p, color, 18)
	else -- Bolt, Fireball, Holy, Orb
		local size = if kind == "Fireball" then 2.6 elseif kind == "Orb" then 2.4 else 1.2
		p = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = color, CFrame = facing })
		trail(p, color, size * 0.7, 0.2)
		light(p, color, 12)
		if kind == "Fireball" then
			local fire = Instance.new("Fire")
			fire.Color = color
			fire.Size = 4
			fire.Parent = p
		elseif kind == "Orb" then
			particles(p, color, nil, 30)
		end
	end
	return p
end

-- Flies a projectile from `from` to `to`, then calls onArrive (after the travel time).
function Effects.projectile(kind: string, from: Vector3, to: Vector3, color: Color3, onArrive: () -> (), speed: number?)
	local distance = (to - from).Magnitude
	local travel = math.max(0.05, distance / (speed or SPEED[kind] or 110))
	local p = makeProjectile(kind, from, to, color)
	TweenService:Create(p, TweenInfo.new(travel, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(to) * p.CFrame.Rotation,
	}):Play()
	Debris:AddItem(p, travel + 0.3)
	task.delay(travel, function()
		p.Transparency = 1
		onArrive()
	end)
	return travel
end

-- Lines ---------------------------------------------------------------------------------

-- A straight glowing beam between two points.
function Effects.beam(from: Vector3, to: Vector3, color: Color3, width: number, duration: number): Part
	local length = (to - from).Magnitude
	local beam = Effects.part({
		Size = Vector3.new(width, width, length),
		Color = color,
		Transparency = 0.2,
		CFrame = CFrame.lookAt((from + to) / 2, to),
	})
	light(beam, color, 12)
	fade(beam, duration, { Size = Vector3.new(width * 0.2, width * 0.2, length) })
	return beam
end

-- A jagged lightning bolt between two points.
function Effects.lightning(from: Vector3, to: Vector3, color: Color3)
	local segments = math.clamp(math.floor((to - from).Magnitude / 3), 3, 12)
	local previous = from
	for i = 1, segments do
		local point = from:Lerp(to, i / segments)
		if i < segments then
			point += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
		end
		Effects.beam(previous, point, color, 0.3, 0.25)
		previous = point
	end
end

-- Ground effects ------------------------------------------------------------------------

-- A spike that bursts up out of the floor, then sinks.
function Effects.spike(position: Vector3, height: number, color: Color3, material: Enum.Material?)
	local spike = Effects.part({
		Size = Vector3.new(1.4, height, 1.4),
		Color = color,
		Material = material or M.Ice,
		CFrame = CFrame.new(position - Vector3.new(0, height / 2, 0)) * CFrame.Angles(math.rad(math.random(-15, 15)), math.random() * math.pi, math.rad(math.random(-15, 15))),
	})
	TweenService:Create(spike, TweenInfo.new(0.12, Enum.EasingStyle.Back), { CFrame = spike.CFrame + Vector3.new(0, height * 0.9, 0) }):Play()
	task.delay(0.8, function()
		TweenService:Create(spike, TweenInfo.new(0.4), { CFrame = spike.CFrame - Vector3.new(0, height, 0), Transparency = 1 }):Play()
	end)
	Debris:AddItem(spike, 1.3)
end

-- A column of light from the sky.
function Effects.pillar(position: Vector3, radius: number, color: Color3, duration: number?)
	local column = Effects.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(40, radius * 2, radius * 2),
		Color = color,
		Transparency = 0.3,
		CFrame = CFrame.new(position + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	light(column, color, radius * 4, 3)
	fade(column, duration or 0.5, { Size = Vector3.new(40, 0.2, 0.2) })
	Effects.ring(position, radius * 1.5, color)
end

-- A meteor that falls from the sky onto `target`, then calls onImpact.
function Effects.meteor(target: Vector3, color: Color3, fallTime: number, radius: number, onImpact: () -> ())
	Effects.warning(target, radius, color, fallTime)
	local start = target + Vector3.new(math.random(-12, 12), 60, math.random(-12, 12))
	local rock = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3.5, Color = color:Lerp(Color3.new(0.2, 0.1, 0.05), 0.5), Material = M.Basalt, CFrame = CFrame.new(start) })
	local fire = Instance.new("Fire")
	fire.Color = color
	fire.Size = 8
	fire.Heat = 12
	fire.Parent = rock
	trail(rock, color, 3, 0.4)
	TweenService:Create(rock, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target) }):Play()
	Debris:AddItem(rock, fallTime + 0.05)
	task.delay(fallTime, function()
		Effects.burst(target, radius, color, 0.4)
		Effects.ring(target, radius * 1.3, color, 0.4)
		onImpact()
	end)
end

-- A lingering cloud (poison, sand, etc.).
function Effects.cloud(center: Vector3, radius: number, color: Color3, duration: number)
	local area = Effects.part({ Size = Vector3.new(radius * 2, 3, radius * 2), CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)), Transparency = 1 })
	local e = particles(area, color, "Smoke", radius * 5)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.LightEmission = 0.3
	e.Size = NumberSequence.new(2.5, 4)
	e.Transparency = NumberSequence.new(0.6, 1)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Speed = NumberRange.new(0.3, 0.8)
	Debris:AddItem(area, duration + 1.6)
	task.delay(duration, function()
		e.Enabled = false
	end)
end

-- A burst of particles at a point (hit sparks, smoke puffs).
function Effects.sparks(position: Vector3, color: Color3, kind: string?, amount: number?)
	local anchor = Effects.part({ Size = Vector3.one * 0.2, CFrame = CFrame.new(position), Transparency = 1 })
	local e = particles(anchor, color, kind, 0)
	e.Speed = NumberRange.new(4, 10)
	e:Emit(amount or 14)
	Debris:AddItem(anchor, 1)
end

return Effects
