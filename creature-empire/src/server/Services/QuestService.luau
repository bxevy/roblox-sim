--!strict
-- The onboarding questline. Steps come from QuestConfig.Tutorial; each step's Kind names
-- an evaluator below. State-based steps (levels, counts, assignments) are checked against
-- saved data; counter-based steps (collect, sell, earn) count events during the step.
-- A finished step must be claimed; the claim is validated and rewards are granted by the
-- server exactly once (the step index only moves forward).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local QuestConfig = require(Shared.Config.QuestConfig)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)

local QuestService = {}

type Evaluator = (data: Types.PlayerData, step: Types.QuestStep) -> number

-- Returns current progress towards step.Amount.
local Evaluators: { [string]: Evaluator } = {
	ChooseStarter = function(data)
		return if data.StarterChosen then 1 else 0
	end,
	Assign = function(data)
		local count = 0
		for _, creature in data.Creatures do
			if creature.Assignment then
				count += 1
			end
		end
		return count
	end,
	BuildingLevel = function(data, step)
		local best = 0
		for _, building in data.Buildings do
			if building.Type == step.Target then
				best = math.max(best, building.Level)
			end
		end
		return best
	end,
	BuildingCount = function(data, step)
		local count = 0
		for _, building in data.Buildings do
			if building.Type == step.Target then
				count += 1
			end
		end
		return count
	end,
	-- Counter-based kinds read the per-step counter.
	Collect = function(data)
		return data.Quests.Progress
	end,
	Sell = function(data)
		return data.Quests.Progress
	end,
	UseAbility = function(data)
		return data.Quests.Progress
	end,
	EarnGold = function(data)
		return data.Quests.Progress
	end,
	Hatch = function(data)
		return data.Quests.Progress
	end,
	Evolve = function(data)
		return data.Quests.Progress
	end,
	Visit = function(data)
		return data.Quests.Progress
	end,
	Gather = function(data)
		return data.Quests.Progress
	end,
	Craft = function(data)
		return data.Quests.Progress
	end,
	Befriend = function(data)
		return data.Quests.Progress
	end,
	Expedition = function(data)
		return data.Quests.Progress
	end,
	Guardian = function(data)
		return data.Quests.Progress
	end,
	Discover = function(data)
		local count = 0
		for _ in data.Discoveries do
			count += 1
		end
		return count
	end,
}
QuestService.Evaluators = Evaluators

local function currentStep(data: Types.PlayerData): Types.QuestStep?
	return QuestConfig.Tutorial[data.Quests.Tutorial]
end

local function progressOf(data: Types.PlayerData, step: Types.QuestStep): number
	local evaluate = Evaluators[step.Kind]
	if not evaluate then
		return 0
	end
	return math.min(evaluate(data, step), step.Amount)
end

local function grantReward(player: Player, data: Types.PlayerData, reward: Types.QuestReward)
	if reward.Gold then
		EconomyService.Add(player, "Gold", reward.Gold, "Quest")
	end
	if reward.Essence then
		EconomyService.Add(player, "Essence", reward.Essence, "Quest")
	end
	if reward.Shards then
		EconomyService.Add(player, "EmpireShards", reward.Shards, "Quest")
	end
	if reward.Creature then
		local speciesId = if reward.Creature == "NextStarter"
			then CreatureService.NextStarter(data)
			else reward.Creature
		if speciesId then
			CreatureService.Grant(player, speciesId, "Quest", false)
		end
	end
end

