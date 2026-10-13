--!strict
-- Owns creatures: granting them (with server-generated ids), the starter choice, job
-- assignment, active abilities and the lightweight "anchor" instances clients render.
--
-- Creatures are not simulated on the server. Each owned creature has a Configuration
-- under its owner's plot (Plot/Creatures/<id>) whose attributes describe it; every client
-- builds and animates the visual model locally (client/Controllers/CreatureController).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local JobConfig = require(Shared.Config.JobConfig)
local Production = require(Shared.Util.Production)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local Mutation = require(Shared.Util.Mutation)
local Research = require(Shared.Util.Research)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local ProductionService = require(script.Parent.ProductionService)

local IMPLEMENTED_ABILITIES = { InstantHarvest = true, SpeedBurst = true, GoldFind = true, Collect = true }

local CreatureService = {}

local function displayName(creature: Types.CreatureRecord): string
	local species = CreatureConfig.Species[creature.Species]
	return creature.Nickname or (species and species.Name or creature.Species)
end

-- Anchors ------------------------------------------------------------------------------------

local function updateAnchor(player: Player, creature: Types.CreatureRecord)
	local plot = PlotService.Get(player)
	if not plot then
		return
	end
	local folder = plot.Folder:FindFirstChild("Creatures") :: Folder
	local anchor = folder:FindFirstChild(creature.Id) :: Configuration?
	if not anchor then
		local new = Instance.new("Configuration")
		new.Name = creature.Id
		new.Parent = folder
		anchor = new
	end
	local a = anchor :: Configuration
	a:SetAttribute("Species", creature.Species)
	a:SetAttribute("Name", displayName(creature))
	a:SetAttribute("Level", creature.Level)
	a:SetAttribute("Stage", creature.Stage)
	a:SetAttribute("Mutation", creature.Mutation or "")
	a:SetAttribute("Assignment", creature.Assignment or "")
	local data = PlayerDataService.GetData(player)
	a:SetAttribute("Companion", data ~= nil and data.Companion == creature.Id)
	a:SetAttribute("Away", creature.Expedition ~= nil) -- on an expedition: not shown on the plot
	a:SetAttribute("OwnerUserId", player.UserId)
end

function CreatureService.RefreshAnchor(player: Player, creature: Types.CreatureRecord)
	updateAnchor(player, creature)
end

-- Granting -----------------------------------------------------------------------------------

function CreatureService.Grant(
	player: Player,
	speciesId: string,
	source: string,
	tradable: boolean?,
	extra: { [string]: any }? -- added to the client's reveal event (egg id, pity, ...)
): Types.CreatureRecord?
	local data = PlayerDataService.GetData(player)
	local species = CreatureConfig.Species[speciesId]
	if not data or not species then
		Log.Warn("Creature", "Grant rejected", { user = player.UserId, species = speciesId })
		return nil
	end
	local now = os.time()
	local record: Types.CreatureRecord = {
		Id = HttpService:GenerateGUID(false),
		Species = speciesId,
		Level = 1,
		Xp = 0,
		Stage = 1,
		Source = source,
		ObtainedAt = now,
		Tradable = if tradable == nil then false else tradable,
		WorkCycles = 0,
		JobCycles = {},
		RestUntil = 0,
		AbilityReadyAt = 0,
	}
	if MutationConfig.RollSources[source] then
		record.Mutation = Mutation.Roll(speciesId, record.Id .. ":" .. source, CreatureService.MutationMultiplier(data))
	end
	data.Creatures[record.Id] = record
	local entry = data.Collection[speciesId]
	local firstTime = entry == nil
	if entry then
		entry.Count += 1
	else
		data.Collection[speciesId] = { FirstAt = now, Count = 1 }
	end
	PlayerDataService.MarkDirty(player)
	updateAnchor(player, record)
	StateService.Push(player, "Creatures", "Collection", "Empire")
	local payload: { [string]: any } = {
		Id = record.Id,
		Species = speciesId,
		Source = source,
		NewDiscovery = firstTime,
		Mutation = record.Mutation,
	}
	local extras: { [string]: any } = extra or {}
	for key, value in extras do
		payload[key] = value
	end
	Remotes.Events.GameEvent:FireClient(player, "CreatureObtained", payload)
	Events.CreatureObtained:Fire(player, record.Id, source)
	Log.Info("Creature", "Granted", { user = player.UserId, species = speciesId, source = source, id = record.Id })
	return record
