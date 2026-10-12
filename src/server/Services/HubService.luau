-- Builds the medieval town hub around the spawn: walls, towers, gatehouse, castle keep,
-- timber-framed houses, tavern, blacksmith, market, fountain, lamps, banners and lighting.
--
-- Layout (top-down, north = -Z):
--
--                    [ castle keep ]
--   +------------------- north wall --------------------+
--   |  portal  portal  portal  portal  portal  portal   |   <- DungeonService (portal plaza)
--   |  gardens + mage tower    hero statue    chapel     |
--   |  houses        fountain                blacksmith  |
--   |  tavern          SPAWN       shop   market square |   <- ShopService (potion shop)
--   |  windmill farm   hall of heroes        houses      |
--   +----------------- gatehouse (south) ---------------+
--                  [ training grounds ]                     <- TrainingService
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
local WEST, EAST = -120, 120
local NORTH, SOUTH = -120, 56
local PORTAL_Z = -92 -- keep in sync with DungeonService
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
	local chimney = Build.block(hub, "Chimney", Vector3.new(1.8, rise + 3, 1.8), at(width / 3, eave + (rise + 3) / 2, depth / 6), rgb(140, 70, 55), M.Brick)
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(170, 165, 160)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 3
	smoke.Size = 2
	local smokeAnchor = Build.block(hub, "SmokeAnchor", Vector3.new(0.5, 0.5, 0.5), chimney.CFrame * CFrame.new(0, chimney.Size.Y / 2, 0), rgb(0, 0, 0), M.SmoothPlastic)
	smokeAnchor.Transparency = 1
	smokeAnchor.CanCollide = false
	smoke.Parent = smokeAnchor
	-- Flower boxes under the lower windows
	for _, x in { -width / 3, width / 3 } do
		Build.block(hub, "FlowerBox", Vector3.new(2.6, 0.6, 0.8), at(x, 1 + height / 4 - 1.7, front - 0.6), WOOD_DARK, M.Wood)
		for k = -1, 1 do
			local bloom = Build.ball(hub, "Flower", 0.6, at(x + k * 0.8, 1 + height / 4 - 1.2, front - 0.6).Position, ({ rgb(230, 70, 90), rgb(250, 210, 70), rgb(200, 120, 230) })[k + 2], M.SmoothPlastic)
			bloom.CanCollide = false
		end
	end

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
	local curb = rgb(150, 145, 135)
	Build.block(hub, "Road", Vector3.new(12, 0.1, SOUTH - NORTH + 4), CFrame.new(0, 0.25, (NORTH + SOUTH) / 2 + 6), road, M.Pavement)
	Build.block(hub, "Road", Vector3.new(EAST - WEST - 30, 0.1, 10), CFrame.new(0, 0.25, 0), road, M.Pavement)
	for _, side in { -1, 1 } do
		Build.block(hub, "Curb", Vector3.new(0.8, 0.3, SOUTH - NORTH - 40), CFrame.new(side * 6.4, 0.3, (NORTH + SOUTH) / 2 + 12), curb, M.Limestone)
	end
	-- Circular plaza around the fountain
	Build.cylinder(hub, "FountainPlaza", 40, 0.12, CFrame.new(0, 0.26, -20), rgb(165, 155, 140), M.Limestone)
	Build.cylinder(hub, "FountainPlazaRing", 42, 0.1, CFrame.new(0, 0.24, -20), rgb(110, 100, 90), M.Slate)
	-- Portal plaza: a marble terrace along the north wall
	Build.block(hub, "PortalTerrace", Vector3.new(EAST - WEST - 30, 0.12, 34), CFrame.new(0, 0.26, PORTAL_Z - 2), rgb(205, 200, 190), M.Marble)
	Build.block(hub, "PortalTerraceTrim", Vector3.new(EAST - WEST - 28, 0.14, 1.2), CFrame.new(0, 0.27, PORTAL_Z + 15.4), GOLD, M.Metal)
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
	for _, x in { -104, -76, -44, 44, 76, 104 } do
		wallTorch(Vector3.new(x, 10, NORTH + inset + 0.1), Vector3.zAxis)
	end
	-- Towers partway along the long walls
	for _, x in { -60, 60 } do
		roundTower(Vector3.new(x, 0, NORTH), 11, 30, rgb(50, 60, 95))
	end
	for _, x in { WEST, EAST } do
		roundTower(Vector3.new(x, 0, -32), 11, 30, rgb(50, 60, 95))
	end
	for _, z in { -92, -64, -8, 22, 44 } do
		wallTorch(Vector3.new(WEST + inset + 0.1, 10, z), Vector3.xAxis)
		wallTorch(Vector3.new(EAST - inset - 0.1, 10, z), -Vector3.xAxis)
	end
	for _, x in { -8, 8 } do
		wallTorch(Vector3.new(x * 1.6, 9, SOUTH - 4.1), -Vector3.zAxis)
	end

	-- Banners on the north wall, between the dungeon portals
	for _, x in { -96, -32, 32, 96 } do
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
	local west = { { z = -66, w = 16 }, { z = -42, w = 16 }, { z = 16, w = 16 } }
	for i, spot in west do
		local position = Vector3.new(WEST + 12, 0, spot.z)
		house(CFrame.lookAt(position, position + Vector3.xAxis), spot.w, 12, 10, roofs[i], nil)
	end
	-- The tavern: bigger, with a sign and tables out front
	local tavernPosition = Vector3.new(WEST + 13, 0, -13)
	-- South row, facing north into town
	for i, x in { 72, 96 } do
		local position = Vector3.new(x, 0, SOUTH - 10)
		house(CFrame.lookAt(position, position - Vector3.zAxis), 16, 11, 10, roofs[(i % #roofs) + 1], if x == 96 then "Inn" else nil)
	end
	house(CFrame.lookAt(tavernPosition, tavernPosition + Vector3.xAxis), 22, 14, 12, rgb(110, 45, 40), "The Rusty Tankard")
	for _, z in { -20, -6 } do
		local tablePosition = Vector3.new(WEST + 28, 0, z)
		Build.cylinder(hub, "TableTop", 4, 0.4, CFrame.new(tablePosition + Vector3.new(0, 3, 0)), WOOD, M.WoodPlanks)
		Build.cylinder(hub, "TableLeg", 0.8, 3, CFrame.new(tablePosition + Vector3.new(0, 1.5, 0)), WOOD_DARK, M.Wood)
		for _, offset in { Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3) } do
			Build.cylinder(hub, "Stool", 1.6, 1.8, CFrame.new(tablePosition + offset + Vector3.new(0, 0.9, 0)), WOOD, M.WoodPlanks)
		end
		Build.cylinder(hub, "Mug", 0.6, 0.8, CFrame.new(tablePosition + Vector3.new(0.6, 3.6, 0.4)), rgb(200, 190, 170), M.SmoothPlastic)
	end
	barrel(Vector3.new(WEST + 24, 0, -27))
	barrel(Vector3.new(WEST + 24, 0, 1))

	-- East side, facing west (-X)
	local east = { { z = -66 }, { z = -42, sign = "Blacksmith" }, { z = -14 }, { z = 18 } }
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
		-- Along the main roads
		Vector3.new(-9, 0, -40),
		Vector3.new(9, 0, -40),
		Vector3.new(-9, 0, -64),
		Vector3.new(9, 0, -64),
		Vector3.new(-56, 0, -8),
		Vector3.new(-56, 0, 8),
		Vector3.new(-90, 0, -8),
		Vector3.new(-90, 0, 8),
		Vector3.new(56, 0, -8),
		Vector3.new(90, 0, -8),
	} do
		lampPost(position)
	end

	tree(Vector3.new(-20, 0, 47), 1.1)
	tree(Vector3.new(20, 0, 47), 1)
	for _, position in {
		Vector3.new(-40, 0, -46), Vector3.new(40, 0, -60), Vector3.new(100, 0, -28),
		Vector3.new(-52, 0, 18), Vector3.new(50, 0, -14), Vector3.new(-110, 0, 32), Vector3.new(110, 0, 34),
	} do
		tree(position, 0.9 + (math.abs(position.X) % 3) * 0.1)
	end

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
		"R: weapon ability   Training: south gate",
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


-- Districts ------------------------------------------------------------------------

local FLOWER_COLORS = { rgb(230, 70, 90), rgb(250, 210, 70), rgb(200, 120, 230), rgb(255, 255, 255), rgb(255, 140, 60), rgb(110, 160, 255) }

local function flowerBed(center: Vector3, width: number, depth: number, seed: number)
	local rng = Random.new(seed)
	Build.block(hub, "FlowerBedEdge", Vector3.new(width + 1, 0.8, depth + 1), CFrame.new(center + Vector3.new(0, 0.4, 0)), STONE_DARK, M.Cobblestone)
	Build.block(hub, "FlowerBedSoil", Vector3.new(width, 0.9, depth), CFrame.new(center + Vector3.new(0, 0.45, 0)), rgb(80, 60, 40), M.Ground)
	for _ = 1, math.floor(width * depth / 3) do
		local p = center + Vector3.new(rng:NextNumber(-width / 2 + 0.5, width / 2 - 0.5), 1.1, rng:NextNumber(-depth / 2 + 0.5, depth / 2 - 0.5))
		local stem = Build.block(hub, "Stem", Vector3.new(0.15, 0.6, 0.15), CFrame.new(p), rgb(60, 130, 50), M.Grass)
		stem.CanCollide = false
		local bloom = Build.ball(hub, "Flower", rng:NextNumber(0.45, 0.7), p + Vector3.new(0, 0.35, 0), FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], M.SmoothPlastic)
		bloom.CanCollide = false
	end
