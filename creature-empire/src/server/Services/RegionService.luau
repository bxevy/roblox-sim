--!strict
-- Travel between the empire and explorable regions, and everything that happens while a
-- player is in one: heat (Shared/Util/Encounter.HeatRate), vents, eruptions, rescue at
-- full heat, and landmark discovery with rewards.
--
-- Heat lives on the server and is published as the player's "Heat" attribute; region
-- membership as "Region". Vents and eruptions follow the shared server clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local RegionConfig = require(Shared.Config.RegionConfig)
local PlazaConfig = require(Shared.Config.PlazaConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local GameConfig = require(Shared.Config.GameConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Encounter = require(Shared.Util.Encounter)
local Research = require(Shared.Util.Research)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)

local TICK = 0.5
local TRAVEL_COOLDOWN = 4

type Runtime = {
	Region: string?,
	Heat: number,
	VentHit: { [number]: number },
	LastTravel: number,
	ProtectedUntil: number, -- os.clock: no heat builds (Rootwall, Veil)
}

local RegionService = {}

local runtimes: { [Player]: Runtime } = {}

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function coreTier(player: Player): number
	local data = PlayerDataService.GetData(player)
	local core = data and data.Buildings.core
	return if core then core.Level else 1
end

function RegionService.RegionOf(player: Player): string?
	local runtime = runtimes[player]
	return runtime and runtime.Region
end

-- The companion's family, for heat resistance and bonuses.
function RegionService.CompanionFamily(player: Player): string?
	local data = PlayerDataService.GetData(player)
	local companion = data and data.Companion and data.Creatures[data.Companion]
	local species = companion and CreatureConfig.Species[companion.Species]
	return species and species.Family
end

local function setHeat(player: Player, runtime: Runtime, heat: number)
	runtime.Heat = math.clamp(heat, 0, 100)
	player:SetAttribute("Heat", math.floor(runtime.Heat + 0.5))
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	end
end

local function travel(player: Player, destination: string): (boolean, any)
	local runtime = runtimes[player]
	if not runtime then
		return false, "Not ready."
	end
	if os.clock() - runtime.LastTravel < TRAVEL_COOLDOWN then
		return false, "Catch your breath first."
	end
	if destination == "Home" then
		runtime.LastTravel = os.clock()
		PlotService.SendHome(player)
		return true, nil
	end
	if destination == "Shop" then
		-- The plaza, just in front of the Trading Post, facing it.
		runtime.LastTravel = os.clock()
		local shop = PlazaConfig.Position("TradingPost")
		local spot = shop - Vector3.new(shop.X, 0, shop.Z).Unit * 10
		local character = player.Character
		if character then
			character:PivotTo(CFrame.lookAt(spot + Vector3.new(0, 3, 0), Vector3.new(shop.X, spot.Y + 3, shop.Z)))
		end
		return true, nil
	end
	local region = RegionConfig.Regions[destination]
	if not region or region.Phase > GameConfig.Phase then
		return false, "That region isn't open yet."
	end
	if coreTier(player) < region.CoreTier then
		return false, `Reach Empire Core tier {region.CoreTier} to travel there.`
	end
	runtime.LastTravel = os.clock()
	teleport(player, region.Center + region.ArrivalOffset)
	return true, nil
end

local function discover(player: Player, region: RegionConfig.Region, landmark: RegionConfig.Landmark)
	local data = PlayerDataService.GetData(player)
	if not data or data.Discoveries[landmark.Id] then
		return
	end
	data.Discoveries[landmark.Id] = os.time()
	PlayerDataService.MarkDirty(player)
	local parts = {}
	for id, amount in landmark.Reward do
		EconomyService.Add(player, id, amount, "Discovery")
		local def = ResourceConfig[id]
		table.insert(parts, `{Format.Number(amount)} {def and def.Name or id}`)
	end
	Remotes.Events.GameEvent:FireClient(
		player,
		"Discovered",
		{ Id = landmark.Id, Name = landmark.Name, Hidden = landmark.Hidden }
	)
	Remotes.Events.Notify:FireClient(
		player,
		(if landmark.Hidden then "Secret found: " else "Discovered: ")
			.. landmark.Name
			.. " · +"
			.. table.concat(parts, ", "),
		"Reward"
	)
	Events.Discovered:Fire(player, landmark.Id)
	StateService.Push(player, "Exploration")
	Log.Info("Region", "Discovered", { user = player.UserId, region = region.Id, landmark = landmark.Id })
end

-- Share of heat build-up prevented by research (Heat Wards).
local function wardOf(player: Player): number
	local data = PlayerDataService.GetData(player)
	return if data then Research.Total(data, "Heat") else 0
end

local function tickPlayer(player: Player, runtime: Runtime, now: number)
	local part = root(player)
	if not part then
		return
	end
	local region = RegionConfig.At(part.Position)
	local regionId = region and region.Id
	if regionId ~= runtime.Region then
		runtime.Region = regionId
		player:SetAttribute("Region", regionId or "")
		if region then
			Events.RegionEntered:Fire(player, region.Id)
			Remotes.Events.Notify:FireClient(player, `Welcome to {region.Name}. Mind the heat!`, "Info")
		end
	end
	if not region then
		if runtime.Heat > 0 then
			setHeat(player, runtime, runtime.Heat - 10 * TICK)
		end
		return
	end

	local offset = part.Position - region.Center
	local eruption = RegionConfig.EruptionActive(region, now)
	local rate = Encounter.HeatRate(region, {
		Offset = offset,
		CompanionFamily = RegionService.CompanionFamily(player),
		Eruption = eruption,
		OnBridge = offset.Y > 4.3,
		Ward = wardOf(player),
	})
	local protected = os.clock() < runtime.ProtectedUntil
	if protected then
		rate = math.min(rate, 0)
	end
	local heat = runtime.Heat + rate * TICK
	for index, vent in region.Vents do
		if RegionConfig.VentPhase(region, index, now) == "Active" then
			local flat = Vector3.new(offset.X - vent.X, 0, offset.Z - vent.Z)
			-- One burst per eruption of the vent.
			if
				flat.Magnitude <= region.VentCycle.Radius
				and now - (runtime.VentHit[index] or 0) > region.VentCycle.Active
				and not protected
			then
				runtime.VentHit[index] = now
				heat += region.Heat.VentBurst
				Remotes.Events.GameEvent:FireClient(player, "Scorched", { Amount = region.Heat.VentBurst })
			end
		end
	end
	setHeat(player, runtime, heat)
	if runtime.Heat >= region.Heat.Max then
		-- Too hot: friendly creatures carry you back to the gate. No progress is lost.
		teleport(player, region.Center + region.ArrivalOffset)
		setHeat(player, runtime, region.Heat.AfterRescue)
		Remotes.Events.Notify:FireClient(
			player,
			"Too hot! Your creatures carried you back to the gate. Cool off in the blue pools next time.",
			"Error"
		)
	end

	for _, landmark in region.Landmarks do
		local flat = Vector3.new(offset.X - landmark.Offset.X, 0, offset.Z - landmark.Offset.Z)
		if flat.Magnitude <= landmark.Radius and offset.Y >= (landmark.MinHeight or -math.huge) then
			discover(player, region, landmark)
		end
	end
end

function RegionService.Start()
	StateService.Register("Exploration", function(_player, profile)
		local data = profile.Data
		return {
			Discoveries = table.clone(data.Discoveries),
			Guardians = table.clone(data.Guardians),
			Companion = data.Companion,
			Team = table.clone(data.Team),
		}
	end)

	PlayerDataService.Loaded:Connect(function(player)
		runtimes[player] = { Region = nil, Heat = 0, VentHit = {}, LastTravel = 0, ProtectedUntil = 0 }
		player:SetAttribute("Heat", 0)
		player:SetAttribute("Region", "")
	end)
	Players.PlayerRemoving:Connect(function(player)
		runtimes[player] = nil
	end)

	Net.Handle("Travel", { Rate = { 3, 0.5 }, Args = { Net.Check.Id } }, travel)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = Workspace:GetServerTimeNow()
			for player, runtime in runtimes do
				local ok, err = pcall(function()
					tickPlayer(player, runtime, now)
					return true
				end)
				if not ok then
					Log.Warn("Region", "tick failed", { user = player.UserId, error = tostring(err) })
				end
			end
		end
	end)
