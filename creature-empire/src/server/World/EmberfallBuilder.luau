--!strict
-- Builds Emberfall Basin from RegionConfig: basalt terrain ringed by cliffs, lava rivers
-- with bridges, cooling pools, vents, resource deposits, landmarks (Ashen Overlook, Magma
-- Falls, the Guardian's Caldera, the hidden Ember Grotto), a trail of glowing footprints,
-- and the gates between the basin and the plaza.
--
-- Everything is anchored and static. Things the client animates or interacts with are
-- tagged: CE_Vent (index attribute), CE_Node (NodeId/Kind), CE_Gate (Region/Destination).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RegionConfig = require(ReplicatedStorage.Shared.Config.RegionConfig)
local Parts = require(script.Parent.Parts)

local EmberfallBuilder = {}

local BASALT = Color3.fromRGB(52, 44, 44)
local ROCK = Color3.fromRGB(78, 62, 58)
local LAVA = Color3.fromRGB(255, 110, 30)
local POOL = Color3.fromRGB(90, 200, 255)

local rng = Random.new(31337)

-- A rock. Scattered rocks get a random tilt and turn; structural ones (`exact`) don't.
local function rock(parent: Instance, cf: CFrame, size: Vector3, color: Color3?, exact: boolean?)
	Parts.Part(parent, {
		Size = size,
		CFrame = if exact
			then cf
			else cf * CFrame.Angles(
				rng:NextNumber(-0.15, 0.15),
				rng:NextNumber(0, 6.28),
				rng:NextNumber(-0.15, 0.15)
			),
		Color = color or ROCK,
		Material = Enum.Material.Basalt,
	})
end

local function gate(
	parent: Instance,
	position: Vector3,
	facing: Vector3,
	label: string,
	region: string,
	destination: string
)
	local cf = CFrame.lookAt(position, position + facing)
	for _, x in { -6, 6 } do
		Parts.Part(parent, {
			Size = Vector3.new(2, 14, 2),
			CFrame = cf * CFrame.new(x, 7, 0),
			Color = Color3.fromRGB(60, 50, 50),
			Material = Enum.Material.Slate,
		})
	end
	Parts.Part(parent, {
		Size = Vector3.new(15, 2, 2.4),
		CFrame = cf * CFrame.new(0, 14.5, 0),
		Color = Color3.fromRGB(60, 50, 50),
		Material = Enum.Material.Slate,
	})
	local portal = Parts.Decor(parent, {
		Name = "Portal",
		Size = Vector3.new(10, 12, 0.3),
		CFrame = cf * CFrame.new(0, 7, 0),
		Color = LAVA,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	portal.CanQuery = true -- clients attach their travel prompt here
	portal:SetAttribute("Region", region)
	portal:SetAttribute("Destination", destination)
	CollectionService:AddTag(portal, "CE_Gate")
	Parts.Light(portal, LAVA, 18, 1.2)
	Parts.Label(
		portal,
		label,
		{ Offset = Vector3.new(0, 9, 0), MaxDistance = 120, Color = Color3.fromRGB(255, 220, 180) }
	)
	return portal
end

local function terrain(region: RegionConfig.Region)
	local t = Workspace.Terrain
	local c = region.Center
	t:FillBlock(CFrame.new(c + Vector3.new(0, -12, 0)), Vector3.new(600, 24, 600), Enum.Material.Basalt)
	t:SetMaterialColor(Enum.Material.Basalt, BASALT)
	-- Cliffs around the edge (gap at the south for the gate).
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local south = math.abs(math.atan2(math.sin(a), math.cos(a)) - math.pi / 2) < 0.18
		if not south then
			local r = rng:NextNumber(320, 340)
			t:FillBall(
				c + Vector3.new(math.cos(a) * r, 10, math.sin(a) * r),
				rng:NextNumber(45, 58),
				Enum.Material.Rock
			)
		end
	end
	t:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(70, 56, 52))
end

local function lava(parent: Instance, region: RegionConfig.Region)
	for _, river in region.Lava do
		local a, b = region.Center + river.From, region.Center + river.To
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local part = Parts.Part(parent, {
			Name = "Lava",
			Size = Vector3.new(river.Width, 0.6, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), b + Vector3.new(0, 0.1, 0)),
			Color = LAVA,
			Material = Enum.Material.Neon,
			CanCollide = true,
		})
		for i = 1, math.floor(length / 60) do
			local attachment = Instance.new("Attachment")
			attachment.Position = Vector3.new(0, 1, -length / 2 + i * 60)
			attachment.Parent = part
			local light = Instance.new("PointLight")
			light.Color = LAVA
			light.Range = 24
			light.Brightness = 1.4
			light.Parent = attachment
		end
		-- Crusted banks
		for _, side in { -1, 1 } do
			Parts.Part(parent, {
				Size = Vector3.new(2, 0.8, length),
				CFrame = CFrame.lookAt(mid, b) * CFrame.new(side * (river.Width / 2 + 1), 0.4, 0),
				Color = Color3.fromRGB(40, 30, 30),
				Material = Enum.Material.CrackedLava,
			})
		end
	end
	for _, bridge in region.Bridges do
		local cf = CFrame.new(region.Center + bridge.Offset) * CFrame.Angles(0, math.rad(bridge.Rotation), 0)
		Parts.Part(parent, {
			Name = "Bridge",
			Size = Vector3.new(8, 1, bridge.Length),
			CFrame = cf * CFrame.new(0, 2, 0),
			Color = Color3.fromRGB(110, 80, 55),
			Material = Enum.Material.WoodPlanks,
		})
		for _, side in { -1, 1 } do
			-- Ramps up to the deck at both ends
			local ramp = Instance.new("WedgePart")
			ramp.Anchored = true
			ramp.Size = Vector3.new(8, 2.5, 6)
			ramp.Color = Color3.fromRGB(100, 72, 50)
			ramp.Material = Enum.Material.WoodPlanks
			ramp.CFrame = cf
				* CFrame.new(0, 1.25, side * (bridge.Length / 2 + 3))
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
			ramp.Parent = parent
			Parts.Part(parent, {
				Size = Vector3.new(0.5, 2.5, bridge.Length),
				CFrame = cf * CFrame.new(side * 3.8, 3.7, 0),
				Color = Color3.fromRGB(80, 60, 45),
				Material = Enum.Material.Wood,
			})
		end
	end
end

local function pools(parent: Instance, region: RegionConfig.Region)
	for _, offset in region.Pools do
		local position = region.Center + offset
		local water =
			Parts.Cylinder(parent, CFrame.new(position + Vector3.new(0, 0.15, 0)), 0.3, region.Heat.PoolRadius * 2, {
				Name = "CoolingPool",
				Color = POOL,
				Material = Enum.Material.Neon,
				Transparency = 0.35,
			})
		water.CanCollide = false
		Parts.Light(water, POOL, 26, 1.2)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			rock(
				parent,
				CFrame.new(position + Vector3.new(math.cos(a), 0, math.sin(a)) * (region.Heat.PoolRadius + 1.5)),
				Vector3.new(3, 2, 3),
				Color3.fromRGB(70, 90, 100)
			)
		end
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
		steam.Size = NumberSequence.new(2, 6)
		steam.Transparency = NumberSequence.new(0.6, 1)
		steam.Lifetime = NumberRange.new(2, 4)
		steam.Rate = 4
		steam.Speed = NumberRange.new(1, 3)
		steam.SpreadAngle = Vector2.new(30, 30)
		steam.Parent = water
	end
end

local function vents(parent: Instance, region: RegionConfig.Region)
	for index, offset in region.Vents do
		local position = region.Center + offset
		Parts.Cylinder(
			parent,
			CFrame.new(position + Vector3.new(0, 0.6, 0)),
			1.2,
			7,
			{ Color = Color3.fromRGB(40, 32, 30), Material = Enum.Material.Basalt }
		)
		local mouth = Parts.Cylinder(
			parent,
			CFrame.new(position + Vector3.new(0, 1.25, 0)),
			0.1,
			3,
			{ Name = "VentMouth", Color = LAVA, Material = Enum.Material.Neon }
		)
		mouth.CanCollide = false
		mouth:SetAttribute("VentIndex", index)
		CollectionService:AddTag(mouth, "CE_Vent")
	end
end

local function nodes(parent: Instance, region: RegionConfig.Region)
	for _, node in region.Nodes do
		local model = Instance.new("Model")
		model.Name = "Node_" .. node.Id
		local position = region.Center + node.Offset
		local base = Parts.Part(model, {
			Name = "Base",
			Size = Vector3.new(5, 0.4, 5),
			CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)),
			Transparency = 1,
			CanCollide = false,
		})
		model.PrimaryPart = base
		if node.Kind == "Crystal" then
			for i = 1, 5 do
				local part = Parts.Part(model, {
					Name = "Ore",
					Size = Vector3.new(0.9, 2 + i * 0.5, 0.9),
					CFrame = CFrame.new(position + Vector3.new(math.cos(i) * 1.2, 1 + i * 0.25, math.sin(i) * 1.2))
						* CFrame.Angles(0.3 * math.sin(i * 2), i, 0.3 * math.cos(i)),
					Color = Color3.fromRGB(130, 210, 255),
					Material = Enum.Material.Glass,
					Transparency = 0.1,
				})
				if i == 1 then
					Parts.Light(part, Color3.fromRGB(130, 210, 255), 10, 0.8)
				end
			end
		else
			rock(
				model,
				CFrame.new(position + Vector3.new(0, 1.2, 0)),
				Vector3.new(4, 2.6, 3.4),
				Color3.fromRGB(70, 50, 45)
			)
			for i = 1, 4 do
				local vein = Parts.Decor(model, {
					Name = "Ore",
					Size = Vector3.new(0.4, 0.6, 2.4),
					CFrame = CFrame.new(position + Vector3.new(math.cos(i * 1.6) * 1.8, 1.6, math.sin(i * 1.6) * 1.6))
						* CFrame.Angles(0, i * 1.6, 0.4),
					Color = LAVA,
					Material = Enum.Material.Neon,
				})
				if i == 1 then
					Parts.Light(vein, LAVA, 8, 0.6)
				end
			end
		end
		model:SetAttribute("NodeId", node.Id)
		model:SetAttribute("Kind", node.Kind)
		model:SetAttribute("Region", region.Id)
		CollectionService:AddTag(model, "CE_Node")
		model.Parent = parent
	end
