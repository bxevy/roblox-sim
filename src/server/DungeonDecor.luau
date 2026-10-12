-- Theme decorations for dungeon rooms. Each style (Crypt, Temple, Ice) adds props along
-- the walls and corners, leaving the middle of the room open for fighting.

local Build = require(script.Parent.Build)

local DungeonDecor = {}

local rgb = Color3.fromRGB
local M = Enum.Material

export type Room = { Center: Vector3, Size: number }

-- Helpers ----------------------------------------------------------------------

local function fire(part: BasePart, color: Color3, secondary: Color3, size: number)
	local f = Instance.new("Fire")
	f.Color = color
	f.SecondaryColor = secondary
	f.Size = size
	f.Heat = 6
	f.Parent = part
end

local function noCollide(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- Spots along the side walls (x = ±offset from the wall), spread along z.
local function sideSpots(room: Room, inset: number, count: number): { { Position: Vector3, Side: number } }
	local spots = {}
	local half = room.Size / 2
	for _, side in { -1, 1 } do
		for i = 1, count do
			local z = -half + room.Size * i / (count + 1)
			table.insert(spots, { Position = room.Center + Vector3.new(side * (half - inset), 0, z), Side = side })
		end
	end
	return spots
end

local function corners(room: Room, inset: number): { Vector3 }
	local h = room.Size / 2 - inset
	local c = room.Center
	return {
		c + Vector3.new(-h, 0, -h),
		c + Vector3.new(h, 0, -h),
		c + Vector3.new(-h, 0, h),
		c + Vector3.new(h, 0, h),
	}
end

-- A throne against the far (north) wall of the boss room.
local function throne(parent: Instance, room: Room, seat: Color3, trim: Color3, material: Enum.Material)
	local back = room.Center + Vector3.new(0, 0, room.Size / 2 - 5)
	Build.block(parent, "ThroneStep", Vector3.new(16, 1, 8), CFrame.new(back + Vector3.new(0, 0.5, 0)), trim, material)
	Build.block(parent, "ThroneSeat", Vector3.new(7, 4, 5), CFrame.new(back + Vector3.new(0, 3, 0.5)), seat, material)
	Build.block(parent, "ThroneBack", Vector3.new(7, 12, 1.5), CFrame.new(back + Vector3.new(0, 7, 2.5)), seat, material)
	for _, x in { -3.6, 3.6 } do
		Build.block(parent, "ThroneArm", Vector3.new(1, 2, 5), CFrame.new(back + Vector3.new(x, 5.5, 0.5)), trim, material)
	end
	Build.block(parent, "ThroneTop", Vector3.new(8, 1, 2), CFrame.new(back + Vector3.new(0, 13.5, 2.5)), trim, material)
end

-- Crypt --------------------------------------------------------------------------

local function crypt(parent: Instance, room: Room, isBoss: boolean, rng: Random)
	local stone = rgb(90, 88, 92)
	local bone = rgb(225, 220, 200)

	-- Stone coffins along the side walls
	for _, spot in sideSpots(room, 4, if isBoss then 3 else 2) do
		local p = spot.Position
		Build.block(parent, "Coffin", Vector3.new(3.4, 2.2, 7), CFrame.new(p + Vector3.new(0, 1.1, 0)), stone, M.Slate)
		local lidOffset = if rng:NextNumber() < 0.4 then Vector3.new(-spot.Side * 0.8, 0, 0.6) else Vector3.zero
		local lid = Build.block(parent, "CoffinLid", Vector3.new(3.8, 0.5, 7.4), CFrame.new(p + Vector3.new(0, 2.45, 0) + lidOffset) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), rgb(110, 105, 110), M.Slate)
		lid.Name = "CoffinLid"
		Build.block(parent, "Cross", Vector3.new(0.4, 0.2, 3), CFrame.new(p + Vector3.new(0, 2.8, 0) + lidOffset), rgb(150, 140, 120), M.Metal)
		Build.block(parent, "Cross", Vector3.new(1.8, 0.2, 0.4), CFrame.new(p + Vector3.new(0, 2.8, -0.6) + lidOffset), rgb(150, 140, 120), M.Metal)
	end

	-- Gravestones and bone piles in the corners
	for _, corner in corners(room, 5) do
		for i = 1, 3 do
			local p = corner + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			if i == 1 then
				local tilt = CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-10, 10)))
				Build.block(parent, "Gravestone", Vector3.new(2.4, 3, 0.6), CFrame.new(p + Vector3.new(0, 1.4, 0)) * tilt, stone, M.Rock)
			else
				for _ = 1, 4 do
					local b = Build.block(parent, "Bone", Vector3.new(0.35, 0.35, rng:NextNumber(1, 2)), CFrame.new(p + Vector3.new(rng:NextNumber(-1, 1), 0.25, rng:NextNumber(-1, 1))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), bone, M.SmoothPlastic)
					noCollide(b)
				end
				noCollide(Build.ball(parent, "Skull", 0.9, p + Vector3.new(0, 0.45, 0), bone, M.SmoothPlastic))
			end
		end
	end

	-- Cobwebs across the top corners
	for _, corner in corners(room, 1.5) do
		local web = Build.block(parent, "Cobweb", Vector3.new(7, 7, 0.05), CFrame.new(corner + Vector3.new(0, 19, 0)) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(0, 0, math.rad(45)), rgb(230, 230, 235), M.Fabric)
		web.Transparency = 0.75
		noCollide(web)
		local toCenter = (room.Center - corner) * Vector3.new(1, 0, 1)
		web.CFrame = CFrame.lookAt(corner + Vector3.new(0, 19, 0), corner + Vector3.new(0, 19, 0) + toCenter) * CFrame.Angles(0, 0, math.rad(45))
	end

	-- Candles with ghostly green flames
	for _, corner in corners(room, 3) do
		local candle = Build.cylinder(parent, "Candle", 0.5, 1.4, CFrame.new(corner + Vector3.new(0, 0.7, 0)), rgb(230, 225, 200), M.SmoothPlastic)
		noCollide(candle)
		fire(candle, rgb(120, 255, 120), rgb(40, 160, 60), 1.2)
		Build.light(candle, rgb(120, 255, 140), 14, 1)
	end

	-- Low green mist over the floor
	local mist = Build.block(parent, "Mist", Vector3.new(room.Size - 6, 0.2, room.Size - 6), CFrame.new(room.Center + Vector3.new(0, 0.2, 0)), rgb(0, 0, 0), M.SmoothPlastic)
	mist.Transparency = 1
	noCollide(mist)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Color = ColorSequence.new(rgb(120, 200, 130))
	emitter.LightEmission = 0.2
	emitter.Size = NumberSequence.new(4, 7)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(0.5, 1)
	emitter.SpreadAngle = Vector2.new(180, 0)
	emitter.Parent = mist

	-- Ossuary shelves full of skulls between the coffins
	local half = room.Size / 2
	for _, side in { -1, 1 } do
		for _, z in { -half + 3, 0, half - 3 } do
			if math.abs(z) < half - 1 then
				local wallX = side * (half - 0.8)
				for _, y in { 5, 8.5, 12 } do
					Build.block(parent, "Shelf", Vector3.new(1.6, 0.4, 6), CFrame.new(room.Center + Vector3.new(wallX, y, z)), stone, M.Slate)
					for k = -2, 2 do
						noCollide(Build.ball(parent, "Skull", 0.9, room.Center + Vector3.new(wallX, y + 0.65, z + k * 1.15), bone, M.SmoothPlastic))
					end
				end
			end
		end
	end

	-- Broken columns near the corners
	for i, corner in corners(room, 7) do
		local height = 6 + (i % 3) * 4
		Build.cylinder(parent, "BrokenColumn", 3, height, CFrame.new(corner + Vector3.new(0, height / 2, 0)), rgb(105, 100, 105), M.Cobblestone)
		local rubble = Build.block(parent, "Rubble", Vector3.new(2, 1.2, 1.6), CFrame.new(corner + Vector3.new(2.4, 0.6, 1)) * CFrame.Angles(0.3, 0.8, 0.2), rgb(105, 100, 105), M.Cobblestone)
		noCollide(rubble)
	end

	-- Hanging chains
	for i = 1, 4 do
		local p = room.Center + Vector3.new(rng:NextNumber(-room.Size / 3, room.Size / 3), 0, rng:NextNumber(-room.Size / 3, room.Size / 3))
		noCollide(Build.block(parent, "Chain", Vector3.new(0.3, 7, 0.3), CFrame.new(p + Vector3.new(0, 18.5, 0)), rgb(60, 60, 65), M.Metal))
	end

	if isBoss then
		throne(parent, room, rgb(220, 215, 195), rgb(70, 65, 70), M.Marble)
		for _, x in { -6, 6 } do
			noCollide(Build.ball(parent, "ThroneSkull", 1.6, room.Center + Vector3.new(x, 2, room.Size / 2 - 3), rgb(235, 230, 215), M.SmoothPlastic))
		end
	end
