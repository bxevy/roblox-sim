-- Spawns enemy models, runs their AI (chase, melee, ranged shots, boss mechanics), and
-- handles damage. Enemies are built from plain parts, so no models or assets are needed.
--
-- Boss mechanics (see Enemies.luau for each boss's list): every few seconds a boss picks
-- one of its attacks, shows a telegraph on the floor (red = danger, green = safe), waits
-- out the windup, then hits everyone still in the danger zone. Phases trigger at health
-- thresholds: summoning adds, shielding itself until its totems are destroyed, enraging.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Sfx = require(script.Parent.Parent.Sfx)
local Effects = require(script.Parent.Parent.Effects)

local AI_TICK = 0.2
local AGGRO_RANGE = 250
local DANGER = Color3.fromRGB(255, 40, 40)
local SAFE = Color3.fromRGB(80, 255, 120)
local PROJECTILE_SPEED = 45 -- enemy shots are slow enough to dodge
local MAX_ADDS = 8

local EnemyService = {}

export type Arena = { Center: Vector3, Size: number }

export type Enemy = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Def: Enemies.EnemyDef,
	Damage: number,
	DamageMultiplier: number,
	Radius: number,
	GroundOffset: number, -- distance from Root center down to the floor
	GetTargets: () -> { Player },
	OnDied: (Enemy) -> (),
	LastAttack: number,
	Busy: boolean,
	Dead: boolean,
	SlowedUntil: number,
	SpeedMultiplier: number,
	-- Bosses
	Phase: number,
	NextMechanic: number,
	AttackReady: { [Enemies.BossAttack]: number },
	PhasesDone: { [number]: boolean },
	Shielded: boolean,
	ShieldAdds: { Enemy },
	ShieldPart: BasePart?,
	EnrageDamage: number,
	GapMultiplier: number,
	Adds: { Enemy },
	Arena: Arena?,
	Summon: ((enemyId: string, position: Vector3) -> Enemy?)?,
	Announce: ((text: string, color: Color3) -> ())?,
	LastImmuneText: number,
	-- Training dummies never move, attack or die; they just track damage.
	Dummy: boolean,
	DummyLabel: TextLabel?,
	DummyHits: { { Time: number, Amount: number } }?,
}

export type SpawnOptions = {
	HealthMultiplier: number,
	DamageMultiplier: number,
	Position: Vector3, -- point on the floor
	Parent: Instance,
	GetTargets: () -> { Player },
	OnDied: (Enemy) -> (),
	Arena: Arena?, -- the room, so boss mechanics stay inside it
	Summon: ((enemyId: string, position: Vector3) -> Enemy?)?, -- spawns adds that count for the room
	Announce: ((text: string, color: Color3) -> ())?,
}

local enemies: { [Enemy]: true } = {}

-- Model building -----------------------------------------------------------

