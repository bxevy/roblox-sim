-- Player combat: gives each player their equipped sword, handles swings and abilities.
-- Everything is checked on the server (cooldowns, range, damage).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)

local TOOL_TAG = "DungeonWeapon"

local CombatService = {}

local lastSwing: { [Player]: number } = {}
local abilityReadyAt: { [Player]: { [string]: number } } = {}

local function getAlive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function rollDamage(player: Player, base: number): (number, boolean)
	local amount = base * Config.DamageMultiplier(PlayerService.GetLevel(player)) * (0.9 + math.random() * 0.2)
	local isCrit = math.random() < Config.CritChance
	if isCrit then
		amount *= Config.CritMultiplier
	end
	return amount, isCrit
end

-- Swords -------------------------------------------------------------------

local function slashEffect(root: BasePart, weapon: Weapons.WeaponDef)
	local slash = Instance.new("Part")
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanQuery = false
	slash.Material = Enum.Material.Neon
	slash.Color = weapon.BladeColor
	slash.Transparency = 0.4
	slash.Size = Vector3.new(weapon.Range * 1.4, 0.2, 1.2)
	slash.CFrame = root.CFrame * CFrame.new(0, 0.5, -weapon.Range / 2) * CFrame.Angles(0, math.rad(math.random(-25, 25)), math.rad(math.random(-30, 30)))
	slash.Parent = workspace
	TweenService:Create(slash, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(slash, 0.2)
end

local function swing(player: Player, tool: Tool)
	local weapon = PlayerService.GetWeapon(player)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < weapon.Cooldown then
		return
	end
	local _, root = getAlive(player)
	if not root then
		return
	end
	lastSwing[player] = now

	-- The default character Animate script plays a slash animation when it sees this value.
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	slashEffect(root, weapon)

	local look = root.CFrame.LookVector
	for _, enemy in EnemyService.GetEnemiesNear(root.Position, weapon.Range) do
		local offset = enemy.Root.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		-- Hit enemies in a wide arc in front of you (or ones basically on top of you).
		if flat.Magnitude < 3 or flat.Unit:Dot(look) > 0.25 then
			local amount, isCrit = rollDamage(player, weapon.Damage)
			EnemyService.Damage(enemy, amount, isCrit)
		end
	end
end

local function buildTool(weaponId: string): Tool
	local weapon = Weapons.Defs[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = weapon.DisplayName
	tool.CanBeDropped = false
	tool.ToolTip = `{weapon.Rarity} - {weapon.Damage} damage`
	tool:SetAttribute(TOOL_TAG, weaponId)

	local length = weapon.BladeLength
	-- The Handle is the blade; Grip shifts it so the bottom of the blade sits in the hand.
	local blade = Instance.new("Part")
	blade.Name = "Handle"
	blade.Size = Vector3.new(0.2, length, 0.6)
	blade.Color = weapon.BladeColor
	blade.Material = weapon.BladeMaterial
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = tool
	tool.Grip = CFrame.new(0, -length / 2 + 0.4, 0)

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.35, 0.3, 1.6)
	guard.Color = Color3.fromRGB(90, 70, 40)
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.Massless = true
	guard.CFrame = blade.CFrame * CFrame.new(0, -length / 2 + 0.8, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = blade
	weld.Part1 = guard
	weld.Parent = guard
	guard.Parent = tool

	return tool
end

local function removeWeaponTools(player: Player)
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(TOOL_TAG) then
					child:Destroy()
				end
			end
		end
	end
end

local function giveWeapon(player: Player)
	local data = PlayerService.GetData(player)
	local humanoid = getAlive(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not data or not humanoid or not backpack then
		return
	end
	removeWeaponTools(player)

	local tool = buildTool(data.Equipped)
	tool.Activated:Connect(function()
		swing(player, tool)
	end)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

-- Abilities ----------------------------------------------------------------

local function whirlwind(player: Player, root: BasePart)
	local ability = Config.Abilities.Whirlwind
	local weapon = PlayerService.GetWeapon(player)
	for _, enemy in EnemyService.GetEnemiesNear(root.Position, ability.Radius) do
		local amount, isCrit = rollDamage(player, weapon.Damage * ability.DamageMultiplier)
		EnemyService.Damage(enemy, amount, isCrit)
	end

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = ability.Color
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.3), {
		Size = Vector3.new(0.4, ability.Radius * 2, ability.Radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.35)
end

local function heal(_player: Player, root: BasePart, humanoid: Humanoid)
	local ability = Config.Abilities.Heal
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * ability.HealPercent)

	local glow = Instance.new("Part")
	glow.Shape = Enum.PartType.Ball
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Color = ability.Color
	glow.Transparency = 0.5
	glow.Size = Vector3.one * 4
	glow.Position = root.Position
	glow.Parent = workspace
	TweenService:Create(glow, TweenInfo.new(0.5), { Size = Vector3.one * 9, Transparency = 1 }):Play()
	Debris:AddItem(glow, 0.55)
end

local function onUseAbility(player: Player, abilityId: unknown): (boolean, number)
	if type(abilityId) ~= "string" or not Config.Abilities[abilityId] then
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
	if abilityId == "Whirlwind" then
		whirlwind(player, root)
	elseif abilityId == "Heal" then
		heal(player, root, humanoid)
	end
	return true, ability.Cooldown
end

function CombatService.Start()
	PlayerService.OnCharacterReady(giveWeapon)
	PlayerService.OnEquipChanged(giveWeapon)
	Remotes.UseAbility.OnServerInvoke = onUseAbility

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		abilityReadyAt[player] = nil
	end)
end

return CombatService