end

local function hedge(from: Vector3, to: Vector3)
	local center = (from + to) / 2
	local length = (to - from).Magnitude
	Build.block(hub, "Hedge", Vector3.new(2.4, 3, length), CFrame.lookAt(center, to) * CFrame.new(0, 1.5, 0), rgb(55, 105, 45), M.Grass)
end

local function bench(position: Vector3, lookAt: Vector3)
	local facing = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	Build.block(hub, "BenchSeat", Vector3.new(5, 0.4, 1.6), facing * CFrame.new(0, 1.6, 0), WOOD, M.WoodPlanks)
	Build.block(hub, "BenchBack", Vector3.new(5, 1.6, 0.3), facing * CFrame.new(0, 2.6, 0.8), WOOD, M.WoodPlanks)
	for _, x in { -2, 2 } do
		Build.block(hub, "BenchLeg", Vector3.new(0.4, 1.4, 1.4), facing * CFrame.new(x, 0.7, 0), IRON, M.Metal)
	end
end

local function cart(position: Vector3, yaw: number, cargo: Color3)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	Build.block(hub, "CartBed", Vector3.new(4, 1.6, 6), cf * CFrame.new(0, 2, 0), WOOD, M.WoodPlanks)
	for _, x in { -2.3, 2.3 } do
		Build.cylinder(hub, "CartWheel", 2.8, 0.4, cf * CFrame.new(x, 1.4, 1) * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, M.Wood)
	end
	Build.block(hub, "CartHandle", Vector3.new(0.3, 0.3, 4), cf * CFrame.new(-1, 2, -5), WOOD_DARK, M.Wood)
	Build.block(hub, "CartHandle", Vector3.new(0.3, 0.3, 4), cf * CFrame.new(1, 2, -5), WOOD_DARK, M.Wood)
	for i = 1, 4 do
		Build.ball(hub, "Cargo", 1.3, (cf * CFrame.new(((i % 2) - 0.5) * 1.6, 3.3, (i - 2.5) * 1.2)).Position, cargo, M.SmoothPlastic)
	end
