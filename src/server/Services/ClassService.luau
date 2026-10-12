-- Class rolling. Players don't pick a class: they roll one, weighted by rarity
-- (Config.Classes[...].Weight). The first roll is free; after that each roll costs
-- coins or Robux (a Developer Product, see Config.ClassRoll.RobuxProductId).
-- The rolled class replaces your current one.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local Sfx = require(script.Parent.Parent.Sfx)

local ClassService = {}

local rolling: { [Player]: boolean } = {}

local function rollClassId(): string
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

-- Rolls and applies a class, then tells the client so it can play the reveal.
local function grantRoll(player: Player)
	local classId = rollClassId()
	local class = Config.Classes[classId]
	-- Give the reveal animation time before the class actually changes.
	Remotes.ClassRolled:FireClient(player, classId)
	task.delay(3.6, function()
		if not player.Parent then
			return
		end
		PlayerService.SetClass(player, classId)
		PlayerService.Notify(player, `You rolled {class.Rarity} {class.DisplayName}!`, class.Color)
		if class.Rarity == "Legendary" or class.Rarity == "Epic" then
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

	if data.Class == nil then
		rolling[player] = true
		grantRoll(player) -- first roll is free
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

-- Robux purchases: grant the roll exactly once per receipt, and save immediately.
local function processReceipt(receipt)
	if receipt.ProductId ~= Config.ClassRoll.RobuxProductId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerService.GetData(player)
	if not player or not data then
		-- They left before it was processed; Roblox will retry next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not data.Receipts[receipt.PurchaseId] then
		data.Receipts[receipt.PurchaseId] = true
		rolling[player] = true
		grantRoll(player)
		DataService.Save(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
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
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player)
		rolling[player] = nil
	end)
end

return ClassService