-- Re-checks the current step and marks it claimable when done.
local function refresh(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	local step = currentStep(data)
	if step and step.Kind == "ChooseStarter" and progressOf(data, step) >= step.Amount then
		-- Picking a partner is its own reward; move straight on to the next step.
		data.Quests.Tutorial += 1
		data.Quests.Progress = 0
		data.Quests.Claimable = false
		PlayerDataService.MarkDirty(player)
		grantReward(player, data, step.Reward)
		step = currentStep(data)
	end
	if step and not data.Quests.Claimable and progressOf(data, step) >= step.Amount then
		data.Quests.Claimable = true
		PlayerDataService.MarkDirty(player)
		Remotes.Events.GameEvent:FireClient(player, "QuestReady", { Id = step.Id })
	end
	StateService.Push(player, "Quests")
end

local function addCounter(player: Player, kind: string, target: string?, amount: number)
	local data = PlayerDataService.GetData(player)
	local step = data and currentStep(data)
	if not data or not step or step.Kind ~= kind or data.Quests.Claimable then
		return
	end
	if step.Target and target and step.Target ~= target then
		return
	end
	data.Quests.Progress = math.min(data.Quests.Progress + amount, step.Amount)
	PlayerDataService.MarkDirty(player)
	refresh(player)
end

local function claim(player: Player): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local step = currentStep(data)
	if not step then
		return false, "No quest to claim."
	end
	-- Re-evaluate on the server; the client's view of progress is never trusted.
	if progressOf(data, step) < step.Amount then
		data.Quests.Claimable = false
		StateService.Push(player, "Quests")
		return false, "Not finished yet."
	end
	-- Advance first so a failure while granting can never let the reward be claimed twice.
	data.Quests.Tutorial += 1
	data.Quests.Progress = 0
	data.Quests.Claimable = false
	PlayerDataService.MarkDirty(player)
	grantReward(player, data, step.Reward)
	Log.Info("Quest", "Claimed", { user = player.UserId, step = step.Id })
	Remotes.Events.GameEvent:FireClient(player, "QuestClaimed", { Id = step.Id, Reward = step.Reward })
	refresh(player)
	return true, nil
end

-- Developer use: completes the current step and grants its reward.
function QuestService.ForceComplete(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	local step = data and currentStep(data)
	if not data or not step then
		return false
	end
	data.Quests.Tutorial += 1
	data.Quests.Progress = 0
	data.Quests.Claimable = false
	PlayerDataService.MarkDirty(player)
	grantReward(player, data, step.Reward)
	refresh(player)
	return true
end

local function questsState(_player: Player, profile: PlayerDataService.Profile)
	local data = profile.Data
	local step = currentStep(data)
	return {
		Index = data.Quests.Tutorial,
		Total = #QuestConfig.Tutorial,
		Step = step,
		Progress = if step then progressOf(data, step) else 0,
		Claimable = data.Quests.Claimable,
	}
end

function QuestService.Start()
	StateService.Register("Quests", questsState)

	PlayerDataService.Loaded:Connect(function(player)
		refresh(player)
	end)
	Events.StarterChosen:Connect(refresh)
	Events.AssignmentsChanged:Connect(refresh)
	Events.BuildingChanged:Connect(refresh)
	Events.CreatureObtained:Connect(refresh)
	Events.Collected:Connect(function(player, resource, amount)
		addCounter(player, "Collect", resource, amount)
	end)
	Events.Sold:Connect(function(player, resource, amount)
		addCounter(player, "Sell", resource, amount)
	end)
	Events.AbilityUsed:Connect(function(player)
		addCounter(player, "UseAbility", nil, 1)
	end)
	Events.Hatched:Connect(function(player)
		addCounter(player, "Hatch", nil, 1)
	end)
	Events.Evolved:Connect(function(player)
		addCounter(player, "Evolve", nil, 1)
	end)
	Events.RegionEntered:Connect(function(player, regionId)
		addCounter(player, "Visit", regionId, 1)
	end)
	Events.Gathered:Connect(function(player, resource, amount)
		addCounter(player, "Gather", resource, amount)
	end)
	Events.Discovered:Connect(refresh)
	Events.Crafted:Connect(function(player, item, amount)
		addCounter(player, "Craft", item, amount)
	end)
	Events.Befriended:Connect(function(player)
		addCounter(player, "Befriend", nil, 1)
	end)
	Events.ExpeditionCompleted:Connect(function(player)
		addCounter(player, "Expedition", nil, 1)
	end)
	Events.GuardianDefeated:Connect(function(player, guardianId)
		addCounter(player, "Guardian", guardianId, 1)
	end)
	Events.CurrencyEarned:Connect(function(player, currency, amount, reason)
		-- Quest rewards don't count towards "earn gold" steps.
		if currency == "Gold" and reason ~= "Quest" then
			addCounter(player, "EarnGold", nil, amount)
		end
	end)

	Net.Handle("ClaimQuest", { Rate = { 3, 1 } }, claim)
end

return QuestService