end

local function hayBale(position: Vector3, yaw: number)
	Build.cylinder(hub, "HayBale", 3, 3.4, CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(yaw), math.rad(90)), rgb(220, 190, 100), M.Grass)
end

-- A tall knight statue between the fountain and the portals.
local function buildStatue()
	local base = Vector3.new(0, 0, -60)
	Build.block(hub, "StatueStep", Vector3.new(14, 1, 14), CFrame.new(base + Vector3.new(0, 0.5, 0)), STONE_DARK, M.Slate)
	Build.block(hub, "StatuePedestal", Vector3.new(9, 6, 9), CFrame.new(base + Vector3.new(0, 4, 0)), rgb(200, 195, 185), M.Marble)
	Build.block(hub, "StatuePedestalTrim", Vector3.new(9.6, 0.8, 9.6), CFrame.new(base + Vector3.new(0, 7.2, 0)), GOLD, M.Metal)
	local plaque = Build.block(hub, "StatuePlaque", Vector3.new(6, 2, 0.3), CFrame.new(base + Vector3.new(0, 4, 4.6)), GOLD, M.Metal)
	Build.label(plaque, "THE FIRST DELVER", rgb(60, 40, 20), Enum.Font.Fantasy)
	local bronze = rgb(150, 120, 80)
	local y = 7.6
	local function part(name: string, size: Vector3, cf: CFrame)
		Build.block(hub, name, size, CFrame.new(base + Vector3.new(0, y, 0)) * cf, bronze, M.Metal)
	end
	for _, x in { -1, 1 } do
		part("StatueLeg", Vector3.new(1.6, 6, 1.8), CFrame.new(x * 1.1, 3, 0))
		part("StatueArm", Vector3.new(1.4, 5, 1.4), CFrame.new(x * 3, 9.2, 0) * CFrame.Angles(0, 0, math.rad(x * 10)))
		part("StatuePauldron", Vector3.new(2.4, 1.2, 2.4), CFrame.new(x * 3, 11.6, 0))
	end
	part("StatueTorso", Vector3.new(4.4, 5, 2.4), CFrame.new(0, 8.5, 0))
	part("StatueHead", Vector3.new(2.2, 2.4, 2.2), CFrame.new(0, 12.4, 0))
	part("StatuePlume", Vector3.new(0.5, 1.6, 2.4), CFrame.new(0, 14.2, 0))
	part("StatueCape", Vector3.new(4.6, 8, 0.4), CFrame.new(0, 7.5, 1.5) * CFrame.Angles(math.rad(-8), 0, 0))
	-- A greatsword raised overhead
	part("StatueSword", Vector3.new(0.5, 9, 1.2), CFrame.new(3.3, 17, 0))
	part("StatueSwordGuard", Vector3.new(0.6, 0.6, 3), CFrame.new(3.3, 12.4, 0))
	local glow = Build.block(hub, "StatueSwordGlow", Vector3.new(0.55, 8.4, 0.2), CFrame.new(base + Vector3.new(3.3, y + 17.2, -0.62)), rgb(255, 230, 140), M.Neon)
	Build.light(glow, rgb(255, 220, 140), 24, 1.5)
	for _, corner in { Vector3.new(-6, 0, -6), Vector3.new(6, 0, -6), Vector3.new(-6, 0, 6), Vector3.new(6, 0, 6) } do
		local brazier = Build.cylinder(hub, "StatueBrazier", 1.6, 0.6, CFrame.new(base + corner + Vector3.new(0, 2.6, 0)), IRON, M.Metal)
		Build.block(hub, "StatueBrazierStand", Vector3.new(0.4, 2.3, 0.4), CFrame.new(base + corner + Vector3.new(0, 1.15, 0)), IRON, M.Metal)
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 5
		fire.Parent = brazier
		Build.light(brazier, WARM_LIGHT, 14, 1.4)
	end
