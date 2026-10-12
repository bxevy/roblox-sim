--!strict
-- Core simulator loop: Train -> gain Power, step on the Sell pad -> Power becomes Coins,
-- spend Coins on upgrades. All validation happens here on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local GameService = {}

local lastTrain: { [Player]: number } = {}

-- Snapshot of everything the client UI needs to draw.
local function buildState(data: { [string]: any })
	local upgrades = data.Upgrades
	local costs = {}
	for id, def in Config.Upgrades do
		local level = upgrades[id]
		costs[id] = if level >= def.MaxLevel then nil else Config.GetUpgradeCost(id, level)
	end
	return {
		Power = data.Power,
		Coins = data.Coins,
		Capacity = Config.GetCapacity(upgrades.Backpack),
		PowerPerClick = Config.GetPowerPerClick(upgrades.Strength),
		CoinsPerPower = Config.GetCoinsPerPower(upgrades.Value),
		Upgrades = upgrades,
		UpgradeCosts = costs,
	}
end

local function setupLeaderstats(player: Player, data: { [string]: any })
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats

	local power = Instance.new("IntValue")
	power.Name = "Power"
	power.Value = data.Power
	power.Parent = leaderstats

	leaderstats.Parent = player
end

-- Call after any change to a player's data to update leaderboard + UI.
local function pushUpdate(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Coins") :: IntValue).Value = data.Coins;
		(leaderstats:FindFirstChild("Power") :: IntValue).Value = data.Power
	end
	Remotes.DataChanged:FireClient(player, buildState(data))
end

local function onTrain(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end

	local now = os.clock()
	if now - (lastTrain[player] or 0) < Config.TrainCooldown then
		return
	end
	lastTrain[player] = now

	local capacity = Config.GetCapacity(data.Upgrades.Backpack)
	if data.Power >= capacity then
		Remotes.Notify:FireClient(player, "Backpack full! Go sell your Power.")
		return
	end

	data.Power = math.min(capacity, data.Power + Config.GetPowerPerClick(data.Upgrades.Strength))
	pushUpdate(player)
end

function GameService.Sell(player: Player)
	local data = DataService.Get(player)
	if not data or data.Power <= 0 then
		return
	end
	local earned = data.Power * Config.GetCoinsPerPower(data.Upgrades.Value)
	data.Coins += earned
	data.Power = 0
	pushUpdate(player)
	Remotes.Notify:FireClient(player, `Sold for {earned} Coins!`)
end

local function onBuyUpgrade(player: Player, upgradeId: unknown): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded yet"
	end
	if type(upgradeId) ~= "string" or not Config.Upgrades[upgradeId] then
		return false, "Unknown upgrade"
	end

	local def = Config.Upgrades[upgradeId]
	local level = data.Upgrades[upgradeId]
	if level >= def.MaxLevel then
		return false, "Already maxed"
	end

	local cost = Config.GetUpgradeCost(upgradeId, level)
	if data.Coins < cost then
		return false, "Not enough Coins"
	end

	data.Coins -= cost
	data.Upgrades[upgradeId] = level + 1
	pushUpdate(player)
	return true, nil
end

function GameService.Start()
	DataService.OnLoaded(function(player, data)
		setupLeaderstats(player, data)
		pushUpdate(player)
	end)

	Remotes.Train.OnServerEvent:Connect(onTrain)
	Remotes.BuyUpgrade.OnServerInvoke = onBuyUpgrade
	Remotes.GetData.OnServerInvoke = function(player)
		local data = DataService.Get(player)
		return data and buildState(data)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTrain[player] = nil
	end)
end

return GameService
