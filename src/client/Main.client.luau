-- Client entry point. Builds the UI, sends input to the server, and renders state.
-- The server owns all game state; the client only displays it and sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Items = require(ReplicatedStorage.Shared.Items)
local WeaponMoves = require(ReplicatedStorage.Shared.WeaponMoves)

local UI = script.Parent:WaitForChild("UI")
local Util = require(UI.Util)
local Hud = require(UI.Hud)
local Inventory = require(UI.Inventory)
local Shop = require(UI.Shop)
local ClassRoller = require(UI.ClassRoller)
local PortalPanel = require(UI.PortalPanel)
local AdminPanel = require(UI.AdminPanel)
local CrateWindow = require(UI.CrateWindow)
local StatsWindow = require(UI.StatsWindow)
local QuestWindow = require(UI.QuestWindow)
local SkillsWindow = require(UI.SkillsWindow)
local CardWindow = require(UI.CardWindow)
local PartyWindow = require(UI.PartyWindow)
local EventWindow = require(UI.EventWindow)
local RobuxStore = require(UI.RobuxStore)
local CardUI = require(ReplicatedStorage.Shared.CardUI)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Controllers = script.Parent:WaitForChild("Controllers")
local Movement = require(Controllers.Movement)
local Audio = require(Controllers.Audio)
local Animator = require(Controllers.Animator)
local PetsController = require(Controllers.Pets)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local ABILITY_KEYS = { Enum.KeyCode.Q, Enum.KeyCode.E }
local POTION_KEYS = { Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
local ERROR_COLOR = Color3.fromRGB(255, 90, 90)

-- Your weapon is always out, and we draw our own health bar.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local gui = Util.make("ScreenGui", player:WaitForChild("PlayerGui"), {
	Name = "HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local state = nil
local hud, inventory, shop, classPicker, adminPanel, crateWindow, statsWindow, questWindow, skillsWindow, cardWindow, partyWindow, eventWindow, robuxStore

-- Direction from your character toward the mouse (flat on the ground).
local function getAim(): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local offset = mouse.Hit.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 0.1 then
		return root.CFrame.LookVector
	end
	return flat.Unit
end

-- Calls a RemoteFunction that returns (ok, err) and shows the error if it failed.
local function request(remote: RemoteFunction, ...): boolean
	local ok, err = remote:InvokeServer(...)
	if not ok and type(err) == "string" then
		hud.Toast(err, ERROR_COLOR)
	end
	return ok
end

-- Actions --------------------------------------------------------------------------

local function useAbility(abilityId: string)
	if hud.IsOnCooldown(abilityId) then
		return
	end
	local ok, cooldown, motion = Remotes.UseAbility:InvokeServer(abilityId, getAim())
	if ok then
		Animator.Play(player.Character, WeaponMoves.AbilityAnims[abilityId])
		Animator.Move(motion)
	end
	if cooldown and cooldown > 0 then
		hud.StartCooldown(abilityId, cooldown)
	elseif not ok then
		hud.Toast("Can't use that right now", ERROR_COLOR)
	end
end

-- R: the equipped weapon's own ability (the weapon has to be out).
local function useWeaponSkill()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local weapon = tool and Items.Weapons[tool:GetAttribute("WeaponId") :: string]
	if not weapon then
		hud.Toast("Draw your weapon first [1]", ERROR_COLOR)
		return
	end
	if hud.IsOnCooldown("WeaponSkill") then
		return
	end
	local ok, cooldown, motion = Remotes.UseWeaponSkill:InvokeServer(getAim())
	if ok then
		Animator.Play(player.Character, WeaponMoves.SkillAnims[weapon.Skill.Mechanic])
		Animator.Move(motion)
	end
	if cooldown and cooldown > 0 then
		hud.StartCooldown("WeaponSkill", cooldown)
	elseif not ok then
		hud.Toast("No target in range", ERROR_COLOR)
	end
end

local function usePotion(potionId: string)
	request(Remotes.UsePotion, potionId)
end

-- Key 1: draw or put away your weapon.
local function toggleWeapon()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if character:FindFirstChildOfClass("Tool") then
		humanoid:UnequipTools()
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("WeaponId") then
				humanoid:EquipTool(tool)
				return
			end
		end
	end
end

hud = Hud.new(gui, {
	UseAbility = useAbility,
	UseWeaponSkill = useWeaponSkill,
	UsePotion = usePotion,
	ToggleInventory = function()
		inventory.Toggle()
	end,
	OpenClassPicker = function()
		classPicker.Open()
	end,
	OpenAdmin = function()
		adminPanel.Toggle()
	end,
	ToggleStats = function()
		statsWindow.Toggle()
	end,
	ToggleQuests = function()
		questWindow.Toggle()
	end,
	ToggleSkills = function()
		skillsWindow.Toggle()
	end,
	ToggleCard = function()
		cardWindow.Toggle()
	end,
	ToggleParty = function()
		partyWindow.Toggle()
	end,
	ToggleEvent = function()
		eventWindow.Toggle()
	end,
	ToggleStore = function()
		robuxStore.Toggle()
	end,
	ToggleWeapon = toggleWeapon,
	ToggleMusic = Audio.ToggleMusic,
	SetSprint = Movement.SetSprint,
	Dodge = Movement.Dodge,
})

adminPanel = AdminPanel.new(gui, function(action, arg)
	local ok, message = Remotes.Admin:InvokeServer(action, arg)
	if message then
		hud.Toast(message, if ok then Color3.fromRGB(150, 255, 150) else ERROR_COLOR)
	end
end)

inventory = Inventory.new(gui, function(kind, id)
	request(Remotes.Equip, kind, id)
end)

shop = Shop.new(gui, function(potionId)
	if request(Remotes.BuyPotion, potionId) then
		Util.playSfx("Coins")
		hud.Toast(`Bought {Config.Potions[potionId].DisplayName}`, Config.Potions[potionId].Color)
	end
end)

questWindow = QuestWindow.new(gui, function(kind, index)
	if request(Remotes.ClaimQuest, kind, index) then
		Util.playSfx("Coins")
	end
end)

skillsWindow = SkillsWindow.new(gui, function(skillId)
	request(Remotes.UpgradeSkill, skillId)
end)

cardWindow = CardWindow.new(gui, {
	Set = function(field, value)
		request(Remotes.SetCard, field, value)
	end,
	Prestige = function()
		request(Remotes.Prestige)
	end,
	GetCard = function(userId)
		return Remotes.GetCard:InvokeServer(userId)
	end,
})

partyWindow = PartyWindow.new(gui, function(message, isError)
	hud.Toast(message, if isError then ERROR_COLOR else Color3.fromRGB(150, 255, 150))
end)

eventWindow = EventWindow.new(gui, {
	Open = function(currency)
		return Remotes.OpenHalloweenCrate:InvokeServer(currency)
	end,
	EquipPet = function(petId)
		request(Remotes.EquipPet, petId)
	end,
	EquipClass = function(classId)
		local ok, message = Remotes.EquipLimitedClass:InvokeServer(classId)
		if message then
			hud.Toast(message, if ok then Config.Rarities.Limited else ERROR_COLOR)
		end
	end,
}, function(message, isError)
	hud.Toast(message, if isError then ERROR_COLOR else Config.Rarities.Limited)
end)
Remotes.OpenEvent.OnClientEvent:Connect(eventWindow.Open)

-- The event button shows while the event runs (or if you still have candies to spend)
local function updateEventButton()
	local active = workspace:GetAttribute("HalloweenActive") == true
	hud.SetEventButton(active, "Halloween Event [K]")
end
workspace:GetAttributeChangedSignal("HalloweenActive"):Connect(updateEventButton)
updateEventButton()

statsWindow = StatsWindow.new(gui, function()
	return Remotes.GetLeaderboards:InvokeServer()
end)

crateWindow = CrateWindow.new(gui, function(crateId)
	return Remotes.OpenCrate:InvokeServer(crateId)
end, function(result)
	Util.playSfx(if result.Rarity == "Godly" or result.Rarity == "Mythic" then "LevelUp" else "Coins")
	if result.IsNew then
		hud.Toast(`New armor: {result.DisplayName}! Equip it in Gear [G]`, Config.Rarities[result.Rarity])
	end
end)

local function classSlot(action: string, slot: number?)
	local ok, message = Remotes.ClassSlot:InvokeServer(action, slot)
	if message then
		hud.Toast(message, if ok then Color3.fromRGB(150, 255, 150) else ERROR_COLOR)
	end
end

classPicker = ClassRoller.new(gui, function(currency)
	request(Remotes.RollClass, currency)
end, classSlot)

robuxStore = RobuxStore.new(gui, {
	BuyPerk = function(perkId)
		request(Remotes.RobuxStore, "Perk", perkId)
	end,
	BuyArmor = function(setId)
		request(Remotes.RobuxStore, "Armor", setId)
	end,
	BuySlot = function()
		classSlot("Buy")
	end,
})
Remotes.ClassRolled.OnClientEvent:Connect(classPicker.ShowRoll)

local portalPanel = PortalPanel.new(gui, function(difficultyId)
	request(Remotes.SetDifficulty, difficultyId)
end)

-- Server -> client -----------------------------------------------------------------

local function render(newState)
	if not newState then
		return
	end
	state = newState
	hud.Render(state)
	inventory.Render(state)
	shop.Render(state)
	crateWindow.Render(state)
	eventWindow.Render(state)
	statsWindow.Render(state)
	skillsWindow.Render(state)
	cardWindow.Render(state)
	classPicker.Render(state)
	robuxStore.Render(state)
end

Remotes.StateChanged.OnClientEvent:Connect(render)
Remotes.Notify.OnClientEvent:Connect(function(message, color)
	hud.Toast(message, color)
end)
Remotes.DungeonStatus.OnClientEvent:Connect(function(status, info)
	hud.SetStatus(status)
	Audio.SetDungeon(if status then info else nil)
end)
Remotes.PortalUpdate.OnClientEvent:Connect(portalPanel.Update)
Remotes.OpenShop.OnClientEvent:Connect(shop.Open)
Remotes.OpenCrates.OnClientEvent:Connect(crateWindow.Open)
Remotes.OpenSkills.OnClientEvent:Connect(skillsWindow.Open)
Remotes.OpenQuests.OnClientEvent:Connect(questWindow.Open)
Remotes.QuestsChanged.OnClientEvent:Connect(questWindow.Render)

-- Animated (spinning) gradients on high prestige emblems and frames
RunService.RenderStepped:Connect(function(dt)
	for _, gradient in CollectionService:GetTagged(CardUI.SpinTag) do
		(gradient :: UIGradient).Rotation = ((gradient :: UIGradient).Rotation + dt * 60) % 360
	end
end)

-- Attacking --------------------------------------------------------------------------
-- Clicking with your weapon out sends the aim direction; the server does the damage.
-- The combo step is worked out here too (same rules as the server) so the move's
-- animation plays instantly.

local combo = { Step = 0, Time = 0, ReadyAt = 0 }

local function attack(tool: Tool)
	local weapon = Items.Weapons[tool:GetAttribute("WeaponId") :: string]
	local moves = weapon and WeaponMoves.Combos[weapon.Combo]
	local now = os.clock()
	if not moves or now < combo.ReadyAt then
		return
	end
	local step = if now - combo.Time <= WeaponMoves.ComboWindow and combo.Step < #moves.Steps then combo.Step + 1 else 1
	combo.Step = step
	combo.Time = now
	combo.ReadyAt = now + moves.Steps[step].Cooldown
	Remotes.Attack:FireServer(getAim())
	Animator.Play(player.Character, moves.Steps[step].Anim)
end

local watchedTools: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watchTool(child: Instance)
	-- Tools move between the backpack and the character, so only connect once.
	if child:IsA("Tool") and child:GetAttribute("WeaponId") and not watchedTools[child] then
		watchedTools[child] = true
		child.Activated:Connect(function()
			attack(child)
		end)
	end
end

local function watchCharacter(character: Model)
	combo.Step = 0
	character.ChildAdded:Connect(watchTool)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end

-- Keyboard -----------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not state then
		return
	end
	local class = state.Class and Config.Classes[state.Class]
	if class then
		local abilityIndex = table.find(ABILITY_KEYS, input.KeyCode)
		if abilityIndex and class.Abilities[abilityIndex] then
			useAbility(class.Abilities[abilityIndex])
			return
		end
	end
	local potionIndex = table.find(POTION_KEYS, input.KeyCode)
	if potionIndex then
		usePotion(Config.PotionOrder[potionIndex])
	elseif input.KeyCode == Enum.KeyCode.R then
		useWeaponSkill()
	elseif input.KeyCode == Enum.KeyCode.One then
		toggleWeapon()
	elseif input.KeyCode == Enum.KeyCode.G then
		inventory.Toggle()
	elseif input.KeyCode == Enum.KeyCode.T then
		statsWindow.Toggle()
	elseif input.KeyCode == Enum.KeyCode.J then
		questWindow.Toggle()
	elseif input.KeyCode == Enum.KeyCode.H then
		cardWindow.Toggle()
	elseif input.KeyCode == Enum.KeyCode.O then
		partyWindow.Toggle()
	elseif input.KeyCode == Enum.KeyCode.K then
		eventWindow.Toggle()
	elseif input.KeyCode == Enum.KeyCode.B then
		robuxStore.Toggle()
	elseif input.KeyCode == Enum.KeyCode.P and player:GetAttribute("IsAdmin") then
		adminPanel.Toggle()
	end
end)

Remotes.BossBar.OnClientEvent:Connect(function(info)
	hud.SetBossBar(info)
end)

Movement.Start(Util.playSfx)
Audio.Start()
Animator.Start()
PetsController.Start()

-- Data may have loaded before this script started listening.
task.spawn(function()
	questWindow.Render(Remotes.GetQuests:InvokeServer())
end)
render(Remotes.GetState:InvokeServer())
