-- Spawns enemy models, runs their AI (chase, attack, boss slams), and handles damage.
-- Enemies are built from plain parts, so no models or assets are needed.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)

local AI_TICK = 0.2
local AGGRO_RANGE = 250

local EnemyService = {}

export type Enemy = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Def: Enemies.EnemyDef,
	Damage: number,
	Radius: number,
	GroundOffset: number, -- distance from Root center down to the floor
	GetTargets: () -> { Player },
	OnDied: (Enemy) -> (),
	LastAttack: number,
	LastSlam: number,
	Busy: boolean,
	Dead: boolean,
}

export type SpawnOptions = {
	Power: number,
	Position: Vector3, -- point on the floor
	Parent: Instance,
	GetTargets: () -> { Player },
	OnDied: (Enemy) -> (),
}

local enemies: { [Enemy]: true } = {}

-- Model building -----------------------------------------------------------

local function buildModel(def: Enemies.EnemyDef)
	local s = def.Scale
	local material = def.Material or Enum.Material.SmoothPlastic
	local model = Instance.new("Model")
	model.Name = def.DisplayName

	local torsoSize = Vector3.new(2, 2, 1) * s
	local legHeight = 2 * s

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = torsoSize
	root.Color = def.BodyColor
	root.Material = material
	root.CFrame = CFrame.new()
	root.Parent = model

	local function limb(name: string, size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or material
		p.CanCollide = false
		p.Massless = true
		p.CFrame = root.CFrame + offset
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local headY = torsoSize.Y / 2 + 0.6 * s
	local head = limb("Head", Vector3.one * 1.2 * s, Vector3.new(0, headY, 0), def.HeadColor)
	for _, side in { -1, 1 } do
		limb("Eye", Vector3.new(0.25, 0.25, 0.1) * s, Vector3.new(0.28 * s * side, headY + 0.1 * s, -0.62 * s), def.EyeColor, Enum.Material.Neon)
		limb("Arm", Vector3.new(0.8, 2, 0.8) * s, Vector3.new(1.4 * s * side, 0, 0), def.BodyColor)
		limb("Leg", Vector3.new(0.9, 2, 0.9) * s, Vector3.new(0.5 * s * side, -torsoSize.Y / 2 - legHeight / 2, 0), def.BodyColor)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 honors HipHeight on custom rigs
	humanoid.HipHeight = legHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, root, head, humanoid, torsoSize.Y / 2 + legHeight
end

local function buildHealthBar(enemy: Enemy, head: BasePart)
	local isBoss = enemy.Def.Boss ~= nil
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if isBoss then 220 else 120, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y + 1, 0)
	gui.MaxDistance = 120
	gui.Parent = head

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 18)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = if isBoss then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = enemy.Def.DisplayName
	name.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 22)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	fill.BorderSizePixel = 0
	fill.Parent = back

	enemy.Humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / enemy.Humanoid.MaxHealth, 0, 1), 1)
	end)
end

-- Effects ------------------------------------------------------------------

local function showDamageNumber(enemy: Enemy, amount: number, isCrit: boolean)
	local anchor = Instance.new("Attachment")
	anchor.Position = Vector3.new(math.random(-10, 10) / 10, enemy.Root.Size.Y, 0)
	anchor.Parent = enemy.Root

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(100, 40)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.TextColor3 = if isCrit then Color3.fromRGB(255, 200, 40) else Color3.new(1, 1, 1)
	label.Text = if isCrit then `{amount}!` else tostring(amount)
	label.Parent = gui

	TweenService:Create(gui, TweenInfo.new(0.7), { StudsOffset = Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.8)
end

local function flash(model: Model, color: Color3)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, 0.12)
end

-- AI -----------------------------------------------------------------------

local function findTarget(enemy: Enemy): (Humanoid?, BasePart?, number)
	local bestHumanoid, bestRoot, bestDistance = nil, nil, AGGRO_RANGE
	for _, player in enemy.GetTargets() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - enemy.Root.Position).Magnitude
			if distance < bestDistance then
				bestHumanoid, bestRoot, bestDistance = humanoid, root, distance
			end
		end
	end
	return bestHumanoid, bestRoot, bestDistance
end

local function faceTowards(enemy: Enemy, position: Vector3)
	local from = enemy.Root.Position
	local flat = Vector3.new(position.X, from.Y, position.Z)
	if (flat - from).Magnitude > 0.1 then
		enemy.Root.CFrame = CFrame.lookAt(from, flat)
	end
end

