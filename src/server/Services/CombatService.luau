-- Player combat: builds weapon and armor models, handles attacks, weapon effects and
-- class abilities. Everything is checked on the server (cooldowns, range, damage).
--
-- Attacking: the client sends the direction it's aiming (toward the mouse). Swords hit
-- an arc in that direction; staffs and bows auto-target the enemy closest to your aim.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)
local Sfx = require(script.Parent.Parent.Sfx)

local TOOL_ATTRIBUTE = "WeaponId"
local ARMOR_FOLDER = "ArmorVisual"
local BACK_MODEL = "SheathedWeapon"
local PROJECTILE_SPEED = { Staff = 90, Bow = 150 }
local BURN_COLOR = Color3.fromRGB(255, 140, 40)
local FROST_COLOR = Color3.fromRGB(140, 220, 255)

local CombatService = {}

local lastAttack: { [Player]: number } = {}
local abilityReadyAt: { [Player]: { [string]: number } } = {}

-- Helpers --------------------------------------------------------------------

local function getAlive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

-- Turns whatever the client sent into a safe flat unit direction.
local function sanitizeAim(aim: unknown, root: BasePart): Vector3
	if typeof(aim) == "Vector3" then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude > 0.01 and flat.Magnitude == flat.Magnitude then -- second check rejects NaN
			return flat.Unit
		end
	end
	local look = root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

local function rollDamage(player: Player, base: number): (number, boolean)
	local amount = base * PlayerService.GetDamageMultiplier(player) * (0.9 + math.random() * 0.2)
	local isCrit = math.random() < Config.CritChance
	if isCrit then
		amount *= Config.CritMultiplier
	end
	return amount, isCrit
end

local function effectPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = workspace
	return p
end

-- Expanding flat ring on the floor (abilities).
local function ringEffect(center: Vector3, radius: number, color: Color3)
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Transparency = 0.3,
		Size = Vector3.new(0.4, 2, 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
	})
	TweenService:Create(ring, TweenInfo.new(0.3), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.35)
end

local function burstEffect(center: Vector3, radius: number, color: Color3)
	local ball = effectPart({
		Shape = Enum.PartType.Ball,
		Color = color,
		Transparency = 0.3,
		Size = Vector3.one * 2,
		Position = center,
	})
	TweenService:Create(ball, TweenInfo.new(0.3), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.35)
end

-- Flies a projectile from `from` to `to`, then calls onArrive. Returns nothing.
local function fireProjectile(kind: string, from: Vector3, to: Vector3, color: Color3, onArrive: () -> ())
	local distance = (to - from).Magnitude
	local travel = math.max(0.05, distance / (PROJECTILE_SPEED[kind] or 120))
	local projectile
	if kind == "Bow" then
		projectile = effectPart({
			Size = Vector3.new(0.15, 0.15, 2.5),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.lookAt(from, to),
		})
	else
		projectile = effectPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (if kind == "Fireball" then 2.5 else 1.2),
			Color = color,
			CFrame = CFrame.lookAt(from, to),
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Parent = projectile
	end
	TweenService:Create(projectile, TweenInfo.new(travel, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from).Unit),
	}):Play()
	Debris:AddItem(projectile, travel + 0.05)
	task.delay(travel, onArrive)
end

-- The enemy closest to where you're aiming (within range and a forward cone).
local function findAimTarget(origin: Vector3, aim: Vector3, range: number, minDot: number): EnemyService.Enemy?
	local best, bestScore = nil, math.huge
	for _, enemy in EnemyService.GetEnemiesNear(origin, range) do
		local offset = enemy.Root.Position - origin
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local dot = if flat.Magnitude > 0.01 then flat.Unit:Dot(aim) else 1
		if dot >= minDot then
			local score = flat.Magnitude * (2 - dot)
			if score < bestScore then
				best, bestScore = enemy, score
			end
		end
	end
	return best
end

-- Weapon effects -------------------------------------------------------------

local function applyEffect(player: Player, enemy: EnemyService.Enemy, effect: Items.Effect?, dealt: number)
	if not effect or dealt <= 0 then
		return
	end
	if effect.Type == "Lifesteal" then
		local humanoid = getAlive(player)
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dealt * effect.Amount)
		end
	elseif effect.Type == "Frost" then
		EnemyService.Slow(enemy, effect.Amount, effect.Duration or 2)
	elseif effect.Type == "Burn" then
		local tick = dealt * effect.Amount
		task.spawn(function()
			for _ = 1, effect.Duration or 3 do
				task.wait(1)
				if enemy.Dead then
					return
				end
				EnemyService.Damage(enemy, tick, false, BURN_COLOR)
			end
		end)
	end
