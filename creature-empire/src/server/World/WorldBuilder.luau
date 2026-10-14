--!strict
-- Builds Verdant Reach: terrain, the central plaza with the Founders' Crystal, paths to
-- every plot, trees, rocks and wild moonpetals, plus lighting and the day/night cycle.
-- All geometry is code-built and anchored; nothing here simulates physics.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local PlazaConfig = require(ReplicatedStorage.Shared.Config.PlazaConfig)
local SpinConfig = require(ReplicatedStorage.Shared.Config.SpinConfig)
local BuildingModels = require(script.Parent.BuildingModels)
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

-- The Spin Wheel: a stone plinth, two posts and a big prize wheel facing the crystal. The
-- wheel itself is its own model so the client can turn it slowly (CE_Spin).
local function spinWheel(parent: Instance, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "SpinWheel"
	local base = Parts.Part(model, {
		Name = "Base",
		Size = Vector3.new(14, 1, 6),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(200, 196, 188),
		Material = Enum.Material.Marble,
	})
	model.PrimaryPart = base
	local custom = CustomModels.Find("World", "SpinWheel")
	if custom then
		-- Hand-made wheel: about 16 studs tall, standing on the plaza floor. The plinth
		-- becomes an invisible marker that carries the Spin prompt and the labels.
		base.Transparency = 1
		base.CanCollide = false
		base.CanQuery = false
		base.CanTouch = false
		base.CastShadow = false
		base.CFrame = cf * CFrame.new(0, 0.1, 0)
		base.Size = Vector3.new(14, 0.2, 6)
		CustomModels.Place(custom, model, cf, { Fit = Vector3.new(math.huge, 16, math.huge) })
		model.Parent = parent
		return model
	end
	local RADIUS = 6
	local center = cf * CFrame.new(0, RADIUS + 2.6, 0)
	for _, x in { -RADIUS - 0.8, RADIUS + 0.8 } do
		Parts.Part(model, {
			Size = Vector3.new(0.9, RADIUS + 3, 0.9),
			CFrame = cf * CFrame.new(x, (RADIUS + 3) / 2 + 1, 0.6),
			Color = Color3.fromRGB(125, 88, 58),
			Material = Enum.Material.Wood,
		})
	end
	Parts.Part(model, {
		Size = Vector3.new(RADIUS * 2 + 2.5, 0.8, 0.8),
		CFrame = center * CFrame.new(0, 0, 0.9),
		Color = Color3.fromRGB(125, 88, 58),
		Material = Enum.Material.Wood,
	})

	local disc = Instance.new("Model")
	disc.Name = "WheelDisc"
	local back = Parts.Part(disc, {
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, RADIUS * 2 + 0.8, RADIUS * 2 + 0.8),
		CFrame = center * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(240, 190, 70),
		Material = Enum.Material.Metal,
	})
	disc.PrimaryPart = back
	-- One coloured blade per prize, clockwise from the top as seen from the front.
	local count = #SpinConfig.Prizes
	for index, prize in SpinConfig.Prizes do
		local angle = math.rad((index - 0.5) * 360 / count)
		Parts.Decor(disc, {
			Name = "Segment",
			Size = Vector3.new(2 * RADIUS * math.sin(math.pi / count) * 0.92, RADIUS * 0.82, 0.3),
			CFrame = center * CFrame.Angles(0, 0, angle) * CFrame.new(0, RADIUS * 0.53, -0.35),
			Color = prize.Color,
			Material = if prize.Kind == "Creature" then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		})
	end
	Parts.Ball(disc, (center * CFrame.new(0, 0, -0.5)).Position, 1.6, {
		Color = Color3.fromRGB(240, 190, 70),
		Material = Enum.Material.Metal,
	})
	disc.WorldPivot = center
	disc:SetAttribute("SpinSpeed", 12)
	disc:SetAttribute("SpinAxis", "Z")
	CollectionService:AddTag(disc, "CE_Spin")
	disc.Parent = model

	-- The pointer at the top marks the prize.
	Parts.Decor(model, {
		Name = "Pointer",
		ClassName = "WedgePart",
		Size = Vector3.new(0.6, 1.6, 1.4),
		CFrame = center * CFrame.new(0, RADIUS + 0.9, -0.6) * CFrame.Angles(math.rad(180), 0, 0),
		Color = Color3.fromRGB(230, 60, 60),
		Material = Enum.Material.Neon,
	})
	model.Parent = parent
	return model
