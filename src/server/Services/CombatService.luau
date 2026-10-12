-- Player combat: weapons in hand, combos, weapon abilities (R), class abilities (Q/E),
-- weapon effects and the Healer passive. Everything is checked on the server.
--
-- Attacking: the client sends the direction it's aiming (toward the mouse). Each click is
-- the next step of the weapon's combo (WeaponMoves) if it comes within the combo window;
-- every step has its own hit shape, damage and animation.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponMoves = require(ReplicatedStorage.Shared.WeaponMoves)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)
local Sfx = require(script.Parent.Parent.Sfx)
local Effects = require(script.Parent.Parent.Effects)
local ArmorVisuals = require(script.Parent.Parent.ArmorVisuals)
local WeaponModels = require(script.Parent.Parent.WeaponModels)
local WeaponSkills = require(script.Parent.Parent.WeaponSkills)

local TOOL_ATTRIBUTE = WeaponModels.ToolAttribute
local BACK_MODEL = "SheathedWeapon"
local OFFHAND_MODEL = "OffhandWeapon"
local BURN_COLOR = Color3.fromRGB(255, 140, 40)
local FROST_COLOR = Color3.fromRGB(140, 220, 255)
local DEFAULT_COMBO = {
	Sword = "Blademaster", Dagger = "Flurry", Mace = "Crusher", Staff = "Arcanist", Bow = "Marksman", Tome = "Psalm",
	Axe = "Ravager", Greatsword = "Crusader", Scythe = "Reaper", Spear = "Impaler", Katana = "Iaijutsu", Halberd = "Seraphic",
}
local PROJECTILE = { Bow = "Arrow", Staff = "Bolt", Tome = "Holy" }
local HEAVY = { Mace = true, Axe = true, Greatsword = true, Halberd = true }

local CombatService = {}

type AttackState = { Step: number, Time: number, ReadyAt: number }
local attackState: { [Player]: AttackState } = {}
local abilityReadyAt: { [Player]: { [string]: number } } = {}

-- Helpers --------------------------------------------------------------------------

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
	local class: any = PlayerService.GetClass(player)
	local amount = base * PlayerService.GetDamageMultiplier(player) * (0.9 + math.random() * 0.2)
	-- Berserker rage: more damage the lower your health
	local humanoid = getAlive(player)
	if class and class.Rage and humanoid then
		amount *= 1 + class.Rage * (1 - humanoid.Health / humanoid.MaxHealth)
	end
	local isCrit = math.random() < PlayerService.GetCritChance(player)
	if isCrit then
		amount *= Config.CritMultiplier + (if class then class.CritDamage or 0 else 0)
	end
	return amount, isCrit
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

-- Plays an animation on this player's character for everyone else (the attacker's own
-- client already played it the moment they clicked).
local function broadcastMove(player: Player, animName: string?)
	if not animName or not player.Character then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.PlayMove:FireClient(other, player.Character, animName)
		end
	end
end

local function showTrail(player: Player, duration: number)
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local trail = handle and handle:FindFirstChild("SwingTrail") :: Trail?
	if trail then
		trail.Enabled = true
		task.delay(duration, function()
			trail.Enabled = false
		end)
	end
end

-- Weapon effects --------------------------------------------------------------------

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

-- Healer passive: heal the most hurt teammate nearby (including yourself).
local function healOnHit(player: Player, dealt: number)
	local class = PlayerService.GetClass(player)
	local share = class and (class :: any).HealOnHit
	local _, root = getAlive(player)
	if not share or not root or dealt <= 0 then
		return
	end
	local target, lowest = nil, 1
	for _, other in Players:GetPlayers() do
		local humanoid, otherRoot = getAlive(other)
		if humanoid and otherRoot and (otherRoot.Position - root.Position).Magnitude <= 40 then
			local ratio = humanoid.Health / humanoid.MaxHealth
			if ratio < lowest then
				target, lowest = humanoid, ratio
			end
		end
	end
	if target then
		target.Health = math.min(target.MaxHealth, target.Health + dealt * share)
	end
end

-- Damages an enemy with a weapon hit. Returns the damage dealt.
local function hit(player: Player, enemy: EnemyService.Enemy, baseDamage: number, weapon: Items.WeaponDef): number
	local amount, isCrit = rollDamage(player, baseDamage)
	local color = if weapon.Effect and weapon.Effect.Type == "Frost" then FROST_COLOR else nil
	local dealt = EnemyService.Damage(enemy, amount, isCrit, if isCrit then nil else color)
	applyEffect(player, enemy, weapon.Effect, dealt)
	healOnHit(player, dealt)
	-- Necromancer passive: hits heal you
	local class: any = PlayerService.GetClass(player)
	local humanoid = getAlive(player)
	if class and class.LifeSteal and humanoid and dealt > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + dealt * class.LifeSteal)
	end
	return dealt
end

local function hitAll(player: Player, enemies: { EnemyService.Enemy }, baseDamage: number, weapon: Items.WeaponDef)
	for _, enemy in enemies do
		hit(player, enemy, baseDamage, weapon)
	end
end

-- Combo hit shapes ------------------------------------------------------------------