end

-- Royal gardens (north-west): hedges, flower beds, a pond and the mage tower.
local function buildGardens()
	local c = Vector3.new(-78, 0, -52)
	Build.block(hub, "Lawn", Vector3.new(44, 0.12, 30), CFrame.new(c + Vector3.new(0, 0.27, 0)), rgb(85, 140, 65), M.Grass)
	hedge(c + Vector3.new(-22, 0, -15), c + Vector3.new(22, 0, -15))
	hedge(c + Vector3.new(-22, 0, -15), c + Vector3.new(-22, 0, 15))
	hedge(c + Vector3.new(22, 0, -15), c + Vector3.new(22, 0, 4))
	hedge(c + Vector3.new(-22, 0, 15), c + Vector3.new(4, 0, 15))
	-- Pond with lily pads
	local pond = c + Vector3.new(6, 0, 0)
	Build.cylinder(hub, "PondRim", 14, 0.8, CFrame.new(pond + Vector3.new(0, 0.4, 0)), STONE, M.Limestone)
	local water = Build.cylinder(hub, "Pond", 12.6, 0.3, CFrame.new(pond + Vector3.new(0, 0.7, 0)), rgb(60, 130, 170), M.Glass)
	water.Transparency = 0.2
	for i = 1, 5 do
		local angle = i * 1.3
		Build.cylinder(hub, "LilyPad", 1.4, 0.1, CFrame.new(pond + Vector3.new(math.cos(angle) * 3.5, 0.9, math.sin(angle) * 3.5)), rgb(70, 150, 60), M.Grass).CanCollide = false
	end
	flowerBed(c + Vector3.new(-12, 0, -8), 8, 4, 11)
	flowerBed(c + Vector3.new(-12, 0, 8), 8, 4, 12)
	flowerBed(c + Vector3.new(15, 0, -10), 6, 3, 13)
	bench(c + Vector3.new(6, 0, 9), pond)
	bench(c + Vector3.new(6, 0, -9), pond)
	tree(c + Vector3.new(-17, 0, 0), 1)

	-- Mage tower with glowing windows and orbiting crystals
	local towerAt = Vector3.new(-104, 0, -88)
	local purple = rgb(150, 90, 255)
	Build.cylinder(hub, "MageTower", 12, 36, CFrame.new(towerAt + Vector3.new(0, 18, 0)), rgb(90, 85, 110), M.Cobblestone)
	for i = 0, 7 do
		Build.cylinder(hub, "MageRoof", 15 - i * 1.8, 2, CFrame.new(towerAt + Vector3.new(0, 37 + i * 2, 0)), rgb(70, 40, 130), M.Slate)
	end
	for i = 0, 3 do
		local angle = i / 4 * math.pi * 2 + math.pi / 4
		local window = Build.block(hub, "MageWindow", Vector3.new(1.6, 3.4, 0.4), CFrame.new(towerAt + Vector3.new(math.cos(angle) * 6, 26, math.sin(angle) * 6)) * CFrame.Angles(0, -angle + math.pi / 2, 0), purple, M.Neon)
		window.Transparency = 0.2
	end
	local orb = Build.ball(hub, "MageOrb", 3, towerAt + Vector3.new(0, 56, 0), purple, M.Neon)
	Build.light(orb, purple, 40, 2)
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		local crystal = Build.block(hub, "MageCrystal", Vector3.new(1, 3, 1), CFrame.new(towerAt + Vector3.new(math.cos(angle) * 9, 44, math.sin(angle) * 9)) * CFrame.Angles(0, angle, math.rad(20)), rgb(200, 160, 255), M.Neon)
		crystal.CanCollide = false
	end
	local door = Build.block(hub, "MageDoor", Vector3.new(3, 6, 0.6), CFrame.lookAt(towerAt + Vector3.new(4.3, 3, 4.3), towerAt + Vector3.new(10, 3, 10)), WOOD_DARK, M.WoodPlanks)
	door.Name = "MageDoor"
