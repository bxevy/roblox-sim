-- Player progression and stats: level, XP, gold, class, items, potions, buffs,
-- leaderstats, and applying health / speed / defense to the character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local PlayerService = {}

local characterReadyCallbacks: { (Player, Model) -> () } = {}
local loadoutChangedCallbacks: { (Player) -> () } = {}
local buffs: { [Player]: { [string]: number } } = {} -- buff id -> expires at (os.clock)

-- Stats --------------------------------------------------------------------

local function getClass(data): Config.ClassDef?
	return data.Class and Config.Classes[data.Class]
end

local function buffTotal(player: Player, stat: string): number
	local total = 0
	local now = os.clock()
	for buffId, expiresAt in buffs[player] or {} :: { [string]: number } do
		if expiresAt > now then
			total += Config.Buffs[buffId][stat] or 0
		end
	end
	return total
end

function PlayerService.GetMaxHealth(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 100
	end
	local class = getClass(data)
	local armor = data.Equipped.Armor and Items.Armors[data.Equipped.Armor]
	local health = Config.BaseHealth(data.Level) * (if class then class.HealthMultiplier else 1)
	return math.floor(health + (if armor then armor.Health else 0))
end

function PlayerService.GetDefense(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local class = getClass(data)
	local armor = data.Equipped.Armor and Items.Armors[data.Equipped.Armor]
	local defense = (if class then class.Defense else 0) + (if armor then armor.Defense else 0) + buffTotal(player, "Defense")
	return math.min(defense, Config.MaxDefense)
end

function PlayerService.GetDamageMultiplier(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local class = getClass(data)
	return Config.LevelDamageMultiplier(data.Level) * (if class then class.DamageMultiplier else 1) * (1 + buffTotal(player, "Damage"))
end

function PlayerService.GetWalkSpeed(player: Player): number
	local data = DataService.Get(player)
	local class = data and getClass(data)
	return Config.BaseWalkSpeed * (if class then class.SpeedMultiplier else 1) * (1 + buffTotal(player, "Speed"))
end

-- Pushes current stats onto the character. `refill` restores full health.
function PlayerService.RefreshStats(player: Player, refill: boolean?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not DataService.Get(player) then
		return
	end
	humanoid.MaxHealth = PlayerService.GetMaxHealth(player)
	humanoid.Health = if refill then humanoid.MaxHealth else math.min(humanoid.Health, humanoid.MaxHealth)
	humanoid.WalkSpeed = PlayerService.GetWalkSpeed(player)
	-- Enemies read this attribute when they hit you.
	character:SetAttribute("Defense", PlayerService.GetDefense(player))
end

-- State sync ---------------------------------------------------------------

local function buildState(player: Player, data)
	local now = os.clock()
	local activeBuffs = {}
	for buffId, expiresAt in buffs[player] or {} :: { [string]: number } do
		if expiresAt > now then
			activeBuffs[buffId] = expiresAt - now
		end
	end
	return {
		Level = data.Level,
		XP = data.XP,
		XPNeeded = Config.XPToLevel(data.Level),
		Gold = data.Gold,
		Class = data.Class,
		Weapons = data.Weapons,
		Armors = data.Armors,
		Equipped = data.Equipped,
		Potions = data.Potions,
		Buffs = activeBuffs, -- buff id -> seconds remaining
		Stats = {
			MaxHealth = PlayerService.GetMaxHealth(player),
			Defense = PlayerService.GetDefense(player),
			Damage = PlayerService.GetDamageMultiplier(player),
		},
	}
end

function PlayerService.Push(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Level") :: IntValue).Value = data.Level;
		(leaderstats:FindFirstChild("Gold") :: IntValue).Value = data.Gold
	end
	Remotes.StateChanged:FireClient(player, buildState(player, data))
end

local function setupLeaderstats(player: Player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Level", "Gold" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Value = data[name]
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

local function fireLoadoutChanged(player: Player)
	for _, callback in loadoutChangedCallbacks do
		task.spawn(callback, player)
	end
end

-- Public API -----------------------------------------------------------------

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

function PlayerService.GetClass(player: Player): Config.ClassDef?
	local data = DataService.Get(player)
	return data and getClass(data)
end

function PlayerService.GetWeapon(player: Player): Items.WeaponDef?
	local data = DataService.Get(player)
	return data and data.Equipped.Weapon and Items.Weapons[data.Equipped.Weapon]
end

function PlayerService.GetArmor(player: Player): Items.ArmorDef?
	local data = DataService.Get(player)
	return data and data.Equipped.Armor and Items.Armors[data.Equipped.Armor]
end

function PlayerService.AddGold(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Gold += math.floor(amount)
	PlayerService.Push(player)
end

-- Returns false (and charges nothing) if the player can't afford it.
function PlayerService.SpendGold(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or data.Gold < amount then
		return false
	end
	data.Gold -= amount
	PlayerService.Push(player)
	return true
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
		PlayerService.RefreshStats(player, true)
		PlayerService.Notify(player, `LEVEL UP! You are now level {data.Level}`, Color3.fromRGB(255, 220, 80))
	end
	PlayerService.Push(player)
end

function PlayerService.SetLevel(player: Player, level: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Level = math.clamp(math.floor(level), 1, Config.MaxLevel)
	data.XP = 0
	PlayerService.RefreshStats(player, true)
	PlayerService.Push(player)
end

-- Adds an item to the player's inventory. Returns false if they already owned it.
function PlayerService.GiveItem(player: Player, kind: string, itemId: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local owned = if kind == "Weapon" then data.Weapons else data.Armors
	local defs = if kind == "Weapon" then Items.Weapons else Items.Armors
	if not defs[itemId] or owned[itemId] then
		return false
	end
	owned[itemId] = true
	PlayerService.Push(player)
	return true
end

function PlayerService.Heal(player: Player, fraction: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * fraction)
	end
end

function PlayerService.AddBuff(player: Player, buffId: string, duration: number)
	local playerBuffs = buffs[player]
	if not playerBuffs then
		return
	end
	local expiresAt = os.clock() + duration
	playerBuffs[buffId] = expiresAt
	PlayerService.RefreshStats(player)
	PlayerService.Push(player)

	task.delay(duration, function()
		-- Only expire if it wasn't refreshed (or cleared) in the meantime.
		if buffs[player] == playerBuffs and playerBuffs[buffId] == expiresAt then
			playerBuffs[buffId] = nil
			PlayerService.RefreshStats(player)
			PlayerService.Push(player)
		end
	end)
end

-- Runs whenever a player's character spawns and their data is loaded.
function PlayerService.OnCharacterReady(callback: (Player, Model) -> ())
	table.insert(characterReadyCallbacks, callback)
end

-- Runs when the player's class, weapon or armor changes.
function PlayerService.OnLoadoutChanged(callback: (Player) -> ())
	table.insert(loadoutChangedCallbacks, callback)
end

-- Equipping & classes ----------------------------------------------------------

local function bestWeaponOfType(data, weaponType: string): string?
	local bestId, bestTier = nil, 0
	for weaponId in data.Weapons do
		local weapon = Items.Weapons[weaponId]
		if weapon and weapon.Type == weaponType and weapon.Tier > bestTier then
			bestId, bestTier = weaponId, weapon.Tier
		end
	end
	return bestId
end

-- Makes sure the player's class has its starter weapon and a valid weapon equipped.
local function fixLoadout(data)
	local class = getClass(data)
	if not class then
		data.Equipped.Weapon = nil
		return
	end
	data.Weapons[class.StarterWeapon] = true
	local current = data.Equipped.Weapon and Items.Weapons[data.Equipped.Weapon]
	if not current or current.Type ~= class.WeaponType or not data.Weapons[current.Id] then
		data.Equipped.Weapon = bestWeaponOfType(data, class.WeaponType)
	end
end

local function onEquip(player: Player, kind: unknown, itemId: unknown): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Still loading"
	end
	if type(itemId) ~= "string" then
		return false, "Unknown item"
	end

	if kind == "Weapon" then
		local weapon = Items.Weapons[itemId]
		local class = getClass(data)
		if not weapon or not data.Weapons[itemId] then
			return false, "You don't own that weapon"
		end
		if not class or weapon.Type ~= class.WeaponType then
			return false, "Your class can't use that weapon"
		end
		data.Equipped.Weapon = itemId
	elseif kind == "Armor" then
		if not Items.Armors[itemId] or not data.Armors[itemId] then
			return false, "You don't own that armor"
		end
		-- Clicking your equipped armor takes it off.
		data.Equipped.Armor = if data.Equipped.Armor == itemId then nil else itemId
	else
		return false, "Unknown item"
	end

	PlayerService.RefreshStats(player)
	PlayerService.Push(player)
	fireLoadoutChanged(player)
	return true
end

local function onChooseClass(player: Player, classId: unknown): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Still loading"
	end
	if type(classId) ~= "string" or not Config.Classes[classId] then
		return false, "Unknown class"
	end
	if player:GetAttribute("InDungeon") then
		return false, "You can't change class inside a dungeon"
	end
	if data.Class == classId then
		return true
	end

	data.Class = classId
	fixLoadout(data)
	PlayerService.RefreshStats(player, true)
	PlayerService.Push(player)
	fireLoadoutChanged(player)
	PlayerService.Notify(player, `You are now a {Config.Classes[classId].DisplayName}!`, Config.Classes[classId].Color)
	return true
end

-- Setup ----------------------------------------------------------------------

local function fireCharacterReady(player: Player, character: Model)
	character:WaitForChild("Humanoid")
	buffs[player] = {} -- buffs end when you die
	PlayerService.RefreshStats(player, true)
	PlayerService.Push(player)
	for _, callback in characterReadyCallbacks do
		task.spawn(callback, player, character)
	end
end

local function sanitize(data)
	for weaponId in data.Weapons do
		if not Items.Weapons[weaponId] then
			data.Weapons[weaponId] = nil
		end
	end
	for armorId in data.Armors do
		if not Items.Armors[armorId] then
			data.Armors[armorId] = nil
		end
	end
	for potionId in data.Potions do
		if not Config.Potions[potionId] then
			data.Potions[potionId] = nil
		end
	end
	if data.Class and not Config.Classes[data.Class] then
		data.Class = nil
	end
	if data.Equipped.Armor and not data.Armors[data.Equipped.Armor] then
		data.Equipped.Armor = nil
	end
	fixLoadout(data)
end

local function onPlayerAdded(player: Player)
	buffs[player] = {}
	player.CharacterAdded:Connect(function(character)
		if DataService.Get(player) then
			fireCharacterReady(player, character)
		end
	end)
end

function PlayerService.Start()
	DataService.OnLoaded(function(player, data)
		sanitize(data)
		setupLeaderstats(player, data)
		PlayerService.Push(player)
		if player.Character then
			fireCharacterReady(player, player.Character)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		buffs[player] = nil
	end)

	Remotes.Equip.OnServerInvoke = onEquip
	Remotes.ChooseClass.OnServerInvoke = onChooseClass
	Remotes.GetState.OnServerInvoke = function(player)
		local data = DataService.Get(player)
		return data and buildState(player, data)
	end
end

return PlayerService