end

-- Temple -------------------------------------------------------------------------

local function temple(parent: Instance, room: Room, isBoss: boolean, rng: Random)
	local sandstone = rgb(200, 170, 110)
	local gold = rgb(225, 180, 60)
	local lapis = rgb(40, 70, 150)

	-- Columns with gold caps
	for _, spot in sideSpots(room, 4, 3) do
		local p = spot.Position
		Build.cylinder(parent, "Column", 3.2, 20, CFrame.new(p + Vector3.new(0, 10, 0)), sandstone, M.Sandstone)
		Build.block(parent, "ColumnBase", Vector3.new(4.2, 1, 4.2), CFrame.new(p + Vector3.new(0, 0.5, 0)), gold, M.Metal)
		Build.block(parent, "ColumnCap", Vector3.new(4.2, 1.2, 4.2), CFrame.new(p + Vector3.new(0, 19.4, 0)), gold, M.Metal)
		Build.cylinder(parent, "ColumnBand", 3.4, 0.8, CFrame.new(p + Vector3.new(0, 12, 0)), lapis, M.SmoothPlastic)
	end

	-- Painted bands along the walls (hieroglyph stripes)
	local half = room.Size / 2
	for _, side in { -1, 1 } do
		for i, color in { gold, lapis, rgb(170, 60, 40) } do
			noCollide(Build.block(parent, "WallBand", Vector3.new(0.2, 0.6, room.Size - 2), CFrame.new(room.Center + Vector3.new(side * (half - 0.1), 13 + i * 0.8, 0)), color, M.SmoothPlastic))
		end
	end

	-- Guardian statues in the corners: jackal heads on plinths
	for _, corner in corners(room, 4) do
		local facing = CFrame.lookAt(corner, room.Center * Vector3.new(1, 0, 1) + Vector3.new(0, corner.Y, 0))
		Build.block(parent, "Plinth", Vector3.new(4, 3, 4), facing * CFrame.new(0, 1.5, 0), sandstone, M.Sandstone)
		Build.block(parent, "StatueBody", Vector3.new(2.6, 5, 2), facing * CFrame.new(0, 5.5, 0), rgb(30, 30, 35), M.Basalt)
		Build.block(parent, "StatueHead", Vector3.new(1.8, 1.8, 2.4), facing * CFrame.new(0, 9, -0.3), rgb(30, 30, 35), M.Basalt)
		for _, x in { -0.6, 0.6 } do
			Build.block(parent, "StatueEar", Vector3.new(0.4, 1.4, 0.4), facing * CFrame.new(x, 10.5, 0), rgb(30, 30, 35), M.Basalt)
		end
		Build.block(parent, "StatueCollar", Vector3.new(2.8, 0.6, 2.2), facing * CFrame.new(0, 7.9, 0), gold, M.Metal)
		local eye = Build.block(parent, "StatueEyes", Vector3.new(1.2, 0.25, 0.1), facing * CFrame.new(0, 9.3, -1.55), rgb(80, 255, 160), M.Neon)
		noCollide(eye)
	end

	-- Sand drifts against the walls
	for _ = 1, 6 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local p = room.Center + Vector3.new(side * (half - 2), -1.5, rng:NextNumber(-half + 6, half - 6))
		noCollide(Build.ball(parent, "Sand", rng:NextNumber(5, 8), p, rgb(220, 190, 130), M.Sand))
	end

	-- Braziers with green fire between the columns
	for _, spot in sideSpots(room, 9, 2) do
		local p = spot.Position
		Build.cylinder(parent, "BrazierStand", 0.8, 3, CFrame.new(p + Vector3.new(0, 1.5, 0)), gold, M.Metal)
		local bowl = Build.cylinder(parent, "Brazier", 2.4, 0.8, CFrame.new(p + Vector3.new(0, 3.4, 0)), gold, M.Metal)
		fire(bowl, rgb(80, 255, 170), rgb(30, 160, 90), 3)
		Build.light(bowl, rgb(100, 255, 180), 22, 1.6)
	end

	if isBoss then
		throne(parent, room, gold, lapis, M.Metal)
		-- Treasure heaped around the throne
		for _ = 1, 30 do
			local p = room.Center + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(0, 1.2), half - rng:NextNumber(2, 9))
			noCollide(Build.ball(parent, "Gold", rng:NextNumber(0.6, 1.4), p, gold, M.Metal))
		end
		for _, x in { -11, 11 } do
			local chest = room.Center + Vector3.new(x, 0, half - 5)
			Build.block(parent, "Chest", Vector3.new(3, 2, 2), CFrame.new(chest + Vector3.new(0, 1, 0)), rgb(110, 70, 40), M.WoodPlanks)
			Build.block(parent, "ChestLid", Vector3.new(3.1, 0.6, 2.1), CFrame.new(chest + Vector3.new(0, 2.3, 0)), gold, M.Metal)
		end
	end