end

-- A small stone chapel with a steeple and stained-glass windows (north-east).
local function buildChapel()
	local base = Vector3.new(86, 0, -60)
	local facing = CFrame.lookAt(base, base - Vector3.xAxis) -- front faces the town
	local function at(x: number, y: number, z: number): CFrame
		return facing * CFrame.new(x, y, z)
	end
	Build.block(hub, "ChapelFoundation", Vector3.new(19, 1, 27), at(0, 0.5, 0), STONE_DARK, M.Cobblestone)
	Build.block(hub, "Chapel", Vector3.new(18, 14, 26), at(0, 8, 0), rgb(200, 195, 185), M.Limestone)
	local angle = math.atan2(7, 9)
	local slant = math.sqrt(9 ^ 2 + 7 ^ 2) + 1
	for _, side in { -1, 1 } do
		Build.block(hub, "ChapelRoof", Vector3.new(slant, 0.8, 27), at(side * 4.5, 18.5, 0) * CFrame.Angles(0, 0, -side * angle), rgb(70, 75, 95), M.Slate)
		for _, z in { -7, 0, 7 } do
			local glass = Build.block(hub, "StainedGlass", Vector3.new(0.3, 6, 2.6), at(side * 9.05, 9, z), ({ rgb(220, 60, 60), rgb(60, 120, 230), rgb(240, 200, 60) })[(z / 7) + 2], M.Neon)
			glass.Transparency = 0.25
		end
	end
	-- Steeple over the door
	Build.block(hub, "Steeple", Vector3.new(7, 24, 7), at(0, 13, -13), rgb(200, 195, 185), M.Limestone)
	for i = 0, 5 do
		Build.block(hub, "SteepleRoof", Vector3.new(8 - i * 1.3, 2, 8 - i * 1.3), at(0, 26 + i * 2, -13), rgb(70, 75, 95), M.Slate)
	end
	Build.block(hub, "SteepleCross", Vector3.new(0.6, 4, 0.6), at(0, 39, -13), GOLD, M.Metal)
	Build.block(hub, "SteepleCross", Vector3.new(2.6, 0.6, 0.6), at(0, 39.6, -13), GOLD, M.Metal)
	local rose = Build.cylinder(hub, "RoseWindow", 4, 0.4, at(0, 18, -16.6) * CFrame.Angles(math.rad(90), 0, 0), rgb(200, 90, 230), M.Neon)
	rose.Transparency = 0.2
	Build.light(rose, rgb(220, 150, 255), 16, 1)
	Build.block(hub, "ChapelDoor", Vector3.new(4, 7, 0.6), at(0, 4.5, -16.6), WOOD, M.WoodPlanks)
	flowerBed((at(-7, 0, -18)).Position, 4, 2, 21)
	flowerBed((at(7, 0, -18)).Position, 4, 2, 22)
