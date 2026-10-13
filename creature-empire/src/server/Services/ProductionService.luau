--!strict
-- Advances every production building from elapsed server time. Rates come from validated
-- saved state (assignments, levels, creature stats) via Shared/Util/Production; nothing a
-- client sends and no animation affects output.
--
-- One loop runs for the whole server (not one per building or creature). Rates are cached
-- per player and recomputed only when something that affects them changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Production = require(Shared.Util.Production)
local Formulas = require(Shared.Util.Formulas)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)

local RESYNC_INTERVAL = 5 -- seconds between "Buildings" refreshes while anything produces

type Runtime = {
	Rates: { [string]: Production.BuildingRate },
	Buffs: { [string]: { Production.Buff } },
	CycleProgress: { [string]: number }, -- fractional work cycles per creature
	Starved: { [string]: boolean }, -- buildings whose inputs ran out on the last step
	LastWalletPush: number,
	LastTick: number,
	LastResync: number,
	Stale: boolean,
}

local ProductionService = {}

local runtimes: { [Player]: Runtime } = {}

local function getRuntime(player: Player): Runtime?
	return runtimes[player]
end

local function recompute(player: Player, runtime: Runtime)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	local now = os.clock()
	for buildingId, buffs in runtime.Buffs do
		for i = #buffs, 1, -1 do
			if buffs[i].Expires <= now then
				table.remove(buffs, i)
			end
		end
		if #buffs == 0 then
			runtime.Buffs[buildingId] = nil
		end
	end
	runtime.Rates = Production.Rates(data, runtime.Buffs)
	-- Buildings with no workers can't be "starved".
	for buildingId in runtime.Starved do
		local rate = runtime.Rates[buildingId]
		if not rate or rate.PerSecond <= 0 then
			runtime.Starved[buildingId] = nil
		end
	end
	runtime.Stale = false
end

-- Moves production forward by dt seconds. `efficiency` < 1 for offline time.
-- Returns produced amounts per resource. XP is only granted for online time.
local function advance(
	player: Player,
	runtime: Runtime,
	dt: number,
	efficiency: number,
	grantXp: boolean
): { [string]: number }
	local data = PlayerDataService.GetData(player)
	local produced: { [string]: number } = {}
	if not data or dt <= 0 then
		return produced
	end
	local consumedAny = false
	-- Stable order so buildings sharing inputs (two smelters) are served predictably.
	local ids = {}
	for buildingId in runtime.Rates do
		table.insert(ids, buildingId)
	end
	table.sort(ids)
	for _, buildingId in ids do
		local rate = runtime.Rates[buildingId]
		local building = data.Buildings[buildingId]
		if building and rate.PerSecond > 0 then
			local stored = building.Stored[rate.Output] or 0
			local newStored, made, consumed, starved = Production.Step(
				stored,
				rate.PerSecond * efficiency,
				dt,
				rate.Capacity,
				rate.InputsPerUnit,
				data.Resources
			)
			building.Stored[rate.Output] = newStored
			if (runtime.Starved[buildingId] == true) ~= starved then
				-- Paused or resumed: refresh panels and the creatures' task text.
				StateService.Push(player, "Buildings", "Creatures")
			end
			if starved then
				runtime.Starved[buildingId] = true
			else
				runtime.Starved[buildingId] = nil
			end
			if next(consumed) then
				consumedAny = true
			end
			if made > 0 then
				produced[rate.Output] = (produced[rate.Output] or 0) + made
			end
			-- Creatures gain experience only for the share of time they actually worked
			-- (not while storage is full or inputs ran out).
			local worked = if rate.PerSecond > 0 then made / (rate.PerSecond * efficiency) else 0
			if grantXp and worked > 0 then
				for _, worker in rate.Workers do
					local creature = data.Creatures[worker.CreatureId]
					if creature then
						local progress = (runtime.CycleProgress[worker.CreatureId] or 0) + worked / worker.CycleTime
						local cycles = math.floor(progress)
						runtime.CycleProgress[worker.CreatureId] = progress - cycles
						if cycles > 0 then
							creature.WorkCycles += cycles
							creature.JobCycles[rate.Job] = (creature.JobCycles[rate.Job] or 0) + cycles
							local gained = Production.AddXp(creature, cycles * EconomyConfig.XpPerCycle)
							if gained > 0 then
								runtime.Stale = true -- level changes the rate
								Events.CreatureLeveled:Fire(player, creature.Id, creature.Level)
							end
							StateService.Push(player, "Creatures")
						end
					end
				end
			end
		end
	end
	if next(produced) or consumedAny then
		PlayerDataService.MarkDirty(player)
	end
	-- Inputs drain a little every tick; refresh the wallet at most every few seconds
	-- (otherwise every open window would rebuild once a second).
	if consumedAny and os.clock() - runtime.LastWalletPush >= RESYNC_INTERVAL then
		runtime.LastWalletPush = os.clock()
		StateService.Push(player, "Wallet")
	end
	return produced
end