end

local function hit(player: Player, enemy: EnemyService.Enemy, baseDamage: number, weapon: Items.WeaponDef)
	local amount, isCrit = rollDamage(player, baseDamage)
	local color = if weapon.Effect and weapon.Effect.Type == "Frost" then FROST_COLOR else nil
	local dealt = EnemyService.Damage(enemy, amount, isCrit, if isCrit then nil else color)
	applyEffect(player, enemy, weapon.Effect, dealt)
end

-- Attacks ----------------------------------------------------------------------

local function swordAttack(player: Player, root: BasePart, aim: Vector3, weapon: Items.WeaponDef)
	local slash = effectPart({
		Color = weapon.Color,
		Transparency = 0.4,
		Size = Vector3.new(weapon.Range * 1.4, 0.2, 1.2),
		CFrame = CFrame.lookAt(root.Position, root.Position + aim)
			* CFrame.new(0, 0.5, -weapon.Range / 2)
			* CFrame.Angles(0, math.rad(math.random(-25, 25)), math.rad(math.random(-30, 30))),
	})
	TweenService:Create(slash, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(slash, 0.2)

	for _, enemy in EnemyService.GetEnemiesNear(root.Position, weapon.Range) do
		local offset = enemy.Root.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		-- Hit enemies in a wide arc in front of you (or ones basically on top of you).
		if flat.Magnitude < 3 or flat.Unit:Dot(aim) > 0.25 then
			hit(player, enemy, weapon.Damage, weapon)
		end
	end
end

local function rangedAttack(player: Player, root: BasePart, aim: Vector3, weapon: Items.WeaponDef)
	local from = root.Position + aim * 2 + Vector3.new(0, 1, 0)
	local target = findAimTarget(root.Position, aim, weapon.Range, 0.75)
	local color = weapon.Accent

	if not target then
		fireProjectile(weapon.Type, from, from + aim * weapon.Range, color, function() end)
		return
	end

	local to = target.Root.Position
	fireProjectile(weapon.Type, from, to, color, function()
		if weapon.Splash then
			-- Staff bolts splash: everything near the impact gets hit.
			local center = if target.Dead then to else target.Root.Position
			burstEffect(center, weapon.Splash, color)
			for _, enemy in EnemyService.GetEnemiesNear(center, weapon.Splash) do
				hit(player, enemy, weapon.Damage, weapon)
			end
		elseif not target.Dead then
			hit(player, target, weapon.Damage, weapon)
		end
	end)
end

local function onAttack(player: Player, aim: unknown)
	local weapon = PlayerService.GetWeapon(player)
	local _, root = getAlive(player)
	if not weapon or not root then
		return
	end
	local now = os.clock()
	if now - (lastAttack[player] or 0) < weapon.Cooldown * 0.9 then -- small allowance for network jitter
		return
	end

	-- Must actually be holding the weapon.
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute(TOOL_ATTRIBUTE) ~= weapon.Id then
		return
	end
	lastAttack[player] = now

	-- The default character Animate script plays a slash animation when it sees this value.
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool

	local direction = sanitizeAim(aim, root)
	Sfx.play(if weapon.Type == "Sword" then "Swing" elseif weapon.Type == "Staff" then "Cast" else "BowShot", root)
	if weapon.Type == "Sword" then
		swordAttack(player, root, direction, weapon)
	else
		rangedAttack(player, root, direction, weapon)
	end
end

-- Weapon models ------------------------------------------------------------------
-- Each weapon is built from parts. The Tool's Handle is held in the right hand.

local function weld(handle: BasePart, part: BasePart, offset: CFrame)
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = part
	w.Parent = part
end

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- How tools sit in the hand: Roblox welds the Tool's Handle to the right hand's grip
-- point. While you hold a tool, the default animation raises your right arm straight
-- forward, so in the grip's frame +Y points up and -Z points forward (away from you).
-- Each Handle below is the part the hand actually closes around, and Tool.Grip only
-- rotates it; the rest of the weapon is welded relative to the Handle.

local SWORD_TILT = math.rad(70) -- 0 = blade straight up, 90 = straight out in front
local STAFF_TILT = math.rad(10) -- staffs stand almost upright

local function buildSword(tool: Tool, weapon: Items.WeaponDef)
	local length = 3 + weapon.Tier * 0.25
	local grip = newPart(tool, "Handle", Vector3.new(0.3, 1.1, 0.3), Color3.fromRGB(60, 40, 28), Enum.Material.Leather)
	grip.CanCollide = false
	grip.Massless = true
	tool.Grip = CFrame.Angles(SWORD_TILT, 0, 0)

	local guardWidth = if weapon.Tier >= 4 then 2 else 1.4
	weld(grip, newPart(tool, "Guard", Vector3.new(0.35, 0.3, guardWidth), weapon.Accent, Enum.Material.Metal), CFrame.new(0, 0.7, 0))
	weld(grip, newPart(tool, "Pommel", Vector3.new(0.4, 0.4, 0.4), weapon.Accent, Enum.Material.Metal, Enum.PartType.Ball), CFrame.new(0, -0.7, 0))
	-- Blade sits above the guard; its flat faces point sideways and its edge points forward.
	local bladeCenter = CFrame.new(0, 0.85 + length / 2, 0)
	weld(grip, newPart(tool, "Blade", Vector3.new(0.2, length, 0.6), weapon.Color, weapon.Material), bladeCenter)
	if weapon.Effect then
		-- Glowing edge on effect weapons.
		local edgeColor = if weapon.Effect.Type == "Frost" then FROST_COLOR elseif weapon.Effect.Type == "Burn" then BURN_COLOR else Color3.fromRGB(200, 40, 40)
		weld(grip, newPart(tool, "Edge", Vector3.new(0.22, length * 0.8, 0.1), edgeColor, Enum.Material.Neon), bladeCenter * CFrame.new(0, 0.2, -0.3))
	end
end

local function buildStaff(tool: Tool, weapon: Items.WeaponDef)
	local length = 5 + weapon.Tier * 0.15
	local shaft = newPart(tool, "Handle", Vector3.new(0.3, length, 0.3), weapon.Color, weapon.Material)
	shaft.CanCollide = false
	shaft.Massless = true
	-- Hold it a third of the way up: the shaft's center is length/6 above the hand.
	tool.Grip = CFrame.new(0, -length / 6, 0) * CFrame.Angles(STAFF_TILT, 0, 0)

	local top = length / 2
	local gemSize = 0.8 + weapon.Tier * 0.08
	local gem = newPart(tool, "Gem", Vector3.one * gemSize, weapon.Accent, Enum.Material.Neon, Enum.PartType.Ball)
	weld(shaft, gem, CFrame.new(0, top + gemSize / 2, 0))
	local light = Instance.new("PointLight")
	light.Color = weapon.Accent
	light.Range = 8
	light.Parent = gem
	for _, side in { -1, 1 } do
		weld(shaft, newPart(tool, "Prong", Vector3.new(0.15, gemSize * 1.1, 0.15), weapon.Color, weapon.Material), CFrame.new(side * gemSize * 0.45, top + gemSize * 0.45, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)))
	end
