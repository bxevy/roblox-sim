-- The potion shop in the lobby: builds the stall, sells potions, and lets players drink them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local SHOP_POSITION = Vector3.new(38, 0, 6)

local ShopService = {}

local lastHealPotion: { [Player]: number } = {}

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildStall()
	local stall = Instance.new("Model")
	stall.Name = "PotionShop"

	-- Faces -X (toward the spawn).
	local base = CFrame.lookAt(SHOP_POSITION, SHOP_POSITION - Vector3.xAxis)
	local wood = Color3.fromRGB(110, 75, 45)

	local counter = block(stall, "Counter", Vector3.new(12, 3.5, 3), base * CFrame.new(0, 1.75, 0), wood, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		block(stall, "Post", Vector3.new(1, 11, 1), base * CFrame.new(side * 5.5, 5.5, 3), wood, Enum.Material.Wood)
		block(stall, "Post", Vector3.new(1, 11, 1), base * CFrame.new(side * 5.5, 5.5, -1), wood, Enum.Material.Wood)
	end
	-- Striped awning
	for i = 0, 5 do
		local color = if i % 2 == 0 then Color3.fromRGB(170, 50, 140) else Color3.fromRGB(240, 230, 210)
		block(stall, "Awning", Vector3.new(2, 0.4, 6), base * CFrame.new(-5 + i * 2, 11, 1) * CFrame.Angles(math.rad(-12), 0, 0), color, Enum.Material.Fabric)
	end

	-- Potion bottles on the counter
	for i, potionId in Config.PotionOrder do
		local potion = Config.Potions[potionId]
		local bottle = block(stall, "Bottle", Vector3.new(0.8, 1.2, 0.8), base * CFrame.new(-4 + (i - 1) * 2, 4.1, 0), potion.Color, Enum.Material.Glass)
		bottle.Transparency = 0.2
		bottle.CanCollide = false
	end

	local sign = block(stall, "Sign", Vector3.new(8, 2, 0.4), base * CFrame.new(0, 9, -1.3), wood, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.Text = "POTIONS"
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Potion Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(function(player)
		Remotes.OpenShop:FireClient(player)
	end)

	stall.Parent = workspace
end

local function onBuyPotion(player: Player, potionId: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	if type(potionId) ~= "string" or not Config.Potions[potionId] then
		return false, "Unknown potion"
	end
	if player:GetAttribute("InDungeon") then
		return false, "The shop is in the lobby"
	end
	local count = data.Potions[potionId] or 0
	if count >= Config.MaxPotionStack then
		return false, `You can only carry {Config.MaxPotionStack}`
	end
	if not PlayerService.SpendGold(player, Config.Potions[potionId].Price) then
		return false, "Not enough Gold"
	end
	data.Potions[potionId] = count + 1
	PlayerService.Push(player)
	return true
end

local function onUsePotion(player: Player, potionId: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data or type(potionId) ~= "string" or not Config.Potions[potionId] then
		return false, "Unknown potion"
	end
	if (data.Potions[potionId] or 0) <= 0 then
		return false, "You don't have any - buy some at the shop"
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "You're dead"
	end

	local potion = Config.Potions[potionId]
	if potion.Heal then
		local now = os.clock()
		if now - (lastHealPotion[player] or 0) < Config.HealPotionCooldown then
			return false, "Healing potions are on cooldown"
		end
		if humanoid.Health >= humanoid.MaxHealth then
			return false, "Already at full health"
		end
		lastHealPotion[player] = now
		PlayerService.Heal(player, potion.Heal)
	elseif potion.Buff then
		PlayerService.AddBuff(player, potion.Buff, potion.Duration)
	end

	data.Potions[potionId] -= 1
	if data.Potions[potionId] <= 0 then
		data.Potions[potionId] = nil
	end
	PlayerService.Push(player)
	return true
end

function ShopService.Start()
	buildStall()
	Remotes.BuyPotion.OnServerInvoke = onBuyPotion
	Remotes.UsePotion.OnServerInvoke = onUsePotion
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastHealPotion[player] = nil
	end)
end

return ShopService
