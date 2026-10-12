-- The training grounds outside the south gate: practice dummies that show your damage
-- per second, an archery range for staffs and bows, and a sparring ring.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local EnemyService = require(script.Parent.EnemyService)

local TrainingService = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local WOOD = rgb(105, 72, 45)
local WOOD_DARK = rgb(62, 42, 28)
local STRAW = rgb(214, 180, 100)
local IRON = rgb(45, 45, 50)

-- Area bounds (just south of the town wall at z = 56)
local WEST, EAST = -50, 50
local NORTH, SOUTH = 58, 150

local area: Folder

local function palisade(from: Vector3, to: Vector3)
	local direction = (to - from).Unit
	local length = (to - from).Magnitude
	local count = math.floor(length / 1.6)
	for i = 0, count do
		local p = from + direction * (i * length / count)
		local height = 7 + (i % 3) * 0.6
		Build.cylinder(area, "Stake", 1.5, height, CFrame.new(p + Vector3.new(0, height / 2, 0)), WOOD, M.Wood)
		-- Sharpened tip
		Build.block(area, "StakeTip", Vector3.new(1, 1, 1), CFrame.new(p + Vector3.new(0, height + 0.2, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), WOOD, M.Wood)
	end
	-- Two cross rails holding it together
	for _, y in { 2, 5 } do
		Build.beam(area, "Rail", from + Vector3.new(0, y, 0), to + Vector3.new(0, y, 0), 0.5, WOOD_DARK, M.Wood)
	end
end

local function torchPost(position: Vector3)
	Build.block(area, "TorchPost", Vector3.new(0.6, 7, 0.6), CFrame.new(position + Vector3.new(0, 3.5, 0)), WOOD_DARK, M.Wood)
	local bowl = Build.block(area, "TorchBowl", Vector3.new(1.2, 0.6, 1.2), CFrame.new(position + Vector3.new(0, 7.2, 0)), IRON, M.Metal)
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 7
	fire.Parent = bowl
	Build.light(bowl, rgb(255, 170, 80), 22, 2)
end

local function hayBale(position: Vector3, yaw: number)
	Build.block(area, "HayBale", Vector3.new(4, 2.4, 2.6), CFrame.new(position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.rad(yaw), 0), STRAW, M.Fabric)
end

-- A straw dummy on a post. Returns the model (registered with EnemyService).
local function dummy(position: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "Training Dummy"
	local base = CFrame.lookAt(position, position + facing)

	Build.block(model, "Stand", Vector3.new(2.6, 0.6, 2.6), base * CFrame.new(0, 0.3, 0), WOOD_DARK, M.WoodPlanks)
	Build.block(model, "Post", Vector3.new(0.6, 4, 0.6), base * CFrame.new(0, 2.6, 0), WOOD, M.Wood)
	local body = Build.block(model, "HumanoidRootPart", Vector3.new(2.4, 3, 1.4), base * CFrame.new(0, 5.6, 0), STRAW, M.Fabric)
	Build.ball(model, "Head", 1.9, (base * CFrame.new(0, 8.1, 0)).Position, rgb(190, 160, 110), M.Fabric)
	Build.block(model, "Arms", Vector3.new(5.4, 0.5, 0.5), base * CFrame.new(0, 6.4, 0), WOOD, M.Wood)
	Build.block(model, "Rope", Vector3.new(2.5, 0.3, 1.5), base * CFrame.new(0, 4.6, 0), rgb(150, 120, 80), M.Fabric)
	-- Red target painted on its chest
	local target = Build.cylinder(model, "Target", 1.4, 0.1, base * CFrame.new(0, 5.8, -0.72) * CFrame.Angles(math.rad(90), 0, 0), rgb(200, 40, 40), M.SmoothPlastic)
	target.CanCollide = false
	model.PrimaryPart = body
	model.Parent = area
	EnemyService.RegisterDummy(model, "Training Dummy")
end

-- A round archery target on a wooden easel, facing `facing`.
local function archeryTarget(position: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "Archery Target"
	local base = CFrame.lookAt(position, position + facing)
	for _, x in { -1.6, 1.6 } do
		Build.block(model, "Leg", Vector3.new(0.5, 7, 0.5), base * CFrame.new(x, 3.4, 0.6) * CFrame.Angles(math.rad(-10), 0, 0), WOOD, M.Wood)
	end
	Build.block(model, "BackLeg", Vector3.new(0.5, 7, 0.5), base * CFrame.new(0, 3.2, 2) * CFrame.Angles(math.rad(20), 0, 0), WOOD, M.Wood)
	-- Disc faces the shooters: cylinders point along X, so turn them to face along Z.
	local face = base * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, math.rad(90), 0)
	local disc = Build.block(model, "HumanoidRootPart", Vector3.new(0.5, 6, 6), face, STRAW, M.Fabric)
	disc.Shape = Enum.PartType.Cylinder
	for i, color in { rgb(240, 240, 240), rgb(200, 40, 40), rgb(240, 240, 240), rgb(240, 200, 40) } do
		local ring = Build.block(model, "Ring", Vector3.new(0.52 + i * 0.02, 6 - i * 1.3, 6 - i * 1.3), face, color, M.SmoothPlastic)
		ring.Shape = Enum.PartType.Cylinder
		ring.CanCollide = false
	end
	local head = Build.block(model, "Head", Vector3.new(1, 1, 1), base * CFrame.new(0, 7.6, 0), WOOD, M.Wood)
	head.Transparency = 1
	head.CanCollide = false
	model.PrimaryPart = disc
	model.Parent = area
	EnemyService.RegisterDummy(model, "Archery Target")
end

local function sign(position: Vector3, facing: Vector3, text: string, width: number)
	local base = CFrame.lookAt(position, position + facing)
	for _, x in { -width / 2 + 0.4, width / 2 - 0.4 } do
		Build.block(area, "SignPost", Vector3.new(0.5, 6, 0.5), base * CFrame.new(x, 3, 0.2), WOOD_DARK, M.Wood)
	end
	local board = Build.block(area, "Sign", Vector3.new(width, 2.4, 0.3), base * CFrame.new(0, 4.6, 0), WOOD, M.WoodPlanks)
	Build.label(board, text, rgb(255, 225, 150))
end

local function build()
	area = Instance.new("Folder")
	area.Name = "TrainingGrounds"
	area.Parent = workspace

	-- Ground and the path from the gate
	Build.block(area, "Yard", Vector3.new(EAST - WEST, 0.4, SOUTH - NORTH), CFrame.new(0, 0, (NORTH + SOUTH) / 2), rgb(150, 120, 85), M.Ground)
	Build.block(area, "Path", Vector3.new(10, 0.1, 30), CFrame.new(0, 0.25, NORTH + 15), rgb(115, 100, 80), M.Pavement)

	-- Palisade fence on three sides (the town wall closes the fourth)
	palisade(Vector3.new(WEST, 0, NORTH), Vector3.new(WEST, 0, SOUTH))
	palisade(Vector3.new(EAST, 0, NORTH), Vector3.new(EAST, 0, SOUTH))
	palisade(Vector3.new(WEST, 0, SOUTH), Vector3.new(EAST, 0, SOUTH))

	-- Entrance arch
	local archZ = NORTH + 10
	for _, x in { -6, 6 } do
		Build.block(area, "ArchPost", Vector3.new(1.2, 12, 1.2), CFrame.new(x, 6, archZ), WOOD_DARK, M.Wood)
	end
	local beam = Build.block(area, "ArchBeam", Vector3.new(15, 2.6, 0.6), CFrame.lookAt(Vector3.new(0, 12.5, archZ), Vector3.new(0, 12.5, archZ - 1)), WOOD, M.WoodPlanks)
	Build.label(beam, "TRAINING GROUNDS", rgb(255, 220, 140))

	-- Melee dummies (west side), facing the path
	for row = 0, 1 do
		for col = 0, 2 do
			dummy(Vector3.new(-40 + col * 10, 0.2, 88 + row * 14), Vector3.xAxis)
		end
	end
	sign(Vector3.new(-30, 0, 78), Vector3.new(0, 0, -1), "Melee practice", 8)

	-- Archery range (east side): shoot from the line at z = 82, targets 40 studs away
	Build.block(area, "ShootingLine", Vector3.new(30, 0.12, 0.8), CFrame.new(30, 0.26, 82), rgb(235, 235, 235), M.SmoothPlastic)
	for _, x in { 19, 30, 41 } do
		archeryTarget(Vector3.new(x, 0.2, 122), Vector3.new(0, 0, -1))
		hayBale(Vector3.new(x, 0.2, 126), 0)
	end
	sign(Vector3.new(30, 0, 76), Vector3.new(0, 0, -1), "Archery & magic range", 10)

	-- Sparring ring of logs
	local ringCenter = Vector3.new(0, 0, 128)
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		local p = ringCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 12
		Build.cylinder(area, "RingLog", 1.4, 1, CFrame.lookAt(p, ringCenter) * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0), WOOD, M.Wood)
	end
	Build.block(area, "RingSand", Vector3.new(22, 0.1, 22), CFrame.new(ringCenter + Vector3.new(0, 0.26, 0)), rgb(210, 185, 135), M.Sand)

	-- Props
	for _, p in { Vector3.new(-44, 0, 70), Vector3.new(-44, 0, 140), Vector3.new(44, 0, 70), Vector3.new(44, 0, 140), Vector3.new(-12, 0, 100), Vector3.new(12, 0, 100) } do
		torchPost(p)
	end
	hayBale(Vector3.new(-44, 0.2, 110), 20)
	hayBale(Vector3.new(-44, 0.2, 116), -10)
	hayBale(Vector3.new(-43.6, 2.6, 113), 5)
	for i, z in { 92, 98 } do
		local rack = Vector3.new(-47, 0, z)
		Build.block(area, "Rack", Vector3.new(0.6, 0.4, 5), CFrame.new(rack + Vector3.new(0, 4, 0)), WOOD, M.Wood)
		Build.block(area, "Rack", Vector3.new(0.6, 0.4, 5), CFrame.new(rack + Vector3.new(0, 1, 0)), WOOD, M.Wood)
		for k, offset in { -1.6, -0.5, 0.6, 1.7 } do
			local color = if (i + k) % 2 == 0 then rgb(185, 190, 200) else WOOD
			Build.block(area, "PracticeWeapon", Vector3.new(0.5, 4.6, 0.2), CFrame.new(rack + Vector3.new(0.4, 2.6, offset)) * CFrame.Angles(math.rad(5), 0, 0), color, if color == WOOD then M.Wood else M.Metal)
		end
	end
	for _, x in { 22, 38 } do
		Build.cylinder(area, "Quiver", 1, 2.5, CFrame.new(x, 1.45, 84), rgb(120, 80, 45), M.Leather)
	end
end

function TrainingService.Start()
	build()
	-- Keep the spawn point in sync for the admin teleport
	assert(Config.TrainingSpawn.Z > NORTH and Config.TrainingSpawn.Z < SOUTH, "TrainingSpawn should be inside the grounds")
end

return TrainingService