end

local function overlook(parent: Instance, position: Vector3)
	-- A stepped spire with ramps winding up to a lookout platform.
	local height = 46
	for tier = 0, 4 do
		local radius = 22 - tier * 3.5
		Parts.Cylinder(
			parent,
			CFrame.new(position + Vector3.new(0, tier * 9 + 4.5, 0)),
			9,
			radius * 2,
			{ Color = ROCK, Material = Enum.Material.Basalt }
		)
	end
	for tier = 0, 4 do
		local radius = 22 - tier * 3.5 + 2.5
		local a = tier * math.pi / 2
		local ramp = Instance.new("WedgePart")
		ramp.Anchored = true
		ramp.Size = Vector3.new(6, 9, 16)
		ramp.Color = Color3.fromRGB(95, 75, 68)
		ramp.Material = Enum.Material.Slate
		ramp.CFrame = CFrame.new(position + Vector3.new(math.cos(a) * radius, tier * 9 + 4.5, math.sin(a) * radius))
			* CFrame.Angles(0, -a, 0)
		ramp.Parent = parent
	end
	local top = Parts.Part(parent, {
		Name = "OverlookTop",
		Size = Vector3.new(12, 1, 12),
		CFrame = CFrame.new(position + Vector3.new(0, height - 0.5, 0)),
		Color = Color3.fromRGB(120, 100, 90),
		Material = Enum.Material.Slate,
	})
	Parts.Label(
		top,
		"Ashen Overlook",
		{ Offset = Vector3.new(0, 8, 0), MaxDistance = 250, Color = Color3.fromRGB(255, 210, 170) }
	)