local function inCone(root: BasePart, aim: Vector3, range: number, minDot: number): { EnemyService.Enemy }
	local found = {}
	for _, enemy in EnemyService.GetEnemiesNear(root.Position, range) do
		local flat = (enemy.Root.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude < 3 or flat.Unit:Dot(aim) > minDot then
			table.insert(found, enemy)
		end
	end
	return found
end

local function slashEffect(root: BasePart, aim: Vector3, range: number, color: Color3, thrust: boolean)
	local size = if thrust then Vector3.new(0.5, 0.5, range * 1.2) else Vector3.new(range * 1.5, 0.2, 1.4)
	local slash = Effects.part({
		Color = color,
		Transparency = 0.35,
		Size = size,
		CFrame = CFrame.lookAt(root.Position, root.Position + aim)
			* CFrame.new(0, 0.5, -range / 2)
			* CFrame.Angles(0, if thrust then 0 else math.rad(math.random(-20, 20)), if thrust then 0 else math.rad(math.random(-35, 35))),
	})
	TweenService:Create(slash, TweenInfo.new(0.18), { Transparency = 1, Size = size * Vector3.new(1.15, 1, 1.15) }):Play()
	Debris:AddItem(slash, 0.2)
end

local function meleeStep(player: Player, root: BasePart, aim: Vector3, weapon: Items.WeaponDef, step: WeaponMoves.Step)
	local class: any = PlayerService.GetClass(player)
	local range = (step.Range or weapon.Range) * (if class then class.Reach or 1 else 1)
	local damage = weapon.Damage * step.Damage
	local color = weapon.Design.Trail or weapon.Color
	if step.Hit == "Thrust" then
		slashEffect(root, aim, range * 1.3, color, true)
		hitAll(player, inCone(root, aim, range * 1.3, 0.75), damage, weapon)
	elseif step.Hit == "Spin" then
		Effects.ring(root.Position - Vector3.new(0, 2, 0), range, color, 0.3)
		hitAll(player, EnemyService.GetEnemiesNear(root.Position, range), damage, weapon)
	elseif step.Hit == "Slam" then
		-- Lands a moment later, in front of you
		task.delay(0.35, function()
			local _, liveRoot = getAlive(player)
			if not liveRoot then
				return
			end
			local center = liveRoot.Position + aim * 3
			local radius = step.Radius or 10
			Effects.ring(center - Vector3.new(0, 2.5, 0), radius, color, 0.4)
			Effects.burst(center - Vector3.new(0, 2, 0), radius * 0.5, color, 0.3)
			Effects.sparks(center - Vector3.new(0, 2, 0), color, "Smoke", 20)
			Sfx.play("Slam", liveRoot, 0.6)
			hitAll(player, EnemyService.GetEnemiesNear(center, radius), damage, weapon)
		end)
	else -- Arc
		slashEffect(root, aim, range, color, false)
		hitAll(player, inCone(root, aim, range, 0.25), damage, weapon)
	end
end

local function rangedStep(player: Player, root: BasePart, aim: Vector3, weapon: Items.WeaponDef, step: WeaponMoves.Step)
	local range = step.Range or weapon.Range
	local damage = weapon.Damage * step.Damage
	local color = weapon.Design.Glow or weapon.Accent
	local kind = PROJECTILE[weapon.Type] or "Bolt"
	local from = root.Position + aim * 2 + Vector3.new(0, 1, 0)

	local function shoot(direction: Vector3, minDot: number, onHit: ((EnemyService.Enemy, Vector3) -> ())?)
		local target = findAimTarget(root.Position, direction, range, minDot)
		local to = if target then target.Root.Position else from + direction * range
		Effects.projectile(kind, from, to, color, function()
			if target and not target.Dead then
				Effects.sparks(target.Root.Position, color, nil, 8)
				if onHit then
					onHit(target, target.Root.Position)
				else
					hit(player, target, damage, weapon)
				end
			end
		end)
	end

	if step.Hit == "Multishot" then
		local count = step.Count or 3
		local spread = step.Spread or 10
		for i = 1, count do
			local angle = (i - (count + 1) / 2) * spread
			shoot(CFrame.Angles(0, math.rad(angle), 0) * aim, 0.9)
		end
	elseif step.Hit == "Burst" then
		local target = findAimTarget(root.Position, aim, range, 0.7)
		local to = if target then target.Root.Position else from + aim * math.min(range, 25)
		Effects.projectile("Fireball", from, to, color, function()
			local radius = step.Radius or 10
			Effects.burst(to, radius, color, 0.35)
			Effects.ring(to - Vector3.new(0, 2, 0), radius, color, 0.35)
			hitAll(player, EnemyService.GetEnemiesNear(to, radius), damage, weapon)
		end)
	elseif step.Hit == "Pierce" then
		local to = from + aim * range
		Effects.projectile(kind, from, to, color, function() end, 180)
		for _, enemy in EnemyService.GetEnemiesNear((from + to) / 2, range / 2 + 3) do
			local offset = enemy.Root.Position - from
			local along = math.clamp(offset:Dot(aim), 0, range)
			if ((enemy.Root.Position - (from + aim * along)) * Vector3.new(1, 0, 1)).Magnitude <= 2.5 + enemy.Radius then
				task.delay(along / 180, function()
					if not enemy.Dead then
						hit(player, enemy, damage, weapon)
					end
				end)
			end
		end
	elseif step.Hit == "Nova" then
		local radius = step.Radius or 12
		Effects.burst(root.Position, radius, color, 0.35)
		Effects.ring(root.Position - Vector3.new(0, 2.5, 0), radius * 1.2, color, 0.4)
		hitAll(player, EnemyService.GetEnemiesNear(root.Position, radius), damage, weapon)
		if step.Heal then
			for _, other in Players:GetPlayers() do
				local _, otherRoot = getAlive(other)
				if otherRoot and (otherRoot.Position - root.Position).Magnitude <= radius + 6 then
					PlayerService.Heal(other, step.Heal)
				end
			end
		end
	elseif step.Hit == "Smite" then
		local target = findAimTarget(root.Position, aim, range, 0.6)
		local point = if target then target.Root.Position else root.Position + aim * math.min(range, 20)
		local radius = step.Radius or 8
		Effects.warning(point - Vector3.new(0, 2.5, 0), radius, color, 0.35)
		task.delay(0.35, function()
			Effects.pillar(point - Vector3.new(0, 2.5, 0), radius * 0.5, color)
			hitAll(player, EnemyService.GetEnemiesNear(point, radius), damage, weapon)
		end)
	else -- Shot
		shoot(aim, 0.75, if weapon.Splash
			then function(_, position)
				-- Staff bolts splash: everything near the impact gets hit.
				Effects.burst(position, weapon.Splash :: number, color, 0.25)
				hitAll(player, EnemyService.GetEnemiesNear(position, weapon.Splash :: number), damage, weapon)
			end
			else nil)
	end
end

local function onAttack(player: Player, aim: unknown)
	local weapon = PlayerService.GetWeapon(player)
	local _, root = getAlive(player)
	if not weapon or not root then
		return
	end
	-- Must actually be holding the weapon.
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute(TOOL_ATTRIBUTE) ~= weapon.Id then
		return
	end

	local combo = WeaponMoves.Combos[weapon.Combo] or WeaponMoves.Combos[DEFAULT_COMBO[weapon.Type]]
	local state = attackState[player] or { Step = 0, Time = 0, ReadyAt = 0 }
	attackState[player] = state
	local now = os.clock()
	if now < state.ReadyAt - 0.08 then -- small allowance for network jitter
		return
	end
	local stepIndex = if now - state.Time <= WeaponMoves.ComboWindow and state.Step < #combo.Steps then state.Step + 1 else 1
	local step = combo.Steps[stepIndex]
	state.Step = stepIndex
	state.Time = now
	state.ReadyAt = now + step.Cooldown

	local direction = sanitizeAim(aim, root)
	broadcastMove(player, step.Anim)
	local melee = PROJECTILE[weapon.Type] == nil
	local finisher = stepIndex == #combo.Steps
	local sound = if melee then (if finisher then "Lunge" else "Swing") elseif weapon.Type == "Bow" then "BowShot" else "Cast"
	Sfx.play(sound, root, if HEAVY[weapon.Type] or finisher then 1.3 else 1)
	showTrail(player, (WeaponMoves.Animations[step.Anim] or { Duration = 0.3 }).Duration + 0.05)
	if melee then
		meleeStep(player, root, direction, weapon, step)
	else
		rangedStep(player, root, direction, weapon, step)
	end
end

-- Weapon ability (R) -------------------------------------------------------------------

local function onUseWeaponSkill(player: Player, aim: unknown): (boolean, number)
	local weapon = PlayerService.GetWeapon(player)
	local humanoid, root = getAlive(player)
	if not weapon or not humanoid or not root then
		return false, 0
	end
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute(TOOL_ATTRIBUTE) ~= weapon.Id then
		return false, 0
	end
	local readyAt = abilityReadyAt[player]
	if not readyAt then
		readyAt = {}
		abilityReadyAt[player] = readyAt
	end
	local key = `Weapon_{weapon.Id}`
	local now = os.clock()
	if now < (readyAt[key] or 0) then
		return false, readyAt[key] - now
	end

	local skill = weapon.Skill
	local direction = sanitizeAim(aim, root)
	local ctx: WeaponSkills.Context = {
		Player = player,
		Root = root,
		Aim = direction,
		Skill = skill,
		WeaponId = weapon.Id,
		Hit = function(enemy, multiplier)
			return hit(player, enemy, weapon.Damage * multiplier, weapon)
		end,
		EnemiesNear = EnemyService.GetEnemiesNear,
		AimTarget = function(range, minDot)
			return findAimTarget(root.Position, direction, range, minDot)
		end,
		Heal = PlayerService.Heal,
		Buff = function(target, duration)
			PlayerService.AddBuff(target, `Skill_{weapon.Id}`, duration)
		end,
		AddGold = function(amount)
			PlayerService.AddGold(player, amount, true)
		end,
		Pull = EnemyService.Pull,
		Stun = EnemyService.Stun,
		Knockback = EnemyService.Knockback,
	}
	if not WeaponSkills.Run(ctx) then
		return false, 0
	end
	local cooldown = skill.Cooldown * PlayerService.GetCooldownMultiplier(player)
	readyAt[key] = now + cooldown
	PlayerService.AddStat(player, "AbilitiesUsed")
	broadcastMove(player, WeaponMoves.SkillAnims[skill.Mechanic])
	showTrail(player, 0.8)
	Sfx.play(if skill.Style == "Holy" then "Heal" elseif skill.Style == "Gold" then "Coins" else "Lunge", root, 1.5)
	return true, cooldown
end

-- Loadout -----------------------------------------------------------------------------

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

-- Copies a tool's parts into a model welded to `part` with the Handle at `handleCFrame`.
local function copyWeapon(tool: Tool, part: BasePart, handleCFrame: CFrame, name: string): Model?
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, source in tool:GetDescendants() do
		if source:IsA("BasePart") then
			local copy = source:Clone()
			for _, child in copy:GetChildren() do
				if child:IsA("WeldConstraint") or child:IsA("Light") or child:IsA("Trail") then
					child:Destroy()
				end
			end
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = true
			copy.Anchored = false
			copy.CFrame = handleCFrame * handle.CFrame:ToObjectSpace(source.CFrame)
			local w = Instance.new("WeldConstraint")
			w.Part0 = part
			w.Part1 = copy
			w.Parent = copy
			copy.Parent = model
		end
	end
	return model
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
	local model = copyWeapon(tool, torso, handleCFrame, BACK_MODEL)
	if model then
		model.Parent = character
	end
end

-- Assassins hold a second dagger (reverse grip) in their left hand.
local function updateOffhand(player: Player, tool: Tool, weapon: Items.WeaponDef)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild(OFFHAND_MODEL)
	if old then
		old:Destroy()
	end
	local leftHand = character:FindFirstChild("LeftHand") :: BasePart?
	local gripAttachment = leftHand and leftHand:FindFirstChild("LeftGripAttachment") :: Attachment?
	if weapon.Type ~= "Dagger" or tool.Parent ~= character or not leftHand or not gripAttachment then
		return
	end
	local model = copyWeapon(tool, leftHand, leftHand.CFrame * gripAttachment.CFrame * tool.Grip:Inverse(), OFFHAND_MODEL)
	if model then
		model.Parent = character
	end
end

-- Class looks: the Seraph has wings of light and a halo.
local CLASS_LOOK = "ClassLook"
local function applyClassLook(player: Player, character: Model)
	local old = character:FindFirstChild(CLASS_LOOK)
	if old then
		old:Destroy()
	end
	local class = PlayerService.GetClass(player)
	local torso: BasePart? = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: any
	local head = character:FindFirstChild("Head") :: BasePart?
	if not class or not class.Revive or not torso or not head then
		return
	end
	local model = Instance.new("Model")
	model.Name = CLASS_LOOK
	local function piece(name: string, size: Vector3, cframe: CFrame, to: BasePart, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = to
		w.Part1 = p
		w.Parent = p
		p.Parent = model
		return p
	end
	local gold = Color3.fromRGB(255, 225, 130)
	local back = torso.CFrame * CFrame.new(0, 0.4, torso.Size.Z / 2 + 0.3)
	for _, side in { -1, 1 } do
		for i = 0, 4 do
			local feather = piece("WingFeather", Vector3.new(2.6 - i * 0.35, 0.18, 0.7),
				back * CFrame.new(side * (1 + i * 0.35), 0.9 - i * 0.45, 0.3 + i * 0.1) * CFrame.Angles(0, side * math.rad(-20), side * math.rad(25 - i * 14)),
				torso, if i == 0 then gold else Color3.fromRGB(255, 255, 255), if i == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic)
			feather.Transparency = 0.05
			if i == 2 then
				local e = Instance.new("ParticleEmitter")
				e.Color = ColorSequence.new(gold)
				e.LightEmission = 1
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Size = NumberSequence.new(0.25, 0)
				e.Lifetime = NumberRange.new(0.6, 1.2)
				e.Rate = 8
				e.Speed = NumberRange.new(0.5, 1)
				e.Acceleration = Vector3.new(0, -1, 0)
				e.Parent = feather
			end
		end
	end
	local haloCenter = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.6, 0)
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		piece("Halo", Vector3.new(0.16, 0.12, 0.42), haloCenter * CFrame.Angles(0, angle, 0) * CFrame.new(0.75, 0, 0), head, gold, Enum.Material.Neon)
	end
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = model:FindFirstChild("Halo")
	model.Parent = character
end

local function applyLoadout(player: Player)
	local humanoid = getAlive(player)
	local character = player.Character
	if not humanoid or not character then
		return
	end

	local pieces, fullSet = PlayerService.GetArmor(player)
	ArmorVisuals.apply(character, pieces, fullSet)
	applyClassLook(player, character)

	removeWeaponTools(player)
	local weapon = PlayerService.GetWeapon(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if weapon and backpack then
		local tool = WeaponModels.Build(weapon)
		tool.AncestryChanged:Connect(function()
			updateBackWeapon(player, tool)
			updateOffhand(player, tool, weapon)
		end)
		tool.Equipped:Connect(function()
			local handle = tool:FindFirstChild("Handle") :: BasePart?
			if handle then
				Sfx.play("Unsheath", handle)
			end
		end)
		tool.Destroying:Connect(function()
			for _, name in { BACK_MODEL, OFFHAND_MODEL } do
				local copy = player.Character and player.Character:FindFirstChild(name)
				if copy then
					copy:Destroy()
				end
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

-- Exposed so tools can be previewed outside the game.
CombatService.BuildTool = WeaponModels.Build

-- Class abilities (Q / E) --------------------------------------------------------------

local function damageAround(player: Player, center: Vector3, radius: number, multiplier: number, weapon: Items.WeaponDef)
	hitAll(player, EnemyService.GetEnemiesNear(center, radius), weapon.Damage * multiplier, weapon)
end

local function highlight(model: Instance?, color: Color3, transparency: number, duration: number)
	if not model then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.FillTransparency = transparency
	h.OutlineColor = color
	h.Parent = model
	Debris:AddItem(h, duration)
end

local function healPlayersNear(position: Vector3, radius: number, fraction: number)
	for _, other in Players:GetPlayers() do
		local _, otherRoot = getAlive(other)
		if otherRoot and (otherRoot.Position - position).Magnitude <= radius then
			PlayerService.Heal(other, fraction)
		end
	end
end

-- Shoots at the closest enemies in front of you (Volley, Coin Barrage).
local function barrage(player: Player, root: BasePart, aim: Vector3, weapon: Items.WeaponDef, ability, kind: string, onHit: (() -> ())?)
	local targets = {}
	for _, enemy in inCone(root, aim, ability.Range, 0.4) do
		table.insert(targets, { Enemy = enemy, Distance = (enemy.Root.Position - root.Position).Magnitude })
	end
	table.sort(targets, function(a, b)
		return a.Distance < b.Distance
	end)
	local from = root.Position + aim * 2 + Vector3.new(0, 1.5, 0)
	if #targets == 0 then
		for i = -2, 2 do
			Effects.projectile(kind, from, from + (CFrame.Angles(0, math.rad(i * 9), 0) * aim) * ability.Range * 0.6, ability.Color, function() end)
		end
		return
	end
	for i = 1, math.min(#targets, ability.MaxTargets) do
		local enemy = targets[i].Enemy
		Effects.projectile(kind, from, enemy.Root.Position, ability.Color, function()
			if not enemy.Dead then
				hit(player, enemy, weapon.Damage * ability.DamageMultiplier, weapon)
				if onHit then
					onHit()
				end
			end
		end)
	end
end

-- How far you can travel from `root` along `direction` before hitting a wall (dashes and
-- leaps never put you inside scenery).
local function clearDistance(root: BasePart, direction: Vector3, distance: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	local result = workspace:Raycast(root.Position, direction * distance, params)
	if result and result.Instance.CanCollide then
		return math.max(0, (result.Position - root.Position).Magnitude - 2.5)
	end
	return distance
end

-- Moves a character along an arc to `target` (leaps, dives). Runs in the background.
local function leap(character: Model, root: BasePart, target: Vector3, height: number, duration: number, onLand: () -> ())
	task.spawn(function()
		local start = root.Position
		local flat = (target - start) * Vector3.new(1, 0, 1)
		local steps = math.max(6, math.floor(duration * 30))
		for i = 1, steps do
			if not character.Parent then
				return
			end
			local t = i / steps
			local p = start:Lerp(Vector3.new(target.X, start.Y, target.Z), t) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
			character:PivotTo(if flat.Magnitude > 0.1 then CFrame.lookAt(p, p + flat) else CFrame.new(p) * root.CFrame.Rotation)
			task.wait(duration / steps)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		onLand()
	end)
end

-- Where a leap should land: next to the aimed enemy, or partway along your aim.
local function landingPoint(root: BasePart, aim: Vector3, range: number): Vector3
	local target = findAimTarget(root.Position, aim, range, 0.5)
	if target then
		local offset = (target.Root.Position - root.Position) * Vector3.new(1, 0, 1)
		local direction = if offset.Magnitude > 0.1 then offset.Unit else aim
		local distance = math.max(0, offset.Magnitude - target.Radius - 2)
		return root.Position + direction * clearDistance(root, direction, distance)
	end
	return root.Position + aim * clearDistance(root, aim, range * 0.5)
end

local function stunAround(center: Vector3, radius: number, duration: number)
	for _, enemy in EnemyService.GetEnemiesNear(center, radius) do
		EnemyService.Stun(enemy, duration)
	end
end

-- Handlers return false if nothing happened (no cooldown is used).
local abilityHandlers: { [string]: (Player, Humanoid, BasePart, Vector3, Items.WeaponDef) -> boolean? } = {
	Whirlwind = function(player, _, root, _, weapon)
		local ability = Config.Abilities.Whirlwind
		damageAround(player, root.Position, ability.Radius, ability.DamageMultiplier, weapon)
		Effects.ring(root.Position - Vector3.new(0, 2, 0), ability.Radius, ability.Color)
	end,

	ShieldWall = function(player, _, root)
		local ability = Config.Abilities.ShieldWall
		PlayerService.AddBuff(player, ability.Buff, ability.Duration)
		highlight(root.Parent, ability.Color, 0.7, ability.Duration)
	end,

	Fireball = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.Fireball
		local target = findAimTarget(root.Position, aim, ability.Range, 0.6)
		local from = root.Position + aim * 2 + Vector3.new(0, 1, 0)
		local to = if target then target.Root.Position else from + aim * ability.Range * 0.6
		Effects.projectile("Fireball", from, to, ability.Color, function()
			Effects.burst(to, ability.Radius, ability.Color)
			damageAround(player, to, ability.Radius, ability.DamageMultiplier, weapon)
		end)
	end,

	HealingCircle = function(_, _, root)
		local ability = Config.Abilities.HealingCircle
		healPlayersNear(root.Position, ability.Radius, ability.HealPercent)
		Effects.ring(root.Position - Vector3.new(0, 2.5, 0), ability.Radius, ability.Color)
	end,

	Volley = function(player, _, root, aim, weapon)
		barrage(player, root, aim, weapon, Config.Abilities.Volley, "Arrow")
	end,

	SwiftStep = function(player, _, root)
		local ability = Config.Abilities.SwiftStep
		PlayerService.AddBuff(player, ability.Buff, ability.Duration)
		Effects.ring(root.Position - Vector3.new(0, 2.5, 0), 6, ability.Color)
	end,

	HolyNova = function(player, _, root, _, weapon)
		local ability = Config.Abilities.HolyNova
		healPlayersNear(root.Position, ability.Radius, ability.HealPercent)
		damageAround(player, root.Position, ability.DamageRadius, ability.DamageMultiplier, weapon)
		Effects.ring(root.Position - Vector3.new(0, 2.5, 0), ability.Radius, ability.Color)
		Effects.burst(root.Position, ability.DamageRadius, ability.Color)
	end,

	DivineShield = function(_, _, root)
		local ability = Config.Abilities.DivineShield
		for _, other in Players:GetPlayers() do
			local _, otherRoot = getAlive(other)
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= ability.Radius then
				PlayerService.AddBuff(other, ability.Buff, ability.Duration)
				highlight(otherRoot.Parent, ability.Color, 0.75, ability.Duration)
			end
		end
		Effects.ring(root.Position - Vector3.new(0, 2.5, 0), ability.Radius, ability.Color)
	end,

	ShadowStrike = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.ShadowStrike
		local target = findAimTarget(root.Position, aim, ability.Range, 0.5)
		if not target then
			return false
		end
		Effects.burst(root.Position, 3, ability.Color)
		-- Appear just behind the target, facing it
		local targetPos = target.Root.Position
		local away = (targetPos - root.Position) * Vector3.new(1, 0, 1)
		local behind = targetPos + (if away.Magnitude > 0.1 then away.Unit else aim) * (target.Radius + 2.5)
		local character = root.Parent :: Model
		character:PivotTo(CFrame.lookAt(Vector3.new(behind.X, root.Position.Y, behind.Z), Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)))
		Effects.burst(behind, 3, ability.Color)
		hit(player, target, weapon.Damage * ability.DamageMultiplier, weapon)
		return true
	end,

	Vanish = function(player, _, root)
		local ability = Config.Abilities.Vanish
		local character = root.Parent :: Model
		PlayerService.AddBuff(player, ability.Buff, ability.Duration)
		-- Enemies lose track of you (EnemyService skips "Vanished" characters)
		character:SetAttribute("Vanished", true)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part:SetAttribute("VanishOriginal", part.Transparency)
				part.Transparency = math.max(part.Transparency, 0.75)
			end
		end
		Effects.burst(root.Position, 5, ability.Color)
		task.delay(ability.Duration, function()
			if character.Parent then
				character:SetAttribute("Vanished", nil)
				for _, part in character:GetDescendants() do
					local original = part:IsA("BasePart") and part:GetAttribute("VanishOriginal")
					if original ~= nil then
						(part :: BasePart).Transparency = original
						part:SetAttribute("VanishOriginal", nil)
					end
				end
			end
		end)
	end,

	CoinBarrage = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.CoinBarrage
		barrage(player, root, aim, weapon, ability, "Coin", function()
			PlayerService.AddGold(player, ability.CoinsPerHit, true)
		end)
	end,

	MidasTouch = function(player, _, root)
		local ability = Config.Abilities.MidasTouch
		PlayerService.AddBuff(player, ability.Buff, ability.Duration)
		highlight(root.Parent, ability.Color, 0.6, ability.Duration)
		Effects.burst(root.Position, 6, ability.Color)
	end,

	-- Berserker
	Bloodlust = function(player, _, root)
		local ability = Config.Abilities.Bloodlust
		PlayerService.AddBuff(player, ability.Buff, ability.Duration)
		PlayerService.Heal(player, ability.HealPercent)
		highlight(root.Parent, ability.Color, 0.55, ability.Duration)
		Effects.burst(root.Position, 7, ability.Color)
		Effects.sparks(root.Position, ability.Color, "Smoke", 25)
	end,

	LeapSmash = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.LeapSmash
		leap(root.Parent :: Model, root, landingPoint(root, aim, ability.Range), 10, 0.5, function()
			local ground = root.Position - Vector3.new(0, 2.5, 0)
			Effects.ring(ground, ability.Radius, ability.Color, 0.4)
			Effects.burst(ground, ability.Radius * 0.6, ability.Color, 0.3)
			Effects.sparks(ground, Color3.fromRGB(140, 120, 100), "Smoke", 30)
			for i = 1, 6 do
				local angle = i / 6 * math.pi * 2
				Effects.spike(ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * ability.Radius * 0.6, 3, Color3.fromRGB(120, 100, 85), Enum.Material.Rock)
			end
			Sfx.play("Slam", root, 1.2)
			damageAround(player, root.Position, ability.Radius, ability.DamageMultiplier, weapon)
			stunAround(root.Position, ability.Radius, ability.Stun)
		end)
	end,

	-- Paladin
	Consecration = function(player, _, root, _, weapon)
		local ability = Config.Abilities.Consecration
		local center = root.Position - Vector3.new(0, 2.6, 0)
		local zone = Effects.part({
			Shape = Enum.PartType.Cylinder,
			Color = ability.Color,
			Transparency = 0.55,
			Size = Vector3.new(0.3, ability.Radius * 2, ability.Radius * 2),
			CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		})
		Debris:AddItem(zone, ability.Duration + 0.2)
		task.spawn(function()
			for _ = 1, ability.Duration do
				Effects.ring(center, ability.Radius, ability.Color, 0.6)
				Effects.sparks(center + Vector3.new(0, 1, 0), ability.Color, nil, 20)
				damageAround(player, center, ability.Radius, ability.DamageMultiplier, weapon)
				healPlayersNear(center, ability.Radius, ability.HealPercent)
				task.wait(1)
			end
		end)
	end,

	Judgment = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.Judgment
		local target = findAimTarget(root.Position, aim, ability.Range, 0.5)
		local point = (if target then target.Root.Position else root.Position + aim * 20) - Vector3.new(0, 2.5, 0)
		Effects.warning(point, ability.Radius, ability.Color, 0.5)
		-- A giant sword of light drops from the sky
		local sword = Effects.part({ Size = Vector3.new(1, 14, 3), Color = ability.Color, Transparency = 0.15, CFrame = CFrame.new(point + Vector3.new(0, 40, 0)) })
		local guard = Effects.part({ Size = Vector3.new(1.2, 1, 7), Color = ability.Color, Transparency = 0.15, CFrame = sword.CFrame * CFrame.new(0, 7.5, 0) })
		for _, part in { sword, guard } do
			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = part.CFrame - Vector3.new(0, 33, 0) }):Play()
			Debris:AddItem(part, 1.4)
		end
		task.delay(0.5, function()
			Effects.pillar(point, ability.Radius * 0.6, ability.Color)
			Effects.burst(point, ability.Radius, ability.Color, 0.4)
			Sfx.play("Slam", point, 1.2)
			damageAround(player, point, ability.Radius, ability.DamageMultiplier, weapon)
			stunAround(point, ability.Radius, ability.Stun)
			for _, part in { sword, guard } do
				TweenService:Create(part, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			end
		end)
	end,

	-- Necromancer
	RaiseDead = function(player, _, root, _, weapon)
		local ability = Config.Abilities.RaiseDead
		for i = 1, ability.Count do
			local spirit = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Color = ability.Color, Transparency = 0.3, Position = root.Position + Vector3.new(math.cos(i * 2.1) * 4, 2, math.sin(i * 2.1) * 4) })
			local skull = Effects.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Color = Color3.fromRGB(235, 230, 210), Material = Enum.Material.SmoothPlastic, Position = spirit.Position })
			local fire = Instance.new("Fire")
			fire.Color = ability.Color
			fire.SecondaryColor = Color3.fromRGB(20, 80, 40)
			fire.Size = 3
			fire.Parent = spirit
			Effects.sparks(spirit.Position, ability.Color, "Smoke", 12)
			task.spawn(function()
				local endsAt = os.clock() + ability.Duration
				while os.clock() < endsAt and spirit.Parent do
					local _, ownerRoot = getAlive(player)
					if not ownerRoot then
						break
					end
					local enemies = EnemyService.GetEnemiesNear(ownerRoot.Position, 45)
					local enemy = enemies[math.random(math.max(#enemies, 1))]
					local to = if enemy then enemy.Root.Position + Vector3.new(0, 1, 0) else ownerRoot.Position + Vector3.new(math.cos(i * 2.1 + os.clock()) * 4, 3, math.sin(i * 2.1 + os.clock()) * 4)
					for _, part in { spirit, skull } do
						TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = to }):Play()
					end
					task.wait(0.4)
					if enemy and not enemy.Dead then
						hit(player, enemy, weapon.Damage * ability.DamageMultiplier, weapon)
						Effects.sparks(to, ability.Color, nil, 10)
					end
					task.wait(0.3)
				end
				Effects.sparks(spirit.Position, ability.Color, "Smoke", 15)
				spirit:Destroy()
				skull:Destroy()
			end)
		end
	end,

	SoulHarvest = function(player, _, root, _, weapon)
		local ability = Config.Abilities.SoulHarvest
		local enemies = EnemyService.GetEnemiesNear(root.Position, ability.Radius)
		if #enemies == 0 then
			return false
		end
		Effects.ring(root.Position - Vector3.new(0, 2.5, 0), ability.Radius, ability.Color, 0.5)
		for _, enemy in enemies do
			EnemyService.Pull(enemy, root.Position, 6)
			hit(player, enemy, weapon.Damage * ability.DamageMultiplier, weapon)
			Effects.projectile("Orb", enemy.Root.Position, root.Position, ability.Color, function() end, 60)
		end
		PlayerService.Heal(player, ability.HealPerEnemy * #enemies)
		return true
	end,

	-- Dragoon
	DragonDive = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.DragonDive
		Effects.burst(root.Position, 5, ability.Color, 0.3)
		leap(root.Parent :: Model, root, landingPoint(root, aim, ability.Range), 15, 0.8, function()
			local ground = root.Position - Vector3.new(0, 2.5, 0)
			Effects.pillar(ground, ability.Radius * 0.5, ability.Color, 0.6)
			Effects.ring(ground, ability.Radius, ability.Color, 0.45)
			Effects.sparks(ground, Color3.fromRGB(255, 150, 60), "Fire", 40)
			Sfx.play("Slam", root, 1.3)
			damageAround(player, root.Position, ability.Radius, ability.DamageMultiplier, weapon)
		end)
	end,

	WyvernLance = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.WyvernLance
		local start = root.Position
		local distance = clearDistance(root, aim, ability.Range)
		if distance < 3 then
			return false -- facing a wall
		end
		local finish = start + aim * distance
		Effects.beam(start, finish, ability.Color, 2.5, 0.35)
		for _, enemy in EnemyService.GetEnemiesNear((start + finish) / 2, ability.Range / 2 + 3) do
			local along = math.clamp((enemy.Root.Position - start):Dot(aim), 0, ability.Range)
			if ((enemy.Root.Position - (start + aim * along)) * Vector3.new(1, 0, 1)).Magnitude <= 4 + enemy.Radius then
				hit(player, enemy, weapon.Damage * ability.DamageMultiplier, weapon)
				EnemyService.Knockback(enemy, start, 30)
			end
		end
		local character = root.Parent :: Model
		character:PivotTo(CFrame.lookAt(finish, finish + aim))
		Effects.sparks(finish, ability.Color, nil, 20)
		return true
	end,

	-- Ronin
	Iaido = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.Iaido
		local start = root.Position
		local distance = clearDistance(root, aim, ability.Range)
		if distance < 3 then
			return false -- facing a wall
		end
		local finish = start + aim * distance
		local cut = {}
		for _, enemy in EnemyService.GetEnemiesNear((start + finish) / 2, ability.Range / 2 + 3) do
			local along = math.clamp((enemy.Root.Position - start):Dot(aim), 0, ability.Range)
			if ((enemy.Root.Position - (start + aim * along)) * Vector3.new(1, 0, 1)).Magnitude <= 4 + enemy.Radius then
				table.insert(cut, enemy)
				EnemyService.Stun(enemy, 0.7)
			end
		end
		local character = root.Parent :: Model
		character:PivotTo(CFrame.lookAt(finish, finish + aim))
		local length = distance
		local slash = Effects.part({ Size = Vector3.new(0.2, 0.2, length), Color = ability.Color, CFrame = CFrame.lookAt((start + finish) / 2, finish + aim * 0.01) })
		TweenService:Create(slash, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(0.05, 3, length) }):Play()
		Debris:AddItem(slash, 0.65)
		-- The cut lands a moment after you sheathe
		task.delay(0.6, function()
			for _, enemy in cut do
				if not enemy.Dead then
					Effects.sparks(enemy.Root.Position, ability.Color, nil, 16)
					hit(player, enemy, weapon.Damage * ability.DamageMultiplier, weapon)
				end
			end
			Sfx.play("Lunge", root, 1.5)
		end)
		return true
	end,

	ThousandCuts = function(player, _, root, _, weapon)
		local ability = Config.Abilities.ThousandCuts
		task.spawn(function()
			for i = 1, ability.Ticks do
				local _, liveRoot = getAlive(player)
				if not liveRoot then
					return
				end
				local angle = i * 2.4
				local slash = Effects.part({
					Size = Vector3.new(ability.Radius * 1.6, 0.15, 0.6),
					Color = ability.Color,
					Transparency = 0.2,
					CFrame = CFrame.new(liveRoot.Position) * CFrame.Angles(0, angle, math.rad(math.random(-40, 40))),
				})
				TweenService:Create(slash, TweenInfo.new(0.15), { Transparency = 1 }):Play()
				Debris:AddItem(slash, 0.2)
				damageAround(player, liveRoot.Position, ability.Radius, ability.DamageMultiplier, weapon)
				task.wait(0.12)
			end
		end)
	end,

	-- Seraph (Godly)
	HeavensWrath = function(player, _, root, aim, weapon)
		local ability = Config.Abilities.HeavensWrath
		local target = findAimTarget(root.Position, aim, ability.Range, 0.5)
		local center = (if target then target.Root.Position else root.Position + aim * 22) - Vector3.new(0, 2.5, 0)
		Effects.warning(center, ability.Radius, ability.Color, 2)
		task.spawn(function()
			for _ = 1, ability.Count do
				local point = center + Vector3.new(math.random(-ability.Radius, ability.Radius) * 0.7, 0, math.random(-ability.Radius, ability.Radius) * 0.7)
				local spear = Effects.part({ Size = Vector3.new(0.6, 9, 0.6), Color = ability.Color, CFrame = CFrame.new(point + Vector3.new(0, 45, 0)) })
				TweenService:Create(spear, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(point + Vector3.new(0, 3, 0)) }):Play()
				Debris:AddItem(spear, 0.9)
				task.delay(0.25, function()
					Effects.burst(point, 4, ability.Color, 0.25)
					damageAround(player, point, 6, ability.DamageMultiplier, weapon)
					TweenService:Create(spear, TweenInfo.new(0.6), { Transparency = 1 }):Play()
				end)
				task.wait(0.15)
			end
		end)
	end,

	Ascension = function(player, _, root, _, weapon)
		local ability = Config.Abilities.Ascension
		local character = root.Parent :: Model
		character:SetAttribute("InvulnerableUntil", os.clock() + ability.Duration + 0.5)
		highlight(character, ability.Color, 0.4, ability.Duration + 0.5)
		Effects.pillar(root.Position - Vector3.new(0, 2.5, 0), 4, ability.Color, ability.Duration)
		leap(character, root, root.Position, 14, ability.Duration, function()
			local ground = root.Position - Vector3.new(0, 2.5, 0)
			Effects.burst(root.Position, ability.Radius, ability.Color, 0.5)
			Effects.ring(ground, ability.Radius * 1.2, ability.Color, 0.5)
			Sfx.play("Heal", root, 1.5)
			damageAround(player, root.Position, ability.Radius, ability.DamageMultiplier, weapon)
			healPlayersNear(root.Position, ability.Radius + 8, ability.HealPercent)
		end)
	end,
}