end

-- Adds or removes heat (guardian slams, support cooling).
-- Elderbark's Rootwall: no heat for you and allies within 30 studs.
local function rootwall(player: Player, _creature: any, _power: number, duration: number): (boolean, string)
	local me = root(player)
	local runtime = runtimes[player]
	if not me or not runtime or not runtime.Region then
		return false, "Use Rootwall in a hot region, like Emberfall Basin."
	end
	local count = 0
	for other, otherRuntime in runtimes do
		local part = root(other)
		if part and (part.Position - me.Position).Magnitude <= 30 then
			otherRuntime.ProtectedUntil = math.max(otherRuntime.ProtectedUntil, os.clock() + duration)
			count += 1
			if other ~= player then
				Remotes.Events.Notify:FireClient(
					other,
					`{player.DisplayName}'s Rootwall shields you from heat for {math.floor(duration)}s!`,
					"Success"
				)
			end
		end
	end
	return true,
		`Rootwall! {count} {if count == 1 then "explorer is" else "explorers are"} shielded from heat for {math.floor(
			duration
		)}s.`
end

-- Shadeling's Veil: heat doesn't build for you.
local function veil(player: Player, _creature: any, _power: number, duration: number): (boolean, string)
	local runtime = runtimes[player]
	if not runtime or not runtime.Region then
		return false, "Use Veil in a hot region, like Emberfall Basin."
	end
	runtime.ProtectedUntil = math.max(runtime.ProtectedUntil, os.clock() + duration)
	return true, `Veil! Heat can't touch you for {math.floor(duration)}s.`
end

function RegionService.AddHeat(player: Player, amount: number)
	local runtime = runtimes[player]
	if runtime and amount > 0 and os.clock() < runtime.ProtectedUntil then
		return -- shielded
	end
	if runtime then
		setHeat(player, runtime, runtime.Heat + amount)
	end
end

CreatureService.AbilityHandlers.Shield = rootwall
CreatureService.AbilityHandlers.Stealth = veil

return RegionService