-- Boss attack: a red circle appears on the floor, then everyone inside takes big damage.
local function slam(enemy: Enemy)
	local boss = enemy.Def.Boss :: Enemies.BossDef
	enemy.Busy = true
	enemy.Humanoid:MoveTo(enemy.Root.Position)

	local center = enemy.Root.Position - Vector3.new(0, enemy.GroundOffset, 0)
	local circle = Instance.new("Part")
	circle.Name = "SlamWarning"
	circle.Shape = Enum.PartType.Cylinder
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.Material = Enum.Material.Neon
	circle.Color = Color3.fromRGB(255, 40, 40)
	circle.Transparency = 0.6
	circle.Size = Vector3.new(0.2, boss.SlamRadius * 2, boss.SlamRadius * 2)
	circle.CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Parent = enemy.Model.Parent

	task.wait(boss.SlamWindup)
	circle:Destroy()
	enemy.Busy = false
	if enemy.Dead then
		return
	end

	local damage = boss.SlamDamage * (enemy.Damage / enemy.Def.Damage)
	for _, player in enemy.GetTargets() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root then
			local offset = root.Position - center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= boss.SlamRadius then
				humanoid:TakeDamage(damage)
			end
		end
	end

	local shock = Instance.new("Part")
	shock.Shape = Enum.PartType.Ball
	shock.Anchored = true
	shock.CanCollide = false
	shock.CanQuery = false
	shock.Material = Enum.Material.Neon
	shock.Color = Color3.fromRGB(255, 120, 60)
	shock.Transparency = 0.3
	shock.Size = Vector3.one * 2
	shock.Position = center
	shock.Parent = enemy.Model.Parent
	TweenService:Create(shock, TweenInfo.new(0.35), {
		Size = Vector3.one * boss.SlamRadius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(shock, 0.4)
end

local function think(enemy: Enemy, now: number)
	if enemy.Busy then
		return
	end
	local targetHumanoid, targetRoot, distance = findTarget(enemy)
	if not targetHumanoid or not targetRoot then
		enemy.Humanoid:MoveTo(enemy.Root.Position)
		return
	end

	local boss = enemy.Def.Boss
	if boss and now - enemy.LastSlam >= boss.SlamCooldown and distance <= boss.SlamRadius then
		enemy.LastSlam = now
		task.spawn(slam, enemy)
		return
	end

	if distance > enemy.Def.AttackRange + enemy.Radius then
		enemy.Humanoid:MoveTo(targetRoot.Position)
		return
	end

	enemy.Humanoid:MoveTo(enemy.Root.Position)
	faceTowards(enemy, targetRoot.Position)
	if now - enemy.LastAttack >= enemy.Def.AttackCooldown then
		enemy.LastAttack = now
		targetHumanoid:TakeDamage(enemy.Damage)
		if targetHumanoid.Parent then
			flash(targetHumanoid.Parent :: Model, Color3.fromRGB(255, 60, 60))
		end
	end
end

-- Public API ---------------------------------------------------------------

function EnemyService.Spawn(enemyId: string, options: SpawnOptions): Enemy
	local def = Enemies[enemyId]
	assert(def, `Unknown enemy {enemyId}`)

	local model, root, head, humanoid, groundOffset = buildModel(def)
	humanoid.MaxHealth = math.floor(def.Health * options.Power)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = def.Speed

	local enemy: Enemy = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Def = def,
		Damage = def.Damage * options.Power,
		Radius = root.Size.X / 2,
		GroundOffset = groundOffset,
		GetTargets = options.GetTargets,
		OnDied = options.OnDied,
		LastAttack = 0,
		-- Give players a moment before the boss's first slam.
		LastSlam = os.clock(),
		Busy = false,
		Dead = false,
	}
	buildHealthBar(enemy, head)

	-- Face a random direction so groups don't look copy-pasted.
	model:PivotTo(CFrame.new(options.Position + Vector3.new(0, groundOffset, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model.Parent = options.Parent
	root:SetNetworkOwner(nil) -- server simulates enemies, so exploiters can't fling them

	humanoid.Died:Connect(function()
		if enemy.Dead then
			return
		end
		enemy.Dead = true
		enemies[enemy] = nil
		task.spawn(enemy.OnDied, enemy)
		-- Joints break on death so the enemy falls apart; clean up shortly after.
		Debris:AddItem(model, 2)
	end)

	enemies[enemy] = true
	return enemy
end

-- Removes an enemy without counting it as a kill (used when a dungeon closes).
function EnemyService.Despawn(enemy: Enemy)
	enemy.Dead = true
	enemies[enemy] = nil
	enemy.Model:Destroy()
end

function EnemyService.GetEnemiesNear(position: Vector3, radius: number): { Enemy }
	local found = {}
	for enemy in enemies do
		if (enemy.Root.Position - position).Magnitude <= radius + enemy.Radius then
			table.insert(found, enemy)
		end
	end
	return found
end

function EnemyService.Damage(enemy: Enemy, amount: number, isCrit: boolean)
	if enemy.Dead then
		return
	end
	amount = math.max(1, math.floor(amount))
	enemy.Humanoid.Health = math.max(0, enemy.Humanoid.Health - amount)
	showDamageNumber(enemy, amount, isCrit)
	flash(enemy.Model, Color3.new(1, 1, 1))
end

function EnemyService.Start()
	task.spawn(function()
		while true do
			task.wait(AI_TICK)
			local now = os.clock()
			for enemy in enemies do
				if enemy.Root.Parent then
					think(enemy, now)
				else
					enemies[enemy] = nil
				end
			end
		end
	end)
end

return EnemyService