end

local function buildBow(tool: Tool, weapon: Items.WeaponDef)
	-- The riser is held upright with the string on your side (+Z) and the bow facing forward.
	local riser = newPart(tool, "Handle", Vector3.new(0.3, 1.2, 0.4), weapon.Color, weapon.Material)
	riser.CanCollide = false
	riser.Massless = true
	tool.Grip = CFrame.new()

	local limbLength = 2 + weapon.Tier * 0.08
	local bend = math.rad(20)
	local tipY = 0.6 + math.cos(bend) * limbLength
	local tipZ = 0.15 + math.sin(bend) * limbLength
	for _, side in { -1, 1 } do
		-- Limbs curve back toward the archer (+Z); string joins the tips.
		local center = CFrame.new(0, side * (0.6 + math.cos(bend) * limbLength / 2), 0.15 + math.sin(bend) * limbLength / 2)
		weld(riser, newPart(tool, "Limb", Vector3.new(0.25, limbLength, 0.3), weapon.Color, weapon.Material), center * CFrame.Angles(side * bend, 0, 0))
	end
	weld(riser, newPart(tool, "String", Vector3.new(0.06, tipY * 2, 0.06), weapon.Accent, Enum.Material.Neon), CFrame.new(0, 0, tipZ))
end

-- Voidlight Greatsword (Mythic): white blade with a glowing blue fuller, navy trim,
-- jagged shards toward the tip, a horned navy guard, spiral-wrapped grip and a crown pommel.
local function buildVoidlight(tool: Tool, weapon: Items.WeaponDef)
	local white = weapon.Color
	local navy = weapon.Accent
	local darkNavy = Color3.fromRGB(16, 18, 50)
	local lightBlue = Color3.fromRGB(125, 150, 255)
	local glow = Color3.fromRGB(90, 125, 255)

	local grip = newPart(tool, "Handle", Vector3.new(0.34, 1.6, 0.34), navy, Enum.Material.Leather)
	grip.CanCollide = false
	grip.Massless = true
	tool.Grip = CFrame.Angles(SWORD_TILT, 0, 0)

	local function add(name: string, size: Vector3, color: Color3, material: Enum.Material, offset: CFrame, shape: Enum.PartType?): BasePart
		local part = newPart(tool, name, size, color, material, shape)
		weld(grip, part, offset)
		return part
	end

	-- Spiral wrap on the grip
	for i = 0, 4 do
		add("Wrap", Vector3.new(0.4, 0.1, 0.4), lightBlue, Enum.Material.Fabric, CFrame.new(0, -0.6 + i * 0.3, 0) * CFrame.Angles(math.rad(25), 0, 0))
	end

	-- Crown pommel: a ball with spikes splaying downward
	add("Pommel", Vector3.one * 0.55, darkNavy, Enum.Material.Metal, CFrame.new(0, -1.05, 0), Enum.PartType.Ball)
	add("PommelSpike", Vector3.new(0.14, 0.5, 0.14), navy, Enum.Material.Metal, CFrame.new(0, -1.45, 0))
	for k = 0, 4 do
		add("PommelSpike", Vector3.new(0.12, 0.5, 0.12), navy, Enum.Material.Metal, CFrame.new(0, -1.15, 0) * CFrame.Angles(0, math.rad(k * 72), 0) * CFrame.Angles(math.rad(140), 0, 0) * CFrame.new(0, 0.3, 0))
	end

	-- Guard: a banded block with curved horns
	local guardY = 1
	add("Guard", Vector3.new(0.55, 0.55, 1.5), navy, Enum.Material.Metal, CFrame.new(0, guardY, 0))
	for _, y in { -0.2, 0.2 } do
		add("GuardTrim", Vector3.new(0.58, 0.07, 1.53), lightBlue, Enum.Material.Metal, CFrame.new(0, guardY + y, 0))
	end
	add("GuardKnot", Vector3.new(0.62, 0.28, 0.28), lightBlue, Enum.Material.Neon, CFrame.new(0, guardY, 0))

	-- Each horn is a chain of short segments bending as it goes, like a claw.
	local function horn(start: Vector3, outward: Vector3, startAngle: number, bendPerSegment: number, segments: number, length: number, thickness: number)
		local position = start
		for i = 1, segments do
			local theta = math.rad(startAngle + (i - 1) * bendPerSegment)
			local direction = (outward * math.cos(theta) + Vector3.yAxis * math.sin(theta)).Unit
			local segmentLength = length * (1 - (i - 1) * 0.15)
			local center = position + direction * segmentLength / 2
			local size = Vector3.new(thickness, thickness * 1.4, segmentLength) * Vector3.new(1, 1 - (i - 1) * 0.15, 1)
			add("Horn", size, if i == segments then lightBlue else navy, Enum.Material.Metal, CFrame.lookAt(center, center + direction))
			position += direction * segmentLength * 0.9
		end
	end
	for _, side in { -1, 1 } do
		local edge = Vector3.zAxis * side
		horn(Vector3.new(0, guardY, side * 0.7), edge, 10, 22, 4, 0.55, 0.16) -- big horns curving up
		horn(Vector3.new(0, guardY - 0.1, side * 0.6), edge, -15, -25, 3, 0.4, 0.12) -- small horns curving down
		horn(Vector3.new(side * 0.25, guardY + 0.1, 0), Vector3.xAxis * side, 20, 25, 3, 0.4, 0.12) -- side horns
	end

	-- Blade: wide lower section, narrower upper section, and a long point
	local base = guardY + 0.3
	local lowerLength, upperLength = 4.2, 2.1
	local lowerWidth, upperWidth = 1.15, 0.85
	add("Blade", Vector3.new(0.24, lowerLength, lowerWidth), white, Enum.Material.Metal, CFrame.new(0, base + lowerLength / 2, 0))
	local upperY = base + lowerLength + upperLength / 2
	add("Blade", Vector3.new(0.24, upperLength, upperWidth), white, Enum.Material.Metal, CFrame.new(0, upperY, 0))
	local tipBase = base + lowerLength + upperLength
	for _, side in { -1, 1 } do
		add("BladeTip", Vector3.new(0.22, 1.7, upperWidth / 2 + 0.05), white, Enum.Material.Metal, CFrame.new(0, tipBase + 0.6, side * upperWidth / 4) * CFrame.Angles(-side * math.rad(15), 0, 0))
	end

	-- Edge trim
	for _, side in { -1, 1 } do
		add("EdgeTrim", Vector3.new(0.26, lowerLength, 0.07), navy, Enum.Material.Metal, CFrame.new(0, base + lowerLength / 2, side * (lowerWidth / 2 - 0.02)))
		add("EdgeTrim", Vector3.new(0.26, upperLength, 0.07), navy, Enum.Material.Metal, CFrame.new(0, upperY, side * (upperWidth / 2 - 0.02)))
	end

	-- Fuller: dark groove down the middle with a glowing line inside
	local fullerLength = lowerLength + upperLength - 0.3
	add("Fuller", Vector3.new(0.27, fullerLength, 0.22), darkNavy, Enum.Material.Metal, CFrame.new(0, base + fullerLength / 2 + 0.1, 0))
	local line = add("FullerGlow", Vector3.new(0.29, fullerLength - 0.2, 0.06), glow, Enum.Material.Neon, CFrame.new(0, base + fullerLength / 2 + 0.1, 0))
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = line
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(lightBlue)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.15, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Rate = 6
	sparkles.Speed = NumberRange.new(0.5, 1)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = line

	-- Jagged shards along both edges toward the tip, raked back like ice
	for _, side in { -1, 1 } do
		for k = 1, 6 do
			local y = base + 2.6 + k * 0.6
			local width = if y < base + lowerLength then lowerWidth else upperWidth
			add("Shard", Vector3.new(0.2, 0.45 - k * 0.03, 0.2), white, Enum.Material.Metal, CFrame.new(0, y, side * (width / 2 + 0.06)) * CFrame.Angles(side * math.rad(35), 0, 0))
		end
	end
