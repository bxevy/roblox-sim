--!strict
-- Developer-only test commands. Allowed in Studio, or for user ids listed in
-- GameConfig.DeveloperUserIds. Everyone else gets a refusal (and the attempt is logged).
--
-- Commands (from the Developer section of the Settings window, or the command bar:
--   game.ReplicatedStorage.CreatureEmpireRemotes.Dev:InvokeServer("gold", 1000) from a
--   client script in Studio):
--   gold <n>            add gold
--   petals <n>          add moonpetals (up to silo capacity)
--   essence <n>         add essence
--   crystals <n>        add raw and refined crystal (up to silo capacity)
--   ember <n>           add emberstone (up to silo capacity) and 5 ember lures
--   insight <n>         add Insight
--   shards <n>          add Empire Shards
--   coremax             raise the Empire Core to tier 5 (to test Ascension)
--   finishexpeditions   bring every active expedition home now (and end creature rest)
--   levelup             +5 levels and +200 work cycles per job for every creature
--   grant <speciesId>   add a creature
--   offline <minutes>   pretend you were away (sets LastOnline back; rejoin to apply)
--   fillstorage         fill every production building's storage
--   skipquest           complete the current tutorial step
--   resetcooldowns      make every ability ready
--   verbose             toggle verbose economy logging
--   save                save now
--   reset               wipe this profile back to a new player (Studio only)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local ProductionService = require(script.Parent.ProductionService)
local QuestService = require(script.Parent.QuestService)

local DevService = {}

function DevService.IsDeveloper(player: Player): boolean
	return RunService:IsStudio() or table.find(GameConfig.DeveloperUserIds, player.UserId) ~= nil
end

local commands: { [string]: (Player, any) -> (boolean, string) } = {}

commands.gold = function(player, n)
	local amount = tonumber(n) or 1000
	return true, `Added {EconomyService.Add(player, "Gold", amount, "Dev")} gold.`
end

commands.petals = function(player, n)
	local amount = tonumber(n) or 100
	return true, `Added {EconomyService.Add(player, "Moonpetal", amount, "Dev")} moonpetals.`
end

commands.essence = function(player, n)
	local amount = tonumber(n) or 100
	return true, `Added {EconomyService.Add(player, "Essence", amount, "Dev")} essence.`
end

commands.crystals = function(player, n)
	local amount = tonumber(n) or 50
	local raw = EconomyService.Add(player, "RawCrystal", amount, "Dev")
	local refined = EconomyService.Add(player, "RefinedCrystal", amount, "Dev")
	return true, `Added {raw} raw and {refined} refined crystal (up to silo capacity).`
end

commands.ember = function(player, n)
	local amount = tonumber(n) or 50
	local stone = EconomyService.Add(player, "Emberstone", amount, "Dev")
	local lures = EconomyService.Add(player, "EmberLure", 5, "Dev")
	return true, `Added {stone} emberstone and {lures} ember lures.`
end

commands.insight = function(player, n)
	local amount = tonumber(n) or 100
	return true, `Added {EconomyService.Add(player, "Insight", amount, "Dev")} Insight.`
end

commands.shards = function(player, n)
	local amount = tonumber(n) or 20
	return true, `Added {EconomyService.Add(player, "EmpireShards", amount, "Dev")} Empire Shards.`
end

commands.coremax = function(player)
	local data = PlayerDataService.GetData(player)
	if not data or not data.Buildings.core then
		return false, "Not loaded."
	end
	data.Buildings.core.Level = 5
	PlayerDataService.MarkDirty(player)
	ProductionService.Invalidate(player)
	StateService.Push(player, "Buildings", "Ascension")
	return true, "Empire Core is tier 5 (rejoin to see the model change)."
end

commands.finishexpeditions = function(player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Not loaded."
	end
	local now = os.time()
	for _, record in data.Expeditions do
		record.StartedAt -= math.max(record.EndsAt - now, 0)
		record.EndsAt = math.min(record.EndsAt, now)
	end
	for _, creature in data.Creatures do
		creature.RestUntil = 0
	end
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Expeditions", "Creatures")
	return true, "Every expedition is back. Claim them at the Expedition Portal."
end

commands.levelup = function(player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Not loaded."
	end
	for _, creature in data.Creatures do
		creature.Level = math.min(creature.Level + 5, 30)
		for _, job in { "Farmer", "Miner", "Smelter", "Alchemist", "Explorer" } do
			creature.JobCycles[job] = (creature.JobCycles[job] or 0) + 200
		end
	end
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Creatures")
	ProductionService.Invalidate(player)
	return true, "Every creature gained 5 levels and 200 work cycles in each job."
end

commands.grant = function(player, speciesId)
	if type(speciesId) ~= "string" or not CreatureConfig.Species[speciesId] then
		return false, "Unknown species."
	end
	CreatureService.Grant(player, speciesId, "Dev", false)
	return true, "Granted " .. speciesId
end

commands.offline = function(player, minutes)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Not loaded."
	end
	-- PlayerDataService applies this when it writes LastOnline in the final save.
	local profile = PlayerDataService.Get(player)
	if profile then
		profile.Runtime.OfflineOverride = (tonumber(minutes) or 60) * 60
	end
	return true, "Leave and rejoin to collect offline progress."
end

commands.fillstorage = function(player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Not loaded."
	end
	for id, building in data.Buildings do
		local rate = ProductionService.GetRate(player, id)
		if rate then
			building.Stored[rate.Output] = rate.Capacity
		end
	end
	StateService.Push(player, "Buildings")
	return true, "Storage filled."
end

commands.skipquest = function(player)
	if QuestService.ForceComplete(player) then
		return true, "Quest completed and rewarded."
	end
	return false, "No quest to complete."
end

commands.resetcooldowns = function(player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "Not loaded."
	end
	for _, creature in data.Creatures do
		creature.AbilityReadyAt = 0
	end
	StateService.Push(player, "Creatures")
	return true, "Abilities ready."
end

commands.verbose = function()
	Log.Verbose = not Log.Verbose
	return true, "Verbose logging " .. (if Log.Verbose then "on" else "off")
end

commands.save = function(player)
	return PlayerDataService.SaveNow(player), "Save requested."
end

commands.reset = function(player)
	if not RunService:IsStudio() then
		return false, "Studio only."
	end
	PlayerDataService.ResetForTesting(player)
	return true, "Profile reset. Rejoin (stop and play) to rebuild your plot."
end

function DevService.Start()
	StateService.Register("Dev", function(player)
		return { Allowed = DevService.IsDeveloper(player) }
	end)

	Net.Handle("Dev", { Rate = { 10, 5 }, Args = { Net.Check.String, Net.Check.Any } }, function(player, command, arg)
		if not DevService.IsDeveloper(player) then
			Log.Warn("Dev", "Refused developer command", { user = player.UserId, command = command })
			return false, "Not allowed."
		end
		local run = commands[command]
		if not run then
			return false, "Unknown command."
		end
		Log.Info("Dev", "Command", { user = player.UserId, command = command, arg = tostring(arg) })
		return run(player, arg)
	end)
end

return DevService