end

-- Mutation chance multiplier from research (1 = base chances).
function CreatureService.MutationMultiplier(data: Types.PlayerData): number
	return 1 + Research.Total(data, "Mutation")
end

-- The next starter species the player does not own yet (tutorial rewards).
function CreatureService.NextStarter(data: Types.PlayerData): string?
	local owned = {}
	for _, creature in data.Creatures do
		owned[creature.Species] = true
	end
	for _, speciesId in CreatureConfig.Starters do
		if not owned[speciesId] then
			return speciesId
		end
	end
	return nil
end

-- Requests -----------------------------------------------------------------------------------

local function chooseStarter(player: Player, speciesId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	if data.StarterChosen then
		return false, "You already have a partner."
	end
	local species = CreatureConfig.Species[speciesId]
	if not species or not species.Starter then
		return false, "Pick one of the starter creatures."
	end
	data.StarterChosen = speciesId
	local record = CreatureService.Grant(player, speciesId, "Starter", false)
	if not record then
		data.StarterChosen = nil
		return false, "Something went wrong."
	end
	Events.StarterChosen:Fire(player, speciesId)
	return true, record.Id
end

local function assign(player: Player, creatureId: string, buildingId: string?): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local creature = data.Creatures[creatureId]
	if not creature then
		return false, "That creature isn't yours."
	end
	if creature.Assignment == buildingId then
		return true, nil
	end
	if creature.Expedition then
		return false, "It's away on an expedition."
	end
	if buildingId ~= nil and data.Companion == creatureId then
		-- Going to work: it stops following you.
		data.Companion = nil
		StateService.Push(player, "Exploration")
	end
	if buildingId == nil then
		creature.Assignment = nil
	else
		local building = data.Buildings[buildingId]
		local def = building and BuildingConfig[building.Type]
		if not building or not def then
			return false, "That building isn't yours."
		end
		if def.Locked then
			return false, def.Locked
		end
		if not def.Job then
			return false, "Creatures can't work there."
		end
		local species = CreatureConfig.Species[creature.Species]
		local affinity = if species then CreatureConfig.Affinity(species, creature.Stage, def.Job) else 0
		if affinity <= 0 then
			local job = JobConfig[def.Job]
			return false, `{displayName(creature)} can't work as a {job and job.Name or def.Job}.`
		end
		local level = def.Levels[building.Level]
		local used = 0
		for otherId, other in data.Creatures do
			if otherId ~= creatureId and other.Assignment == buildingId then
				used += 1
			end
		end
		if used >= (level.Slots or 0) then
			return false, "No free worker slot. Upgrade the building for more."
		end
		creature.Assignment = buildingId
	end
	PlayerDataService.MarkDirty(player)
	updateAnchor(player, creature)
	ProductionService.Invalidate(player)
	Events.AssignmentsChanged:Fire(player)
	return true, nil
end

local function setCompanion(player: Player, creatureId: string?): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local previous = data.Companion and data.Creatures[data.Companion]
	if creatureId == nil then
		data.Companion = nil
	else
		local creature = data.Creatures[creatureId]
		if not creature then
			return false, "That creature isn't yours."
		end
		if creature.Expedition then
			return false, "It's away on an expedition."
		end
		if creature.Assignment then
			creature.Assignment = nil -- leaves its job to come with you
			ProductionService.Invalidate(player)
		end
		data.Companion = creatureId
		updateAnchor(player, creature)
	end
	if previous then
		updateAnchor(player, previous)
	end
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Exploration", "Creatures")
	return true, nil
end

-- All anchors (after expeditions start or end).
-- Re-syncs every anchor on the player's plot with their data (and removes anchors of
-- creatures they no longer have, e.g. after a trade).
function CreatureService.RefreshAll(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	for _, creature in data.Creatures do
		updateAnchor(player, creature)
	end
	local plot = PlotService.Get(player)
	local folder = plot and plot.Folder:FindFirstChild("Creatures")
	if folder then
		for _, anchor in folder:GetChildren() do
			if not data.Creatures[anchor.Name] then
				anchor:Destroy()
			end
		end
	end
end

-- Abilities that act outside production (regions, guardians, expeditions) are handled by
-- the service that owns that system; it registers a handler here at Start.
-- handler(player, creature, power, duration) -> (ok, message)
CreatureService.AbilityHandlers =
	{} :: { [string]: (Player, Types.CreatureRecord, number, number) -> (boolean, string) }
-- Kinds that only work while the creature is your companion.
local COMPANION_ABILITIES = { Shield = true, Debuff = true, Stealth = true }

local function useAbility(player: Player, creatureId: string): (boolean, any)
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	local creature = data.Creatures[creatureId]
	if not creature then
		return false, "That creature isn't yours."
	end
	local species = CreatureConfig.Species[creature.Species]
	if not species then
		return false, "Unknown creature."
	end
	if creature.Expedition then
		return false, "It's away on an expedition."
	end
	local ability = species.Active
	if not IMPLEMENTED_ABILITIES[ability.Kind] and not CreatureService.AbilityHandlers[ability.Kind] then
		return false, "This ability isn't available yet."
	end
	local now = os.time()
	if creature.AbilityReadyAt > now then
		return false, `{ability.Name} is ready in {creature.AbilityReadyAt - now}s.`
	end
	local buildingId = creature.Assignment
	local anywhere = ability.Kind == "GoldFind"
		or ability.Kind == "Collect"
		or CreatureService.AbilityHandlers[ability.Kind] ~= nil
	if COMPANION_ABILITIES[ability.Kind] and data.Companion ~= creatureId then
		return false, `Take {displayName(creature)} with you first (Creatures window → Take with me).`
	end
	if (ability.RequiresAssignment or not anywhere) and not buildingId then
		return false, `Assign {displayName(creature)} to a job first.`
	end
	local stage = species.Evolution[creature.Stage] or species.Evolution[1]
	local multiplier = stage.AbilityMultiplier or 1
	local strength = (species.BaseStats.AbilityStrength or 10) / 10 * multiplier
	local duration = (ability.Duration or 15) * multiplier
	local message: string

	if ability.Kind == "InstantHarvest" then
		ProductionService.Flush(player)
		local building = data.Buildings[buildingId :: string]
		local rate = ProductionService.GetRate(player, buildingId :: string)
		local worker = ProductionService.GetWorkerRate(player, creatureId)
		if not building or not rate or not worker then
			return false, "It needs to be working to use this."
		end
		local stored = building.Stored[rate.Output] or 0
		if stored >= rate.Capacity then
			return false, "Storage is full. Collect first!"
		end
		-- Goes through the same step as normal work, so recipes with inputs (smelter,
		-- condenser) still consume silo materials and nothing is made from nothing.
		local amount = worker.PerCycle * ability.Power * strength
		local newStored, made = Production.Step(stored, amount, 1, rate.Capacity, rate.InputsPerUnit, data.Resources)
		if made <= 0 then
			return false, "Not enough materials in your silo for that."
		end
		building.Stored[rate.Output] = newStored
		local output = ResourceConfig[rate.Output]
		message = `{ability.Name}! +{math.floor(made)} {output and output.Name or rate.Output} at the building.`
		StateService.Push(player, "Wallet")
	elseif ability.Kind == "SpeedBurst" then
		ProductionService.AddBuff(player, buildingId :: string, {
			Stat = "WorkSpeed",
			Category = "Ability",
			Value = ability.Power * strength,
			Duration = duration,
		})
		message = `{ability.Name}! Workers are {math.floor(ability.Power * strength * 100)}% faster for {math.floor(
			duration
		)}s.`
	elseif ability.Kind == "GoldFind" then
		local tier = Production.CoreTier(data)
		local gold = math.floor(ability.Power * strength * (1 + EconomyConfig.GoldFindPerCoreLevel * (tier - 1)))
		EconomyService.Add(player, "Gold", gold, "Ability " .. ability.Id)
		message = `{ability.Name}! {displayName(creature)} dug up {gold} gold.`
	elseif ability.Kind == "Collect" then
		local carried = ProductionService.CarryNow(player, math.floor(ability.Power * strength))
		if carried <= 0 then
			return false, "Nothing is waiting at your buildings (or your silo is full)."
		end
		message = `{ability.Name}! {displayName(creature)} carried {carried} items to your silo.`
	elseif CreatureService.AbilityHandlers[ability.Kind] then
		local ok, result =
			CreatureService.AbilityHandlers[ability.Kind](player, creature, ability.Power * strength, duration)
		if not ok then
			return false, result
		end
		message = result
	else
		return false, "This ability isn't available yet."
	end

	creature.AbilityReadyAt = now + ability.Cooldown
	data.Stats.AbilitiesUsed = (data.Stats.AbilitiesUsed or 0) + 1
	PlayerDataService.MarkDirty(player)
	StateService.Push(player, "Creatures", "Buildings")
	-- Everyone nearby sees the effect.
	Remotes.Events.GameEvent:FireAllClients("AbilityFx", {
		OwnerUserId = player.UserId,
		CreatureId = creatureId,
		BuildingId = buildingId,
		Kind = ability.Kind,
		Family = species.Family,
	})
	Remotes.Events.Notify:FireClient(player, message, "Success")
	Events.AbilityUsed:Fire(player, creatureId, ability.Id)
	return true, nil
end

-- State --------------------------------------------------------------------------------------

local function creaturesState(player: Player, profile: PlayerDataService.Profile)
	local data = profile.Data
	local list = {}
	local now = os.time()
	for id, creature in data.Creatures do
		local species = CreatureConfig.Species[creature.Species]
		if species then
			local worker = ProductionService.GetWorkerRate(player, id)
			local building = creature.Assignment and data.Buildings[creature.Assignment]
			local def = building and BuildingConfig[building.Type]
			local job = def and def.Job and JobConfig[def.Job]
			local task = if data.Companion == id
				then "Following you"
				elseif creature.Expedition then "Away on an expedition"
				else "Relaxing in the habitat"
			if job and building then
				local rate = ProductionService.GetRate(player, building.Id)
				local full = rate and (building.Stored[rate.Output] or 0) >= rate.Capacity
				task = if full
					then "Waiting: storage is full"
					elseif ProductionService.IsStarved(player, building.Id) then "Waiting: needs materials in the silo"
					else job.Verb
			end
			list[id] = {
				Id = id,
				Species = creature.Species,
				Name = displayName(creature),
				Level = creature.Level,
				Xp = creature.Xp,
				XpToNext = CreatureConfig.XpToNext(creature.Level),
				Stage = creature.Stage,
				Mutation = creature.Mutation,
				Assignment = creature.Assignment,
				Task = task,
				PerSecond = worker and worker.PerSecond or 0,
				CycleTime = worker and worker.CycleTime,
				SpeedMultiplier = worker and worker.SpeedMultiplier,
				YieldMultiplier = worker and worker.YieldMultiplier,
				AbilityReadyIn = math.max(creature.AbilityReadyAt - now, 0),
				Source = creature.Source,
				Tradable = creature.Tradable,
				WorkCycles = creature.WorkCycles,
				JobCycles = table.clone(creature.JobCycles),
				Expedition = creature.Expedition,
				RestIn = math.max(creature.RestUntil - now, 0),
				-- Absolute, on the shared server clock, so the client can count down without
				-- a fresh push.
				RestUntilServer = Workspace:GetServerTimeNow() + math.max(creature.RestUntil - now, 0),
				Companion = data.Companion == id,
				ObtainedAt = creature.ObtainedAt,
			}
		end
	end
	return { List = list, StarterChosen = data.StarterChosen }
end

function CreatureService.Start()
	StateService.Register("Creatures", creaturesState)
	StateService.Register("Collection", function(_player, profile)
		return table.clone(profile.Data.Collection)
	end)

	PlotService.OnClaimed(function(player)
		local data = PlayerDataService.GetData(player)
		if data then
			for _, creature in data.Creatures do
				updateAnchor(player, creature)
			end
		end
	end)

	Events.CreatureLeveled:Connect(function(player, creatureId, level)
		local data = PlayerDataService.GetData(player)
		local creature = data and data.Creatures[creatureId]
		if creature then
			updateAnchor(player, creature)
			Remotes.Events.Notify:FireClient(player, `{displayName(creature)} reached level {level}!`, "Reward")
			Remotes.Events.GameEvent:FireClient(player, "CreatureLeveled", { Id = creatureId, Level = level })
		end
	end)

	local Check = Net.Check
	Net.Handle("ChooseStarter", { Rate = { 2, 0.5 }, Args = { Check.Id } }, chooseStarter)
	Net.Handle("AssignCreature", { Rate = { 6, 2 }, Args = { Check.Id, Check.OptionalId } }, assign)
	Net.Handle("UseAbility", { Rate = { 4, 1 }, Args = { Check.Id } }, useAbility)
	Net.Handle("SetCompanion", { Rate = { 4, 1 }, Args = { Check.OptionalId } }, setCompanion)
end

return CreatureService
