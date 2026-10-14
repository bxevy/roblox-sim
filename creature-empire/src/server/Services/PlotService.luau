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
local CustomModels = require(script.Parent.Parent.World.CustomModels)
local CUSTOM_FENCE_HEIGHT = 4.5 -- studs: hand-made fence sections are scaled to this height
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

local buildBounds: (Plot, { [string]: boolean }) -> ()
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

	local bounds = Instance.new("Folder")
	bounds.Name = "Bounds"
	bounds.Parent = folder

	folder.Parent = plotsFolder
	local plot: Plot = { Index = index, Folder = folder, Origin = origin, Owner = nil, Sign = sign, Spawn = spawn }
	buildBounds(plot, {})
	return plot
end

-- The plot's edge: expansion zones (owned = more lawn, otherwise overgrown with a sign),
-- then a stone curb and a wooden fence around the whole buildable area, open at the
-- entrance. Rebuilt when the owner changes or buys an expansion.
local FENCE_HEIGHT = 4
local POST_SPACING = 6
local POST_COLOR = Color3.fromRGB(110, 78, 50)
local RAIL_COLOR = Color3.fromRGB(150, 110, 72)
local CURB_COLOR = Color3.fromRGB(170, 164, 155)
local LAWN_COLOR = Color3.fromRGB(108, 172, 80)

buildBounds = function(plot: Plot, expansions: { [string]: boolean })
	local folder = plot.Folder:FindFirstChild("Bounds") :: Folder
	folder:ClearAllChildren()
	local origin = plot.Origin
	local cell = PlotConfig.CellSize

	for _, zone in PlotConfig.ExpansionZones do
		local r = zone.Rect
		local x1, z1 = r.X1 * cell, r.Z1 * cell
		local x2, z2 = (r.X2 + 1) * cell, (r.Z2 + 1) * cell
		local size = Vector3.new(x2 - x1, 1, z2 - z1)
		local cf = origin * CFrame.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
		if expansions[zone.Id] then
			Parts.Part(folder, {
				Name = "ExpansionFloor",
				Size = size,
				CFrame = cf * CFrame.new(0, -0.5, 0),
				Color = LAWN_COLOR,
				Material = Enum.Material.Grass,
			})
		else
			Parts.Part(folder, {
				Name = "Overgrowth",
				Size = Vector3.new(size.X, 0.4, size.Z),
				CFrame = cf * CFrame.new(0, -0.2, 0),
				Color = Color3.fromRGB(78, 120, 60),
				Material = Enum.Material.LeafyGrass,
				CanQuery = false,
			})
			local rng = Random.new(plot.Index * 100 + #zone.Name)
			for _ = 1, 6 do
				local offset = Vector3.new(rng:NextNumber(-0.4, 0.4) * size.X, 1, rng:NextNumber(-0.4, 0.4) * size.Z)
				Parts.Ball(folder, (cf * CFrame.new(offset)).Position, rng:NextNumber(2.5, 4), {
					Color = Color3.fromRGB(60, 110, 50),
					Material = Enum.Material.Grass,
				})
			end
			Parts.Sign(folder, cf, `{zone.Name} · expand at your Empire Core (tier {zone.CoreTier})`, 12)
		end
	end

	-- Outer rectangle of the buildable area.
	local minX = if expansions.West then -4 * cell else 0
	local maxX = WIDTH + (if expansions.East then 4 * cell else 0)
	local maxZ = DEPTH + (if expansions.North then 4 * cell else 0)
	local entranceLeft = 11 * cell
	local entranceRight = 13 * cell

	local function edge(x1: number, z1: number, x2: number, z2: number)
		local from = Vector3.new(x1, 0, z1)
		local to = Vector3.new(x2, 0, z2)
		local length = (to - from).Magnitude
		if length < 1 then
			return
		end
		local direction = (to - from).Unit
		local mid = (from + to) / 2
		local facing = CFrame.lookAt(Vector3.zero, direction).Rotation
		-- A hand-made FenceSegment (built along its X axis) replaces the curb, posts and
		-- rails: copies are laid end to end, stretched slightly so they fill the edge.
		local segment = CustomModels.Find("World", "FenceSegment")
		if segment then
			local _, size = CustomModels.Bounds(segment)
			local turned = math.abs(math.cos(math.rad((segment:GetAttribute("Facing") :: number?) or 0))) < 0.5
			-- Imported models come in at any size: scale to a normal fence height first
			-- (unless KeepSize), then work out how many sections fill the edge.
			local baseScale = if segment:GetAttribute("KeepSize") == true or size.Y <= 0
				then 1
				else CUSTOM_FENCE_HEIGHT / size.Y
			local segLength = math.max((if turned then size.Z else size.X) * baseScale, 0.5)
			local count = math.max(math.floor(length / segLength + 0.5), 1)
			local along = CFrame.fromMatrix(Vector3.zero, direction, Vector3.yAxis)
			for i = 0, count - 1 do
				local p = from + direction * (length * (i + 0.5) / count)
				CustomModels.Place(segment, folder, origin * CFrame.new(p.X, 0, p.Z) * along, {
					Scale = baseScale * (length / count) / segLength,
				})
			end
			return
		end
		Parts.Part(folder, {
			Name = "Curb",
			Size = Vector3.new(1, 1, length + 1),
			CFrame = origin * CFrame.new(mid.X, 0.5, mid.Z) * facing,
			Color = CURB_COLOR,
			Material = Enum.Material.Cobblestone,
		})
		local posts = math.max(math.floor(length / POST_SPACING), 1)
		for i = 0, posts do
			local p = from + direction * (length * i / posts)
			Parts.Part(folder, {
				Name = "FencePost",
				Size = Vector3.new(0.8, FENCE_HEIGHT + 0.6, 0.8),
				CFrame = origin * CFrame.new(p.X, 1 + (FENCE_HEIGHT + 0.6) / 2, p.Z),
				Color = POST_COLOR,
				Material = Enum.Material.Wood,
			})
		end
		for _, height in { 1.6, 3.4 } do
			Parts.Part(folder, {
				Name = "FenceRail",
				Size = Vector3.new(0.35, 0.5, length),
				CFrame = origin * CFrame.new(mid.X, 1 + height, mid.Z) * facing,
				Color = RAIL_COLOR,
				Material = Enum.Material.WoodPlanks,
			})
		end
	end
	edge(minX, 0, entranceLeft, 0)
	edge(entranceRight, 0, maxX, 0)
	edge(maxX, 0, maxX, maxZ)
	edge(maxX, maxZ, minX, maxZ)
	edge(minX, maxZ, minX, 0)
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
	buildBounds(plot, {})
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

-- Redraws the owner's sign (Supporters get a golden star).
function PlotService.RefreshSign(player: Player)
	local plot = byPlayer[player]
	if plot then
		local star = if player:GetAttribute("Supporter") == true then "★ " else ""
		setSignText(plot.Sign, star .. player.DisplayName .. "'s Empire")
	end
end

-- Fires after a plot has been claimed and its folders are ready.
local claimedCallbacks: { (Player, Plot) -> () } = {}
function PlotService.OnClaimed(callback: (Player, Plot) -> ())
	table.insert(claimedCallbacks, callback)
end

-- Redraws a player's plot edge after they buy an expansion.
function PlotService.RefreshBounds(player: Player)
	local plot = byPlayer[player]
	local data = PlayerDataService.GetData(player)
	if plot and data then
		buildBounds(plot, data.Expansions)
	end
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
			PlotService.RefreshBounds(player)
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