end

-- The shared shop area: the Trading Post, the Hatchery nest and the Spin Wheel. Players
-- use them with proximity prompts (client BuildingController); the server checks range.
local function buildStations(plaza: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Stations"
	folder.Parent = plaza
	-- Studio layout markers (PlazaConfig) stay in place but can't be seen or touched.
	local layout = Workspace:FindFirstChild("PlazaLayout")
	for _, part in layout and layout:GetDescendants() or {} do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		elseif part:IsA("SurfaceGui") or part:IsA("BillboardGui") then
			part.Enabled = false
		end
	end
	for id, station in PlazaConfig.Stations do
		local cf = PlazaConfig.CFrame(id)
		local model: Model
		if id == "SpinWheel" then
			model = spinWheel(folder, cf)
		else
			model = BuildingModels.Build(id, 1, cf)
			model.Parent = folder
		end
		model.Name = id
		model:SetAttribute("PlazaStation", id)
		-- Plaza buildings have no level: show just the name.
		local base = model.PrimaryPart
		local labelled = false
		if base then
			for _, d in base:GetDescendants() do
				if d:IsA("TextLabel") then
					d.Text = station.Name
					labelled = true
				end
			end
			if not labelled then
				Parts.Label(base, station.Name, { Offset = Vector3.new(0, 18, 0), MaxDistance = 120 })
			end
		end
		CollectionService:AddTag(model, "CE_PlazaStation")
	end
end

local PLAZA_APOTHEM = 35 -- studs from the centre to the middle of each side (where paths start)
local CENTREPIECE_HEIGHT = 18 -- studs: a hand-made centrepiece is scaled to this height

-- Swimmable water inside a hand-made well in the middle of the plaza. Imported meshes often
-- collide as a solid lump, so the well's own parts stop colliding and an invisible ring
-- wall keeps people out unless they jump over the rim into the water.
-- A part named "Water" in the model marks the water exactly (its size and height);
-- without one, the water fills the middle of the well up to about a fifth of its height.
local function wellWater(parent: Instance, well: Model, size: Vector3)
	local floor = PlazaConfig.FloorY
	local marker = well:FindFirstChild("Water", true)
	local radius: number
	local top: number
	if marker and marker:IsA("BasePart") then
		radius = math.min(marker.Size.X, marker.Size.Z) / 2
		top = marker.Position.Y + marker.Size.Y / 2
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanQuery = false
	else
		radius = math.min(size.X, size.Z) * 0.36
		top = floor + size.Y * 0.22
	end
	radius = math.max(radius, 2)
	top = math.max(top, floor + 2)
	for _, d in well:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	-- The rim: a ring of invisible wall segments a little higher than the water.
	local rimHeight = top - floor + 1
	local segments = 24
	local wall = 2 * math.pi * (radius + 0.5) / segments + 0.4
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local at =
			Vector3.new(math.sin(angle) * (radius + 0.5), floor + rimHeight / 2, math.cos(angle) * (radius + 0.5))
		local rim = Parts.Part(parent, {
			Name = "WellRim",
			Size = Vector3.new(wall, rimHeight, 1),
			CFrame = CFrame.lookAt(at, Vector3.new(0, at.Y, 0)),
			Transparency = 1,
			CastShadow = false,
		})
		rim.CanQuery = false
	end
	local depth = top - floor
	Workspace.Terrain:FillCylinder(CFrame.new(0, floor + depth / 2, 0), depth, radius, Enum.Material.Water)
end

-- A flat hexagon (0.5 thick, centred at height `y`) whose sides face the path directions:
-- three overlapping slabs turned 60 degrees apart.
local function hexagon(
	parent: Instance,
	name: string,
	apothem: number,
	y: number,
	color: Color3,
	material: Enum.Material
)
	local side = 2 * apothem / math.sqrt(3)
	for i = 0, 2 do
		local angle = i / PlotConfig.PlotCount * math.pi * 2
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		Parts.Part(parent, {
			Name = name,
			Size = Vector3.new(side, 0.5, 2 * apothem),
			CFrame = CFrame.lookAt(Vector3.new(0, y, 0), Vector3.new(0, y, 0) + direction),
			Color = color,
			Material = material,
		})
	end
end

local function buildPlaza(folder: Folder)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = folder

	-- A hexagon with one flat side facing each of the six paths, so every path starts
	-- square-on at the middle of a side: a cobblestone border around slate paving.
	local floorModel = CustomModels.Find("World", "PlazaFloor")
	if floorModel then
		-- Hand-made floor: fitted to the hexagon (80.8 studs corner to corner, 70 side to
		-- side, a side facing each path) with its top surface at the plaza floor height.
		local placed = CustomModels.Place(floorModel, plaza, CFrame.new(0, 0, 0), {
			Fit = Vector3.new(4 * PLAZA_APOTHEM / math.sqrt(3), 0, 2 * PLAZA_APOTHEM),
		})
		local center, size = CustomModels.Bounds(placed)
		local top = center.Y + size.Y / 2
		placed:PivotTo(placed:GetPivot() + Vector3.new(0, PlazaConfig.FloorY - top, 0))
	else
		hexagon(plaza, "PlazaBorder", PLAZA_APOTHEM, 0.25, STONE, Enum.Material.Cobblestone)
		hexagon(plaza, "PlazaFloor", PLAZA_APOTHEM - 2, 0.3, Color3.fromRGB(176, 170, 160), Enum.Material.Slate)
	end

	-- Founders' Crystal monument, or a hand-made centrepiece (the creator's wishing well)
	local crystalModel = CustomModels.Find("World", "FoundersCrystal")
	local labelAnchor: BasePart
	if crystalModel then
		local placed = CustomModels.Place(crystalModel, plaza, CFrame.new(0, PlazaConfig.FloorY, 0), {
			Fit = Vector3.new(math.huge, CENTREPIECE_HEIGHT, math.huge),
		})
		local center, size = CustomModels.Bounds(placed)
		wellWater(plaza, placed, size)
		labelAnchor = Parts.Decor(plaza, {
			Name = "FoundersCrystal",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(0, center.Y + size.Y / 2, 0),
			Transparency = 1,
		})
	else
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
		labelAnchor = crystal
	end
	Parts.Label(labelAnchor, "CREATURE EMPIRE", {
		Size = UDim2.fromScale(22, 4),
		Offset = Vector3.new(0, if crystalModel then 4 else 10, 0),
		MaxDistance = 200,
		Color = Color3.fromRGB(220, 250, 255),
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
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

	buildStations(plaza)
end

local function buildPaths(folder: Folder)
	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = folder
	for i = 0, PlotConfig.PlotCount - 1 do
		local angle = i / PlotConfig.PlotCount * math.pi * 2
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local from, to = PLAZA_APOTHEM, PlotConfig.RingRadius -- from the middle of a plaza side
		local length = to - from
		local mid = direction * (from + length / 2)
		local side = Vector3.new(-direction.Z, 0, direction.X)
		-- Centred on the path edge (it is 8 studs wide): the front, with the glowing
		-- mushrooms, leans out over the path.
		lamp(paths, direction * (from + length * 0.6) + side * 4, -side)
		local piece = CustomModels.Find("World", "PathSegment")
		if piece then
			CustomModels.Tile(piece, paths, CFrame.identity, direction * from, direction * to, 8)
			continue
		end
		Parts.Part(paths, {
			Size = Vector3.new(8, 0.3, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), mid + direction + Vector3.new(0, 0.15, 0)),
			Color = PATH,
			Material = Enum.Material.Pavement,
		})
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
