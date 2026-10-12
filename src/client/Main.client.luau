-- Client entry point. Builds the UI, sends input to the server, and renders state.
-- The server owns all game state; the client only displays it and sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local UI = script.Parent:WaitForChild("UI")
local Util = require(UI.Util)
local Hud = require(UI.Hud)
local Inventory = require(UI.Inventory)
local Shop = require(UI.Shop)
local ClassPicker = require(UI.ClassPicker)
local PortalPanel = require(UI.PortalPanel)
local AdminPanel = require(UI.AdminPanel)
local CrateWindow = require(UI.CrateWindow)
local StatsWindow = require(UI.StatsWindow)
local QuestWindow = require(UI.QuestWindow)
local SkillsWindow = require(UI.SkillsWindow)
local CardWindow = require(UI.CardWindow)
local CardUI = require(ReplicatedStorage.Shared.CardUI)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Controllers = script.Parent:WaitForChild("Controllers")
local Movement = require(Controllers.Movement)
local Audio = require(Controllers.Audio)

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
})

local state = nil
local hud, inventory, shop, classPicker, adminPanel, crateWindow, statsWindow, questWindow, skillsWindow, cardWindow

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
	local ok, cooldown = Remotes.UseAbility:InvokeServer(abilityId, getAim())
	if cooldown and cooldown > 0 then
		hud.StartCooldown(abilityId, cooldown)
	elseif not ok then
		hud.Toast("Can't use that right now", ERROR_COLOR)
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

classPicker = ClassPicker.new(gui, function(classId)
	if request(Remotes.ChooseClass, classId) then
		classPicker.Close()
	end
end)

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
	statsWindow.Render(state)
	skillsWindow.Render(state)
	cardWindow.Render(state)
	classPicker.Render(state)
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
-- Clicking with your weapon out sends the aim direction; the server does the rest.

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			child.Activated:Connect(function()
				Remotes.Attack:FireServer(getAim())
			end)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			child.Activated:Connect(function()
				Remotes.Attack:FireServer(getAim())
			end)
		end
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
	elseif input.KeyCode == Enum.KeyCode.P and player:GetAttribute("IsAdmin") then
		adminPanel.Toggle()
	end
end)

Movement.Start(Util.playSfx)
Audio.Start()

-- Data may have loaded before this script started listening.
task.spawn(function()
	questWindow.Render(Remotes.GetQuests:InvokeServer())
end)
render(Remotes.GetState:InvokeServer())
