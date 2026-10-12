-- Builds the medieval town hub around the spawn: walls, towers, gatehouse, castle keep,
-- timber-framed houses, tavern, blacksmith, market, fountain, lamps, banners and lighting.
--
-- Layout (top-down, north = -Z):
--
--            [ castle keep ]
--   +---------- north wall ----------+
--   |   portal    portal    portal   |   <- DungeonService builds the portals
--   |  houses      fountain   houses |
--   |  tavern       SPAWN     shop   |   <- ShopService builds the potion shop
--   |  houses                market  |
--   +------ gatehouse (south) -------+
--          [ training grounds ]          <- TrainingService
--
-- Everything is plain parts, so it can be swapped for hand-built models in Studio later.

local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)

local HubService = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local STONE = rgb(120, 115, 108)
local STONE_DARK = rgb(85, 80, 76)
local WOOD = rgb(105, 72, 45)
local WOOD_DARK = rgb(62, 42, 28)
local PLASTER = rgb(226, 214, 186)
local IRON = rgb(45, 45, 50)
local WARM_LIGHT = rgb(255, 180, 90)
local BANNER_RED = rgb(150, 30, 35)
local GOLD = rgb(220, 175, 60)

-- Town bounds
local WEST, EAST = -72, 72
local NORTH, SOUTH = -72, 56
local WALL_HEIGHT = 18
local WALL_THICKNESS = 4

local hub: Folder

-- Pieces ------------------------------------------------------------------------

local function battlements(parent: Instance, from: Vector3, to: Vector3, thickness: number)
	local direction = (to - from).Unit
	local length = (to - from).Magnitude
	local count = math.floor(length / 5)
	for i = 0, count do
		local position = from + direction * (i * length / math.max(count, 1))
		Build.block(parent, "Merlon", Vector3.new(2.5, 3, thickness), CFrame.lookAt(position, position + direction:Cross(Vector3.yAxis)) * CFrame.new(0, 1.5, 0), STONE, M.Cobblestone)
	end
end

-- Straight wall between two points on the ground, with battlements on top.
local function wall(from: Vector3, to: Vector3)
	local center = (from + to) / 2
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt(center, to)
	Build.block(hub, "Wall", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length), cframe * CFrame.new(0, WALL_HEIGHT / 2, 0), STONE, M.Cobblestone)
	Build.block(hub, "WallTrim", Vector3.new(WALL_THICKNESS + 0.6, 1, length), cframe * CFrame.new(0, WALL_HEIGHT - 0.5, 0), STONE_DARK, M.Slate)
	battlements(hub, from + Vector3.new(0, WALL_HEIGHT, 0), to + Vector3.new(0, WALL_HEIGHT, 0), WALL_THICKNESS)
end

local function flag(position: Vector3, color: Color3)
	Build.block(hub, "FlagPole", Vector3.new(0.4, 10, 0.4), CFrame.new(position + Vector3.new(0, 5, 0)), IRON, M.Metal)
	local cloth = Build.block(hub, "Flag", Vector3.new(0.2, 3, 5), CFrame.new(position + Vector3.new(0, 8.4, 2.5)), color, M.Fabric)
	cloth.CanCollide = false
end

local function squareTower(position: Vector3, width: number, height: number, flagColor: Color3?)
	Build.block(hub, "Tower", Vector3.new(width, height, width), CFrame.new(position + Vector3.new(0, height / 2, 0)), STONE, M.Cobblestone)
	Build.block(hub, "TowerTrim", Vector3.new(width + 1, 1.2, width + 1), CFrame.new(position + Vector3.new(0, height - 0.6, 0)), STONE_DARK, M.Slate)
	local h = width / 2 + 0.5
	local top = position + Vector3.new(0, height, 0)
	for _, corners in {
		{ Vector3.new(-h, 0, -h), Vector3.new(h, 0, -h) },
		{ Vector3.new(h, 0, -h), Vector3.new(h, 0, h) },
		{ Vector3.new(h, 0, h), Vector3.new(-h, 0, h) },
		{ Vector3.new(-h, 0, h), Vector3.new(-h, 0, -h) },
	} do
		battlements(hub, top + corners[1], top + corners[2], 1.5)
	end
	-- Arrow slits
	for _, y in { height * 0.4, height * 0.7 } do
		Build.block(hub, "ArrowSlit", Vector3.new(0.6, 2.5, width + 0.1), CFrame.new(position + Vector3.new(0, y, 0)), rgb(20, 18, 18), M.Slate)
		Build.block(hub, "ArrowSlit", Vector3.new(width + 0.1, 2.5, 0.6), CFrame.new(position + Vector3.new(0, y, 0)), rgb(20, 18, 18), M.Slate)
	end
	if flagColor then
		flag(top, flagColor)
	end
