--!strict
-- Resource deposits in regions. Each player has their own cooldown per deposit, so players
-- never compete for nodes (co-op friendly). The server checks the player is next to the
-- node, rolls the yield, and adds a bonus roll from the companion's Discovery stat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local RegionConfig = require(Shared.Config.RegionConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Encounter = require(Shared.Util.Encounter)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)

local GATHER_RANGE = 14

local NodeService = {}

local cooldowns: { [Player]: { [string]: number } } = {} -- node key -> server time when ready
local rng = Random.new()

local function findNode(nodeId: string): (RegionConfig.Region?, RegionConfig.Node?)
	for _, regionId in RegionConfig.Order do
		local region = RegionConfig.Regions[regionId]
		for _, node in region.Nodes do
			if node.Id == nodeId then
				return region, node
			end
		end
	end
	return nil, nil
end

function NodeService.CompanionInfo(player: Player): Encounter.Companion?
	local data = PlayerDataService.GetData(player)
	local creature = data and data.Companion and data.Creatures[data.Companion]
	if not creature then
		return nil
	end
	return { Species = creature.Species, Level = creature.Level, Stage = creature.Stage }
end

local function gather(player: Player, nodeId: string): (boolean, any)
	local region, node = findNode(nodeId)
	if not region or not node then
		return false, "Unknown deposit."
	end
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not part or (part.Position - (region.Center + node.Offset)).Magnitude > GATHER_RANGE then
		return false, "Walk closer to the deposit."
	end
	local now = Workspace:GetServerTimeNow()
	local mine = cooldowns[player]
	if mine[nodeId] and mine[nodeId] > now then
		return false, `This deposit needs {math.ceil(mine[nodeId] - now)}s to recover.`
	end
	local kind = region.NodeKinds[node.Kind]
	local amount = rng:NextInteger(kind.Min, kind.Max)
	local bonus = rng:NextNumber() < Encounter.BonusGatherChance(NodeService.CompanionInfo(player))
	if bonus then
		amount += math.ceil(amount / 2)
	end
	local added = EconomyService.Add(player, kind.Resource, amount, "Gather")
	if added <= 0 then
		local def = ResourceConfig[kind.Resource]
		return false, `Your silo is full of {def and def.Name or kind.Resource}. Sell some or upgrade it.`
	end
	mine[nodeId] = now + kind.Respawn
	local data = PlayerDataService.GetData(player)
	if data then
		data.Stats.Gathered = (data.Stats.Gathered or 0) + added
	end
	Events.Gathered:Fire(player, kind.Resource, added)
	StateService.Push(player, "Nodes")
	Remotes.Events.GameEvent:FireClient(
		player,
		"Gathered",
		{ Node = nodeId, Resource = kind.Resource, Amount = added, Bonus = bonus }
	)
	return true, added
end

function NodeService.Start()
	StateService.Register("Nodes", function(player)
		return table.clone(cooldowns[player] or {})
	end)
	PlayerDataService.Loaded:Connect(function(player)
		cooldowns[player] = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
	Net.Handle("Gather", { Rate = { 4, 1 }, Args = { Net.Check.Id } }, gather)
end

return NodeService
