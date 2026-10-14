--!strict
-- Builds Verdant Reach: terrain, the central plaza with the Founders' Crystal, paths to
-- every plot, trees, rocks and wild moonpetals, plus lighting and the day/night cycle.
-- All geometry is code-built and anchored; nothing here simulates physics.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local Parts = require(script.Parent.Parts)
local CustomModels = require(script.Parent.CustomModels)

local WorldBuilder = {}

local GROUND = Color3.fromRGB(96, 160, 72)
local PATH = Color3.fromRGB(196, 172, 128)
local STONE = Color3.fromRGB(160, 156, 150)

local rng = Random.new(20261013) -- fixed seed: same world every server

-- A hand-made Assets/World/<name> model at `position` (random turn, scaled), if one exists.
-- With `height`, the model is first sized to that many studs tall (unless it has KeepSize).
local function customPiece(
	name: string,
	parent: Instance,
	position: Vector3,
	scale: number,
	turn: boolean,
	height: number?
): boolean
	local template = CustomModels.Find("World", name)
	if not template then
		return false
	end
	local yaw = if turn then rng:NextNumber(0, math.pi * 2) else 0
	CustomModels.Place(template, parent, CFrame.new(position) * CFrame.Angles(0, yaw, 0), {
		Scale = scale,
		Fit = if height then Vector3.new(math.huge, height, math.huge) else nil,
	})
	return true
end

local TREE_HEIGHT = 13 -- studs at scale 1: imported trees are sized like the built-in ones

local function tree(parent: Instance, position: Vector3, scale: number)
	if customPiece("Tree", parent, position, scale, true, TREE_HEIGHT) then
		return
	end
	local trunkHeight = 7 * scale
	Parts.Cylinder(parent, CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)), trunkHeight, 1.4 * scale, {
		Color = Color3.fromRGB(110, 78, 52),
		Material = Enum.Material.Wood,
	})
	local leafColor = Color3.fromRGB(70 + rng:NextInteger(-10, 20), 145 + rng:NextInteger(-15, 25), 65)
	for i = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(0, 2.4), rng:NextNumber(-1.8, 1.8)) * scale
		Parts.Ball(parent, position + Vector3.new(0, trunkHeight + 1, 0) + offset, (5 - i * 0.4) * scale, {
			Color = leafColor,
			Material = Enum.Material.Grass,
		})
	end
end

local function rock(parent: Instance, position: Vector3, scale: number)
	if customPiece("Rock", parent, position, scale, true) then
		return
	end
	Parts.Part(parent, {
		Size = Vector3.new(3, 2, 2.6) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 0.6 * scale, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(130, 128, 125),
		Material = Enum.Material.Rock,
	})
end

local function wildPetal(parent: Instance, position: Vector3)
	Parts.Decor(parent, {
		Size = Vector3.new(0.2, 1.2, 0.2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)),
		Color = Color3.fromRGB(80, 150, 70),
		Material = Enum.Material.Grass,
	})
	Parts.Ball(parent, position + Vector3.new(0, 1.4, 0), 0.7, {
		Color = Color3.fromRGB(160, 210, 255),
		Material = Enum.Material.Neon,
	})
end

local LAMP_HEIGHT = 11 -- studs: imported lamps are scaled to this unless they have KeepSize

-- `facing` is the flat direction the lamp's front points (toward the walkway it lights).
local function lamp(parent: Instance, position: Vector3, facing: Vector3)
	local template = CustomModels.Find("World", "Lamp")
	if template then
		local look = Vector3.new(facing.X, 0, facing.Z).Unit
		local model = CustomModels.Place(template, parent, CFrame.lookAt(position, position + look), {
			Fit = Vector3.new(math.huge, LAMP_HEIGHT, math.huge),
		})
		-- Imported meshes carry no light, so add a glow at the front (where the glowing
		-- mushrooms are) to keep paths lit at night.
		local center, size = CustomModels.Bounds(model)
		local depth = math.abs(look.X) * size.X + math.abs(look.Z) * size.Z
		local glow = Parts.Decor(model, {
			Name = "LampGlow",
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(center + look * (depth * 0.4) + Vector3.new(0, size.Y * 0.2, 0)),
			Transparency = 1,
			CastShadow = false,
		})
		Parts.Light(glow, Color3.fromRGB(255, 215, 150), 16, 1)
		return
	end
	Parts.Cylinder(parent, CFrame.new(position + Vector3.new(0, 3.5, 0)), 7, 0.5, {
		Color = Color3.fromRGB(60, 58, 64),
		Material = Enum.Material.Metal,
	})
	local bulb = Parts.Ball(parent, position + Vector3.new(0, 7.4, 0), 1.2, {
		Color = Color3.fromRGB(255, 225, 160),
		Material = Enum.Material.Neon,
	})
	Parts.Light(bulb, Color3.fromRGB(255, 215, 150), 16, 1)