end

local function roundTower(position: Vector3, diameter: number, height: number, roofColor: Color3)
	Build.cylinder(hub, "Tower", diameter, height, CFrame.new(position + Vector3.new(0, height / 2, 0)), STONE, M.Cobblestone)
	Build.cylinder(hub, "TowerTrim", diameter + 1.2, 1.2, CFrame.new(position + Vector3.new(0, height - 0.6, 0)), STONE_DARK, M.Slate)
	-- Cone roof from stacked, shrinking discs
	local layers = 8
	for i = 0, layers - 1 do
		local d = (diameter + 2) * (1 - i / layers)
		Build.cylinder(hub, "Roof", d, 1.6, CFrame.new(position + Vector3.new(0, height + 0.8 + i * 1.6, 0)), roofColor, M.Slate)
	end
	flag(position + Vector3.new(0, height + layers * 1.6, 0), BANNER_RED)
end

local function wallTorch(position: Vector3, facing: Vector3)
	local cframe = CFrame.lookAt(position, position + facing)
	Build.block(hub, "TorchBracket", Vector3.new(0.4, 0.4, 1.2), cframe * CFrame.new(0, 0, -0.6), IRON, M.Metal)
	local head = Build.block(hub, "Torch", Vector3.new(0.6, 1.2, 0.6), cframe * CFrame.new(0, 0.5, -1.2), WOOD_DARK, M.Wood)
	head.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Color = rgb(255, 140, 40)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = head
	Build.light(head, WARM_LIGHT, 20, 2)
end

local function banner(position: Vector3, facing: Vector3, color: Color3)
	local cframe = CFrame.lookAt(position, position + facing)
	Build.block(hub, "BannerRod", Vector3.new(7, 0.4, 0.4), cframe * CFrame.new(0, 0, -0.4), IRON, M.Metal)
	local cloth = Build.block(hub, "Banner", Vector3.new(6, 11, 0.2), cframe * CFrame.new(0, -5.7, -0.4), color, M.Fabric)
	cloth.CanCollide = false
	Build.block(hub, "BannerTrim", Vector3.new(6.2, 0.6, 0.25), cframe * CFrame.new(0, -11, -0.4), GOLD, M.Fabric)
	-- Emblem: a gold diamond with a crossed-sword stripe
	Build.block(hub, "Emblem", Vector3.new(2.6, 2.6, 0.3), cframe * CFrame.new(0, -4.5, -0.45) * CFrame.Angles(0, 0, math.rad(45)), GOLD, M.Fabric)
	Build.block(hub, "Emblem", Vector3.new(0.4, 4.5, 0.35), cframe * CFrame.new(0, -4.5, -0.5), rgb(230, 230, 235), M.Metal)
end