end

-- Market square (east): a ring of stalls around a well, with carts and crates.
local function buildMarketSquare()
	local c = Vector3.new(80, 0, 18)
	Build.cylinder(hub, "MarketSquare", 44, 0.12, CFrame.new(c + Vector3.new(0, 0.26, 0)), rgb(150, 135, 115), M.Brick)
	-- Well
	Build.cylinder(hub, "Well", 5, 3, CFrame.new(c + Vector3.new(0, 1.5, 0)), STONE, M.Cobblestone)
	local water = Build.cylinder(hub, "WellWater", 4, 0.2, CFrame.new(c + Vector3.new(0, 2.6, 0)), rgb(50, 110, 150), M.Glass)
	water.Transparency = 0.2
	for _, x in { -2.2, 2.2 } do
		Build.block(hub, "WellPost", Vector3.new(0.5, 5, 0.5), CFrame.new(c + Vector3.new(x, 5, 0)), WOOD_DARK, M.Wood)
	end
	Build.block(hub, "WellRoof", Vector3.new(6, 0.4, 4), CFrame.new(c + Vector3.new(0, 7.8, 0)), rgb(140, 60, 45), M.Slate)
	Build.block(hub, "WellCrank", Vector3.new(4.4, 0.4, 0.4), CFrame.new(c + Vector3.new(0, 6, 0)), WOOD, M.Wood)
	local stalls = {
		{ Angle = 0, Cloth = rgb(180, 50, 50), Goods = { rgb(220, 60, 50), rgb(240, 200, 60), rgb(120, 200, 80) } },
		{ Angle = 70, Cloth = rgb(50, 90, 170), Goods = { rgb(120, 170, 255), rgb(200, 200, 220), rgb(80, 120, 200) } },
		{ Angle = 140, Cloth = rgb(200, 160, 40), Goods = { rgb(255, 215, 80), rgb(230, 130, 40), rgb(160, 90, 40) } },
		{ Angle = 215, Cloth = rgb(120, 60, 150), Goods = { rgb(200, 120, 230), rgb(150, 90, 200), rgb(240, 240, 240) } },
		{ Angle = 285, Cloth = rgb(60, 140, 80), Goods = { rgb(90, 180, 80), rgb(200, 230, 120), rgb(230, 80, 90) } },
	}
	for _, stall in stalls do
		local angle = math.rad(stall.Angle)
		local position = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 15
		marketStall(CFrame.lookAt(position, c), stall.Cloth, stall.Goods)
	end
	cart(c + Vector3.new(-16, 0, -14), 30, rgb(220, 190, 100))
	barrel(c + Vector3.new(18, 0, -10))
	barrel(c + Vector3.new(19.5, 0, -7.5))
	crate(c + Vector3.new(-18, 0, 12), 2.4, 20)
	crate(c + Vector3.new(-16, 0, 14), 2, -10)
	-- String lights over the square
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		local lamp = Build.ball(hub, "StringLight", 0.6, c + Vector3.new(math.cos(angle) * 9, 10, math.sin(angle) * 9), WARM_LIGHT, M.Neon)
		lamp.CanCollide = false
	end