end

local function buildTool(weapon: Items.WeaponDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.DisplayName
	tool.CanBeDropped = false
	tool.ToolTip = `{weapon.Rarity} {weapon.Type} - {weapon.Damage} damage`
	tool:SetAttribute(TOOL_ATTRIBUTE, weapon.Id)
	if weapon.Model == "Voidlight" then
		buildVoidlight(tool, weapon)
	elseif weapon.Type == "Sword" then
		buildSword(tool, weapon)
	elseif weapon.Type == "Staff" then
		buildStaff(tool, weapon)
	else
		buildBow(tool, weapon)
	end
	return tool
end

-- Exposed so tools can be previewed outside the game.
CombatService.BuildTool = buildTool

-- Armor models -------------------------------------------------------------------

local function buildArmor(character: Model, armor: Items.ArmorDef)
	local old = character:FindFirstChild(ARMOR_FOLDER)
	if old then
		old:Destroy()
	end
	local torso: BasePart? = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: any
	if not torso then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = ARMOR_FOLDER

	local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material, offset: CFrame)
		local p = newPart(folder, name, size, color, material)
		p.CanTouch = false
		weld(torso, p, offset)
	end

	local t = torso.Size
	piece("Chest", t + Vector3.new(0.2, 0.1, 0.2), armor.Color, armor.Material, CFrame.new())
	for _, side in { -1, 1 } do
		piece("Shoulder", Vector3.new(1.2, 0.5, 1.3), armor.Accent, armor.Material, CFrame.new(side * (t.X / 2 + 0.35), t.Y / 2 - 0.1, 0))
	end
	if armor.Tier >= 3 then
		piece("Belt", Vector3.new(t.X + 0.3, 0.3, t.Z + 0.3), armor.Accent, Enum.Material.Metal, CFrame.new(0, -t.Y / 2 + 0.1, 0))
	end
	if armor.Tier >= 6 then
		-- Glowing emblem on the chest for high-tier armor.
		piece("Emblem", Vector3.new(0.6, 0.6, 0.1), armor.Accent, Enum.Material.Neon, CFrame.new(0, 0.1, -t.Z / 2 - 0.12))
	end
	folder.Parent = character