end

-- Ice ------------------------------------------------------------------------------

local function ice(parent: Instance, room: Room, isBoss: boolean, rng: Random)
	local iceColor = rgb(160, 210, 245)
	local glow = rgb(120, 200, 255)

	-- Glowing crystal clusters along the walls
	for _, spot in sideSpots(room, 3, 3) do
		local base = spot.Position
		for i = 1, 4 do
			local height = rng:NextNumber(4, 9)
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-25, 25)))
			local crystal = Build.block(parent, "Crystal", Vector3.new(1.2, height, 1.2), CFrame.new(base + Vector3.new(rng:NextNumber(-1.5, 1.5), height / 2 - 0.5, rng:NextNumber(-1.5, 1.5))) * tilt, if i == 1 then glow else iceColor, if i == 1 then M.Neon else M.Ice)
			crystal.Transparency = if i == 1 then 0.2 else 0.15
		end
		local lightPart = noCollide(Build.block(parent, "CrystalLight", Vector3.one, CFrame.new(base + Vector3.new(0, 3, 0)), glow, M.SmoothPlastic))
		lightPart.Transparency = 1
		Build.light(lightPart, glow, 18, 1.4)
	end

	-- Icicles hanging from the ceiling
	for _ = 1, 18 do
		local length = rng:NextNumber(2, 5)
		local p = room.Center + Vector3.new(rng:NextNumber(-room.Size / 2 + 2, room.Size / 2 - 2), 22 - length / 2, rng:NextNumber(-room.Size / 2 + 2, room.Size / 2 - 2))
		local icicle = Build.cylinder(parent, "Icicle", rng:NextNumber(0.4, 0.8), length, CFrame.new(p), iceColor, M.Ice)
		icicle.Transparency = 0.2
		noCollide(icicle)
	end

	-- Snow drifts
	for _, corner in corners(room, 2) do
		noCollide(Build.ball(parent, "Snow", rng:NextNumber(7, 10), corner - Vector3.new(0, 2, 0), rgb(240, 245, 250), M.Snow))
	end
	for _ = 1, 4 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		noCollide(Build.ball(parent, "Snow", rng:NextNumber(4, 6), room.Center + Vector3.new(side * (room.Size / 2 - 1.5), -1.5, rng:NextNumber(-room.Size / 3, room.Size / 3)), rgb(240, 245, 250), M.Snow))
	end

	-- Frozen pillars in the corners
	for _, corner in corners(room, 5) do
		local pillar = Build.cylinder(parent, "FrozenPillar", 3, 22, CFrame.new(corner + Vector3.new(0, 11, 0)), rgb(130, 170, 210), M.Glacier)
		pillar.Transparency = 0.1
	end

	-- Falling snow
	local sky = noCollide(Build.block(parent, "Snowfall", Vector3.new(room.Size - 4, 0.2, room.Size - 4), CFrame.new(room.Center + Vector3.new(0, 21, 0)), rgb(0, 0, 0), M.SmoothPlastic))
	sky.Transparency = 1
	local snow = Instance.new("ParticleEmitter")
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Color = ColorSequence.new(rgb(255, 255, 255))
	snow.LightEmission = 0.4
	snow.Size = NumberSequence.new(0.25)
	snow.Lifetime = NumberRange.new(6, 8)
	snow.Rate = 30
	snow.Speed = NumberRange.new(2.5, 4)
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Parent = sky

	if isBoss then
		throne(parent, room, rgb(170, 220, 250), rgb(90, 140, 200), M.Ice)
		for _, x in { -9, 9 } do
			local spike = Build.block(parent, "IceSpike", Vector3.new(2, 14, 2), CFrame.new(room.Center + Vector3.new(x, 7, room.Size / 2 - 4)) * CFrame.Angles(0, math.rad(45), math.rad(x > 0 and -8 or 8)), glow, M.Neon)
			spike.Transparency = 0.3
		end
	end
end

local DECORATORS = { Crypt = crypt, Temple = temple, Ice = ice }

function DungeonDecor.decorate(style: string, parent: Instance, room: Room, isBoss: boolean, seed: number)
	local decorator = DECORATORS[style]
	if decorator then
		decorator(parent, room, isBoss, Random.new(seed))
	end
end

-- Material/color for the doors between rooms.
function DungeonDecor.doorLook(style: string): (Color3, Enum.Material, number)
	if style == "Crypt" then
		return rgb(55, 55, 60), M.DiamondPlate, 0
	elseif style == "Temple" then
		return rgb(190, 150, 80), M.Sandstone, 0
	elseif style == "Ice" then
		return rgb(150, 210, 245), M.Ice, 0.25
	end
	return rgb(70, 45, 30), M.WoodPlanks, 0
end

return DungeonDecor