local function lampPost(position: Vector3)
	Build.block(hub, "LampBase", Vector3.new(1.4, 0.8, 1.4), CFrame.new(position + Vector3.new(0, 0.4, 0)), STONE_DARK, M.Slate)
	Build.block(hub, "LampPost", Vector3.new(0.5, 9, 0.5), CFrame.new(position + Vector3.new(0, 4.5, 0)), IRON, M.Metal)
	Build.block(hub, "LampCap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(position + Vector3.new(0, 10.2, 0)), IRON, M.Metal)
	local lantern = Build.block(hub, "Lantern", Vector3.new(1.1, 1.4, 1.1), CFrame.new(position + Vector3.new(0, 9.3, 0)), WARM_LIGHT, M.Neon)
	lantern.Transparency = 0.15
	Build.light(lantern, WARM_LIGHT, 22, 2)
end

local function tree(position: Vector3, size: number)
	Build.cylinder(hub, "Planter", 6 * size, 1.2, CFrame.new(position + Vector3.new(0, 0.6, 0)), STONE_DARK, M.Cobblestone)
	Build.cylinder(hub, "Trunk", 1.4 * size, 9 * size, CFrame.new(position + Vector3.new(0, 4.5 * size, 0)), rgb(90, 62, 40), M.Wood)
	local leaves = rgb(70, 120, 55)
	for _, offset in { Vector3.new(0, 10, 0), Vector3.new(2.2, 8.6, 1), Vector3.new(-2, 8.8, -1.4), Vector3.new(0.6, 12, -0.6) } do
		local ball = Build.ball(hub, "Leaves", 6 * size, position + offset * size, leaves, M.Grass)
		ball.CanCollide = false
	end
end

local function barrel(position: Vector3)
	Build.cylinder(hub, "Barrel", 2.2, 3, CFrame.new(position + Vector3.new(0, 1.5, 0)), rgb(120, 80, 45), M.WoodPlanks)
	for _, y in { 0.6, 2.4 } do
		Build.cylinder(hub, "BarrelBand", 2.35, 0.25, CFrame.new(position + Vector3.new(0, y, 0)), IRON, M.Metal)
	end
end

local function crate(position: Vector3, size: number, yaw: number)
	Build.block(hub, "Crate", Vector3.one * size, CFrame.new(position + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, math.rad(yaw), 0), rgb(150, 110, 65), M.WoodPlanks)
end

-- Timber-framed house. `cframe` sits on the ground at the house's center and faces the front.
local function house(cframe: CFrame, width: number, depth: number, height: number, roofColor: Color3, signText: string?)
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local front = -depth / 2

	Build.block(hub, "Foundation", Vector3.new(width + 1, 1, depth + 1), at(0, 0.5, 0), STONE_DARK, M.Cobblestone)
	Build.block(hub, "Walls", Vector3.new(width, height, depth), at(0, 1 + height / 2, 0), PLASTER, M.Plaster)

	-- Timber frame on the front: posts, floor beams and diagonal braces
	for _, x in { -width / 2 + 0.3, -width / 6, width / 6, width / 2 - 0.3 } do
		Build.block(hub, "Beam", Vector3.new(0.6, height, 0.4), at(x, 1 + height / 2, front - 0.15), WOOD_DARK, M.Wood)
	end
	for _, y in { 1.3, 1 + height / 2, 1 + height - 0.3 } do
		Build.block(hub, "Beam", Vector3.new(width, 0.6, 0.4), at(0, y, front - 0.15), WOOD_DARK, M.Wood)
	end
	for _, side in { -1, 1 } do
		local outer = side * (width / 2 - 0.3)
		local inner = side * width / 6
		Build.beam(hub, "Brace", at(outer, 1 + height / 2, front - 0.15).Position, at(inner, 1 + height - 0.3, front - 0.15).Position, 0.45, WOOD_DARK, M.Wood)
		-- Corner posts on the back
		Build.block(hub, "Beam", Vector3.new(0.6, height, 0.6), at(outer, 1 + height / 2, depth / 2), WOOD_DARK, M.Wood)
	end

	-- Door and windows
	Build.block(hub, "Door", Vector3.new(3, 5.5, 0.5), at(0, 1 + 2.75, front - 0.2), WOOD, M.WoodPlanks)
	Build.block(hub, "DoorHandle", Vector3.new(0.3, 0.3, 0.3), at(0.9, 3.8, front - 0.5), IRON, M.Metal)
	local windowSpots = {
		{ -width / 3, 1 + height / 4 },
		{ width / 3, 1 + height / 4 },
		{ -width / 3, 1 + height * 0.75 },
		{ 0, 1 + height * 0.75 },
		{ width / 3, 1 + height * 0.75 },
	}
	for _, spot in windowSpots do
		local glass = Build.block(hub, "Window", Vector3.new(2.2, 2.4, 0.3), at(spot[1], spot[2], front - 0.2), WARM_LIGHT, M.Neon)
		glass.Transparency = 0.3
		Build.block(hub, "WindowBar", Vector3.new(0.2, 2.4, 0.35), at(spot[1], spot[2], front - 0.25), WOOD_DARK, M.Wood)
		Build.block(hub, "WindowSill", Vector3.new(2.8, 0.3, 0.6), at(spot[1], spot[2] - 1.3, front - 0.3), WOOD_DARK, M.Wood)
	end
	local glow = Build.block(hub, "InteriorGlow", Vector3.new(1, 1, 1), at(0, 1 + height / 2, front + 1.5), WARM_LIGHT, M.SmoothPlastic)
	glow.Transparency = 1
	glow.CanCollide = false
	Build.light(glow, WARM_LIGHT, 14, 1.2)

	-- Gable roof: two sloped slabs, a ridge beam, and stepped gable ends underneath
	local rise = depth * 0.5
	local angle = math.atan2(rise, depth / 2)
	local slant = math.sqrt((depth / 2) ^ 2 + rise ^ 2) + 1.5
	local eave = 1 + height
	for _, side in { -1, 1 } do
		Build.block(hub, "Roof", Vector3.new(width + 2, 0.8, slant), at(0, eave + rise / 2, side * depth / 4) * CFrame.Angles(side * angle, 0, 0), roofColor, M.Slate)
	end
	Build.block(hub, "Ridge", Vector3.new(width + 2.2, 0.9, 0.9), at(0, eave + rise, 0), WOOD_DARK, M.Wood)
	local steps = 6
	for i = 0, steps - 1 do
		local stepDepth = depth * (1 - (i + 1) / steps)
		if stepDepth > 0.2 then
			Build.block(hub, "Gable", Vector3.new(width, rise / steps, stepDepth), at(0, eave + rise / steps * (i + 0.5), 0), PLASTER, M.Plaster)
		end
	end
	Build.block(hub, "Chimney", Vector3.new(1.8, rise + 3, 1.8), at(width / 3, eave + (rise + 3) / 2, depth / 6), rgb(140, 70, 55), M.Brick)

	if signText then
		Build.block(hub, "SignArm", Vector3.new(0.3, 0.3, 2.4), at(width / 2 - 1.5, 1 + height / 2 + 2.5, front - 1.2), IRON, M.Metal)
		local sign = Build.block(hub, "Sign", Vector3.new(4.5, 2.2, 0.3), at(width / 2 - 1.5, 1 + height / 2 + 1, front - 2.2) * CFrame.Angles(0, math.rad(90), 0), WOOD, M.WoodPlanks)
		Build.label(sign, signText, rgb(255, 220, 140))
		-- Same text on the back so it reads from both directions
		local back = Build.block(hub, "SignBack", Vector3.new(4.5, 2.2, 0.05), sign.CFrame * CFrame.new(0, 0, 0.18) * CFrame.Angles(0, math.rad(180), 0), WOOD, M.WoodPlanks)
		Build.label(back, signText, rgb(255, 220, 140))
	end
end

local function marketStall(cframe: CFrame, clothColor: Color3, goods: { Color3 })
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	Build.block(hub, "Counter", Vector3.new(9, 3, 3), at(0, 1.5, 0), WOOD, M.WoodPlanks)
	for _, x in { -4.2, 4.2 } do
		Build.block(hub, "Post", Vector3.new(0.6, 8, 0.6), at(x, 4, 1.8), WOOD_DARK, M.Wood)
		Build.block(hub, "Post", Vector3.new(0.6, 9.5, 0.6), at(x, 4.75, -1.4), WOOD_DARK, M.Wood)
	end
	local cloth = Build.block(hub, "Awning", Vector3.new(10, 0.3, 5), at(0, 9.2, 0.2) * CFrame.Angles(math.rad(-15), 0, 0), clothColor, M.Fabric)
	cloth.CanCollide = false
	for i, color in goods do
		local x = -3.5 + (i - 1) * (7 / math.max(#goods - 1, 1))
		Build.ball(hub, "Goods", 1.1, at(x, 3.55, -0.2).Position, color, M.SmoothPlastic)
	end
end

-- Areas ---------------------------------------------------------------------------

local function buildGround()
	Build.block(hub, "Plaza", Vector3.new(EAST - WEST, 0.4, SOUTH - NORTH), CFrame.new((WEST + EAST) / 2, 0, (NORTH + SOUTH) / 2), rgb(128, 122, 112), M.Cobblestone)
	-- Main roads (slightly raised so they don't flicker against the plaza)
	local road = rgb(98, 92, 86)
	Build.block(hub, "Road", Vector3.new(12, 0.1, SOUTH - NORTH + 4), CFrame.new(0, 0.25, (NORTH + SOUTH) / 2 + 6), road, M.Pavement)
	Build.block(hub, "Road", Vector3.new(EAST - WEST - 30, 0.1, 10), CFrame.new(0, 0.25, 0), road, M.Pavement)
end

local function buildWalls()
	local inset = WALL_THICKNESS / 2
	wall(Vector3.new(WEST + 6, 0, NORTH), Vector3.new(EAST - 6, 0, NORTH))
	wall(Vector3.new(WEST, 0, NORTH + 6), Vector3.new(WEST, 0, SOUTH - 6))
	wall(Vector3.new(EAST, 0, NORTH + 6), Vector3.new(EAST, 0, SOUTH - 6))
	wall(Vector3.new(WEST + 6, 0, SOUTH), Vector3.new(-18, 0, SOUTH))
	wall(Vector3.new(18, 0, SOUTH), Vector3.new(EAST - 6, 0, SOUTH))

	for _, corner in { Vector3.new(WEST, 0, NORTH), Vector3.new(EAST, 0, NORTH), Vector3.new(WEST, 0, SOUTH), Vector3.new(EAST, 0, SOUTH) } do
		squareTower(corner, 12, 28, BANNER_RED)
	end

	-- Gatehouse: two towers, an arch, and a lowered portcullis
	for _, x in { -14, 14 } do
		squareTower(Vector3.new(x, 0, SOUTH), 8, 26, nil)
	end
	Build.block(hub, "GateArch", Vector3.new(20, 6, 6), CFrame.new(0, 17, SOUTH), STONE, M.Cobblestone)
	battlements(hub, Vector3.new(-10, 20, SOUTH), Vector3.new(10, 20, SOUTH), 6)
	-- The portcullis is raised: only its bottom spikes show under the arch.
	for x = -9, 9, 1.5 do
		Build.block(hub, "PortcullisBar", Vector3.new(0.4, 3, 0.4), CFrame.new(x, 12.5, SOUTH), IRON, M.Metal)
	end
	Build.block(hub, "PortcullisBar", Vector3.new(19, 0.4, 0.4), CFrame.new(0, 13.5, SOUTH), IRON, M.Metal)

	-- Torches along the inside of the walls
	for _, x in { -60, -24, 24, 60 } do
		wallTorch(Vector3.new(x, 10, NORTH + inset + 0.1), Vector3.zAxis)
	end
	for _, z in { -29, 3, 29 } do
		wallTorch(Vector3.new(WEST + inset + 0.1, 10, z), Vector3.xAxis)
		wallTorch(Vector3.new(EAST - inset - 0.1, 10, z), -Vector3.xAxis)
	end
	for _, x in { -8, 8 } do
		wallTorch(Vector3.new(x * 1.6, 9, SOUTH - 4.1), -Vector3.zAxis)
	end

	-- Banners on the north wall, between the dungeon portals
	for _, x in { -48, -16, 16, 48 } do
		banner(Vector3.new(x, 16, NORTH + inset + 0.05), Vector3.zAxis, BANNER_RED)
	end

	-- Stone crest above the middle of the north wall with the game's name on it
	Build.block(hub, "Crest", Vector3.new(36, 10, WALL_THICKNESS), CFrame.new(0, WALL_HEIGHT + 4, NORTH), STONE, M.Cobblestone)
	battlements(hub, Vector3.new(-17, WALL_HEIGHT + 9, NORTH), Vector3.new(17, WALL_HEIGHT + 9, NORTH), WALL_THICKNESS)
	local signZ = NORTH + inset + 0.5
	local trim = Build.block(hub, "TitleSignTrim", Vector3.new(31, 6.4, 0.4), CFrame.lookAt(Vector3.new(0, WALL_HEIGHT + 4, signZ - 0.3), Vector3.new(0, WALL_HEIGHT + 4, 0)), GOLD, M.Metal)
	local sign = Build.block(hub, "TitleSign", Vector3.new(30, 5.6, 0.4), trim.CFrame * CFrame.new(0, 0, -0.3), WOOD_DARK, M.WoodPlanks)
	Build.label(sign, "DUNGEON DELVERS", GOLD)
end

local function buildKeep()
	local z = NORTH - 30
	Build.block(hub, "Keep", Vector3.new(60, 34, 30), CFrame.new(0, 17, z), STONE, M.Cobblestone)
	Build.block(hub, "KeepTrim", Vector3.new(61, 1.2, 31), CFrame.new(0, 33.4, z), STONE_DARK, M.Slate)
	battlements(hub, Vector3.new(-30, 34, z + 15), Vector3.new(30, 34, z + 15), 2)
	-- Lit windows facing the town
	for _, x in { -20, -10, 0, 10, 20 } do
		local glass = Build.block(hub, "KeepWindow", Vector3.new(2.5, 4.5, 0.3), CFrame.new(x, 25, z + 15.1), WARM_LIGHT, M.Neon)
		glass.Transparency = 0.25
	end
	for _, x in { -30, 30 } do
		roundTower(Vector3.new(x, 0, z), 14, 46, rgb(50, 60, 95))
	end
	roundTower(Vector3.new(0, 34, z - 4), 12, 20, rgb(50, 60, 95))
end

local function buildFountain()
	local center = Vector3.new(0, 0, -20)
	Build.cylinder(hub, "FountainRim", 15, 2, CFrame.new(center + Vector3.new(0, 1, 0)), STONE, M.Limestone)
	local water = Build.cylinder(hub, "FountainWater", 13.6, 0.3, CFrame.new(center + Vector3.new(0, 1.8, 0)), rgb(70, 140, 190), M.Glass)
	water.Transparency = 0.25
	Build.cylinder(hub, "FountainColumn", 2, 6, CFrame.new(center + Vector3.new(0, 4, 0)), STONE, M.Limestone)
	Build.cylinder(hub, "FountainBasin", 6, 0.8, CFrame.new(center + Vector3.new(0, 6.6, 0)), STONE, M.Limestone)
	local topWater = Build.cylinder(hub, "FountainTopWater", 5.2, 0.2, CFrame.new(center + Vector3.new(0, 7.05, 0)), rgb(70, 140, 190), M.Glass)
	topWater.Transparency = 0.25
	local orb = Build.ball(hub, "FountainOrb", 1.6, center + Vector3.new(0, 8, 0), GOLD, M.Metal)

	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(200, 230, 255))
	spray.LightEmission = 0.3
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Rate = 80
	spray.Speed = NumberRange.new(8, 11)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -28, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = orb

	-- Benches around it
	for _, degrees in { 45, 135, 225, 315 } do
		local angle = math.rad(degrees)
		local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 12
		local facing = CFrame.lookAt(position, center)
		Build.block(hub, "BenchSeat", Vector3.new(5, 0.4, 1.6), facing * CFrame.new(0, 1.6, 0), WOOD, M.WoodPlanks)
		Build.block(hub, "BenchBack", Vector3.new(5, 1.6, 0.3), facing * CFrame.new(0, 2.6, 0.8), WOOD, M.WoodPlanks)
		for _, x in { -2, 2 } do
			Build.block(hub, "BenchLeg", Vector3.new(0.4, 1.4, 1.4), facing * CFrame.new(x, 0.7, 0), IRON, M.Metal)
		end
	end
end

local function buildHouses()
	local roofs = { rgb(140, 60, 45), rgb(70, 75, 90), rgb(120, 85, 50), rgb(95, 50, 50) }
	-- West side, facing east (+X)
	local west = { { z = -42, w = 16 }, { z = 16, w = 16 }, { z = 40, w = 14 } }
	for i, spot in west do
		local position = Vector3.new(WEST + 12, 0, spot.z)
		house(CFrame.lookAt(position, position + Vector3.xAxis), spot.w, 12, 10, roofs[i], nil)
	end
	-- The tavern: bigger, with a sign and tables out front
	local tavernPosition = Vector3.new(WEST + 13, 0, -13)
	house(CFrame.lookAt(tavernPosition, tavernPosition + Vector3.xAxis), 22, 14, 12, rgb(110, 45, 40), "The Rusty Tankard")
	for _, z in { -20, -6 } do
		local tablePosition = Vector3.new(-44, 0, z)
		Build.cylinder(hub, "TableTop", 4, 0.4, CFrame.new(tablePosition + Vector3.new(0, 3, 0)), WOOD, M.WoodPlanks)
		Build.cylinder(hub, "TableLeg", 0.8, 3, CFrame.new(tablePosition + Vector3.new(0, 1.5, 0)), WOOD_DARK, M.Wood)
		for _, offset in { Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3) } do
			Build.cylinder(hub, "Stool", 1.6, 1.8, CFrame.new(tablePosition + offset + Vector3.new(0, 0.9, 0)), WOOD, M.WoodPlanks)
		end
		Build.cylinder(hub, "Mug", 0.6, 0.8, CFrame.new(tablePosition + Vector3.new(0.6, 3.6, 0.4)), rgb(200, 190, 170), M.SmoothPlastic)
	end
	barrel(Vector3.new(-48, 0, -27))
	barrel(Vector3.new(-48, 0, 1))

	-- East side, facing west (-X)
	local east = { { z = -42, sign = "Blacksmith" }, { z = -14 }, { z = 18 }, { z = 42 } }
	for i, spot in ipairs(east) do
		local position = Vector3.new(EAST - 12, 0, spot.z)
		house(CFrame.lookAt(position, position - Vector3.xAxis), 16, 12, 10, roofs[(i % #roofs) + 1], spot.sign)
	end
end

local function buildBlacksmith()
	local base = Vector3.new(44, 0, -40)
	Build.block(hub, "Forge", Vector3.new(5, 3.5, 4), CFrame.new(base + Vector3.new(0, 1.75, 0)), rgb(140, 70, 55), M.Brick)
	local coals = Build.block(hub, "Coals", Vector3.new(3.6, 0.4, 2.6), CFrame.new(base + Vector3.new(0, 3.6, 0)), rgb(255, 110, 30), M.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Parent = coals
	Build.light(coals, rgb(255, 120, 40), 20, 2.5)
	Build.block(hub, "ForgeChimney", Vector3.new(2, 9, 2), CFrame.new(base + Vector3.new(0, 7.5, 1.4)), rgb(120, 60, 50), M.Brick)

	local anvil = base + Vector3.new(-6, 0, 2)
	Build.block(hub, "AnvilBase", Vector3.new(1.4, 2, 1.4), CFrame.new(anvil + Vector3.new(0, 1, 0)), WOOD_DARK, M.Wood)
	Build.block(hub, "Anvil", Vector3.new(1.2, 0.9, 3), CFrame.new(anvil + Vector3.new(0, 2.45, 0)), IRON, M.Metal)
	Build.block(hub, "AnvilHorn", Vector3.new(0.7, 0.6, 1.2), CFrame.new(anvil + Vector3.new(0, 2.6, -2)), IRON, M.Metal)

	-- Weapon rack
	local rack = base + Vector3.new(-1, 0, 6)
	Build.block(hub, "Rack", Vector3.new(6, 0.4, 0.6), CFrame.new(rack + Vector3.new(0, 4, 0)), WOOD, M.Wood)
	Build.block(hub, "Rack", Vector3.new(6, 0.4, 0.6), CFrame.new(rack + Vector3.new(0, 1, 0)), WOOD, M.Wood)
	for i, x in { -2, -0.7, 0.7, 2 } do
		Build.block(hub, "RackSword", Vector3.new(0.2, 4.5, 0.5), CFrame.new(rack + Vector3.new(x, 2.6, -0.4)) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 6 else -6)), rgb(190, 195, 205), M.Metal)
	end
	barrel(base + Vector3.new(4, 0, 4))
	crate(base + Vector3.new(5, 0, -3), 2.5, 15)
end

local function buildMarket()
	local stall = Vector3.new(38, 0, 28)
	marketStall(CFrame.lookAt(stall, stall - Vector3.xAxis), rgb(40, 110, 70), { rgb(220, 60, 50), rgb(240, 200, 60), rgb(120, 200, 80), rgb(230, 130, 40) })
	crate(Vector3.new(44, 0, 24), 2.5, 10)
	crate(Vector3.new(44, 0, 33), 2.2, -20)
	crate(Vector3.new(44.4, 2.5, 24), 1.8, 40)
	barrel(Vector3.new(42, 0, 36))
	barrel(Vector3.new(34, 0, -6))
	crate(Vector3.new(35, 0, 15), 2, 25)
end

local function buildDecor()
	for _, position in {
		Vector3.new(-12, 0, -6),
		Vector3.new(12, 0, -6),
		Vector3.new(-12, 0, 12),
		Vector3.new(12, 0, 12),
		Vector3.new(-30, 0, -30),
		Vector3.new(30, 0, -30),
		Vector3.new(-30, 0, 30),
		Vector3.new(30, 0, 30),
		Vector3.new(-9, 0, 44),
		Vector3.new(9, 0, 44),
	} do
		lampPost(position)
	end

	tree(Vector3.new(-20, 0, 47), 1.1)
	tree(Vector3.new(20, 0, 47), 1)
	tree(Vector3.new(-55, 0, -62), 0.9)
	tree(Vector3.new(55, 0, -62), 0.9)

	-- Notice board next to the spawn with how-to-play tips
	local boardPosition = Vector3.new(-16, 0, 2)
	local facing = CFrame.lookAt(boardPosition, Vector3.new(0, 0, 2))
	for _, x in { -3.4, 3.4 } do
		Build.block(hub, "BoardPost", Vector3.new(0.6, 8, 0.6), facing * CFrame.new(x, 4, 0), WOOD_DARK, M.Wood)
	end
	Build.block(hub, "BoardRoof", Vector3.new(8, 0.4, 2), facing * CFrame.new(0, 8.2, 0) * CFrame.Angles(math.rad(10), 0, 0), WOOD_DARK, M.WoodPlanks)
	local board = Build.block(hub, "NoticeBoard", Vector3.new(6.4, 4.6, 0.3), facing * CFrame.new(0, 5, 0), rgb(170, 135, 90), M.WoodPlanks)
	local text = Build.label(board, table.concat({
		"ADVENTURERS WANTED",
		"",
		"Stand on a portal to enter a dungeon",
		"Click to attack   1: draw / sheathe weapon",
		"Q / E: abilities   2-6: potions   G: gear",
		"Shift: sprint   C: dodge",
		"Training grounds: through the south gate",
	}, "\n"), rgb(50, 30, 20), Enum.Font.Fantasy)
	text.TextScaled = true
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = text

	-- Spawn platform trim
	Build.cylinder(hub, "SpawnRing", 17, 0.6, CFrame.new(0, 0.3, 0), STONE_DARK, M.Slate)
end

local function setupLighting()
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2.2
	Lighting.Ambient = rgb(60, 52, 48)
	Lighting.OutdoorAmbient = rgb(135, 118, 100)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = rgb(255, 215, 175)
	atmosphere.Decay = rgb(120, 90, 80)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.TintColor = rgb(255, 242, 228)
	color.Saturation = 0.1
	color.Contrast = 0.05
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Parent = Lighting
end

function HubService.Start()
	hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = workspace

	setupLighting()
	buildGround()
	buildWalls()
	buildKeep()
	buildFountain()
	buildHouses()
	buildBlacksmith()
	buildMarket()
	buildDecor()
end

return HubService