local function weld(root: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function buildModel(def: Enemies.EnemyDef)
	local s = def.Scale
	local material = def.Material or Enum.Material.SmoothPlastic
	local body = def.Body or "Humanoid"
	local model = Instance.new("Model")
	model.Name = def.DisplayName

	local torsoSize = if body == "Beast" then Vector3.new(1.5, 1.3, 2.8) * s elseif body == "Totem" then Vector3.new(1.8, 4, 1.8) * s else Vector3.new(2, 2, 1) * s
	local legHeight = if body == "Beast" then 1.3 * s elseif body == "Totem" then 0 else 2 * s

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = torsoSize
	root.Color = def.BodyColor
	root.Material = material
	root.CFrame = CFrame.new()
	root.Parent = model

	local function limb(name: string, size: Vector3, offset: CFrame | Vector3, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or material
		p.CanCollide = false
		p.Massless = true
		p.CFrame = if typeof(offset) == "Vector3" then root.CFrame + offset else root.CFrame * offset
		p.Parent = model
		weld(root, p)
		return p
	end

	local head: Part
	if body == "Beast" then
		local headCenter = Vector3.new(0, 0.45 * s, -torsoSize.Z / 2 - 0.45 * s)
		head = limb("Head", Vector3.new(1, 0.9, 1.1) * s, headCenter, def.HeadColor)
		limb("Snout", Vector3.new(0.6, 0.45, 0.6) * s, headCenter + Vector3.new(0, -0.15 * s, -0.75 * s), def.HeadColor)
		for _, side in { -1, 1 } do
			limb("Eye", Vector3.new(0.2, 0.2, 0.1) * s, headCenter + Vector3.new(0.28 * s * side, 0.15 * s, -0.56 * s), def.EyeColor, Enum.Material.Neon)
			limb("Ear", Vector3.new(0.25, 0.45, 0.2) * s, headCenter + Vector3.new(0.3 * s * side, 0.6 * s, 0.1 * s), def.BodyColor)
			for _, z in { -1, 1 } do
				limb("Leg", Vector3.new(0.5, legHeight, 0.5) * Vector3.new(s, 1, s), Vector3.new(0.5 * s * side, -torsoSize.Y / 2 - legHeight / 2, z * torsoSize.Z * 0.35), def.BodyColor)
			end
		end
		limb("Tail", Vector3.new(0.3, 0.3, 1.4) * s, CFrame.new(0, 0.3 * s, torsoSize.Z / 2 + 0.5 * s) * CFrame.Angles(math.rad(30), 0, 0), def.BodyColor)
	elseif body == "Totem" then
		head = limb("Head", Vector3.new(2.2, 1.4, 2.2) * s, Vector3.new(0, torsoSize.Y / 2 + 0.7 * s, 0), def.HeadColor)
		for _, side in { -1, 1 } do
			if not def.HeadShape then
				limb("Eye", Vector3.new(0.35, 0.3, 0.1) * s, Vector3.new(0.45 * s * side, torsoSize.Y / 2 + 0.75 * s, -1.12 * s), def.EyeColor, Enum.Material.Neon)
			end
		end
		for i = 1, 3 do
			local rune = limb("Rune", Vector3.new(1.85, 0.25, 1.85) * s, Vector3.new(0, -torsoSize.Y / 2 + i * torsoSize.Y / 4, 0), def.EyeColor, Enum.Material.Neon)
			rune.Transparency = 0.3
		end
		local light = Instance.new("PointLight")
		light.Color = def.EyeColor
		light.Range = 14
		light.Parent = head
	else
		local headY = torsoSize.Y / 2 + 0.6 * s
		head = limb("Head", Vector3.one * 1.2 * s, Vector3.new(0, headY, 0), def.HeadColor)
		for _, side in { -1, 1 } do
			if not def.HeadShape then
				limb("Eye", Vector3.new(0.25, 0.25, 0.1) * s, Vector3.new(0.28 * s * side, headY + 0.1 * s, -0.62 * s), def.EyeColor, Enum.Material.Neon)
			end
			limb("Arm", Vector3.new(0.8, 2, 0.8) * s, Vector3.new(1.4 * s * side, 0, 0), def.BodyColor)
			if body == "Humanoid" then
				limb("Leg", Vector3.new(0.9, 2, 0.9) * s, Vector3.new(0.5 * s * side, -torsoSize.Y / 2 - legHeight / 2, 0), def.BodyColor)
			end
		end
		if body == "Floating" then
			-- A wispy tail instead of legs
			for i = 1, 3 do
				local wisp = limb("Wisp", Vector3.new(1.6 - i * 0.4, 0.7, 0.9 - i * 0.2) * s, Vector3.new(0, -torsoSize.Y / 2 - (i - 0.5) * 0.65 * s, 0.1 * i * s), def.BodyColor)
				wisp.Transparency = 0.2 + i * 0.2
			end
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(def.EyeColor)
			e.LightEmission = 0.6
			e.Size = NumberSequence.new(0.4 * s, 0)
			e.Transparency = NumberSequence.new(0.4, 1)
			e.Lifetime = NumberRange.new(0.6, 1)
			e.Rate = 10
			e.Speed = NumberRange.new(0.5, 1)
			e.Acceleration = Vector3.new(0, -2, 0)
			e.Parent = root
		end

		-- Held weapon on the right arm
		local weapon = def.Weapon
		if weapon then
			local hand = CFrame.new(1.4 * s, -1 * s, -0.4 * s)
			local tilt = CFrame.Angles(math.rad(-35), 0, 0)
			local kind = weapon.Kind
			if kind == "Sword" then
				limb("WeaponBlade", Vector3.new(0.2, 3.2, 0.55) * s, hand * tilt * CFrame.new(0, 1.7 * s, 0), weapon.Color, Enum.Material.Metal)
				limb("WeaponGuard", Vector3.new(0.3, 0.25, 1.2) * s, hand * tilt * CFrame.new(0, 0.1 * s, 0), Color3.fromRGB(60, 55, 60), Enum.Material.Metal)
			elseif kind == "Axe" or kind == "Hammer" then
				limb("WeaponHaft", Vector3.new(0.25, 3.4, 0.25) * s, hand * tilt * CFrame.new(0, 1.2 * s, 0), Color3.fromRGB(70, 50, 35), Enum.Material.Wood)
				if kind == "Axe" then
					limb("WeaponHead", Vector3.new(0.18, 1.1, 1.2) * s, hand * tilt * CFrame.new(0, 2.6 * s, -0.55 * s), weapon.Color, Enum.Material.Metal)
				else
					limb("WeaponHead", Vector3.new(1, 1, 1.8) * s, hand * tilt * CFrame.new(0, 2.8 * s, 0), weapon.Color, Enum.Material.Metal)
				end
			elseif kind == "Scythe" then
				limb("WeaponHaft", Vector3.new(0.22, 5, 0.22) * s, hand * CFrame.new(0, 1.6 * s, 0), Color3.fromRGB(40, 30, 30), Enum.Material.Wood)
				limb("WeaponBlade", Vector3.new(0.15, 0.6, 2.6) * s, hand * CFrame.new(0, 3.9 * s, -1.2 * s) * CFrame.Angles(math.rad(-15), 0, 0), weapon.Color, Enum.Material.Neon)
			else -- Staff
				limb("WeaponHaft", Vector3.new(0.22, 4.5, 0.22) * s, hand * CFrame.new(0, 1.4 * s, 0), weapon.Color, Enum.Material.Wood)
				local orb = limb("WeaponOrb", Vector3.one * 0.7 * s, hand * CFrame.new(0, 3.9 * s, 0), def.EyeColor, Enum.Material.Neon)
				orb.Shape = Enum.PartType.Ball
				local light = Instance.new("PointLight")
				light.Color = def.EyeColor
				light.Range = 10
				light.Parent = orb
			end
		end
	end

	-- Special heads
	if def.HeadShape == "Pumpkin" then
		local size = math.max(head.Size.X, head.Size.Y) * 1.15
		local center = head.CFrame.Position
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.one * size
		head.Material = Enum.Material.SmoothPlastic
		head.CFrame = CFrame.new(center)
		for i = 0, 2 do
			local rib = limb("PumpkinRib", Vector3.new(0.08 * s, size * 1.03, size * 1.03), CFrame.new(center) * CFrame.Angles(0, i / 3 * math.pi, 0), def.HeadColor:Lerp(Color3.fromRGB(150, 60, 10), 0.35), Enum.Material.SmoothPlastic)
			rib.Shape = Enum.PartType.Cylinder
		end
		limb("PumpkinStem", Vector3.new(0.2, 0.4, 0.2) * s, center + Vector3.new(0, size * 0.55, 0), Color3.fromRGB(70, 100, 40), Enum.Material.Wood)
		for _, side in { -1, 1 } do
			limb("Eye", Vector3.new(0.3, 0.25, 0.08) * s, CFrame.new(center + Vector3.new(side * size * 0.2, size * 0.1, -size * 0.48)) * CFrame.Angles(0, 0, math.rad(side * 15)), def.EyeColor, Enum.Material.Neon)
		end
		limb("Grin", Vector3.new(size * 0.55, 0.14 * s, 0.08 * s), center + Vector3.new(0, -size * 0.17, -size * 0.47), def.EyeColor, Enum.Material.Neon)
		local glow = Instance.new("PointLight")
		glow.Color = def.EyeColor
		glow.Range = 10 * s
		glow.Parent = head
	elseif def.HeadShape == "Headless" then
		head.Transparency = 1
		local neck = limb("Neck", Vector3.new(0.8, 0.3, 0.8) * s, head.CFrame.Position - Vector3.new(0, head.Size.Y / 2, 0), def.BodyColor)
		local fire = Instance.new("Fire")
		fire.Color = def.EyeColor
		fire.SecondaryColor = Color3.fromRGB(120, 20, 10)
		fire.Size = 3 * s
		fire.Heat = 8
		fire.Parent = neck
	end

	-- Crowns and horns
	local top = head.CFrame.Position.Y + head.Size.Y / 2
	if def.Crown then
		limb("CrownBand", Vector3.new(head.Size.X * 1.05, 0.3 * s, head.Size.Z * 1.05), Vector3.new(head.CFrame.Position.X, top + 0.1 * s, head.CFrame.Position.Z), def.Crown, Enum.Material.Metal)
		for i = -2, 2 do
			limb("CrownPoint", Vector3.new(0.18, 0.45, 0.18) * s, Vector3.new(head.CFrame.Position.X + i * head.Size.X * 0.2, top + 0.45 * s, head.CFrame.Position.Z - head.Size.Z * 0.5), def.Crown, Enum.Material.Neon)
		end
	end
	if def.Horns then
		for _, side in { -1, 1 } do
			local base = CFrame.new(head.CFrame.Position + Vector3.new(side * head.Size.X * 0.45, head.Size.Y * 0.3, 0))
			limb("Horn", Vector3.new(0.25, 0.8, 0.25) * s, base * CFrame.Angles(0, 0, math.rad(-side * 35)) * CFrame.new(0, 0.4 * s, 0), def.Horns, Enum.Material.Slate)
		end
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

	if def.Static then
		root.Anchored = true
	end

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
	name.TextColor3 = if isBoss then Color3.fromRGB(255, 120, 120) elseif enemy.Def.Static then Color3.fromRGB(255, 220, 120) else Color3.new(1, 1, 1)
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
	enemy.Model:GetAttributeChangedSignal("Shielded"):Connect(function()
		fill.BackgroundColor3 = if enemy.Model:GetAttribute("Shielded") then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(220, 50, 50)
	end)
end

-- Effects ------------------------------------------------------------------

local function showDamageNumber(enemy: Enemy, amount: number, isCrit: boolean, color: Color3?)
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
	label.TextColor3 = color or if isCrit then Color3.fromRGB(255, 200, 40) else Color3.new(1, 1, 1)
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

local function floatingText(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 36)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.6), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	Debris:AddItem(gui, 0.6)
end

-- Players ------------------------------------------------------------------

-- Hurts a player's character, reduced by their Defense (armor, class, buffs).
-- Dodging (and admin god mode) makes you immune.
local function damagePlayer(humanoid: Humanoid, amount: number)
	local character = humanoid.Parent
	if character and (character:GetAttribute("God") or (character:GetAttribute("InvulnerableUntil") or 0) > os.clock()) then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			floatingText(root, if character:GetAttribute("God") then "Immune" else "Dodged!", Color3.fromRGB(150, 230, 255))
		end
		return
	end
	local defense = character and character:GetAttribute("Defense") or 0
	local dealt = amount * (1 - defense)
	-- Seraph passive: cheat death once per life
	if character and dealt >= humanoid.Health and character:GetAttribute("Revive") then
		character:SetAttribute("Revive", nil)
		character:SetAttribute("InvulnerableUntil", os.clock() + 2)
		humanoid.Health = humanoid.MaxHealth * 0.5
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			floatingText(root, "REVIVED!", Color3.fromRGB(255, 230, 140))
			Sfx.play("LevelUp", root)
		end
		flash(character :: Model, Color3.fromRGB(255, 240, 180))
		return
	end
	humanoid:TakeDamage(dealt)
	if character then
		flash(character :: Model, Color3.fromRGB(255, 60, 60))
	end
end

-- Living, visible targets as (humanoid, root) pairs.
local function livingTargets(enemy: Enemy): { { Humanoid: Humanoid, Root: BasePart } }
	local list = {}
	for _, player in enemy.GetTargets() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			table.insert(list, { Humanoid = humanoid, Root = root })
		end
	end
	return list
end

-- Damages every player whose position passes `test`.
local function hurtWhere(enemy: Enemy, damage: number, test: (Vector3) -> boolean)
	for _, target in livingTargets(enemy) do
		if test(target.Root.Position) then
			damagePlayer(target.Humanoid, damage)
		end
	end
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function findTarget(enemy: Enemy): (Humanoid?, BasePart?, number)
	local bestHumanoid, bestRoot, bestDistance = nil, nil, AGGRO_RANGE
	for _, player in enemy.GetTargets() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 and not (character :: Model):GetAttribute("Vanished") then
			local distance = (root.Position - enemy.Root.Position).Magnitude
			if distance < bestDistance then
				bestHumanoid, bestRoot, bestDistance = humanoid, root, distance
			end
		end
	end
	return bestHumanoid, bestRoot, bestDistance
end

local function faceTowards(enemy: Enemy, position: Vector3)
	if enemy.Def.Static then
		return
	end
	local from = enemy.Root.Position
	local flat = Vector3.new(position.X, from.Y, position.Z)
	if (flat - from).Magnitude > 0.1 then
		enemy.Root.CFrame = CFrame.lookAt(from, flat)
	end
end

-- Telegraphs ------------------------------------------------------------------

local function groundOf(enemy: Enemy): Vector3
	return enemy.Root.Position - Vector3.new(0, enemy.GroundOffset, 0)
end

-- Keeps a point inside the boss's room.
local function clampToArena(enemy: Enemy, point: Vector3, margin: number): Vector3
	local arena = enemy.Arena
	if not arena then
		return point
	end
	local half = arena.Size / 2 - margin
	return Vector3.new(
		math.clamp(point.X, arena.Center.X - half, arena.Center.X + half),
		point.Y,
		math.clamp(point.Z, arena.Center.Z - half, arena.Center.Z + half)
	)
end

local function disc(center: Vector3, radius: number, color: Color3, transparency: number, height: number?): Part
	return Effects.part({
		Name = "Telegraph",
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Transparency = transparency,
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, height or 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

-- Danger circle with an inner circle that grows until it's full: then it hits.
local function telegraphCircle(center: Vector3, radius: number, windup: number, color: Color3?)
	local outer = disc(center, radius, color or DANGER, 0.7)
	local inner = disc(center, 0.5, color or DANGER, 0.45, 0.16)
	TweenService:Create(inner, TweenInfo.new(windup, Enum.EasingStyle.Linear), { Size = Vector3.new(0.12, radius * 2, radius * 2) }):Play()
	Debris:AddItem(outer, windup)
	Debris:AddItem(inner, windup)
end

-- Danger lane from `from` along `direction` (flat).
local function telegraphLane(from: Vector3, direction: Vector3, length: number, width: number, windup: number)
	local facing = CFrame.lookAt(from, from + direction)
	local lane = Effects.part({ Name = "Telegraph", Color = DANGER, Transparency = 0.7, Size = Vector3.new(width, 0.12, length), CFrame = facing * CFrame.new(0, 0.12, -length / 2) })
	local fill = Effects.part({ Name = "Telegraph", Color = DANGER, Transparency = 0.45, Size = Vector3.new(width, 0.14, 0.2), CFrame = facing * CFrame.new(0, 0.16, -0.1) })
	TweenService:Create(fill, TweenInfo.new(windup, Enum.EasingStyle.Linear), { Size = Vector3.new(width, 0.14, length), CFrame = facing * CFrame.new(0, 0.16, -length / 2) }):Play()
	Debris:AddItem(lane, windup)
	Debris:AddItem(fill, windup)
end

local function inLane(point: Vector3, from: Vector3, direction: Vector3, length: number, width: number): boolean
	local offset = Vector3.new(point.X - from.X, 0, point.Z - from.Z)
	local along = offset:Dot(direction)
	if along < -1 or along > length then
		return false
	end
	return (offset - direction * along).Magnitude <= width / 2
end

-- Boss mechanics ----------------------------------------------------------------

local function attackDamage(enemy: Enemy, attack: Enemies.BossAttack): number
	return (attack.Damage or 25) * enemy.DamageMultiplier * enemy.EnrageDamage
end

local function slamVisual(center: Vector3, radius: number, color: Color3)
	Effects.burst(center, radius, color, 0.35)
	Effects.ring(center, radius * 1.1, color, 0.4)
	Effects.sparks(center + Vector3.new(0, 1, 0), color, "Smoke", 25)
	Sfx.play("Slam", center)
end

local MECHANICS: { [string]: (Enemy, Enemies.BossAttack, BasePart?) -> () } = {}

MECHANICS.Slam = function(enemy, attack)
	local center = groundOf(enemy)
	local radius = attack.Radius or 15
	local windup = attack.Windup or 1.2
	telegraphCircle(center, radius, windup)
	task.wait(windup)
	if enemy.Dead then
		return
	end
	slamVisual(center, radius, (enemy.Def.Boss :: Enemies.BossDef).Color)
	hurtWhere(enemy, attackDamage(enemy, attack), function(p)
		return flatDistance(p, center) <= radius
	end)
end

MECHANICS.Donut = function(enemy, attack)
	local center = groundOf(enemy)
	local safe = attack.Radius or 9
	local outer = attack.Range or 40
	local windup = attack.Windup or 1.6
	local danger = disc(center, outer, DANGER, 0.65)
	local safeZone = disc(center, safe, SAFE, 0.35, 0.2)
	Debris:AddItem(danger, windup)
	Debris:AddItem(safeZone, windup)
	task.wait(windup)
	if enemy.Dead then
		return
	end
	local color = (enemy.Def.Boss :: Enemies.BossDef).Color
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		local r = (safe + outer) / 2
		Effects.spike(center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 5, color, Enum.Material.Neon)
	end
	Effects.ring(center, outer, color, 0.4)
	Sfx.play("Slam", center, 1.3)
	hurtWhere(enemy, attackDamage(enemy, attack), function(p)
		local d = flatDistance(p, center)
		return d > safe and d <= outer
	end)
end

MECHANICS.Charge = function(enemy, attack, targetRoot)
	if not targetRoot then
		return
	end
	local from = groundOf(enemy)
	local flat = Vector3.new(targetRoot.Position.X - from.X, 0, targetRoot.Position.Z - from.Z)
	local direction = if flat.Magnitude > 0.5 then flat.Unit else enemy.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local finish = clampToArena(enemy, from + direction * (attack.Range or 40), enemy.Radius + 3)
	local length = (finish - from).Magnitude
	local width = attack.Width or 7
	local windup = attack.Windup or 1
	faceTowards(enemy, from + direction)
	telegraphLane(from, direction, length, width, windup)
	task.wait(windup)
	if enemy.Dead then
		return
	end
	-- Rush down the lane (the humanoid runs it, so it moves smoothly)
	local rushTime = 0.4
	enemy.Humanoid.WalkSpeed = math.max(length / rushTime, enemy.Def.Speed)
	enemy.Humanoid:MoveTo(finish + Vector3.new(0, enemy.GroundOffset, 0))
	task.wait(rushTime)
	enemy.Humanoid.WalkSpeed = enemy.Def.Speed * enemy.SpeedMultiplier
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	Effects.sparks(enemy.Root.Position, (enemy.Def.Boss :: Enemies.BossDef).Color, "Smoke", 20)
	Sfx.play("Slam", enemy.Root, 0.8)
	hurtWhere(enemy, attackDamage(enemy, attack), function(p)
		return inLane(p, from, direction, length + 2, width)
	end)
end

MECHANICS.Barrage = function(enemy, attack)
	local radius = attack.Radius or 5
	local windup = attack.Windup or 1.1
	local centers = {}
	for _, target in livingTargets(enemy) do
		local center = target.Root.Position - Vector3.new(0, 2.9, 0)
		table.insert(centers, center)
		telegraphCircle(center, radius, windup)
	end
	task.wait(windup)
	if enemy.Dead then
		return
	end
	local color = (enemy.Def.Boss :: Enemies.BossDef).Color
	for _, center in centers do
		Effects.pillar(center, radius * 0.6, color, 0.4)
		Effects.spike(center, 4, color, Enum.Material.Neon)
	end
	Sfx.play("Slam", enemy.Root, 0.8)
	hurtWhere(enemy, attackDamage(enemy, attack), function(p)
		for _, center in centers do
			if flatDistance(p, center) <= radius then
				return true
			end
		end
		return false
	end)
end

MECHANICS.Meteors = function(enemy, attack)
	local radius = attack.Radius or 6
	local windup = attack.Windup or 1.3
	local color = (enemy.Def.Boss :: Enemies.BossDef).Color
	local ground = groundOf(enemy)
	local points = {}
	for _, target in livingTargets(enemy) do
		table.insert(points, target.Root.Position - Vector3.new(0, 2.9, 0))
	end
	local spread = if enemy.Arena then enemy.Arena.Size / 2 - 6 else 30
	local center = if enemy.Arena then Vector3.new(enemy.Arena.Center.X, ground.Y, enemy.Arena.Center.Z) else ground
	while #points < (attack.Count or 8) do
		table.insert(points, center + Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread)))
	end
	local damage = attackDamage(enemy, attack)
	for i, point in points do
		task.delay((i - 1) * 0.08, function()
			Effects.meteor(point, color, windup, radius, function()
				if not enemy.Dead then
					hurtWhere(enemy, damage, function(p)
						return flatDistance(p, point) <= radius
					end)
				end
			end)
		end)
	end
	task.wait(windup + #points * 0.08)
end

MECHANICS.Cross = function(enemy, attack)
	local center = groundOf(enemy)
	local length = attack.Range or 45
	local width = attack.Width or 6
	local windup = attack.Windup or 1.4
	local offset = if math.random() < 0.5 then 0 else math.pi / 4
	local directions = {}
	for i = 0, 3 do
		local angle = offset + i * math.pi / 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		table.insert(directions, direction)
		telegraphLane(center, direction, length, width, windup)
	end
	task.wait(windup)
	if enemy.Dead then
		return
	end
	local color = (enemy.Def.Boss :: Enemies.BossDef).Color
	for _, direction in directions do
		Effects.beam(center + Vector3.new(0, 2, 0), center + direction * length + Vector3.new(0, 2, 0), color, width * 0.6, 0.4)
	end
	Sfx.play("Slam", center, 1.2)
	hurtWhere(enemy, attackDamage(enemy, attack), function(p)
		for _, direction in directions do
			if inLane(p, center, direction, length, width) then
				return true
			end
		end
		return false
	end)
end

-- An expanding ring: only a dodge (or being far enough away) avoids it.
MECHANICS.Wave = function(enemy, attack)
	local center = groundOf(enemy)
	local maxRadius = attack.Range or 45
	local windup = attack.Windup or 1
	local color = (enemy.Def.Boss :: Enemies.BossDef).Color
	for _ = 1, 3 do
		Effects.ring(center, 8, DANGER, windup / 3)
		task.wait(windup / 3)
	end
	if enemy.Dead then
		return
	end
	local speed = 32
	local duration = maxRadius / speed
	local ring = Effects.part({
		Name = "Wave",
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Transparency = 0.25,
		Size = Vector3.new(2.5, 2, 2),
		CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(2.5, maxRadius * 2, maxRadius * 2), Transparency = 0.7 }):Play()
	Debris:AddItem(ring, duration)
	Sfx.play("Slam", center, 1.1)
	local damage = attackDamage(enemy, attack)
	local hit: { [Humanoid]: boolean } = {}
	local started = os.clock()
	while os.clock() - started < duration do
		local radius = (os.clock() - started) * speed
		for _, target in livingTargets(enemy) do
			if not hit[target.Humanoid] and math.abs(flatDistance(target.Root.Position, center) - radius) <= 2.5 then
				hit[target.Humanoid] = true
				damagePlayer(target.Humanoid, damage)
			end
		end
		task.wait(0.05)
	end
end

local function summonAdds(enemy: Enemy, adds: { [string]: number }, radius: number): { Enemy }
	local spawned = {}
	if not enemy.Summon then
		return spawned
	end
	local ground = groundOf(enemy)
	local total = 0
	for _, count in adds do
		total += count
	end
	local i = 0
	for enemyId, count in adds do
		for _ = 1, count do
			i += 1
			local angle = i / total * math.pi * 2
			local position = clampToArena(enemy, ground + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), 4)
			Effects.pillar(position, 2, (enemy.Def.Boss :: Enemies.BossDef).Color, 0.5)
			local add = enemy.Summon(enemyId, position)
			if add then
				table.insert(spawned, add)
				table.insert(enemy.Adds, add)
			end
		end
	end
	return spawned
end

MECHANICS.Summon = function(enemy, attack)
	Effects.burst(enemy.Root.Position, 8, (enemy.Def.Boss :: Enemies.BossDef).Color, 0.4)
	summonAdds(enemy, attack.Adds or {}, 10)
	task.wait(0.8)
end

local function aliveAdds(enemy: Enemy): number
	local count = 0
	for i = #enemy.Adds, 1, -1 do
		if enemy.Adds[i].Dead then
			table.remove(enemy.Adds, i)
		else
			count += 1
		end
	end
	return count
end

local function announce(enemy: Enemy, text: string?)
	if text and enemy.Announce then
		enemy.Announce(text, (enemy.Def.Boss :: Enemies.BossDef).Color)
	end
end

local function setShield(enemy: Enemy, on: boolean)
	enemy.Shielded = on
	enemy.Model:SetAttribute("Shielded", on)
	if on then
		local bubble = Instance.new("Part")
		bubble.Name = "Shield"
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.one * (enemy.Root.Size.Y * 2.6 + 4)
		bubble.CFrame = enemy.Root.CFrame
		bubble.Color = Color3.fromRGB(120, 200, 255)
		bubble.Material = Enum.Material.ForceField
		bubble.Transparency = 0.2
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.Massless = true
		weld(enemy.Root, bubble)
		bubble.Parent = enemy.Model
		enemy.ShieldPart = bubble
	else
		if enemy.ShieldPart then
			enemy.ShieldPart:Destroy()
			enemy.ShieldPart = nil
		end
		Effects.burst(enemy.Root.Position, 12, Color3.fromRGB(120, 200, 255), 0.4)
		Sfx.play("Slam", enemy.Root, 1)
	end
end

local function checkPhases(enemy: Enemy)
	local boss = enemy.Def.Boss :: Enemies.BossDef
	local ratio = enemy.Humanoid.Health / enemy.Humanoid.MaxHealth
	for index, phase in boss.Phases or {} do
		if not enemy.PhasesDone[index] and ratio <= phase.At then
			enemy.PhasesDone[index] = true
			enemy.Phase += 1
			announce(enemy, phase.Message)
			if phase.Type == "Summon" then
				summonAdds(enemy, phase.Adds or {}, 12)
			elseif phase.Type == "Shield" then
				setShield(enemy, true)
				-- Totems go out toward the edges of the room
				enemy.ShieldAdds = summonAdds(enemy, phase.Adds or {}, if enemy.Arena then enemy.Arena.Size * 0.32 else 20)
				if #enemy.ShieldAdds == 0 then
					setShield(enemy, false)
				end
			elseif phase.Type == "Enrage" then
				enemy.EnrageDamage = phase.Damage or 1.25
				enemy.Damage *= enemy.EnrageDamage
				enemy.SpeedMultiplier = phase.Speed or 1.3
				enemy.Humanoid.WalkSpeed = enemy.Def.Speed * enemy.SpeedMultiplier
				enemy.GapMultiplier = 0.7
				local glow = Instance.new("Highlight")
				glow.FillColor = Color3.fromRGB(255, 40, 40)
				glow.FillTransparency = 0.75
				glow.OutlineColor = Color3.fromRGB(255, 80, 40)
				glow.Parent = enemy.Model
				Effects.burst(enemy.Root.Position, 14, Color3.fromRGB(255, 60, 40), 0.5)
			end
		end
	end
	if enemy.Shielded then
		local standing = false
		for _, add in enemy.ShieldAdds do
			if not add.Dead then
				standing = true
			end
		end
		if not standing then
			setShield(enemy, false)
			announce(enemy, `{enemy.Def.DisplayName}'s shield shatters!`)
		end
	end
end

local function pickAttack(enemy: Enemy, now: number, distance: number): Enemies.BossAttack?
	local boss = enemy.Def.Boss :: Enemies.BossDef
	local options = {}
	for _, attack in boss.Attacks do
		local ready = now >= (enemy.AttackReady[attack] or 0) and (attack.Phase or 1) <= enemy.Phase
		if ready and attack.Type == "Slam" and distance > (attack.Radius or 15) + 4 then
			ready = false -- only slam when someone is close
		end
		if ready and attack.Type == "Summon" and aliveAdds(enemy) >= MAX_ADDS then
			ready = false
		end
		if ready then
			table.insert(options, attack)
		end
	end
	if #options == 0 then
		return nil
	end
	return options[math.random(#options)]
end

local function runMechanic(enemy: Enemy, attack: Enemies.BossAttack, targetRoot: BasePart?)
	enemy.Busy = true
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	if targetRoot then
		faceTowards(enemy, targetRoot.Position)
	end
	announce(enemy, attack.Message)
	local ok, err = pcall(MECHANICS[attack.Type], enemy, attack, targetRoot)
	if not ok then
		warn(`[EnemyService] {attack.Type} failed: {err}`)
	end
	enemy.Busy = false
	local boss = enemy.Def.Boss :: Enemies.BossDef
	enemy.NextMechanic = os.clock() + boss.Gap * enemy.GapMultiplier
end

-- AI -----------------------------------------------------------------------

local function shoot(enemy: Enemy, targetRoot: BasePart)
	local ranged = enemy.Def.Ranged :: { Projectile: string, Color: Color3 }
	local head = enemy.Model:FindFirstChild("Head") :: BasePart?
	local from = if head then head.Position else enemy.Root.Position
	local to = targetRoot.Position
	local damage = enemy.Damage
	Effects.projectile(ranged.Projectile, from, to, ranged.Color, function()
		if enemy.Dead then
			return
		end
		Effects.sparks(to, ranged.Color, nil, 8)
		-- Hits whoever is standing where the shot lands (so you can sidestep it)
		hurtWhere(enemy, damage, function(p)
			return (p - to).Magnitude <= 3.5
		end)
	end, PROJECTILE_SPEED)
end

local function think(enemy: Enemy, now: number)
	local boss = enemy.Def.Boss
	if boss then
		checkPhases(enemy)
	end
	if enemy.Busy then
		return
	end
	local targetHumanoid, targetRoot, distance = findTarget(enemy)
	if not targetHumanoid or not targetRoot then
		if not enemy.Def.Static then
			enemy.Humanoid:MoveTo(enemy.Root.Position)
		end
		return
	end

	if boss and now >= enemy.NextMechanic then
		local attack = pickAttack(enemy, now, distance)
		if attack then
			enemy.AttackReady[attack] = now + attack.Cooldown * enemy.GapMultiplier
			enemy.Busy = true
			task.spawn(runMechanic, enemy, attack, targetRoot)
			return
		end
	end

	local def = enemy.Def
	if distance > def.AttackRange + enemy.Radius then
		if not def.Static then
			enemy.Humanoid:MoveTo(targetRoot.Position)
		end
		return
	end

	if not def.Static then
		enemy.Humanoid:MoveTo(enemy.Root.Position)
	end
	faceTowards(enemy, targetRoot.Position)
	if now - enemy.LastAttack >= def.AttackCooldown then
		enemy.LastAttack = now
		if def.Ranged then
			shoot(enemy, targetRoot)
		elseif def.Damage > 0 then
			damagePlayer(targetHumanoid, enemy.Damage)
		end
	end
end

-- Public API ---------------------------------------------------------------

function EnemyService.Spawn(enemyId: string, options: SpawnOptions): Enemy
	local def = Enemies[enemyId]
	assert(def, `Unknown enemy {enemyId}`)

	local model, root, head, humanoid, groundOffset = buildModel(def)
	humanoid.MaxHealth = math.floor(def.Health * options.HealthMultiplier)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = def.Speed

	local enemy: Enemy = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Def = def,
		Damage = def.Damage * options.DamageMultiplier,
		DamageMultiplier = options.DamageMultiplier,
		Radius = math.max(root.Size.X, root.Size.Z) / 2,
		GroundOffset = groundOffset,
		GetTargets = options.GetTargets,
		OnDied = options.OnDied,
		LastAttack = 0,
		Busy = false,
		Dead = false,
		SlowedUntil = 0,
		SpeedMultiplier = 1,
		Phase = 1,
		-- Give players a moment before the first mechanic.
		NextMechanic = os.clock() + 3,
		AttackReady = {},
		PhasesDone = {},
		Shielded = false,
		ShieldAdds = {},
		ShieldPart = nil,
		EnrageDamage = 1,
		GapMultiplier = 1,
		Adds = {},
		Arena = options.Arena,
		Summon = options.Summon,
		Announce = options.Announce,
		LastImmuneText = 0,
		Dummy = false,
	}
	buildHealthBar(enemy, head)

	-- Face a random direction so groups don't look copy-pasted.
	model:PivotTo(CFrame.new(options.Position + Vector3.new(0, groundOffset, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model.Parent = options.Parent
	if not root.Anchored then
		root:SetNetworkOwner(nil) -- server simulates enemies, so exploiters can't fling them
	end

	humanoid.Died:Connect(function()
		if enemy.Dead then
			return
		end
		enemy.Dead = true
		enemies[enemy] = nil
		Sfx.play("EnemyDeath", root.Position)
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

-- Turns a static model into a target players can practice on. The model needs a
-- HumanoidRootPart (anchored) and a Head part for the label.
function EnemyService.RegisterDummy(model: Model, displayName: string): Enemy
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = 0
	humanoid.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y + 1.2, 0)
	gui.MaxDistance = 80
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = `{displayName}\nHit me!`
	label.Parent = gui

	local enemy: Enemy = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Def = Enemies.Skeleton, -- unused for dummies, keeps the type happy
		Damage = 0,
		DamageMultiplier = 0,
		Radius = math.max(root.Size.X, root.Size.Z) / 2,
		GroundOffset = root.CFrame.Position.Y,
		GetTargets = function()
			return {}
		end,
		OnDied = function() end,
		LastAttack = 0,
		Busy = false,
		Dead = false,
		SlowedUntil = 0,
		SpeedMultiplier = 1,
		Phase = 1,
		NextMechanic = 0,
		AttackReady = {},
		PhasesDone = {},
		Shielded = false,
		ShieldAdds = {},
		EnrageDamage = 1,
		GapMultiplier = 1,
		Adds = {},
		LastImmuneText = 0,
		Dummy = true,
		DummyLabel = label,
		DummyHits = {},
	}
	enemies[enemy] = true
	return enemy
end

local DPS_WINDOW = 5

local function updateDummy(enemy: Enemy, now: number)
	local hits = enemy.DummyHits :: { { Time: number, Amount: number } }
	local total, last = 0, nil
	for i = #hits, 1, -1 do
		if now - hits[i].Time > DPS_WINDOW then
			table.remove(hits, i)
		else
			total += hits[i].Amount
			last = last or hits[i].Amount
		end
	end
	local label = enemy.DummyLabel :: TextLabel
	if #hits == 0 then
		label.Text = `{enemy.Model.Name}\nHit me!`
	else
		local span = math.max(1, now - hits[1].Time)
		label.Text = `DPS: {math.floor(total / span)}\nLast hit: {last}`
	end
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

-- `color` tints the damage number (used for burn ticks etc).
function EnemyService.Damage(enemy: Enemy, amount: number, isCrit: boolean, color: Color3?): number
	if enemy.Dead then
		return 0
	end
	if enemy.Shielded then
		local now = os.clock()
		if now - enemy.LastImmuneText > 0.6 then
			enemy.LastImmuneText = now
			floatingText(enemy.Root, "SHIELDED", Color3.fromRGB(120, 200, 255))
		end
		return 0
	end
	amount = math.max(1, math.floor(amount))
	showDamageNumber(enemy, amount, isCrit, color)
	flash(enemy.Model, color or Color3.new(1, 1, 1))
	Sfx.play("Hit", enemy.Root, if isCrit then 1.4 else 0.8)
	if enemy.Dummy then
		-- Dummies don't lose health; they record hits for the damage-per-second readout.
		local now = os.clock()
		local hits = enemy.DummyHits :: { { Time: number, Amount: number } }
		table.insert(hits, { Time = now, Amount = amount })
		return amount
	end
	enemy.Humanoid.Health = math.max(0, enemy.Humanoid.Health - amount)
	return amount
end

-- Bosses and totems can't be shoved around or frozen by player abilities.
local function immovable(enemy: Enemy): boolean
	return enemy.Dead or enemy.Dummy or enemy.Def.Static == true or enemy.Def.Boss ~= nil
end

-- Drags an enemy `step` studs toward a point (vortexes, collapses).
function EnemyService.Pull(enemy: Enemy, toward: Vector3, step: number)
	if immovable(enemy) then
		return
	end
	local offset = (toward - enemy.Root.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude > 1 then
		enemy.Root.CFrame += offset.Unit * math.min(step, offset.Magnitude - 1)
	end
end

-- Stops an enemy from moving or attacking for `duration` seconds. Bosses are only
-- stunned for a third as long, and never in the middle of a mechanic.
function EnemyService.Stun(enemy: Enemy, duration: number)
	if enemy.Dead or enemy.Dummy or enemy.Def.Static then
		return
	end
	if enemy.Def.Boss then
		if enemy.Busy then
			return
		end
		duration /= 3
	end
	enemy.Busy = true
	enemy.Humanoid.WalkSpeed = 0
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	local until_ = os.clock() + duration
	enemy.SlowedUntil = math.max(enemy.SlowedUntil, until_)
	task.delay(duration, function()
		if not enemy.Dead and os.clock() >= enemy.SlowedUntil - 0.05 then
			enemy.Busy = false
			enemy.Humanoid.WalkSpeed = enemy.Def.Speed * enemy.SpeedMultiplier
		end
	end)
end

-- Throws an enemy away from a point.
function EnemyService.Knockback(enemy: Enemy, from: Vector3, force: number)
	if immovable(enemy) then
		return
	end
	local away = (enemy.Root.Position - from) * Vector3.new(1, 0, 1)
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
	enemy.Root.AssemblyLinearVelocity = direction * force + Vector3.new(0, force * 0.4, 0)
end

-- Slows an enemy by `fraction` (0.4 = 40% slower) for `duration` seconds.
function EnemyService.Slow(enemy: Enemy, fraction: number, duration: number)
	if enemy.Dead or enemy.Def.Static then
		return
	end
	local untilTime = os.clock() + duration
	enemy.SlowedUntil = math.max(enemy.SlowedUntil, untilTime)
	enemy.Humanoid.WalkSpeed = enemy.Def.Speed * enemy.SpeedMultiplier * (1 - fraction)
	task.delay(duration, function()
		if not enemy.Dead and os.clock() >= enemy.SlowedUntil - 0.05 then
			enemy.Humanoid.WalkSpeed = enemy.Def.Speed * enemy.SpeedMultiplier
		end
	end)
end

function EnemyService.Start()
	task.spawn(function()
		while true do
			task.wait(AI_TICK)
			local now = os.clock()
			for enemy in enemies do
				if enemy.Dummy then
					updateDummy(enemy, now)
				elseif enemy.Root.Parent then
					think(enemy, now)
				else
					enemies[enemy] = nil
				end
			end
		end
	end)
end

return EnemyService