local function tick(player: Player, runtime: Runtime)
	local now = os.clock()
	local dt = math.min(now - runtime.LastTick, 10) -- a long server hitch never grants a burst
	runtime.LastTick = now

	local hasExpiredBuff = false
	for _, buffs in runtime.Buffs do
		for _, buff in buffs do
			if buff.Expires <= now then
				hasExpiredBuff = true
			end
		end
	end
	if runtime.Stale or hasExpiredBuff then
		-- Advance with the old rates up to now, then switch.
		advance(player, runtime, dt, 1, true)
		recompute(player, runtime)
		StateService.Push(player, "Buildings", "Creatures")
		return
	end
	local produced = advance(player, runtime, dt, 1, true)
	if next(produced) and now - runtime.LastResync >= RESYNC_INTERVAL then
		runtime.LastResync = now
		StateService.Push(player, "Buildings")
	end
end

local function applyOffline(player: Player, runtime: Runtime)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	local seconds = Formulas.OfflineSeconds(data.LastOnline, os.time(), EconomyConfig.Offline.MaxSeconds)
	if seconds < EconomyConfig.Offline.MinSeconds then
		return
	end
	local produced = advance(player, runtime, seconds, EconomyConfig.Offline.Efficiency, false)
	local rounded = {}
	local any = false
	for resource, amount in produced do
		rounded[resource] = math.floor(amount)
		any = any or rounded[resource] > 0
	end
	Log.Info("Production", "Offline progress", { user = player.UserId, seconds = seconds })
	if any then
		Remotes.Events.GameEvent:FireClient(player, "OfflineReport", { Seconds = seconds, Produced = rounded })
	end
end

-- Public -----------------------------------------------------------------------------------

-- Call after anything that changes rates (assignments, upgrades, core tier, level ups).
function ProductionService.Invalidate(player: Player)
	local runtime = getRuntime(player)
	if runtime then
		-- Bring stored amounts up to date with the old rates first.
		tick(player, runtime)
		recompute(player, runtime)
		StateService.Push(player, "Buildings", "Creatures")
	end
end

function ProductionService.AddBuff(
	player: Player,
	buildingId: string,
	buff: { Stat: string, Category: string, Value: number, Duration: number }
)
	local runtime = getRuntime(player)
	if not runtime then
		return
	end
	tick(player, runtime)
	local list = runtime.Buffs[buildingId] or {}
	runtime.Buffs[buildingId] = list
	table.insert(
		list,
		{ Stat = buff.Stat, Category = buff.Category, Value = buff.Value, Expires = os.clock() + buff.Duration }
	)
	recompute(player, runtime)
	StateService.Push(player, "Buildings", "Creatures")
end

function ProductionService.GetRate(player: Player, buildingId: string): Production.BuildingRate?
	local runtime = getRuntime(player)
	return runtime and runtime.Rates[buildingId]
end

function ProductionService.GetWorkerRate(player: Player, creatureId: string): Production.WorkerRate?
	local runtime = getRuntime(player)
	if not runtime then
		return nil
	end
	for _, rate in runtime.Rates do
		for _, worker in rate.Workers do
			if worker.CreatureId == creatureId then
				return worker
			end
		end
	end
	return nil
end

-- Whether a building stopped because its silo inputs ran out.
function ProductionService.IsStarved(player: Player, buildingId: string): boolean
	local runtime = getRuntime(player)
	return runtime ~= nil and runtime.Starved[buildingId] == true
end

-- Remaining seconds of buffs on a building (for the UI).
function ProductionService.GetBuffs(
	player: Player,
	buildingId: string
): { { Stat: string, Value: number, Remaining: number } }
	local runtime = getRuntime(player)
	local list = {}
	if runtime and runtime.Buffs[buildingId] then
		local now = os.clock()
		for _, buff in runtime.Buffs[buildingId] do
			table.insert(list, { Stat = buff.Stat, Value = buff.Value, Remaining = math.max(buff.Expires - now, 0) })
		end
	end
	return list
end

-- Brings everything up to date right now (before collecting, saving, ...).
function ProductionService.Flush(player: Player)
	local runtime = getRuntime(player)
	if runtime then
		tick(player, runtime)
	end
end

function ProductionService.Start()
	PlayerDataService.Loaded:Connect(function(player)
		local runtime: Runtime = {
			Rates = {},
			Buffs = {},
			CycleProgress = {},
			Starved = {},
			LastWalletPush = 0,
			LastTick = os.clock(),
			LastResync = 0,
			Stale = false,
		}
		runtimes[player] = runtime
		recompute(player, runtime)
		applyOffline(player, runtime)
		StateService.Push(player, "Buildings")
	end)

	PlayerDataService.BeforeRelease:Connect(function(player)
		ProductionService.Flush(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			runtimes[player] = nil
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(EconomyConfig.ProductionTick)
			for player, runtime in runtimes do
				if player.Parent then
					local ok, err = pcall(function()
						tick(player, runtime)
						return true
					end)
					if not ok then
						Log.Warn("Production", "tick failed", { user = player.UserId, error = tostring(err) })
					end
				end
			end
		end
	end)
end

return ProductionService