end

local function falls(parent: Instance, position: Vector3)
	-- A cliff with a lavafall; the hidden grotto's path slips round its east side.
	rock(parent, CFrame.new(position + Vector3.new(0, 18, -12)), Vector3.new(70, 36, 14), nil, true)
	local fall = Parts.Decor(parent, {
		Name = "Lavafall",
		Size = Vector3.new(14, 34, 1),
		CFrame = CFrame.new(position + Vector3.new(-6, 17, -4.5)),
		Color = LAVA,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	Parts.Light(fall, LAVA, 40, 2)
	local splash = Parts.Cylinder(
		parent,
		CFrame.new(position + Vector3.new(-6, 0.2, 2)),
		0.4,
		16,
		{ Color = LAVA, Material = Enum.Material.Neon }
	)
	splash.CanCollide = false
	Parts.Label(
		fall,
		"Magma Falls",
		{ Offset = Vector3.new(0, 22, 0), MaxDistance = 250, Color = Color3.fromRGB(255, 210, 170) }
	)
end

local function grotto(parent: Instance, position: Vector3)
	-- Low cave behind Magma Falls: walls on three sides and a roof, open to the east where
	-- the footprint trail arrives.
	local cf = CFrame.new(position)
	rock(parent, cf * CFrame.new(0, 7, -12), Vector3.new(30, 14, 4), nil, true)
	rock(parent, cf * CFrame.new(-13, 7, 0), Vector3.new(4, 14, 26), nil, true)
	rock(parent, cf * CFrame.new(0, 7, 12), Vector3.new(30, 14, 4), nil, true)
	Parts.Part(parent, {
		Size = Vector3.new(32, 3, 28),
		CFrame = cf * CFrame.new(0, 15, 0),
		Color = ROCK,
		Material = Enum.Material.Basalt,
	})
	for i = 1, 6 do
		local crystal = Parts.Decor(parent, {
			Size = Vector3.new(1, 3 + i % 3, 1),
			CFrame = cf * CFrame.new(math.cos(i) * 8, 2, math.sin(i) * 8) * CFrame.Angles(0.3, i, 0.2),
			Color = Color3.fromRGB(255, 160, 220),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		if i % 2 == 0 then
			Parts.Light(crystal, Color3.fromRGB(255, 160, 220), 12, 0.8)
		end
	end
	Parts.Cylinder(
		parent,
		cf * CFrame.new(-6, 1, 4),
		2,
		3,
		{ Color = Color3.fromRGB(200, 190, 170), Material = Enum.Material.Marble }
	)
	local relic = Parts.Ball(
		parent,
		(cf * CFrame.new(-6, 3, 4)).Position,
		1.4,
		{ Color = Color3.fromRGB(255, 200, 80), Material = Enum.Material.Neon }
	)
	relic:SetAttribute("BobHeight", 0.3)
	CollectionService:AddTag(relic, "CE_Bob")
end

local function caldera(parent: Instance, position: Vector3, radius: number)
	Parts.Cylinder(
		parent,
		CFrame.new(position + Vector3.new(0, 0.3, 0)),
		0.6,
		radius * 2,
		{ Color = Color3.fromRGB(70, 60, 58), Material = Enum.Material.Slate }
	)
	local ring = Parts.Cylinder(
		parent,
		CFrame.new(position + Vector3.new(0, 0.62, 0)),
		0.05,
		radius * 2 - 6,
		{ Color = LAVA, Material = Enum.Material.Neon }
	)
	ring.Transparency = 0.6
	ring.CanCollide = false
	-- Broken wall of standing rocks, with gaps to walk in.
	for i = 0, 23 do
		if i % 6 ~= 0 then
			local a = i / 24 * math.pi * 2
			rock(
				parent,
				CFrame.new(position + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius + 4) + Vector3.new(0, 4, 0)),
				Vector3.new(6, 9, 4)
			)
		end
	end
	local marker = Parts.Part(parent, {
		Name = "ArenaCenter",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 1, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	Parts.Label(
		marker,
		"Guardian's Caldera",
		{ Offset = Vector3.new(0, 30, 0), MaxDistance = 300, Color = Color3.fromRGB(255, 200, 160) }
	)
end

local function footprints(parent: Instance, region: RegionConfig.Region)
	for _, offset in region.Footprints do
		local position = region.Center + offset
		for _, side in { -0.7, 0.7 } do
			Parts.Ball(parent, position + Vector3.new(side, 0.1, side * 0.6), 0.9, {
				Name = "Footprint",
				Color = Color3.fromRGB(255, 160, 220),
				Material = Enum.Material.Neon,
				Transparency = 0.45,
			})
		end
	end
end

local function scenery(parent: Instance, region: RegionConfig.Region)
	for _ = 1, 40 do
		local offset = Vector3.new(rng:NextNumber(-250, 250), 0, rng:NextNumber(-250, 250))
		local clear = true
		for _, lava in region.Lava do
			if RegionConfig.DistanceToSegment(offset, lava.From, lava.To) < lava.Width then
				clear = false
			end
		end
		for _, pool in region.Pools do
			if (offset - pool).Magnitude < 22 then
				clear = false
			end
		end
		if clear then
			rock(
				parent,
				CFrame.new(region.Center + offset + Vector3.new(0, 1.5, 0)),
				Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(2, 6), rng:NextNumber(3, 8))
			)
		end
	end
	-- Charred trees
	for _ = 1, 16 do
		local offset = Vector3.new(rng:NextNumber(-240, 240), 0, rng:NextNumber(-240, 240))
		local position = region.Center + offset
		Parts.Cylinder(
			parent,
			CFrame.new(position + Vector3.new(0, 4, 0)) * CFrame.Angles(0.1, 0, 0.1),
			8,
			1,
			{ Color = Color3.fromRGB(35, 28, 26), Material = Enum.Material.Wood }
		)
	end
end

function EmberfallBuilder.Build()
	local region = RegionConfig.Regions.Emberfall
	local root = Workspace:FindFirstChild("WorldRegions") or Instance.new("Folder")
	root.Name = "WorldRegions"
	root.Parent = Workspace
	local folder = Instance.new("Folder")
	folder.Name = "Emberfall"
	folder.Parent = root
	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Nodes"
	nodeFolder.Parent = folder

	terrain(region)
	lava(folder, region)
	pools(folder, region)
	vents(folder, region)
	nodes(nodeFolder, region)
	for _, landmark in region.Landmarks do
		local position = region.Center + landmark.Offset
		if landmark.Id == "Overlook" then
			overlook(folder, position)
		elseif landmark.Id == "Falls" then
			falls(folder, position)
		elseif landmark.Id == "Grotto" then
			grotto(folder, position)
		elseif landmark.Id == "Caldera" then
			caldera(folder, position, region.Guardian.ArenaRadius)
		end
	end
	footprints(folder, region)
	scenery(folder, region)

	gate(
		folder,
		region.Center + region.ArrivalOffset + Vector3.new(0, -3, 12),
		Vector3.new(0, 0, 1),
		"To your empire",
		region.Id,
		"Home"
	)
	gate(
		folder,
		region.PlazaGate,
		(region.PlazaGate * Vector3.new(1, 0, 1)).Unit,
		"Emberfall Basin",
		region.Id,
		region.Id
	)
end

return EmberfallBuilder