end

local PLAY_AREA = 640 -- studs: the flat part-built ground around the plaza and plots

local function buildTerrain()
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1100, 12, 1100), Enum.Material.Grass)
	-- Terrain is stored in 4-stud voxels, so its surface can show up above y = 0 and cover
	-- the plot floors (0.5). The play area is a flat Part instead (exact height), and the
	-- terrain under it is removed; terrain stays for the meadows and hills around it.
	terrain:FillBlock(CFrame.new(0, -9, 0), Vector3.new(PLAY_AREA, 22, PLAY_AREA), Enum.Material.Air)
	local ground = Parts.Part(Workspace, {
		Name = "Ground",
		Size = Vector3.new(PLAY_AREA, 4, PLAY_AREA),
		CFrame = CFrame.new(0, -2, 0),
		Color = GROUND,
		Material = Enum.Material.Grass,
	})
	ground.CastShadow = false
	terrain:SetMaterialColor(Enum.Material.Grass, GROUND)
	-- No animated grass: its blades grow taller than the plot floors and paths, which made
	-- every building, fence and creature look sunk into the ground.
	pcall(function()
		terrain.Decoration = false
	end)
	-- A ring of gentle hills around the edge of the world.
	for i = 1, 28 do
		local angle = i / 28 * math.pi * 2
		local radius = rng:NextNumber(390, 450)
		local size = rng:NextNumber(50, 90)
		terrain:FillBall(
			Vector3.new(math.cos(angle) * radius, -size * 0.45, math.sin(angle) * radius),
			size,
			Enum.Material.Grass
		)
	end
end

