--!strict
-- Gives each player a protected plot, builds the plot's ground and decoration, and turns
-- grid cells into world positions. Visitors can walk onto any plot, but every action that
-- changes a plot is checked against its owner on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local PlotConfig = require(Shared.Config.PlotConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Grid = require(Shared.Util.Grid)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Log = require(Core.Log)
local Parts = require(script.Parent.Parent.World.Parts)
local PlayerDataService = require(script.Parent.PlayerDataService)

export type Plot = {
	Index: number,
	Folder: Folder,
	Origin: CFrame, -- front-left corner on the floor; +Z points away from the plaza
	Owner: Player?,
	Sign: BasePart,
	Spawn: BasePart,
}

local PlotService = {}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}
local plotsFolder: Folder

local WIDTH = PlotConfig.GridX * PlotConfig.CellSize
local DEPTH = PlotConfig.GridZ * PlotConfig.CellSize

local function setSignText(sign: BasePart, text: string)
	for _, surface in sign:GetChildren() do
		local label = surface:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = text
		end
	end
end

local function buildPlot(index: number): Plot
	local angle = (index - 1) / PlotConfig.PlotCount * math.pi * 2
	local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local frontCenter = direction * PlotConfig.RingRadius + Vector3.new(0, PlotConfig.FloorHeight, 0)
	-- LookVector = -direction, so local +Z points away from the plaza.
	local frontCF = CFrame.lookAt(frontCenter, frontCenter - direction)
	local origin = frontCF * CFrame.new(-WIDTH / 2, 0, 0)
	local center = origin * CFrame.new(WIDTH / 2, 0, DEPTH / 2)

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("PlotIndex", index)
	folder:SetAttribute("Origin", origin)
	folder:SetAttribute("OwnerUserId", 0)
	folder:SetAttribute("OwnerName", "")

	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = folder
	for _, name in { "Buildings", "Creatures" } do
		local sub = Instance.new("Folder")
		sub.Name = name
		sub.Parent = folder
	end

	-- Floor (the placement raycast only hits parts named "Floor")
	Parts.Part(ground, {
		Name = "Floor",
		Size = Vector3.new(WIDTH, 1, DEPTH),
		CFrame = center * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(108, 172, 80),
		Material = Enum.Material.Grass,
	})
	-- Stone curb, open at the entrance
	local curb = Color3.fromRGB(170, 164, 155)
	local entranceLeft = 11 * PlotConfig.CellSize
	local entranceRight = 13 * PlotConfig.CellSize
	local function curbPiece(x1: number, z1: number, x2: number, z2: number)
		local size = Vector3.new(math.max(math.abs(x2 - x1), 1), 1, math.max(math.abs(z2 - z1), 1))
		Parts.Part(ground, {
			Size = size,
			CFrame = origin * CFrame.new((x1 + x2) / 2, 0.5, (z1 + z2) / 2),
			Color = curb,
			Material = Enum.Material.Cobblestone,
		})
	end
	curbPiece(0, 0, entranceLeft, 0)
	curbPiece(entranceRight, 0, WIDTH, 0)
	curbPiece(0, DEPTH, WIDTH, DEPTH)
	curbPiece(0, 0, 0, DEPTH)
	curbPiece(WIDTH, 0, WIDTH, DEPTH)

	-- Path from the entrance to the Empire Core (the reserved cells)
	for _, area in PlotConfig.ReservedCells do
		local x1, z1 = area.X1 * PlotConfig.CellSize, area.Z1 * PlotConfig.CellSize
		local x2, z2 = (area.X2 + 1) * PlotConfig.CellSize, (area.Z2 + 1) * PlotConfig.CellSize
		Parts.Part(ground, {
			Name = "Path",
			Size = Vector3.new(x2 - x1, 0.2, z2 - z1),
			CFrame = origin * CFrame.new((x1 + x2) / 2, 0.1, (z1 + z2) / 2),
			Color = Color3.fromRGB(200, 178, 135),
			Material = Enum.Material.Pavement,
			CanQuery = false,
		})
	end

	-- Entrance arch with the owner's name
	local archCF = origin * CFrame.new(WIDTH / 2, 0, -1)
	for _, x in { -5.5, 5.5 } do
		Parts.Part(ground, {
			Size = Vector3.new(1.4, 10, 1.4),
			CFrame = archCF * CFrame.new(x, 5, 0),
			Color = Color3.fromRGB(120, 86, 56),
			Material = Enum.Material.Wood,
		})
	end
	local sign = Parts.Sign(ground, archCF * CFrame.new(0, 5.6, 0), "Unclaimed plot", 12)

	-- Expansion zones: overgrown, roped off, labelled (Phase 2 unlocks them).
	local depthStuds = 4 * PlotConfig.CellSize
	for _, zone in PlotConfig.ExpansionZones do
		local cf, size
		if zone.Side == "Left" then
			cf = origin * CFrame.new(-depthStuds / 2 - 1, 0, DEPTH / 2)
			size = Vector3.new(depthStuds, 0.4, DEPTH)
		elseif zone.Side == "Right" then
			cf = origin * CFrame.new(WIDTH + depthStuds / 2 + 1, 0, DEPTH / 2)
			size = Vector3.new(depthStuds, 0.4, DEPTH)
		else
			cf = origin * CFrame.new(WIDTH / 2, 0, DEPTH + depthStuds / 2 + 1)
			size = Vector3.new(WIDTH, 0.4, depthStuds)
		end
		Parts.Part(ground, {
			Name = "Expansion",
			Size = size,
			CFrame = cf * CFrame.new(0, -0.2, 0),
			Color = Color3.fromRGB(78, 120, 60),
			Material = Enum.Material.LeafyGrass,
			CanQuery = false,
		})
		local rng = Random.new(index * 100 + #zone.Name)
		for _ = 1, 6 do
			local offset = Vector3.new(rng:NextNumber(-0.4, 0.4) * size.X, 0, rng:NextNumber(-0.4, 0.4) * size.Z)
			Parts.Ball(ground, (cf * CFrame.new(offset + Vector3.new(0, 1, 0))).Position, rng:NextNumber(2.5, 4), {
				Color = Color3.fromRGB(60, 110, 50),
				Material = Enum.Material.Grass,
			})
		end
		Parts.Sign(ground, cf * CFrame.new(0, 0, 0), zone.Name .. " · expansion (coming soon)", 10)
	end

	-- Where the owner appears (just inside the entrance, facing the Empire Core).
	local spawn = Instance.new("Part")
	spawn.Name = "PlotSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = origin * CFrame.new(WIDTH / 2, 0.1, 6) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Parent = ground

	folder.Parent = plotsFolder
	return { Index = index, Folder = folder, Origin = origin, Owner = nil, Sign = sign, Spawn = spawn }
end

local function clearPlot(plot: Plot)
	for _, name in { "Buildings", "Creatures" } do
		local sub = plot.Folder:FindFirstChild(name)
		if sub then
			sub:ClearAllChildren()
		end
	end
	plot.Owner = nil
	plot.Folder:SetAttribute("OwnerUserId", 0)
	plot.Folder:SetAttribute("OwnerName", "")
	setSignText(plot.Sign, "Unclaimed plot")
end

-- Public -----------------------------------------------------------------------------------

function PlotService.Get(player: Player): Plot?
	return byPlayer[player]
end

-- World CFrame of a footprint centre (on the floor) for a building placement.
function PlotService.BuildingCFrame(plot: Plot, typeId: string, x: number, z: number, rot: number): CFrame
	local def = BuildingConfig[typeId]
	local localCenter = Grid.LocalCenter(def.Footprint, x, z, rot)
	return plot.Origin * CFrame.new(localCenter) * CFrame.Angles(0, -rot * math.pi / 2, 0)
end

-- Distance check for actions that need the player near something on their plot.
function PlotService.IsNear(player: Player, position: Vector3, range: number?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return (root.Position - position).Magnitude <= (range or PlotConfig.InteractRange)
end

-- Fires after a plot has been claimed and its folders are ready.
local claimedCallbacks: { (Player, Plot) -> () } = {}
function PlotService.OnClaimed(callback: (Player, Plot) -> ())
	table.insert(claimedCallbacks, callback)
end

-- Puts the player's character at their plot entrance.
function PlotService.SendHome(player: Player)
	local plot = byPlayer[player]
	local character = player.Character
	if plot and character then
		character:PivotTo(plot.Spawn.CFrame * CFrame.new(0, 4, 0))
	end
end

local function claim(player: Player)
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			byPlayer[player] = plot
			plot.Folder:SetAttribute("OwnerUserId", player.UserId)
			plot.Folder:SetAttribute("OwnerName", player.DisplayName)
			setSignText(plot.Sign, player.DisplayName .. "'s Empire")
			Log.Info("Plot", "Claimed", { user = player.UserId, plot = plot.Index })
			for _, callback in claimedCallbacks do
				task.spawn(callback, player, plot)
			end
			PlotService.SendHome(player)
			return
		end
	end
	Log.Warn("Plot", "No free plot", { user = player.UserId })
	player:Kick("This server is full. Please join another server.")
end

-- Read-only summary of someone's empire, for visitors.
local function inspect(_viewer: Player, ownerUserId: number): (boolean, any)
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local data = owner and PlayerDataService.GetData(owner)
	if not owner or not data then
		return false, "That empire isn't here right now."
	end
	local core = data.Buildings.core
	local creatures = {}
	for _, creature in data.Creatures do
		local species = CreatureConfig.Species[creature.Species]
		table.insert(creatures, {
			Species = creature.Species,
			Name = creature.Nickname or (species and species.Name or creature.Species),
			Level = creature.Level,
			Rarity = species and species.Rarity or "Common",
		})
	end
	local buildings = 0
	for _, b in data.Buildings do
		local def = BuildingConfig[b.Type]
		if def and def.Placeable then
			buildings += 1
		end
	end
	return true,
		{
			Name = owner.DisplayName,
			CoreTier = core and core.Level or 1,
			Creatures = creatures,
			PlacedBuildings = buildings,
			Discovered = #(function()
				local list = {}
				for id in data.Collection do
					table.insert(list, id)
				end
				return list
			end)(),
		}
end

function PlotService.Start()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "PlayerPlots"
	plotsFolder.Parent = Workspace
	for index = 1, PlotConfig.PlotCount do
		table.insert(plots, buildPlot(index))
	end

	PlayerDataService.Loaded:Connect(function(player)
		claim(player)
	end)
	-- Every respawn happens at home (the plaza spawn is only used before a plot exists).
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			task.wait() -- let the default spawn finish first
			PlotService.SendHome(player)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local plot = byPlayer[player]
		if plot then
			byPlayer[player] = nil
			-- Let the final save finish using plot data first.
			task.defer(clearPlot, plot)
		end
	end)

	Net.Handle("InspectPlot", { Rate = { 4, 1 }, Args = { Net.Check.Integer } }, inspect)
end

return PlotService