end

-- Windmill farm (south-west): a windmill with turning sails, crop rows and hay.
local function buildWindmill()
	local base = Vector3.new(-86, 0, 24)
	Build.cylinder(hub, "WindmillBase", 12, 18, CFrame.new(base + Vector3.new(0, 9, 0)), rgb(210, 200, 180), M.Plaster)
	for i = 0, 5 do
		Build.cylinder(hub, "WindmillRoof", 13.5 - i * 2, 1.6, CFrame.new(base + Vector3.new(0, 18.8 + i * 1.6, 0)), rgb(140, 60, 45), M.Slate)
	end
	Build.block(hub, "WindmillDoor", Vector3.new(3, 5, 0.5), CFrame.new(base + Vector3.new(6, 2.5, 0)) * CFrame.Angles(0, math.rad(90), 0), WOOD, M.WoodPlanks)
	local hubCenter = base + Vector3.new(6.6, 15, 0)
	local hubPart = Build.cylinder(hub, "WindmillHub", 2, 1.4, CFrame.new(hubCenter) * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, M.Wood)
	local sails = {}
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local sail = Build.block(hub, "WindmillSail", Vector3.new(0.3, 11, 2.6), CFrame.new(hubCenter + Vector3.new(0.5, 0, 0)) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 6, 0), rgb(235, 225, 200), M.Fabric)
		sail.CanCollide = false
		table.insert(sails, { Part = sail, Offset = (CFrame.new(hubCenter)):ToObjectSpace(sail.CFrame) })
	end
	-- Turn the sails slowly
	task.spawn(function()
		local angle = 0
		while hubPart.Parent do
			angle += 0.03
			local spin = CFrame.new(hubCenter) * CFrame.Angles(angle, 0, 0)
			for _, sail in sails do
				sail.Part.CFrame = spin * sail.Offset
			end
			task.wait(0.05)
		end
	end)
	-- Crop rows
	local field = Vector3.new(-62, 0, 44)
	Build.block(hub, "Field", Vector3.new(22, 0.3, 12), CFrame.new(field + Vector3.new(0, 0.3, 0)), rgb(95, 70, 45), M.Ground)
	for i = 0, 4 do
		for k = 0, 9 do
			local crop = Build.block(hub, "Crop", Vector3.new(0.8, 1.6, 0.8), CFrame.new(field + Vector3.new(-9.5 + k * 2.1, 1.2, -4.4 + i * 2.2)), if i % 2 == 0 then rgb(110, 170, 60) else rgb(220, 190, 80), M.Grass)
			crop.CanCollide = false
		end
	end
	hayBale(base + Vector3.new(10, 0, 10), 20)
	hayBale(base + Vector3.new(13, 0, 12), 70)
	hayBale(base + Vector3.new(11, 3, 11), 40)
	cart(base + Vector3.new(14, 0, -10), -60, rgb(220, 190, 100))
	-- Fence around the farm
	for i = 0, 6 do
		local x = -110 + i * 6
		Build.block(hub, "FencePost", Vector3.new(0.5, 3, 0.5), CFrame.new(x, 1.5, 51), WOOD_DARK, M.Wood)
		if i < 6 then
			Build.block(hub, "FenceRail", Vector3.new(6, 0.3, 0.3), CFrame.new(x + 3, 2.2, 51), WOOD, M.Wood)
		end
	end
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
	buildStatue()
	buildGardens()
	buildChapel()
	buildMarketSquare()
	buildWindmill()
end

return HubService