local function buildPlaza(folder: Folder)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = folder

	Parts.Cylinder(plaza, CFrame.new(0, 0.25, 0), 0.5, 70, { Color = STONE, Material = Enum.Material.Cobblestone })
	Parts.Cylinder(
		plaza,
		CFrame.new(0, 0.3, 0),
		0.5,
		66,
		{ Color = Color3.fromRGB(176, 170, 160), Material = Enum.Material.Slate }
	)
	-- Founders' Crystal monument
	Parts.Cylinder(plaza, CFrame.new(0, 1.5, 0), 2, 16, { Color = STONE, Material = Enum.Material.Marble })
	Parts.Cylinder(
		plaza,
		CFrame.new(0, 3, 0),
		1,
		11,
		{ Color = Color3.fromRGB(200, 196, 188), Material = Enum.Material.Marble }
	)
	local crystal = Parts.Decor(plaza, {
		Name = "FoundersCrystal",
		Size = Vector3.new(4, 12, 4),
		CFrame = CFrame.new(0, 11, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = Color3.fromRGB(140, 230, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.05,
	})
	crystal:SetAttribute("BobHeight", 1)
	CollectionService:AddTag(crystal, "CE_Bob")
	Parts.Light(crystal, Color3.fromRGB(140, 230, 255), 30, 1.5)
	Parts.Label(crystal, "CREATURE EMPIRE", {
		Size = UDim2.fromScale(22, 4),
		Offset = Vector3.new(0, 10, 0),
		MaxDistance = 200,
		Color = Color3.fromRGB(220, 250, 255),
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 22)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = plaza
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * math.pi * 2
		local spot = Vector3.new(math.sin(angle) * 31, 0.5, math.cos(angle) * 31)
		lamp(plaza, spot, -spot) -- face the Founders' Crystal
	end

	-- Benches and flower beds
	for i = 0, 3 do
		local angle = i / 4 * math.pi * 2 + math.pi / 8
		local cf = CFrame.new(Vector3.new(math.sin(angle) * 22, 0.5, math.cos(angle) * 22)) * CFrame.Angles(0, angle, 0)
		Parts.Part(plaza, {
			Size = Vector3.new(6, 0.5, 1.8),
			CFrame = cf * CFrame.new(0, 1.4, 0),
			Color = Color3.fromRGB(130, 92, 60),
			Material = Enum.Material.WoodPlanks,
		})
		Parts.Part(plaza, {
			Size = Vector3.new(6, 1.4, 0.4),
			CFrame = cf * CFrame.new(0, 2.2, 0.8),
			Color = Color3.fromRGB(130, 92, 60),
			Material = Enum.Material.WoodPlanks,
		})
		for _, x in { -2.5, 2.5 } do
			Parts.Part(plaza, {
				Size = Vector3.new(0.4, 1.2, 1.6),
				CFrame = cf * CFrame.new(x, 0.7, 0),
				Color = Color3.fromRGB(60, 58, 64),
				Material = Enum.Material.Metal,
			})
		end
	end
	for i = 1, 24 do
		local angle = i / 24 * math.pi * 2
		wildPetal(plaza, Vector3.new(math.sin(angle) * 9, 3.4, math.cos(angle) * 9))
	end
end

local function buildPaths(folder: Folder)
	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = folder
	for i = 0, PlotConfig.PlotCount - 1 do
		local angle = i / PlotConfig.PlotCount * math.pi * 2
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local from, to = 34, PlotConfig.RingRadius
		local length = to - from
		local mid = direction * (from + length / 2)
		Parts.Part(paths, {
			Size = Vector3.new(8, 0.3, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), mid + direction + Vector3.new(0, 0.15, 0)),
			Color = PATH,
			Material = Enum.Material.Pavement,
		})
		local side = Vector3.new(-direction.Z, 0, direction.X)
		-- Centred on the path edge (it is 8 studs wide): the front, with the glowing
		-- mushrooms, leans out over the path.
		lamp(paths, direction * (from + length * 0.6) + side * 4, -side)
	end
end

local function buildScenery(folder: Folder)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = folder
	-- Trees between plots and around the outside.
	for i = 0, PlotConfig.PlotCount - 1 do
		local angle = (i + 0.5) / PlotConfig.PlotCount * math.pi * 2
		for _, radius in { 70, 105, 135, 175, 215, 255 } do
			local jitter = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
			tree(
				scenery,
				Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius) + jitter,
				rng:NextNumber(0.9, 1.4)
			)
		end
		rock(scenery, Vector3.new(math.sin(angle) * 55, 0, math.cos(angle) * 55), rng:NextNumber(0.8, 1.6))
		for _ = 1, 4 do
			local r = rng:NextNumber(45, 90)
			local a = angle + rng:NextNumber(-0.1, 0.1)
			wildPetal(scenery, Vector3.new(math.sin(a) * r, 0, math.cos(a) * r))
		end
	end
	for i = 1, 40 do
		local angle = i / 40 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(300, 350)
		tree(scenery, Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius), rng:NextNumber(1.2, 1.9))
	end
end

local function setupLighting()
	Lighting.ClockTime = 15
	Lighting.GeographicLatitude = 35
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 225, 245)
	atmosphere.Decay = Color3.fromRGB(110, 140, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local colour = Instance.new("ColorCorrectionEffect")
	colour.Name = "CE_Grade" -- the client's region mood looks it up by name
	colour.Saturation = 0.12
	colour.Contrast = 0.06
	colour.TintColor = Color3.fromRGB(255, 250, 244)
	colour.Parent = Lighting
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.04
	sunRays.Spread = 0.7
	sunRays.Parent = Lighting
end

-- Verdant Reach's mechanic: a day/night cycle. One full day lasts DayLength seconds;
-- moonpetals (neon) stand out at night.
local DAY_LENGTH = 16 * 60
local function runDayNight()
	task.spawn(function()
		local step = 0.5
		while true do
			task.wait(step)
			Lighting.ClockTime = (Lighting.ClockTime + 24 * step / DAY_LENGTH) % 24
		end
	end)
end

function WorldBuilder.Build()
	local folder = Instance.new("Folder")
	folder.Name = "WorldRegions"
	folder.Parent = Workspace
	local region = Instance.new("Folder")
	region.Name = "VerdantReach"
	region.Parent = folder

	buildTerrain()
	buildPlaza(region)
	buildPaths(region)
	buildScenery(region)
	setupLighting()
	runDayNight()
end

return WorldBuilder