local ABILITY_SOUNDS = {
	Whirlwind = "Lunge",
	ShieldWall = "Unsheath",
	Fireball = "Cast",
	HealingCircle = "Heal",
	Volley = "BowShot",
	SwiftStep = "Dodge",
	HolyNova = "Heal",
	DivineShield = "Heal",
	ShadowStrike = "Lunge",
	Vanish = "Dodge",
	CoinBarrage = "Coins",
	MidasTouch = "Coins",
	Bloodlust = "Slam",
	LeapSmash = "Dodge",
	Consecration = "Heal",
	Judgment = "Cast",
	RaiseDead = "Cast",
	SoulHarvest = "Cast",
	DragonDive = "Dodge",
	WyvernLance = "Lunge",
	Iaido = "Unsheath",
	ThousandCuts = "Swing",
	HeavensWrath = "Cast",
	Ascension = "Heal",
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
	local cooldown = ability.Cooldown * PlayerService.GetCooldownMultiplier(player)
	readyAt[abilityId] = now + cooldown
	if abilityHandlers[abilityId](player, humanoid, root, sanitizeAim(aim, root), weapon) == false then
		readyAt[abilityId] = 0 -- nothing happened (e.g. no target): don't use the cooldown
		return false, 0
	end
	PlayerService.AddStat(player, "AbilitiesUsed")
	broadcastMove(player, WeaponMoves.AbilityAnims[abilityId])
	Sfx.play(ABILITY_SOUNDS[abilityId] or "Lunge", root, 1.3)
	return true, cooldown
end

function CombatService.Start()
	PlayerService.OnCharacterReady(function(player)
		abilityReadyAt[player] = nil
		attackState[player] = nil
		applyLoadout(player)
		-- Seraph passive: survive one killing blow per life (EnemyService checks this)
		local class = PlayerService.GetClass(player)
		if player.Character then
			player.Character:SetAttribute("Revive", if class and class.Revive then true else nil)
		end
	end)
	PlayerService.OnLoadoutChanged(applyLoadout)

	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Remotes.UseAbility.OnServerInvoke = onUseAbility
	Remotes.UseWeaponSkill.OnServerInvoke = onUseWeaponSkill

	Players.PlayerRemoving:Connect(function(player)
		attackState[player] = nil
		abilityReadyAt[player] = nil
	end)

	-- Paladin passive: health regeneration
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local class = PlayerService.GetClass(player)
				local humanoid = getAlive(player)
				if class and class.Regen and humanoid and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * class.Regen)
				end
			end
		end
	end)
end

return CombatService
