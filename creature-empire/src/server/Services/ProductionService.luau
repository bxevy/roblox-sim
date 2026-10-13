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
local Research = require(Shared.Util.Research)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)

local RESYNC_INTERVAL = 5 -- seconds between "Buildings" refreshes while anything produces
local CARRY_INTERVAL = 5 -- couriers deliver in batches so the wallet isn't re-sent every second

type Runtime = {
	Rates: { [string]: Production.BuildingRate },
	Couriers: Production.CourierRate,
	CarryBudget: number, -- units couriers may still carry (fractional, carried in batches)
	CarryTimer: number,
	CourierBlocked: boolean, -- the silo was full on the last delivery
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
-- Server-wide buffs (world events), by id, applied to every production building.
local globalBuffs: { [string]: Production.Buff } = {}

-- Each building's own buffs plus the active server-wide ones.
local function combinedBuffs(data: any, runtime: Runtime): { [string]: { Production.Buff } }
	if next(globalBuffs) == nil then
		return runtime.Buffs
	end
	local combined: { [string]: { Production.Buff } } = {}
	for buildingId in data.Buildings do
		local list = table.clone(runtime.Buffs[buildingId] or {})
		for _, buff in globalBuffs do
			table.insert(list, buff)
		end
		combined[buildingId] = list
	end
	return combined
end

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
	for id, buff in globalBuffs do
		if buff.Expires <= now then
			globalBuffs[id] = nil
		end
	end
	local buffs = combinedBuffs(data, runtime)
	runtime.Rates = Production.Rates(data, buffs)
	runtime.Couriers = Production.Couriers(data, buffs)
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

-- Couriers move stored output from production buildings into the silo or wallet, fullest
-- building first, up to `budget` units. Returns units carried.
local function carry(player: Player, runtime: Runtime, budget: number, grantXp: boolean): number
	local data = PlayerDataService.GetData(player)
	if not data or budget < 1 then
		return 0
	end
	local ids = {}
	for id, building in data.Buildings do
		local rate = runtime.Rates[id]
		if rate and (building.Stored[rate.Output] or 0) >= 1 then
			table.insert(ids, id)
		end
	end
	local function fill(id: string): number
		local rate = runtime.Rates[id]
		return (data.Buildings[id].Stored[rate.Output] or 0) / math.max(rate.Capacity, 1)
	end
	table.sort(ids, function(a, b)
		local fa, fb = fill(a), fill(b)
		if fa ~= fb then
			return fa > fb
		end
		return a < b
	end)
	local carried = 0
	local blocked = false
	for _, id in ids do
		if budget < 1 then
			break
		end
		local building = data.Buildings[id]
		local output = runtime.Rates[id].Output
		local take = math.min(math.floor(building.Stored[output] or 0), math.floor(budget))
		local added = EconomyService.Add(player, output, take, "Courier")
		if added < take then
			blocked = true
		end
		if added > 0 then
			building.Stored[output] -= added
			budget -= added
			carried += added
			data.Stats.Collected = (data.Stats.Collected or 0) + added
			Events.Collected:Fire(player, output, added)
		end
	end
	if blocked ~= runtime.CourierBlocked then
		runtime.CourierBlocked = blocked
		StateService.Push(player, "Buildings")
	end
	-- Couriers gain experience for the trips they made.
	local total = runtime.Couriers.PerSecond
	if grantXp and carried > 0 and total > 0 then
		for _, post in runtime.Couriers.Posts do
			for _, worker in post.Workers do
				local creature = data.Creatures[worker.CreatureId]
				if creature and worker.PerCycle > 0 then
					local trips = carried * (worker.PerSecond / total) / worker.PerCycle
					local progress = (runtime.CycleProgress[worker.CreatureId] or 0) + trips
					local cycles = math.floor(progress)
					runtime.CycleProgress[worker.CreatureId] = progress - cycles
					if cycles > 0 then
						creature.WorkCycles += cycles
						creature.JobCycles.Courier = (creature.JobCycles.Courier or 0) + cycles
						if Production.AddXp(creature, cycles * EconomyConfig.XpPerCycle) > 0 then
							runtime.Stale = true
							Events.CreatureLeveled:Fire(player, creature.Id, creature.Level)
						end
						StateService.Push(player, "Creatures")
					end
				end
			end
		end
	end
	if carried > 0 then
		PlayerDataService.MarkDirty(player)
		StateService.Push(player, "Buildings")
	end
	return carried
end

-- Accumulates courier capacity and delivers in batches.
local function runCouriers(player: Player, runtime: Runtime, dt: number, efficiency: number, force: boolean)
	local perSecond = runtime.Couriers.PerSecond
	if perSecond <= 0 then
		runtime.CarryBudget = 0
		if runtime.CourierBlocked then
			runtime.CourierBlocked = false
			StateService.Push(player, "Buildings")
		end
		return
	end
	runtime.CarryBudget += perSecond * efficiency * dt
	runtime.CarryTimer += dt
	if force or runtime.CarryTimer >= CARRY_INTERVAL then
		runtime.CarryTimer = 0
		local carried = carry(player, runtime, runtime.CarryBudget, efficiency >= 1)
		-- Keep only the fractional leftover: unused trips aren't banked while nothing waits.
		runtime.CarryBudget = math.clamp(runtime.CarryBudget - carried, 0, 1)
	end
end

local function tick(player: Player, runtime: Runtime)
	local now = os.clock()
	local dt = math.min(now - runtime.LastTick, 10) -- a long server hitch never grants a burst
	runtime.LastTick = now

	local hasExpiredBuff = false
	for _, buff in globalBuffs do
		if buff.Expires <= now then
			hasExpiredBuff = true
		end
	end
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
		runCouriers(player, runtime, dt, 1, false)
		recompute(player, runtime)
		StateService.Push(player, "Buildings", "Creatures")
		return
	end
	local produced = advance(player, runtime, dt, 1, true)
	runCouriers(player, runtime, dt, 1, false)
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
	local seconds = Formulas.OfflineSeconds(
		data.LastOnline,
		os.time(),
		EconomyConfig.Offline.MaxSeconds + Research.OfflineExtra(data)
	)
	if seconds < EconomyConfig.Offline.MinSeconds then
		return
	end
	local produced = advance(player, runtime, seconds, EconomyConfig.Offline.Efficiency, false)
	-- Couriers kept working too (one delivery for the whole absence).
	runCouriers(player, runtime, seconds, EconomyConfig.Offline.Efficiency, true)
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
	for _, post in runtime.Couriers.Posts do
		for _, worker in post.Workers do
			if worker.CreatureId == creatureId then
				return worker
			end
		end
	end
	return nil
end

-- Starts (or with nil, ends) a server-wide buff for every player's production buildings.
function ProductionService.SetGlobalBuff(
	id: string,
	buff: { Stat: string, Category: string, Value: number, Duration: number }?
)
	for player, runtime in runtimes do
		tick(player, runtime) -- settle production at the old rates first
	end
	if buff then
		globalBuffs[id] =
			{ Stat = buff.Stat, Category = buff.Category, Value = buff.Value, Expires = os.clock() + buff.Duration }
	else
		globalBuffs[id] = nil
	end
	for player, runtime in runtimes do
		recompute(player, runtime)
		StateService.Push(player, "Buildings", "Creatures")
	end
end

-- Active buff count of one category on a building (cheers use it to cap stacking).
function ProductionService.CountBuffs(player: Player, buildingId: string, category: string): number
	local runtime = getRuntime(player)
	local n = 0
	local now = os.clock()
	local list: { Production.Buff } = runtime and runtime.Buffs[buildingId] or {}
	for _, buff in list do
		if buff.Category == category and buff.Expires > now then
			n += 1
		end
	end
	return n
end

-- A Courier Post's workers and carry rate (for the UI), and whether the silo blocked them.
function ProductionService.GetCourier(
	player: Player,
	buildingId: string
): ({
	PerSecond: number,
	Workers: { Production.WorkerRate },
	Slots: number,
	Synergies: { string },
}?, boolean)
	local runtime = getRuntime(player)
	if not runtime then
		return nil, false
	end
	return runtime.Couriers.Posts[buildingId], runtime.CourierBlocked
end

-- Carries up to `amount` units right away (Gearhound's Fetch). Returns units carried.
function ProductionService.CarryNow(player: Player, amount: number): number
	local runtime = getRuntime(player)
	if not runtime then
		return 0
	end
	tick(player, runtime)
	return carry(player, runtime, amount, false)
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
	local now = os.clock()
	if runtime and runtime.Buffs[buildingId] then
		for _, buff in runtime.Buffs[buildingId] do
			table.insert(list, { Stat = buff.Stat, Value = buff.Value, Remaining = math.max(buff.Expires - now, 0) })
		end
	end
	if runtime and runtime.Rates[buildingId] then
		for _, buff in globalBuffs do
			table.insert(list, { Stat = buff.Stat, Value = buff.Value, Remaining = math.max(buff.Expires - now, 0) })
		end
	end
	return list
end

-- Forgets every buff, starved flag and courier progress (after an Ascension rebuilt the
-- plot) and recomputes rates from the new data.
function ProductionService.Reset(player: Player)
	local runtime = getRuntime(player)
	if not runtime then
		return
	end
	runtime.Buffs = {}
	runtime.Starved = {}
	runtime.CycleProgress = {}
	runtime.CarryBudget = 0
	runtime.CarryTimer = 0
	runtime.CourierBlocked = false
	runtime.LastTick = os.clock()
	recompute(player, runtime)
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
			Couriers = { PerSecond = 0, Posts = {} },
			CarryBudget = 0,
			CarryTimer = 0,
			CourierBlocked = false,
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
