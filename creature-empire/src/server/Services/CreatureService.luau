--!strict
-- Owns creatures: granting them (with server-generated ids), the starter choice, job
-- assignment, active abilities and the lightweight "anchor" instances clients render.
--
-- Creatures are not simulated on the server. Each owned creature has a Configuration
-- under its owner's plot (Plot/Creatures/<id>) whose attributes describe it; every client
-- builds and animates the visual model locally (client/Controllers/CreatureController).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local JobConfig = require(Shared.Config.JobConfig)
local Production = require(Shared.Util.Production)
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

local IMPLEMENTED_ABILITIES = { InstantHarvest = true, SpeedBurst = true, GoldFind = true }

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
	a:SetAttribute("OwnerUserId", player.UserId)
end

-- Granting -----------------------------------------------------------------------------------

function CreatureService.Grant(
	player: Player,
	speciesId: string,
	source: string,
	tradable: boolean?
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
		AbilityReadyAt = 0,
	}
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
	StateService.Push(player, "Creatures", "Collection")
	Remotes.Events.GameEvent:FireClient(player, "CreatureObtained", {
		Id = record.Id,
		Species = speciesId,
		Source = source,
		NewDiscovery = firstTime,
	})
	Events.CreatureObtained:Fire(player, record.Id, source)
	Log.Info("Creature", "Granted", { user = player.UserId, species = speciesId, source = source, id = record.Id })
	return record
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
		local affinity = species and species.JobAffinity[def.Job] or 0
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
	local ability = species.Active
	if not IMPLEMENTED_ABILITIES[ability.Kind] then
		return false, "This ability isn't available yet."
	end
	local now = os.time()
	if creature.AbilityReadyAt > now then
		return false, `{ability.Name} is ready in {creature.AbilityReadyAt - now}s.`
	end
	local buildingId = creature.Assignment
	if (ability.RequiresAssignment or ability.Kind ~= "GoldFind") and not buildingId then
		return false, `Assign {displayName(creature)} to a job first.`
	end
	local strength = (species.BaseStats.AbilityStrength or 10) / 10
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
		local amount = worker.PerCycle * ability.Power * strength
		building.Stored[rate.Output] = math.min(stored + amount, rate.Capacity)
		message = `{ability.Name}! The farm burst into bloom.`
	elseif ability.Kind == "SpeedBurst" then
		ProductionService.AddBuff(player, buildingId :: string, {
			Stat = "WorkSpeed",
			Category = "Ability",
			Value = ability.Power * strength,
			Duration = ability.Duration or 15,
		})
		message =
			`{ability.Name}! Workers are {math.floor(ability.Power * strength * 100)}% faster for {ability.Duration or 15}s.`
	elseif ability.Kind == "GoldFind" then
		local tier = Production.CoreTier(data)
		local gold = math.floor(ability.Power * strength * (1 + EconomyConfig.GoldFindPerCoreLevel * (tier - 1)))
		EconomyService.Add(player, "Gold", gold, "Ability " .. ability.Id)
		message = `{ability.Name}! {displayName(creature)} dug up {gold} gold.`
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
			local task = "Relaxing in the habitat"
			if job and building then
				local rate = ProductionService.GetRate(player, building.Id)
				local full = rate and (building.Stored[rate.Output] or 0) >= rate.Capacity
				task = if full then "Waiting: storage is full" else job.Verb
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
end

return CreatureService
