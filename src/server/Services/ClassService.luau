-- Class rolling. Players don't pick a class: they roll one, weighted by rarity
-- (Config.Classes[...].Weight). The first roll is free; after that each roll costs
-- coins or Robux (a Developer Product, see Config.ClassRoll.RobuxProductId).
-- The rolled class replaces the one in your active class slot.
--
-- Class slots (Config.ClassSlots): keep up to 3 rolled classes and switch between them in
-- town. Slot 1 is free, more slots are a Robux Developer Product, and an empty slot gets
-- a free roll. 2x Luck (Robux Store) rolls twice and keeps the rarer class.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local Sfx = require(script.Parent.Parent.Sfx)
local Receipts = require(script.Parent.Parent.Receipts)
local Luck = require(script.Parent.Parent.Luck)

local ClassService = {}

local rolling: { [Player]: boolean } = {}

local function rollOnce(): string
	local total = 0
	for _, classId in Config.ClassOrder do
		total += Config.Classes[classId].Weight
	end
	local roll = math.random() * total
	for _, classId in Config.ClassOrder do
		roll -= Config.Classes[classId].Weight
		if roll <= 0 then
			return classId
		end
	end
	return Config.ClassOrder[1]
end

local function rollClassId(player: Player): string
	return Luck.Roll(player, rollOnce, function(a, b)
		return Config.Classes[a].Weight < Config.Classes[b].Weight
	end)
end

-- Rolls a class into the active slot, then tells the client so it can play the reveal.
local function grantRoll(player: Player)
	local data = PlayerService.GetData(player)
	local slot = if data then data.ActiveSlot else 1
	local classId = rollClassId(player)
	local class = Config.Classes[classId]
	-- Give the reveal animation time before the class actually changes.
	Remotes.ClassRolled:FireClient(player, classId)
	task.delay(3.6, function()
		if not player.Parent then
			rolling[player] = nil
			return
		end
		local current = PlayerService.GetData(player)
		if current then
			current.ActiveSlot = slot
		end
		PlayerService.SetClass(player, classId)
		PlayerService.Notify(player, `You rolled {class.Rarity} {class.DisplayName}!`, class.Color)
		if class.Rarity == "Godly" then
			PlayerService.AddStat(player, "SeraphRolled")
			for _, other in Players:GetPlayers() do
				PlayerService.Notify(other, `{player.DisplayName} ROLLED THE GODLY {string.upper(class.DisplayName)} CLASS! (0.05%)`, Config.Rarities.Godly)
			end
		elseif class.Rarity == "Legendary" or class.Rarity == "Epic" then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					PlayerService.Notify(other, `{player.DisplayName} rolled the {class.Rarity} {class.DisplayName} class!`, class.Color)
				end
			end
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Sfx.play("LevelUp", root)
		end
		rolling[player] = nil
	end)
end

local function onRollClass(player: Player, currency: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	if player:GetAttribute("InDungeon") then
		return false, "You can't roll a class inside a dungeon"
	end
	if rolling[player] then
		return false, "Already rolling"
	end

	if data.ClassSlots[data.ActiveSlot] == "" then
		rolling[player] = true
		grantRoll(player) -- the first roll in each slot is free
		return true
	end
	if currency == "Coins" then
		if not PlayerService.SpendGold(player, Config.ClassRoll.CoinCost) then
			return false, `You need {Config.ClassRoll.CoinCost} coins`
		end
		rolling[player] = true
		grantRoll(player)
		return true
	elseif currency == "Robux" then
		local productId = Config.ClassRoll.RobuxProductId
		if productId == 0 then
			return false, "Robux rolls aren't set up yet (Config.ClassRoll.RobuxProductId)"
		end
		MarketplaceService:PromptProductPurchase(player, productId)
		return true
	end
	return false, "Unknown currency"
end

-- Class slots: ("Select", slot) switches to a slot, ("Buy") prompts the Robux purchase.
local function onClassSlot(player: Player, action: unknown, slot: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	if action == "Buy" then
		if data.SlotsUnlocked >= Config.ClassSlots.Max then
			return false, "You've unlocked every class slot"
		end
		local productId = Config.ClassSlots.RobuxProductId
		if productId == 0 then
			return false, "Class slots aren't set up yet (Config.ClassSlots.RobuxProductId)"
		end
		MarketplaceService:PromptProductPurchase(player, productId)
		return true
	elseif action == "Select" then
		if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > data.SlotsUnlocked then
			return false, "That slot is locked"
		end
		if player:GetAttribute("InDungeon") then
			return false, "Switch classes in town"
		end
		if rolling[player] then
			return false, "Wait for your roll to finish"
		end
		data.ActiveSlot = slot
		local classId = data.ClassSlots[slot]
		if classId == "" then
			-- Empty slot: your class stays until you use its free roll
			PlayerService.Push(player)
			return true, `Slot {slot} selected - roll for free to fill it!`
		end
		PlayerService.SetClass(player, classId)
		return true, `Slot {slot}: {Config.Classes[classId].DisplayName}`
	end
	return false, "Unknown action"
end

-- Admin/testing: unlock the next class slot for free.
function ClassService.UnlockSlot(player: Player): boolean
	local data = PlayerService.GetData(player)
	if not data or data.SlotsUnlocked >= Config.ClassSlots.Max then
		return false
	end
	data.SlotsUnlocked += 1
	PlayerService.Push(player)
	return true
end

-- Admin/testing helper: roll without paying.
function ClassService.FreeRoll(player: Player)
	if not rolling[player] then
		rolling[player] = true
		grantRoll(player)
	end
end

function ClassService.Start()
	Remotes.RollClass.OnServerInvoke = onRollClass
	Remotes.ClassSlot.OnServerInvoke = onClassSlot
	Receipts.Register(function()
		return Config.ClassSlots.RobuxProductId
	end, function(player)
		local data = PlayerService.GetData(player)
		if not data then
			return
		end
		data.SlotsUnlocked = math.min(data.SlotsUnlocked + 1, Config.ClassSlots.Max)
		data.ActiveSlot = data.SlotsUnlocked
		PlayerService.Push(player)
		PlayerService.Notify(player, `Class slot {data.SlotsUnlocked} unlocked! Your first roll in it is free.`, Config.Rarities.Legendary)
	end)
	Receipts.Register(function()
		return Config.ClassRoll.RobuxProductId
	end, function(player)
		rolling[player] = true
		grantRoll(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		rolling[player] = nil
	end)
end

return ClassService
