--!strict
-- The research tree (ResearchConfig). Research is bought with Insight from the Research
-- Station (plus gold or materials); prerequisites and costs are checked here, and the
-- effects are read from saved data by Shared/Util/Research wherever they apply.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ResearchConfig = require(Shared.Config.ResearchConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Research = require(Shared.Util.Research)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local Types = require(Shared.Types)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local ProductionService = require(script.Parent.ProductionService)

local ResearchService = {}

local function research(player: Player, nodeId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local ok, reason = Research.CanResearch(data, nodeId, GameConfig.Phase)
	if not ok then
		return false, reason
	end
	local node = ResearchConfig.Nodes[nodeId]
	-- Bring production up to date first: research can change rates and silo room.
	ProductionService.Flush(player)
	if not EconomyService.Spend(player, node.Cost, "Research " .. nodeId) then
		return false, "You need " .. Format.Cost(node.Cost, ResourceConfig) .. "."
	end
	data.Research[nodeId] = os.time()
	PlayerDataService.MarkDirty(player)
	ProductionService.Invalidate(player)
	StateService.Push(player, "Research", "Wallet", "Buildings")
	Events.Researched:Fire(player, nodeId)
	Remotes.Events.GameEvent:FireClient(player, "Researched", { Id = nodeId, Name = node.Name })
	Log.Info("Research", "Completed", { user = player.UserId, node = nodeId })
	return true, nodeId
end

function ResearchService.Start()
	StateService.Register("Research", function(_player, profile)
		return { Done = table.clone(profile.Data.Research) }
	end)
	Net.Handle("Research", { Rate = { 4, 1 }, Args = { Net.Check.Id } }, research)
end

return ResearchService