end

-- Loadout ----------------------------------------------------------------------

local function removeWeaponTools(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(TOOL_ATTRIBUTE) then
					child:Destroy()
				end
			end
		end
	end
end

-- While the weapon is put away, a copy of it is strapped diagonally across your back.
local function updateBackWeapon(player: Player, tool: Tool)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild(BACK_MODEL)
	if old then
		old:Destroy()
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local torso: BasePart? = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: any
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if tool.Parent ~= backpack or not torso or not handle then
		return
	end

	local model = Instance.new("Model")
	model.Name = BACK_MODEL
	local handleCFrame: CFrame = torso.CFrame
		* CFrame.new(0, 0, torso.Size.Z / 2 + 0.35)
		* CFrame.Angles(0, 0, math.rad(40))
		* CFrame.Angles(0, math.rad(90), 0)
	-- Centre the weapon on your back (the Handle is the grip, not the middle).
	local sumY, count = 0, 0
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			sumY += handle.CFrame:ToObjectSpace(part.CFrame).Y
			count += 1
		end
	end
	handleCFrame *= CFrame.new(0, -sumY / math.max(count, 1), 0)
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			local copy = part:Clone()
			for _, child in copy:GetChildren() do
				if child:IsA("WeldConstraint") or child:IsA("Light") then
					child:Destroy()
				end
			end
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = true
			copy.Anchored = false
			copy.CFrame = handleCFrame * handle.CFrame:ToObjectSpace(part.CFrame)
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = copy
			w.Parent = copy
			copy.Parent = model
		end
	end
	model.Parent = character
end

local function applyLoadout(player: Player)
	local humanoid = getAlive(player)
	local character = player.Character
	if not humanoid or not character then
		return
	end

	local armor = PlayerService.GetArmor(player)
	if armor then
		buildArmor(character, armor)
	else
		local old = character:FindFirstChild(ARMOR_FOLDER)
		if old then
			old:Destroy()
		end
	end

	removeWeaponTools(player)
	local weapon = PlayerService.GetWeapon(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if weapon and backpack then
		local tool = buildTool(weapon)
		tool.AncestryChanged:Connect(function()
			updateBackWeapon(player, tool)
		end)
		tool.Equipped:Connect(function()
			local handle = tool:FindFirstChild("Handle") :: BasePart?
			if handle then
				Sfx.play("Unsheath", handle)
			end
		end)
		tool.Destroying:Connect(function()
			local back = player.Character and player.Character:FindFirstChild(BACK_MODEL)
			if back then
				back:Destroy()
			end
		end)
		tool.Parent = backpack
		humanoid:EquipTool(tool)
	end
end

-- Takes the weapon out (used when a dungeon starts).
function CombatService.DrawWeapon(player: Player)
	local humanoid = getAlive(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or not backpack then
		return
	end
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(TOOL_ATTRIBUTE) then
			humanoid:EquipTool(child)
			return
		end
	end
end

-- Abilities ------------------------------------------------------------------------

local function damageAround(player: Player, center: Vector3, radius: number, multiplier: number, weapon: Items.WeaponDef)
	for _, enemy in EnemyService.GetEnemiesNear(center, radius) do
		hit(player, enemy, weapon.Damage * multiplier, weapon)
	end
end

local abilityHandlers: { [string]: (Player, Humanoid, BasePart, Vector3, Items.WeaponDef) -> () } = {
	Whirlwind = function(player, _, root, _, weapon)
		local ability = Config.Abilities.Whirlwind
		damageAround(player, root.Position, ability.Radius, ability.DamageMultiplier, weapon)
		ringEffect(root.Position - Vector3.new(0, 2, 0), ability.Radius, ability.Color)
	end,

	ShieldWall = function(player, _, root)
		local ability = Config.Abilities.ShieldWall
		PlayerService.AddBuff(player, ability.Buff, ability.Duration)
		local highlight = Instance.new("Highlight")
		highlight.FillColor = ability.Color
		highlight.FillTransparency = 0.7
		highlight.OutlineColor = ability.Color
		highlight.Parent = root.Parent
		Debris:AddItem(highlight, ability.Duration)
	end,

	Fireball = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.Fireball
		local target = findAimTarget(root.Position, aim, ability.Range, 0.6)
		local from = root.Position + aim * 2 + Vector3.new(0, 1, 0)
		local to = if target then target.Root.Position else from + aim * ability.Range * 0.6
		fireProjectile("Fireball", from, to, ability.Color, function()
			burstEffect(to, ability.Radius, ability.Color)
			damageAround(player, to, ability.Radius, ability.DamageMultiplier, weapon)
		end)
	end,

	HealingCircle = function(_, _, root)
		local ability = Config.Abilities.HealingCircle
		for _, other in Players:GetPlayers() do
			local _, otherRoot = getAlive(other)
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= ability.Radius then
				PlayerService.Heal(other, ability.HealPercent)
			end
		end
		ringEffect(root.Position - Vector3.new(0, 2.5, 0), ability.Radius, ability.Color)
	end,

	Volley = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.Volley
		local targets = {}
		for _, enemy in EnemyService.GetEnemiesNear(root.Position, ability.Range) do
			local offset = enemy.Root.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < 3 or flat.Unit:Dot(aim) >= 0.5 then
				table.insert(targets, { Enemy = enemy, Distance = flat.Magnitude })
			end
		end
		table.sort(targets, function(a, b)
			return a.Distance < b.Distance
		end)

		local from = root.Position + aim * 2 + Vector3.new(0, 1, 0)
		if #targets == 0 then
			for i = -2, 2 do
				local direction = (CFrame.Angles(0, math.rad(i * 8), 0) * aim)
				fireProjectile("Bow", from, from + direction * ability.Range, ability.Color, function() end)
			end
			return
		end
		for i = 1, math.min(#targets, ability.MaxTargets) do
			local enemy = targets[i].Enemy
			fireProjectile("Bow", from, enemy.Root.Position, ability.Color, function()
				if not enemy.Dead then
					hit(player, enemy, weapon.Damage * ability.DamageMultiplier, weapon)
				end
			end)
		end
	end,

	SwiftStep = function(player, _, root)
		local ability = Config.Abilities.SwiftStep
		PlayerService.AddBuff(player, ability.Buff, ability.Duration)
		ringEffect(root.Position - Vector3.new(0, 2.5, 0), 6, ability.Color)
	end,
}

local function onUseAbility(player: Player, abilityId: unknown, aim: unknown): (boolean, number)
	local class = PlayerService.GetClass(player)
	local weapon = PlayerService.GetWeapon(player)
	if type(abilityId) ~= "string" or not class or not weapon or not table.find(class.Abilities, abilityId) then
		return false, 0
	end
	local humanoid, root = getAlive(player)
	if not humanoid or not root then
		return false, 0
	end

	local readyAt = abilityReadyAt[player]
	if not readyAt then
		readyAt = {}
		abilityReadyAt[player] = readyAt
	end
	local now = os.clock()
	if now < (readyAt[abilityId] or 0) then
		return false, readyAt[abilityId] - now
	end

	local ability = Config.Abilities[abilityId]
	readyAt[abilityId] = now + ability.Cooldown
	local sound = ({
		Whirlwind = "Lunge",
		ShieldWall = "Unsheath",
		Fireball = "Cast",
		HealingCircle = "Heal",
		Volley = "BowShot",
		SwiftStep = "Dodge",
	})[abilityId]
	Sfx.play(sound or "Lunge", root, 1.3)
	abilityHandlers[abilityId](player, humanoid, root, sanitizeAim(aim, root), weapon)
	return true, ability.Cooldown
end

function CombatService.Start()
	PlayerService.OnCharacterReady(function(player)
		abilityReadyAt[player] = nil
		applyLoadout(player)
	end)
	PlayerService.OnLoadoutChanged(applyLoadout)

	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Remotes.UseAbility.OnServerInvoke = onUseAbility

	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		abilityReadyAt[player] = nil
	end)
end

return CombatService
