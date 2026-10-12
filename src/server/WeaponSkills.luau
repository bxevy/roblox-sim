-- Weapon abilities (R). Every weapon's Skill (Items.luau) names a Mechanic below and
-- tunes it (damage, radius, range, count, duration, colors, projectile style), which is
-- what makes each weapon's ability its own. Mechanics return false if nothing happened
-- (e.g. no target in range), so no cooldown is used.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Effects = require(ServerScriptService.Server.Effects)

local WeaponSkills = {}

export type Context = {
	Player: Player,
	Root: BasePart,
	Aim: Vector3,
	Skill: { [string]: any },
	WeaponId: string,
	Hit: (enemy: any, multiplier: number) -> (number),
	EnemiesNear: (position: Vector3, radius: number) -> { any },
	AimTarget: (range: number, minDot: number) -> any?,
	Heal: (player: Player, fraction: number) -> (),
	Buff: (player: Player, duration: number) -> (),
	AddGold: (amount: number) -> (),
	Pull: (enemy: any, toward: Vector3, step: number) -> (),
	Stun: (enemy: any, duration: number) -> (),
	Knockback: (enemy: any, from: Vector3, force: number) -> (),
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- Floor height under a point (falls back to 3 studs below the player).
local function ground(ctx: Context, point: Vector3): Vector3
	local floors = {}
	for _, name in { "Dungeons", "Hub", "TrainingGrounds", "Baseplate" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(floors, f)
		end
	end
	rayParams.FilterDescendantsInstances = floors
	local result = workspace:Raycast(point + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams)
	return if result then result.Position else Vector3.new(point.X, ctx.Root.Position.Y - 3, point.Z)
end

-- Where an area ability lands: the enemy you're aiming at, or a point in front of you.
local function targetPoint(ctx: Context, range: number): Vector3
	local target = ctx.AimTarget(range, 0.6)
	local point = if target then target.Root.Position else ctx.Root.Position + ctx.Aim * math.min(range, 18)
	return ground(ctx, point)
end

local function playersNear(position: Vector3, radius: number): { Player }
	local found = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and (root.Position - position).Magnitude <= radius then
			table.insert(found, player)
		end
	end
	return found
end

-- Enemies within `width` of the segment from a to b.
local function enemiesAlongLine(ctx: Context, a: Vector3, b: Vector3, width: number): { any }
	local found = {}
	local length = (b - a).Magnitude
	local direction = if length > 0 then (b - a) / length else ctx.Aim
	for _, enemy in ctx.EnemiesNear((a + b) / 2, length / 2 + width) do
		local offset = enemy.Root.Position - a
		local along = math.clamp(offset:Dot(direction), 0, length)
		local closest = a + direction * along
		local flat = (enemy.Root.Position - closest) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= width + enemy.Radius then
			table.insert(found, enemy)
		end
	end
	return found
end

local function hitAll(ctx: Context, enemies: { any }, multiplier: number)
	for _, enemy in enemies do
		if not enemy.Dead then
			ctx.Hit(enemy, multiplier)
			if ctx.Skill.Coins then
				ctx.AddGold(ctx.Skill.Coins)
			end
		end
	end
end

local function every(ticks: number, duration: number, fn: (number) -> ())
	task.spawn(function()
		for i = 1, ticks do
			fn(i)
			task.wait(duration / ticks)
		end
	end)
end

local function styleProjectile(skill): string
	return skill.Projectile or (if skill.Style == "Fire" then "Fireball" elseif skill.Style == "Holy" then "Holy" else "Bolt")
end

-- Mechanics ------------------------------------------------------------------------------

local MECHANICS: { [string]: (Context) -> boolean? } = {}

MECHANICS.Cyclone = function(ctx)
	local s = ctx.Skill
	every(s.Ticks or 4, 1, function()
		local center = ctx.Root.Position
		Effects.ring(center - Vector3.new(0, 2.5, 0), s.Radius, s.Color, 0.25)
		hitAll(ctx, ctx.EnemiesNear(center, s.Radius), s.Damage)
	end)
end

MECHANICS.Empower = function(ctx)
	local s = ctx.Skill
	ctx.Buff(ctx.Player, s.Duration)
	Effects.burst(ctx.Root.Position, 6, s.Color)
	Effects.pillar(ground(ctx, ctx.Root.Position), 3, s.Color)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = s.Color
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = s.Color
	highlight.Parent = ctx.Root.Parent
	Debris:AddItem(highlight, s.Duration)
end

MECHANICS.Shockwave = function(ctx)
	local s = ctx.Skill
	local origin = ground(ctx, ctx.Root.Position)
	-- Waves rushing forward
	for i = 1, 5 do
		task.delay(i * 0.06, function()
			local center = origin + ctx.Aim * (i * s.Range / 5) + Vector3.new(0, 1, 0)
			local wave = Effects.part({ Size = Vector3.new(4 + i * 1.6, 2.2, 0.8), Color = s.Color, Transparency = 0.25, CFrame = CFrame.lookAt(center, center + ctx.Aim) })
			TweenService:Create(wave, TweenInfo.new(0.35), { Transparency = 1, Size = wave.Size + Vector3.new(2, 1.5, 0) }):Play()
			Debris:AddItem(wave, 0.4)
		end)
	end
	local victims = {}
	for _, enemy in ctx.EnemiesNear(ctx.Root.Position, s.Range) do
		local flat = (enemy.Root.Position - ctx.Root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 3 or flat.Unit:Dot(ctx.Aim) > 0.55 then
			table.insert(victims, enemy)
		end
	end
	hitAll(ctx, victims, s.Damage)
	if s.Knockback then
		for _, enemy in victims do
			ctx.Knockback(enemy, ctx.Root.Position, 45)
		end
	end
end

MECHANICS.Blink = function(ctx)
	local s = ctx.Skill
	local start = ctx.Root.Position
	-- Stop short of walls
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { ctx.Root.Parent :: Instance }
	local result = workspace:Raycast(start, ctx.Aim * s.Range, params)
	local distance = if result then math.max(0, result.Distance - 2) else s.Range
	local finish = start + ctx.Aim * distance
	for i = 0, 4 do
		local ghost = Effects.part({ Size = Vector3.new(2, 4.5, 1), Color = s.Color, Transparency = 0.5, CFrame = CFrame.lookAt(start:Lerp(finish, i / 4), start:Lerp(finish, i / 4) + ctx.Aim) })
		TweenService:Create(ghost, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(ghost, 0.4)
	end
	Effects.beam(start, finish, s.Color, 0.6, 0.3)
	local character = ctx.Root.Parent :: Model
	character:PivotTo(CFrame.lookAt(finish, finish + ctx.Aim))
	hitAll(ctx, enemiesAlongLine(ctx, start, finish, 4), s.Damage)
end

MECHANICS.Spikes = function(ctx)
	local s = ctx.Skill
	local origin = ground(ctx, ctx.Root.Position)
	local hitSet = {}
	local steps = math.floor(s.Range / 2.5)
	for i = 1, steps do
		task.delay(i * 0.04, function()
			local point = ground(ctx, origin + ctx.Aim * i * 2.5)
			Effects.spike(point, 4 + (i % 3), s.Color, if s.Style == "Bone" then Enum.Material.Marble else Enum.Material.Ice)
			for _, enemy in ctx.EnemiesNear(point, 3) do
				if not hitSet[enemy] then
					hitSet[enemy] = true
					ctx.Hit(enemy, s.Damage)
				end
			end
		end)
	end
end

MECHANICS.Vortex = function(ctx)
	local s = ctx.Skill
	local center = targetPoint(ctx, 30)
	Effects.cloud(center, s.Radius, s.Color, s.Duration)
	every(s.Ticks or 6, s.Duration, function()
		Effects.ring(center + Vector3.new(0, 0.3, 0), s.Radius, s.Color, 0.35)
		for _, enemy in ctx.EnemiesNear(center, s.Radius) do
			ctx.Pull(enemy, center, 2.5)
			ctx.Hit(enemy, s.Damage)
		end
	end)
end

MECHANICS.Rain = function(ctx)
	local s = ctx.Skill
	local center = targetPoint(ctx, 45)
	local kind = styleProjectile(s)
	Effects.warning(center, s.Radius, s.Color, s.Duration)
	every(s.Count, s.Duration, function()
		local angle, r = math.random() * math.pi * 2, math.sqrt(math.random()) * s.Radius
		local point = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		if kind == "Meteor" then
			Effects.meteor(point, s.Color, 0.7, 6, function()
				hitAll(ctx, ctx.EnemiesNear(point, 6), s.Damage)
			end)
		else
			local sky = point + Vector3.new(math.random(-3, 3), 30, math.random(-3, 3))
			Effects.projectile(if kind == "Bolt" then "Star" else kind, sky, point, s.Color, function()
				Effects.burst(point, 2.5, s.Color, 0.2)
				hitAll(ctx, ctx.EnemiesNear(point, 3.5), s.Damage)
			end, 90)
		end
	end)
end

MECHANICS.Breath = function(ctx)
	local s = ctx.Skill
	every(s.Ticks or 6, s.Duration, function()
		local origin = ctx.Root.Position + ctx.Aim * 2 + Vector3.new(0, 1, 0)
		for k = -1, 1 do
			local direction = CFrame.Angles(0, math.rad(k * 14 + math.random(-5, 5)), 0) * ctx.Aim
			Effects.projectile("Fireball", origin, origin + direction * s.Range, s.Color, function() end, 70)
		end
		local victims = {}
		for _, enemy in ctx.EnemiesNear(ctx.Root.Position, s.Range) do
			local flat = (enemy.Root.Position - ctx.Root.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude < 3 or flat.Unit:Dot(ctx.Aim) > 0.7 then
				table.insert(victims, enemy)
			end
		end
		hitAll(ctx, victims, s.Damage)
	end)
end

MECHANICS.Collapse = function(ctx)
	local s = ctx.Skill
	local center = targetPoint(ctx, 30) + Vector3.new(0, 2, 0)
	local core = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * s.Radius * 2, Color = s.Color, Transparency = 0.6, CFrame = CFrame.new(center) })
	local dark = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(center) })
	TweenService:Create(core, TweenInfo.new(s.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 2, Transparency = 0.2 }):Play()
	Debris:AddItem(core, s.Duration + 0.05)
	Debris:AddItem(dark, s.Duration + 0.05)
	every(6, s.Duration, function()
		for _, enemy in ctx.EnemiesNear(center, s.Radius + 4) do
			ctx.Pull(enemy, center, 3)
		end
	end)
	task.delay(s.Duration, function()
		Effects.burst(center, s.Radius, s.Color, 0.45)
		Effects.ring(center - Vector3.new(0, 2, 0), s.Radius * 1.4, s.Color, 0.45)
		hitAll(ctx, ctx.EnemiesNear(center, s.Radius), s.Damage)
	end)
end

MECHANICS.Missiles = function(ctx)
	local s = ctx.Skill
	local targets = {}
	for _, enemy in ctx.EnemiesNear(ctx.Root.Position, s.Range) do
		table.insert(targets, { Enemy = enemy, Distance = (enemy.Root.Position - ctx.Root.Position).Magnitude })
	end
	if #targets == 0 then
		return false
	end
	table.sort(targets, function(a, b)
		return a.Distance < b.Distance
	end)
	local kind = styleProjectile(s)
	for i = 1, s.Count do
		local entry = targets[(i - 1) % #targets + 1]
		task.delay(i * 0.08, function()
			local enemy = entry.Enemy
			if enemy.Dead then
				return
			end
			if kind == "Pillar" then
				Effects.pillar(ground(ctx, enemy.Root.Position), 2.5, s.Color)
				ctx.Hit(enemy, s.Damage)
				return
			end
			local from = ctx.Root.Position + Vector3.new(math.random(-2, 2), 3, math.random(-2, 2))
			Effects.projectile(kind, from, enemy.Root.Position, s.Color, function()
				if not enemy.Dead then
					Effects.sparks(enemy.Root.Position, s.Color)
					ctx.Hit(enemy, s.Damage)
				end
			end)
		end)
	end
	return true
end

MECHANICS.Root = function(ctx)
	local s = ctx.Skill
	local center = targetPoint(ctx, 30)
	Effects.ring(center, s.Radius, s.Color, 0.5)
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2
		local p = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * s.Radius * math.random()
		Effects.spike(p, 3, s.Color, Enum.Material.Grass)
	end
	for _, enemy in ctx.EnemiesNear(center, s.Radius) do
		ctx.Stun(enemy, s.Duration)
	end
	every(s.Ticks or 6, s.Duration, function()
		hitAll(ctx, ctx.EnemiesNear(center, s.Radius), s.Damage)
	end)
end

MECHANICS.Beam = function(ctx)
	local s = ctx.Skill
	every(s.Ticks or 6, s.Duration, function()
		local from = ctx.Root.Position + Vector3.new(0, 1, 0) + ctx.Aim * 2
		local to = from + ctx.Aim * s.Range
		Effects.beam(from, to, s.Color, 1.4, s.Duration / (s.Ticks or 6) + 0.05)
		hitAll(ctx, enemiesAlongLine(ctx, from, to, 2.5), s.Damage)
	end)
end

MECHANICS.Chain = function(ctx)
	local s = ctx.Skill
	local current = ctx.AimTarget(s.Range, 0.5)
	if not current then
		return false
	end
	local from = ctx.Root.Position + Vector3.new(0, 1, 0)
	local visited = {}
	local dealt = 0
	for _ = 1, s.Count do
		visited[current] = true
		Effects.lightning(from, current.Root.Position, s.Color)
		dealt += ctx.Hit(current, s.Damage)
		from = current.Root.Position
		local nextEnemy, best = nil, 18
		for _, enemy in ctx.EnemiesNear(from, 18) do
			local distance = (enemy.Root.Position - from).Magnitude
			if not visited[enemy] and not enemy.Dead and distance < best then
				nextEnemy, best = enemy, distance
			end
		end
		if not nextEnemy then
			break
		end
		current = nextEnemy
	end
	if s.Heal then
		local humanoid = ctx.Root.Parent and (ctx.Root.Parent :: Model):FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dealt * s.Heal)
		end
	end
	return true
end

MECHANICS.Meteor = function(ctx)
	local s = ctx.Skill
	local point = targetPoint(ctx, s.Range or 45)
	Effects.meteor(point, s.Color, 0.9, s.Radius, function()
		hitAll(ctx, ctx.EnemiesNear(point, s.Radius), s.Damage)
	end)
end

MECHANICS.Nova = function(ctx)
	local s = ctx.Skill
	local center = ctx.Root.Position
	Effects.burst(center, s.Radius, s.Color, 0.4)
	Effects.ring(ground(ctx, center) + Vector3.new(0, 0.3, 0), s.Radius * 1.2, s.Color, 0.45)
	if s.Projectile == "Knives" then
		for i = 0, 11 do
			local direction = CFrame.Angles(0, i / 12 * math.pi * 2, 0) * Vector3.zAxis
			Effects.projectile("Knives", center, center + direction * s.Radius, s.Color, function() end)
		end
	end
	hitAll(ctx, ctx.EnemiesNear(center, s.Radius), s.Damage)
	if s.HealPercent then
		for _, player in playersNear(center, s.Radius + 6) do
			ctx.Heal(player, s.HealPercent)
		end
	end
end

MECHANICS.Orb = function(ctx)
	local s = ctx.Skill
	local start = ctx.Root.Position + ctx.Aim * 2 + Vector3.new(0, 1, 0)
	local finish = start + ctx.Aim * s.Range
	Effects.projectile("Orb", start, finish, s.Color, function()
		Effects.burst(finish, s.Radius, s.Color)
	end, s.Range / s.Duration)
	every(s.Ticks or 8, s.Duration, function(i)
		local position = start:Lerp(finish, i / (s.Ticks or 8))
		hitAll(ctx, ctx.EnemiesNear(position, s.Radius), s.Damage)
	end)
end

MECHANICS.Pierce = function(ctx)
	local s = ctx.Skill
	local from = ctx.Root.Position + ctx.Aim * 2 + Vector3.new(0, 1, 0)
	local to = from + ctx.Aim * s.Range
	local kind = s.Projectile or "Arrow"
	Effects.projectile(kind, from, to, s.Color, function() end, if kind == "Phoenix" then 90 else 180)
	-- Damage as it passes each enemy
	for _, enemy in enemiesAlongLine(ctx, from, to, if kind == "Phoenix" then 4 else 2.5) do
		local delay = (enemy.Root.Position - from).Magnitude / (if kind == "Phoenix" then 90 else 180)
		task.delay(delay, function()
			if not enemy.Dead then
				Effects.sparks(enemy.Root.Position, s.Color, if kind == "Phoenix" then "Fire" else nil)
				ctx.Hit(enemy, s.Damage)
			end
		end)
	end
end

MECHANICS.Execute = function(ctx)
	local s = ctx.Skill
	local target = ctx.AimTarget(s.Range, 0.5)
	if not target then
		return false
	end
	local wounded = target.Humanoid.Health / target.Humanoid.MaxHealth < 0.3
	if s.Range > 15 then
		Effects.projectile("Arrow", ctx.Root.Position + Vector3.new(0, 1, 0), target.Root.Position, s.Color, function() end, 220)
	end
	task.delay(if s.Range > 15 then 0.15 else 0, function()
		if target.Dead then
			return
		end
		Effects.sparks(target.Root.Position, s.Color, nil, 25)
		Effects.burst(target.Root.Position, 3, s.Color, 0.2)
		ctx.Hit(target, s.Damage * (if wounded then 1.5 else 1))
		if s.Stun then
			ctx.Stun(target, s.Stun)
		end
	end)
	return true
end

MECHANICS.Cloud = function(ctx)
	local s = ctx.Skill
	local center = targetPoint(ctx, 30)
	Effects.cloud(center, s.Radius, s.Color, s.Duration)
	Effects.ring(center, s.Radius, s.Color, 0.4)
	every(s.Ticks or 8, s.Duration, function()
		hitAll(ctx, ctx.EnemiesNear(center, s.Radius), s.Damage)
	end)
end

MECHANICS.Bomb = function(ctx)
	local s = ctx.Skill
	local point = targetPoint(ctx, s.Range or 50)
	local from = ctx.Root.Position + ctx.Aim * 2 + Vector3.new(0, 1, 0)
	Effects.projectile("Arrow", from, point + Vector3.new(0, 1, 0), s.Color, function()
		Effects.burst(point, s.Radius, s.Color, 0.4)
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			Effects.spike(point + Vector3.new(math.cos(angle), 0, math.sin(angle)) * s.Radius * 0.6, 3, s.Color, Enum.Material.Ice)
		end
		for _, enemy in ctx.EnemiesNear(point, s.Radius) do
			ctx.Stun(enemy, 1.2)
		end
		hitAll(ctx, ctx.EnemiesNear(point, s.Radius), s.Damage)
	end)
end

MECHANICS.Summon = function(ctx)
	local s = ctx.Skill
	local blades = {}
	for i = 1, 3 do
		blades[i] = Effects.part({ Size = Vector3.new(0.2, 0.5, 2.2), Color = s.Color, Transparency = 0.2, CFrame = ctx.Root.CFrame })
	end
	local ticks = s.Ticks or 10
	task.spawn(function()
		local elapsed = 0
		local nextHit = 0
		while elapsed < s.Duration and ctx.Root.Parent do
			local dt = task.wait(0.05)
			elapsed += dt
			for i, blade in blades do
				local angle = elapsed * 6 + i / 3 * math.pi * 2
				local position = ctx.Root.Position + Vector3.new(math.cos(angle), 0.5, math.sin(angle)) * (s.Radius * 0.6)
				blade.CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
			end
			if elapsed >= nextHit then
				nextHit += s.Duration / ticks
				hitAll(ctx, ctx.EnemiesNear(ctx.Root.Position, s.Radius), s.Damage)
			end
		end
		for _, blade in blades do
			blade:Destroy()
		end
	end)
end

MECHANICS.Ricochet = function(ctx)
	local s = ctx.Skill
	local targets = {}
	for _, enemy in ctx.EnemiesNear(ctx.Root.Position, s.Range) do
		table.insert(targets, { Enemy = enemy, Distance = (enemy.Root.Position - ctx.Root.Position).Magnitude })
	end
	if #targets == 0 then
		return false
	end
	table.sort(targets, function(a, b)
		return a.Distance < b.Distance
	end)
	local character = ctx.Root.Parent :: Model
	task.spawn(function()
		for i = 1, math.min(s.Count, #targets) do
			local enemy = targets[i].Enemy
			if not enemy.Dead and character.Parent then
				local from = ctx.Root.Position
				local away = (enemy.Root.Position - from) * Vector3.new(1, 0, 1)
				local behind = enemy.Root.Position + (if away.Magnitude > 0.1 then away.Unit else ctx.Aim) * (enemy.Radius + 2)
				Effects.beam(from, behind, s.Color, 0.4, 0.25)
				character:PivotTo(CFrame.lookAt(Vector3.new(behind.X, from.Y, behind.Z), Vector3.new(enemy.Root.Position.X, from.Y, enemy.Root.Position.Z)))
				Effects.sparks(enemy.Root.Position, s.Color, nil, 18)
				ctx.Hit(enemy, s.Damage)
			end
			task.wait(0.15)
		end
	end)
	return true
end

MECHANICS.Heal = function(ctx)
	local s = ctx.Skill
	for _, player in playersNear(ctx.Root.Position, s.Radius) do
		ctx.Heal(player, s.HealPercent)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Effects.pillar(ground(ctx, root.Position), 2.5, s.Color, 0.6)
		end
	end
	Effects.ring(ground(ctx, ctx.Root.Position) + Vector3.new(0, 0.3, 0), s.Radius, s.Color, 0.5)
end

MECHANICS.Zone = function(ctx)
	local s = ctx.Skill
	local center = ground(ctx, ctx.Root.Position)
	local disc = Effects.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, s.Radius * 2, s.Radius * 2), Color = s.Color, Transparency = 0.6, CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	Debris:AddItem(disc, s.Duration)
	every(s.Ticks or 5, s.Duration, function()
		Effects.ring(center + Vector3.new(0, 0.3, 0), s.Radius, s.Color, 0.4)
		for _, player in playersNear(center, s.Radius) do
			ctx.Heal(player, s.HealPercent)
		end
		hitAll(ctx, ctx.EnemiesNear(center, s.Radius), s.Damage)
	end)
end

MECHANICS.Guardian = function(ctx)
	local s = ctx.Skill
	for _, player in playersNear(ctx.Root.Position, s.Radius) do
		ctx.Buff(player, s.Duration)
		local character = player.Character
		if character then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = s.Color
			highlight.FillTransparency = 0.75
			highlight.OutlineColor = s.Color
			highlight.Parent = character
			Debris:AddItem(highlight, s.Duration)
		end
	end
	Effects.ring(ground(ctx, ctx.Root.Position) + Vector3.new(0, 0.3, 0), s.Radius, s.Color, 0.5)
	Effects.pillar(ground(ctx, ctx.Root.Position), 4, s.Color)
end

function WeaponSkills.Run(ctx: Context): boolean
	local mechanic = MECHANICS[ctx.Skill.Mechanic]
	if not mechanic then
		warn(`[WeaponSkills] Unknown mechanic {ctx.Skill.Mechanic}`)
		return false
	end
	return mechanic(ctx) ~= false
end

return WeaponSkills
