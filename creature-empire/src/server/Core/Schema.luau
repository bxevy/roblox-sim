--!strict
-- The saved player data schema: defaults, version migrations and validation.
--
-- Bump CURRENT_VERSION whenever the shape changes and add a migration from the previous
-- version. Migrations run in order on load, so a v1 profile reaches v3 via v1->v2->v3.
-- Sanitize runs after migrations on every load and before every save; it repairs
-- malformed fields instead of discarding the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local QuestConfig = require(Shared.Config.QuestConfig)
local ExpeditionConfig = require(Shared.Config.ExpeditionConfig)
local ResearchConfig = require(Shared.Config.ResearchConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local AscensionConfig = require(Shared.Config.AscensionConfig)
local SocialConfig = require(Shared.Config.SocialConfig)
local PlazaConfig = require(Shared.Config.PlazaConfig)
local SpinConfig = require(Shared.Config.SpinConfig)
local Formulas = require(Shared.Util.Formulas)
local Housing = require(Shared.Util.Housing)
local Team = require(Shared.Util.Team)
local WorkRules = require(Shared.Util.WorkRules)

local Schema = {}

Schema.CURRENT_VERSION = 10

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function cleanAmount(value: any, max: number?): number
	if not isFiniteNumber(value) then
		return 0
	end
	return math.clamp(value, 0, max or EconomyConfig.MaxBalance)
end

local function cleanInteger(value: any, min: number, max: number, default: number): number
	if not isFiniteNumber(value) then
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

local function emptyStored(): { [string]: number }
	return {}
end

function Schema.Default(now: number): Types.PlayerData
	local buildings: { [string]: Types.BuildingRecord } = {}
	for _, entry in PlotConfig.FixedLayout do
		buildings[entry.Id] = {
			Id = entry.Id,
			Type = entry.Type,
			Level = 1,
			X = entry.X,
			Z = entry.Z,
			Rot = entry.Rot,
			Stored = emptyStored(),
		}
	end
	for _, entry in PlotConfig.StarterBuildings do
		buildings[entry.Id] = {
			Id = entry.Id,
			Type = entry.Type,
			Level = 1,
			X = entry.X,
			Z = entry.Z,
			Rot = entry.Rot,
			Stored = emptyStored(),
		}
	end

	return {
		Version = Schema.CURRENT_VERSION,
		Currencies = table.clone(EconomyConfig.StartingCurrencies),
		Resources = table.clone(EconomyConfig.StartingResources),
		Creatures = {},
		Buildings = buildings,
		StarterChosen = nil,
		Quests = { Tutorial = 1, Progress = 0, Claimable = false },
		Collection = {},
		Settings = {
			Music = 0.5,
			Sfx = 0.8,
			Vfx = "Full",
			ReducedMotion = false,
			CameraShake = true,
			FastOpen = false,
		},
		Stats = { GoldEarned = 0, Collected = 0, Sold = 0, AbilitiesUsed = 0, Sessions = 0 },
		LastOnline = now,
		Ascension = { Count = 0, Shards = 0, Perks = {}, RunGold = 0 },
		Research = {},
		Collaborators = {},
		WorldEvents = {},
		Season = { Week = 0, Gold = 0 },
		MutationCharm = 0,
		BoostUntil = 0,
		Spin = { NextFreeAt = 0, Count = 0 },
		Boosts = {},
		Receipts = {},
		Pity = {},
		Expansions = {},
		Companion = nil,
		Team = {},
		Expeditions = {},
		Discoveries = {},
		Guardians = {},
	}
end

-- Migrations[n] upgrades a version-n profile to version n + 1.
Schema.Migrations = {
	-- v0: pre-release test profiles had no Version field and kept gold in `Coins`.
	[0] = function(data: { [string]: any })
		if type(data.Coins) == "number" then
			data.Currencies = data.Currencies or {}
			data.Currencies.Gold = (data.Currencies.Gold or 0) + data.Coins
			data.Coins = nil
		end
	end,
	-- v1 -> v2 (update 2): per-job work counts for evolution, egg pity, land expansions.
	-- Every v1 work cycle was farming (the only job in update 1).
	[1] = function(data: { [string]: any })
		if type(data.Creatures) == "table" then
			for _, creature in data.Creatures do
				if type(creature) == "table" and type(creature.JobCycles) ~= "table" then
					local cycles = if type(creature.WorkCycles) == "number" then creature.WorkCycles else 0
					creature.JobCycles = if cycles > 0 then { Farmer = cycles } else {}
				end
			end
		end
		data.Pity = if type(data.Pity) == "table" then data.Pity else {}
		data.Expansions = if type(data.Expansions) == "table" then data.Expansions else {}
	end,
	-- v2 -> v3 (update 3): companion, expeditions, landmark discoveries, guardian records.
	[2] = function(data: { [string]: any })
		data.Expeditions = if type(data.Expeditions) == "table" then data.Expeditions else {}
		data.Discoveries = if type(data.Discoveries) == "table" then data.Discoveries else {}
		data.Guardians = if type(data.Guardians) == "table" then data.Guardians else {}
		if type(data.Creatures) == "table" then
			for _, creature in data.Creatures do
				if type(creature) == "table" and type(creature.RestUntil) ~= "number" then
					creature.RestUntil = 0
				end
			end
		end
	end,
	-- v3 -> v4 (update 4): research, Ascension perks and the gold earned this run.
	[3] = function(data: { [string]: any })
		data.Research = if type(data.Research) == "table" then data.Research else {}
		if type(data.Ascension) == "table" then
			data.Ascension.Perks = if type(data.Ascension.Perks) == "table" then data.Ascension.Perks else {}
			if type(data.Ascension.RunGold) ~= "number" then
				local earned = type(data.Stats) == "table" and data.Stats.GoldEarned
				data.Ascension.RunGold = if type(earned) == "number" then earned else 0
			end
		end
	end,
	-- v4 -> v5 (update 5): collaborators, world event records, weekly gold.
	[4] = function(data: { [string]: any })
		data.Collaborators = if type(data.Collaborators) == "table" then data.Collaborators else {}
		data.WorldEvents = if type(data.WorldEvents) == "table" then data.WorldEvents else {}
		data.Season = if type(data.Season) == "table" then data.Season else { Week = 0, Gold = 0 }
	end,
	-- v5 -> v6 (release): Dark Gift charm and purchased production boosts.
	[5] = function(data: { [string]: any })
		data.MutationCharm = if type(data.MutationCharm) == "number" then data.MutationCharm else 0
		data.BoostUntil = if type(data.BoostUntil) == "number" then data.BoostUntil else 0
	end,
	-- v6 -> v7 (plaza update): the Trading Post and Hatchery moved from every plot to the
	-- plaza. Plot copies are removed and a built Hatchery's price is refunded. Spin Wheel.
	[6] = function(data: { [string]: any })
		if type(data.Buildings) == "table" then
			for id, record in data.Buildings do
				if type(record) == "table" and PlazaConfig.BuildingTypes[record.Type] then
					if record.Type == "Hatchery" and type(data.Currencies) == "table" then
						local cost: { [string]: number } = BuildingConfig.Hatchery.PlaceCost or {}
						for currency, amount in cost do
							local current = data.Currencies[currency]
							data.Currencies[currency] = (if type(current) == "number" then current else 0) + amount
						end
					end
					data.Buildings[id] = nil
				end
			end
		end
		data.Spin = if type(data.Spin) == "table" then data.Spin else { NextFreeAt = 0, Count = 0 }
		data.Boosts = if type(data.Boosts) == "table" then data.Boosts else {}
	end,
	-- v7 -> v8 (habitats update): every Creature Habitat holds 5 creatures and you build
	-- more instead of upgrading one. Habitat upgrades are refunded (the v7 prices); extra
	-- creatures move to the backpack in Sanitize (Housing.Fit).
	[7] = function(data: { [string]: any })
		if type(data.Buildings) ~= "table" or type(data.Currencies) ~= "table" then
			return
		end
		for _, record in data.Buildings do
			if type(record) == "table" and record.Type == "Habitat" and type(record.Level) == "number" then
				for level = 2, math.clamp(math.floor(record.Level), 1, 5) do
					local gold = Formulas.CostAt(500, 2.6, level - 1)
					data.Currencies.Gold = (tonumber(data.Currencies.Gold) or 0) + gold
					if level >= 4 and type(data.Resources) == "table" then
						data.Resources.RefinedCrystal = (tonumber(data.Resources.RefinedCrystal) or 0)
							+ Formulas.CostAt(10, 2.6, level - 1)
					end
				end
				record.Level = 1
			end
		end
	end,
	-- v8 -> v9 (team update): up to 3 creatures follow you; the companion leads the team.
	[8] = function(data: { [string]: any })
		if type(data.Team) ~= "table" then
			data.Team = if type(data.Companion) == "string" then { data.Companion } else {}
		end
	end,
	-- v10: three currencies (Gold, Essence, Empire Shards). Insight is folded into Essence
	-- one for one; the tutorial's opening steps changed (see QuestRemap below).
	[9] = function(data: { [string]: any })
		local currencies = data.Currencies
		if type(currencies) == "table" then
			local insight = currencies.Insight
			if type(insight) == "number" and insight > 0 and insight == insight and insight ~= math.huge then
				currencies.Essence = (if type(currencies.Essence) == "number" then currencies.Essence else 0)
					+ math.floor(insight)
			end
			currencies.Insight = nil
		end
		-- The tutorial's opening is now the three starters' buildings. Progress is saved as
		-- a position in the list, so map the old positions by step id: anyone still in the
		-- old opening (choosing up to the second farm) starts the new starter steps; the
		-- old Mine and Smelter steps became part of them.
		local OLD = {
			"Starter",
			"FirstJob",
			"FirstHarvest",
			"FirstSale",
			"TwoWorkers",
			"Ability",
			"SecondFarm",
			"Silo",
			"Earn",
			"CoreTier2",
			"Hatchery",
			"FirstHatch",
			"Mine",
			"Smelter",
			"Chamber",
			"Evolve",
			"CoreTier3",
			"Basin",
			"Gather",
			"Landmarks",
			"Lure",
			"Befriend",
			"Expedition",
			"Guardian",
			"Study",
			"Breakthrough",
			"Together",
			"Couriers",
			"Arcane",
			"Researcher",
			"Ascend",
			"WorldEvent",
		}
		local quests = data.Quests
		if type(quests) == "table" and type(quests.Tutorial) == "number" then
			local old = math.floor(quests.Tutorial)
			local function indexOf(id: string): number?
				for i, step in QuestConfig.Tutorial do
					if step.Id == id then
						return i
					end
				end
				return nil
			end
			local new: number?
			if old > #OLD then
				new = #QuestConfig.Tutorial + 1 -- finished
			elseif old <= 1 then
				new = 1
			elseif old <= 7 then
				new = indexOf("Build1")
			else
				local id = OLD[old]
				new = indexOf(if id == "Mine" or id == "Smelter" then "Chamber" else id)
			end
			quests.Tutorial = new or 1
			quests.Progress = 0
			quests.Claimable = false
		end
	end,
} :: { [number]: (data: { [string]: any }) -> () }

-- Runs every migration the profile needs. Returns ok, or false + reason when the profile
-- is from a newer version this server does not understand (it must not be overwritten).
function Schema.Migrate(data: { [string]: any }): (boolean, string?)
	local version = if isFiniteNumber(data.Version) then math.floor(data.Version) else 0
	if version > Schema.CURRENT_VERSION then
		return false, `profile version {version} is newer than this server ({Schema.CURRENT_VERSION})`
	end
	while version < Schema.CURRENT_VERSION do
		local migrate = Schema.Migrations[version]
		if migrate then
			migrate(data)
		end
		version += 1
		data.Version = version
	end
	return true, nil
end

-- Repairs a profile in place. Returns a list of what was fixed (for logs).
function Schema.Sanitize(data: { [string]: any }, now: number): { string }
	local fixes = {}
	local function fix(message: string)
		table.insert(fixes, message)
	end
	local defaults = Schema.Default(now)

	data.Version = Schema.CURRENT_VERSION

	-- Currencies and resources: known ids only, finite, non-negative, capped.
	for _, section in { "Currencies", "Resources" } do
		local template = (defaults :: any)[section]
		if type(data[section]) ~= "table" then
			data[section] = table.clone(template)
			fix(section .. " missing")
		end
		for id, value in data[section] do
			if type(id) ~= "string" or not isFiniteNumber(value) or value < 0 then
				data[section][id] = if type(id) == "string" then cleanAmount(value) else nil
				fix(`{section}.{tostring(id)} invalid`)
			elseif value > EconomyConfig.MaxBalance then
				data[section][id] = EconomyConfig.MaxBalance
				fix(`{section}.{id} over max`)
			end
		end
		for id, value in template do
			if data[section][id] == nil then
				data[section][id] = value
			end
		end
	end
	data.Currencies.Gold = math.floor(data.Currencies.Gold)
	-- Materials may be fractional: smelters and condensers consume them continuously.

	-- Buildings
	if type(data.Buildings) ~= "table" then
		data.Buildings = defaults.Buildings
		fix("Buildings missing")
	end
	for id, record in data.Buildings do
		if type(id) ~= "string" or type(record) ~= "table" or type(record.Type) ~= "string" then
			data.Buildings[id] = nil
			fix(`Building {tostring(id)} malformed, removed`)
			continue
		end
		if PlazaConfig.BuildingTypes[record.Type] then
			data.Buildings[id] = nil -- lives in the plaza now
			fix(`Building {id} moved to the plaza`)
			continue
		end
		record.Id = id
		local def = BuildingConfig[record.Type]
		local maxLevel = if def then #def.Levels else 1
		record.Level = cleanInteger(record.Level, 1, maxLevel, 1)
		-- Expansion zones extend the grid by 4 cells west, east and north.
		record.X = cleanInteger(record.X, -4, PlotConfig.GridX + 3, 0)
		record.Z = cleanInteger(record.Z, 0, PlotConfig.GridZ + 3, 0)
		record.Rot = cleanInteger(record.Rot, 0, 3, 0)
		if type(record.Stored) ~= "table" then
			record.Stored = {}
		end
		for resource, amount in record.Stored do
			record.Stored[resource] = cleanAmount(amount)
		end
	end
	-- Fixed buildings always exist, at their layout position.
	for _, entry in PlotConfig.FixedLayout do
		local record = data.Buildings[entry.Id]
		if not record or record.Type ~= entry.Type then
			data.Buildings[entry.Id] =
				{ Id = entry.Id, Type = entry.Type, Level = 1, X = entry.X, Z = entry.Z, Rot = entry.Rot, Stored = {} }
			fix(`Fixed building {entry.Id} restored`)
		else
			record.X, record.Z, record.Rot = entry.X, entry.Z, entry.Rot
		end
	end

	-- Creatures
	if type(data.Creatures) ~= "table" then
		data.Creatures = {}
		fix("Creatures missing")
	end
	local slotsUsed: { [string]: number } = {}
	for id, record in data.Creatures do
		if type(id) ~= "string" or type(record) ~= "table" or type(record.Species) ~= "string" then
			data.Creatures[id] = nil
			fix(`Creature {tostring(id)} malformed, removed`)
			continue
		end
		record.Id = id
		record.Level = cleanInteger(record.Level, 1, CreatureConfig.MaxLevel, 1)
		record.Xp = cleanAmount(record.Xp)
		record.Stage = cleanInteger(record.Stage, 1, 3, 1)
		record.WorkCycles = cleanAmount(record.WorkCycles)
		if type(record.JobCycles) ~= "table" then
			record.JobCycles = {}
		end
		for job, count in record.JobCycles do
			if type(job) ~= "string" then
				record.JobCycles[job] = nil
			else
				record.JobCycles[job] = cleanAmount(count)
			end
		end
		record.RestUntil = if isFiniteNumber(record.RestUntil) then math.min(record.RestUntil, now + 86400) else 0
		if record.Expedition ~= nil and type(record.Expedition) ~= "string" then
			record.Expedition = nil
		end
		record.AbilityReadyAt = if isFiniteNumber(record.AbilityReadyAt)
			then math.min(record.AbilityReadyAt, now + 3600)
			else 0
		record.ObtainedAt = if isFiniteNumber(record.ObtainedAt) then record.ObtainedAt else now
		record.Source = if type(record.Source) == "string" then record.Source else "Unknown"
		record.Tradable = record.Tradable == true
		record.Stored = if record.Stored == true and record.Expedition == nil then true else nil
		if record.Stored then
			record.Assignment = nil
		end
		if record.Nickname ~= nil and type(record.Nickname) ~= "string" then
			record.Nickname = nil
		end
		if
			record.Mutation ~= nil
			and (type(record.Mutation) ~= "string" or not MutationConfig.Mutations[record.Mutation])
		then
			record.Mutation = nil
			fix(`Creature {id} mutation cleared`)
		end

		-- Assignment must point at an existing building with that job and a free slot.
		local assignment = record.Assignment
		if assignment ~= nil then
			local building = if type(assignment) == "string" then data.Buildings[assignment] else nil
			local def = building and BuildingConfig[building.Type]
			local species = CreatureConfig.Species[record.Species]
			local level = def and def.Levels[building.Level]
			local valid = def ~= nil
				and def.Job ~= nil
				and def.Locked == nil
				and species ~= nil
				and WorkRules.CanWork(def, record.Species, record.Stage)
				and level ~= nil
				and (slotsUsed[assignment] or 0) < (level.Slots or 0)
			if valid then
				slotsUsed[assignment] = (slotsUsed[assignment] or 0) + 1
			else
				record.Assignment = nil
				fix(`Creature {id} assignment cleared`)
			end
		end
	end

	-- Quests
	if type(data.Quests) ~= "table" then
		data.Quests = defaults.Quests
		fix("Quests missing")
	end
	data.Quests.Tutorial = cleanInteger(data.Quests.Tutorial, 1, #QuestConfig.Tutorial + 1, 1)
	data.Quests.Progress = cleanAmount(data.Quests.Progress)
	data.Quests.Claimable = data.Quests.Claimable == true

	-- Settings
	if type(data.Settings) ~= "table" then
		data.Settings = defaults.Settings
		fix("Settings missing")
	end
	local settings = data.Settings
	settings.Music = if isFiniteNumber(settings.Music)
		then math.clamp(settings.Music, 0, 1)
		else defaults.Settings.Music
	settings.Sfx = if isFiniteNumber(settings.Sfx) then math.clamp(settings.Sfx, 0, 1) else defaults.Settings.Sfx
	if settings.Vfx ~= "Full" and settings.Vfx ~= "Reduced" and settings.Vfx ~= "Off" then
		settings.Vfx = "Full"
	end
	for _, key in { "ReducedMotion", "CameraShake", "FastOpen" } do
		if type(settings[key]) ~= "boolean" then
			settings[key] = (defaults.Settings :: any)[key]
		end
	end

	-- Everything else
	if data.StarterChosen ~= nil and type(data.StarterChosen) ~= "string" then
		data.StarterChosen = nil
	end
	for _, key in { "Collection", "Stats", "Receipts", "Pity", "Expansions", "Expeditions", "Discoveries", "Guardians" } do
		if type(data[key]) ~= "table" then
			data[key] = (defaults :: any)[key]
			fix(key .. " missing")
		end
	end
	for key, value in data.Stats do
		data.Stats[key] = cleanAmount(value)
	end
	for eggId, count in data.Pity do
		data.Pity[eggId] = cleanInteger(count, 0, 1000, 0)
	end
	-- Expeditions: drop broken ones and free their creatures; creatures can only be on an
	-- expedition that exists and lists them.
	for id, expedition in data.Expeditions do
		local valid = type(id) == "string"
			and type(expedition) == "table"
			and type(expedition.Destination) == "string"
			and ExpeditionConfig.Destinations[expedition.Destination] ~= nil
			and type(expedition.Creatures) == "table"
			and isFiniteNumber(expedition.EndsAt)
			and isFiniteNumber(expedition.Seed)
		if valid then
			expedition.Id = id
			expedition.Approach = if type(expedition.Approach) == "string" then expedition.Approach else "Balanced"
			expedition.Supplies = if type(expedition.Supplies) == "table" then expedition.Supplies else {}
			expedition.StartedAt = if isFiniteNumber(expedition.StartedAt) then expedition.StartedAt else now
			expedition.Bonus = if isFiniteNumber(expedition.Bonus) then math.clamp(expedition.Bonus, 0, 0.5) else 0
			expedition.Party = if isFiniteNumber(expedition.Party) then math.floor(expedition.Party) else nil
			expedition.PartySize = if isFiniteNumber(expedition.PartySize)
				then cleanInteger(expedition.PartySize, 1, 50, 1)
				else nil
			local members = {}
			for _, creatureId in expedition.Creatures do
				if type(creatureId) == "string" and data.Creatures[creatureId] then
					table.insert(members, creatureId)
				end
			end
			expedition.Creatures = members
			if #members == 0 then
				valid = false
			end
		end
		if not valid then
			data.Expeditions[id] = nil
			fix(`Expedition {tostring(id)} removed`)
		end
	end
	for id, record in data.Creatures do
		local expedition = record.Expedition and data.Expeditions[record.Expedition]
		if record.Expedition and (not expedition or not table.find(expedition.Creatures, id)) then
			record.Expedition = nil
			fix(`Creature {id} expedition cleared`)
		end
		if record.Expedition then
			record.Assignment = nil
		end
	end
	-- The Active Team: valid members only, the leader is the companion.
	Team.Normalize(data :: any)
	-- More creatures on the plot than the habitats hold: the extras go to the backpack.
	for _, id in Housing.Fit(data :: any) do
		fix(`Creature {id} moved to the backpack`)
	end
	for id, at in data.Discoveries do
		if type(id) ~= "string" or not isFiniteNumber(at) then
			data.Discoveries[id] = nil
		end
	end
	for id, record in data.Guardians do
		if type(record) ~= "table" then
			data.Guardians[id] = nil
		else
			record.Defeats = cleanInteger(record.Defeats, 0, 1e6, 0)
			record.LastRewardAt = if isFiniteNumber(record.LastRewardAt) then record.LastRewardAt else 0
		end
	end

	for zoneId, owned in data.Expansions do
		if owned ~= true or not PlotConfig.Zone(zoneId) then
			data.Expansions[zoneId] = nil
			fix(`Expansion {tostring(zoneId)} removed`)
		end
	end
	if type(data.Ascension) ~= "table" then
		data.Ascension = defaults.Ascension
	end
	data.Ascension.Count = cleanInteger(data.Ascension.Count, 0, 1e6, 0)
	data.Ascension.Shards = cleanAmount(data.Ascension.Shards)
	data.Ascension.RunGold = cleanAmount(data.Ascension.RunGold)
	if type(data.Ascension.Perks) ~= "table" then
		data.Ascension.Perks = {}
	end
	for perkId, rank in data.Ascension.Perks do
		local perk = AscensionConfig.Perks[perkId]
		if not perk then
			data.Ascension.Perks[perkId] = nil
			fix(`Perk {tostring(perkId)} removed`)
		else
			data.Ascension.Perks[perkId] = cleanInteger(rank, 0, perk.MaxRank, 0)
		end
	end
	-- Collaborators: up to the limit, keyed by positive user id strings.
	if type(data.Collaborators) ~= "table" then
		data.Collaborators = {}
	end
	local collaborators = 0
	for userId, allowed in data.Collaborators do
		local numeric = type(userId) == "string" and tonumber(userId)
		if allowed ~= true or not numeric or numeric <= 0 or collaborators >= SocialConfig.MaxCollaborators then
			data.Collaborators[userId] = nil
			fix(`Collaborator {tostring(userId)} removed`)
		else
			collaborators += 1
		end
	end
	if type(data.WorldEvents) ~= "table" then
		data.WorldEvents = {}
	end
	for eventId, times in data.WorldEvents do
		if type(eventId) ~= "string" then
			data.WorldEvents[eventId] = nil
		else
			data.WorldEvents[eventId] = cleanInteger(times, 0, 1e6, 0)
		end
	end
	if type(data.Season) ~= "table" then
		data.Season = { Week = 0, Gold = 0 }
	end
	data.Season.Week = cleanInteger(data.Season.Week, 0, 1e7, 0)
	data.Season.Gold = cleanAmount(data.Season.Gold)
	data.MutationCharm = if isFiniteNumber(data.MutationCharm) then math.clamp(data.MutationCharm, 0, 5) else 0
	data.BoostUntil = if isFiniteNumber(data.BoostUntil) then math.clamp(data.BoostUntil, 0, now + 30 * 86400) else 0
	if type(data.Spin) ~= "table" then
		data.Spin = { NextFreeAt = 0, Count = 0 }
	end
	data.Spin.NextFreeAt = if isFiniteNumber(data.Spin.NextFreeAt)
		then math.clamp(data.Spin.NextFreeAt, 0, now + SpinConfig.FreeEvery)
		else 0
	data.Spin.Count = cleanInteger(data.Spin.Count, 0, 1e9, 0)
	if type(data.Boosts) ~= "table" then
		data.Boosts = {}
	end
	for boostId, untilTime in data.Boosts do
		if not SpinConfig.Boosts[boostId] or not isFiniteNumber(untilTime) or untilTime <= now then
			data.Boosts[boostId] = nil
		else
			data.Boosts[boostId] = math.min(untilTime, now + SpinConfig.MaxBoostSeconds)
		end
	end

	-- Research: known nodes only, and only with their prerequisites.
	if type(data.Research) ~= "table" then
		data.Research = {}
	end
	for nodeId, at in data.Research do
		if not ResearchConfig.Nodes[nodeId] or not isFiniteNumber(at) then
			data.Research[nodeId] = nil
			fix(`Research {tostring(nodeId)} removed`)
		end
	end
	local changed = true
	while changed do
		changed = false
		for nodeId in data.Research do
			for _, required in ResearchConfig.Nodes[nodeId].Requires do
				if data.Research[required] == nil then
					data.Research[nodeId] = nil
					changed = true
					fix(`Research {nodeId} missing {required}`)
				end
			end
		end
	end
	if not isFiniteNumber(data.LastOnline) or data.LastOnline > now then
		data.LastOnline = now
	end

	return fixes
end

return Schema
