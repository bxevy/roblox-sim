--!strict
-- Wild creatures roaming explorable regions. The server owns where and what they are;
-- each is a Configuration under Workspace.WildCreatures (attributes: Species, Position,
-- Region, Special) that clients render and animate.
--
-- Befriending costs one Ember Lure; the chance (Shared/Util/Encounter) is shown before the
-- throw. Success or not, the creature leaves, so it can't be retried endlessly.
-- During an eruption a Pyrewing lands on the Ashen Overlook: the region's secret creature.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local RegionConfig = require(Shared.Config.RegionConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Encounter = require(Shared.Util.Encounter)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local BuildingService = require(script.Parent.BuildingService)
local NodeService = require(script.Parent.NodeService)

local BEFRIEND_RANGE = 25
local SPAWN_CHECK = 5

type Wild = {
	Id: string,
	Species: string,
	Position: Vector3,
	ExpiresAt: number,
	Region: string,
	Special: boolean,
	Anchor: Configuration,
}

local WildService = {}

local wilds: { [string]: Wild } = {}
local folder: Folder
local rng = Random.new()

local function despawn(id: string)
	local wild = wilds[id]
	if wild then
		wilds[id] = nil
		wild.Anchor:Destroy()
	end
end

local function spawn(
	region: RegionConfig.Region,
	species: string,
	position: Vector3,
	lifetime: number,
	special: boolean
)
	local id = HttpService:GenerateGUID(false)
	local anchor = Instance.new("Configuration")
	anchor.Name = id
	anchor:SetAttribute("Species", species)
	anchor:SetAttribute("Position", position)
	anchor:SetAttribute("Region", region.Id)
	anchor:SetAttribute("Special", special)
	anchor.Parent = folder
	wilds[id] = {
		Id = id,
		Species = species,
		Position = position,
		ExpiresAt = os.clock() + lifetime,
		Region = region.Id,
		Special = special,
		Anchor = anchor,
	}
end

local function pickSpecies(region: RegionConfig.Region): string
	local total = 0
	for _, entry in region.WildTable do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in region.WildTable do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Species
		end
	end
	return region.WildTable[1].Species
end

local function step(region: RegionConfig.Region)
	local now = os.clock()
	local count = 0
	local used: { [Vector3]: boolean } = {}
	local hasSpecial = false
	for id, wild in wilds do
		if wild.ExpiresAt <= now then
			despawn(id)
		elseif wild.Region == region.Id then
			if wild.Special then
				hasSpecial = true
			else
				count += 1
				used[wild.Position] = true
			end
		end
	end
	if count < region.MaxWild then
		local free = {}
		for _, offset in region.WildSpawns do
			local position = region.Center + offset
			if not used[position] then
				table.insert(free, position)
			end
		end
		if #free > 0 then
			spawn(region, pickSpecies(region), free[rng:NextInteger(1, #free)], region.WildLifetime, false)
		end
	end
	-- The eruption's secret visitor.
	local serverTime = Workspace:GetServerTimeNow()
	if RegionConfig.EruptionActive(region, serverTime) and not hasSpecial then
		local remaining = region.Eruption.Duration - serverTime % region.Eruption.Period
		if remaining > 10 then
			spawn(region, region.Eruption.SpawnSpecies, region.Center + region.Eruption.SpawnOffset, remaining, true)
		end
	end
end

local function creatureCount(data: Types.PlayerData): number
	local count = 0
	for _ in data.Creatures do
		count += 1
	end
	return count
end

local function befriend(player: Player, wildId: string): (boolean, any)
	local wild = wilds[wildId]
	if not wild then
		return false, "It's gone."
	end
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not part or (part.Position - wild.Position).Magnitude > BEFRIEND_RANGE then
		return false, "Get closer first."
	end
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	if creatureCount(data) >= BuildingService.CreatureCapacity(data) then
		return false, "Your habitat is full. Upgrade it to make room."
	end
	if not EconomyService.Spend(player, { EmberLure = 1 }, "Befriend") then
		return false, "You need an Ember Lure (craft one at your Trading Post)."
	end
	despawn(wildId) -- whatever happens, it leaves
	local chance = Encounter.BefriendChance(wild.Species, NodeService.CompanionInfo(player))
	local success = rng:NextNumber() < chance
	local species = CreatureConfig.Species[wild.Species]
	Remotes.Events.GameEvent:FireAllClients("WildResult", { Id = wildId, Success = success, Position = wild.Position })
	if success then
		data.Stats.Befriended = (data.Stats.Befriended or 0) + 1
		CreatureService.Grant(player, wild.Species, "Wild", true, { Wild = true })
		Events.Befriended:Fire(player, wild.Species)
		Log.Info("Wild", "Befriended", { user = player.UserId, species = wild.Species, chance = chance })
		return true, { Success = true, Species = wild.Species }
	end
	Remotes.Events.Notify:FireClient(
		player,
		`The {species and species.Name or wild.Species} sniffed the lure and ran off. Try again with another one!`,
		"Info"
	)
	return true, { Success = false, Species = wild.Species }
end

function WildService.Start()
	folder = Instance.new("Folder")
	folder.Name = "WildCreatures"
	folder.Parent = Workspace
	Net.Handle("Befriend", { Rate = { 3, 1 }, Args = { Net.Check.Id } }, befriend)
	task.spawn(function()
		while true do
			for _, regionId in RegionConfig.Order do
				local ok, err = pcall(function()
					step(RegionConfig.Regions[regionId])
					return true
				end)
				if not ok then
					Log.Warn("Wild", "spawn step failed", { error = tostring(err) })
				end
			end
			task.wait(SPAWN_CHECK)
		end
	end)
end

return WildService
