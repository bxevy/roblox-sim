-- Player progression: level, XP, gold, weapon inventory, leaderstats, and health scaling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local DataService = require(script.Parent.DataService)

local PlayerService = {}

local characterReadyCallbacks: { (Player, Model) -> () } = {}
local equipChangedCallbacks: { (Player) -> () } = {}

local function buildState(data)
	return {
		Level = data.Level,
		XP = data.XP,
		XPNeeded = Config.XPToLevel(data.Level),
		Gold = data.Gold,
		Equipped = data.Equipped,
		Inventory = data.Inventory,
	}
end

local function push(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = data.Level
		leaderstats.Gold.Value = data.Gold
	end
	Remotes.StateChanged:FireClient(player, buildState(data))
end

local function setupLeaderstats(player: Player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data.Level
	level.Parent = leaderstats

	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = data.Gold
	gold.Parent = leaderstats

	leaderstats.Parent = player
end

local function applyMaxHealth(player: Player, refill: boolean)
	local data = DataService.Get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.MaxHealth = Config.MaxHealth(data.Level)
	if refill then
		humanoid.Health = humanoid.MaxHealth
	end
end

local function fireCharacterReady(player: Player, character: Model)
	character:WaitForChild("Humanoid")
	applyMaxHealth(player, true)
	for _, callback in characterReadyCallbacks do
		task.spawn(callback, player, character)
	end
end

function PlayerService.Notify(player: Player, message: string, color: Color3?)
	Remotes.Notify:FireClient(player, message, color)
end

function PlayerService.GetData(player: Player)
	return DataService.Get(player)
end

function PlayerService.GetLevel(player: Player): number
	local data = DataService.Get(player)
	return data and data.Level or 1
end

function PlayerService.GetWeapon(player: Player): Weapons.WeaponDef
	local data = DataService.Get(player)
	return data and Weapons.Defs[data.Equipped] or Weapons.Defs.WoodenSword
end

function PlayerService.AddGold(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Gold += math.floor(amount)
	push(player)
end

function PlayerService.AddXP(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.XP += math.floor(amount)
	local leveledUp = false
	while data.Level < Config.MaxLevel and data.XP >= Config.XPToLevel(data.Level) do
		data.XP -= Config.XPToLevel(data.Level)
		data.Level += 1
		leveledUp = true
	end
	if leveledUp then
		applyMaxHealth(player, true)
		PlayerService.Notify(player, `LEVEL UP! You are now level {data.Level}`, Color3.fromRGB(255, 220, 80))
	end
	push(player)
end

-- Adds a weapon to the player's inventory. Returns false if they already owned it.
function PlayerService.GiveWeapon(player: Player, weaponId: string): boolean
	local data = DataService.Get(player)
	if not data or not Weapons.Defs[weaponId] or data.Inventory[weaponId] then
		return false
	end
	data.Inventory[weaponId] = true
	push(player)
	return true
end

-- Runs whenever a player's character spawns and their data is loaded.
function PlayerService.OnCharacterReady(callback: (Player, Model) -> ())
	table.insert(characterReadyCallbacks, callback)
end

function PlayerService.OnEquipChanged(callback: (Player) -> ())
	table.insert(equipChangedCallbacks, callback)
end

local function onEquipWeapon(player: Player, weaponId: unknown)
	local data = DataService.Get(player)
	if not data then
		return false, "Still loading"
	end
	if type(weaponId) ~= "string" or not data.Inventory[weaponId] then
		return false, "You don't own that weapon"
	end
	data.Equipped = weaponId
	push(player)
	for _, callback in equipChangedCallbacks do
		task.spawn(callback, player)
	end
	return true
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		if DataService.Get(player) then
			fireCharacterReady(player, character)
		end
	end)
end

function PlayerService.Start()
	DataService.OnLoaded(function(player, data)
		-- Drop weapons that were removed from the game, and keep the starter sword.
		for weaponId in data.Inventory do
			if not Weapons.Defs[weaponId] then
				data.Inventory[weaponId] = nil
			end
		end
		data.Inventory.WoodenSword = true
		if not data.Inventory[data.Equipped] then
			data.Equipped = "WoodenSword"
		end

		setupLeaderstats(player, data)
		push(player)
		if player.Character then
			fireCharacterReady(player, player.Character)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Remotes.EquipWeapon.OnServerInvoke = onEquipWeapon
	Remotes.GetState.OnServerInvoke = function(player)
		local data = DataService.Get(player)
		return data and buildState(data)
	end
end

return PlayerService
