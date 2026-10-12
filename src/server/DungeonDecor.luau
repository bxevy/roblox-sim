-- Theme decorations for dungeon rooms. Each style (Crypt, Forest, Temple, Ice, Volcano,
-- Void) adds props along
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

-- Forest ----------------------------------------------------------------------------

local function particlesOver(parent: Instance, room: Room, y: number, color: Color3, rate: number, settings: { [string]: any })
	local area = noCollide(Build.block(parent, "Ambience", Vector3.new(room.Size - 4, 0.2, room.Size - 4), CFrame.new(room.Center + Vector3.new(0, y, 0)), rgb(0, 0, 0), M.SmoothPlastic))
	area.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate
	for k, v in settings do
		(e :: any)[k] = v
	end
	e.Parent = area
end

local function tree(parent: Instance, base: Vector3, height: number, rng: Random, leaf: Color3)
	Build.cylinder(parent, "Trunk", 2.4, height, CFrame.new(base + Vector3.new(0, height / 2, 0)), rgb(80, 58, 38), M.Wood)
	for i = 1, 3 do
		local root = Build.block(parent, "Root", Vector3.new(0.9, 0.8, 3), CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, i * 2.1 + rng:NextNumber(0, 0.5), 0) * CFrame.new(0, 0, 1.6) * CFrame.Angles(math.rad(-15), 0, 0), rgb(75, 55, 35), M.Wood)
		noCollide(root)
	end
	for i = 1, 4 do
		local leaves = Build.ball(parent, "Leaves", rng:NextNumber(5, 8), base + Vector3.new(rng:NextNumber(-2.5, 2.5), height + rng:NextNumber(-1, 2), rng:NextNumber(-2.5, 2.5)), leaf:Lerp(rgb(20, 40, 15), rng:NextNumber(0, 0.4)), M.Grass)
		noCollide(leaves)
		leaves.Name = if i == 1 then "Canopy" else "Leaves"
	end
end

local function forest(parent: Instance, room: Room, isBoss: boolean, rng: Random)
	local glow = rgb(190, 110, 255)
	for _, spot in sideSpots(room, 5, if isBoss then 4 else 3) do
		tree(parent, spot.Position + Vector3.new(0, 0, rng:NextNumber(-3, 3)), rng:NextNumber(12, 17), rng, rgb(60, 110, 50))
	end
	-- Glowing mushrooms and ferns in the corners
	for _, corner in corners(room, 5) do
		for _ = 1, 4 do
			local p = corner + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			local height = rng:NextNumber(0.8, 2.2)
			noCollide(Build.cylinder(parent, "MushroomStem", 0.5, height, CFrame.new(p + Vector3.new(0, height / 2, 0)), rgb(230, 225, 210), M.SmoothPlastic))
			local cap = noCollide(Build.ball(parent, "MushroomCap", height * 1.2, p + Vector3.new(0, height, 0), glow, M.Neon))
			cap.Size = Vector3.new(height * 1.3, height * 0.6, height * 1.3)
		end
		local fern = noCollide(Build.ball(parent, "Fern", 3, corner + Vector3.new(0, 0.4, 0), rgb(50, 120, 45), M.Grass))
		fern.Size = Vector3.new(4, 1.2, 4)
		local lamp = noCollide(Build.block(parent, "MushroomLight", Vector3.one, CFrame.new(corner + Vector3.new(0, 2, 0)), glow, M.SmoothPlastic))
		lamp.Transparency = 1
		Build.light(lamp, glow, 18, 1.2)
	end
	-- Hanging vines
	for _ = 1, 12 do
		local length = rng:NextNumber(4, 9)
		local p = room.Center + Vector3.new(rng:NextNumber(-room.Size / 2 + 2, room.Size / 2 - 2), 22 - length / 2, rng:NextNumber(-room.Size / 2 + 2, room.Size / 2 - 2))
		noCollide(Build.block(parent, "Vine", Vector3.new(0.3, length, 0.3), CFrame.new(p), rgb(50, 100, 40), M.Grass))
	end
	-- Mossy stones
	for _ = 1, 5 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local p = room.Center + Vector3.new(side * (room.Size / 2 - 9), 0, rng:NextNumber(-room.Size / 3, room.Size / 3))
		Build.block(parent, "Stone", Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)), CFrame.new(p + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rgb(90, 100, 85), M.Slate)
	end
	-- Fireflies
	particlesOver(parent, room, 6, rgb(220, 255, 120), 8, {
		Size = NumberSequence.new(0.2),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
	})
	if isBoss then
		-- The witch's cauldron
		local back = room.Center + Vector3.new(0, 0, room.Size / 2 - 10)
		Build.cylinder(parent, "Cauldron", 6, 4, CFrame.new(back + Vector3.new(0, 2, 0)), rgb(35, 35, 40), M.Metal)
		local brew = Build.cylinder(parent, "Brew", 5.2, 0.3, CFrame.new(back + Vector3.new(0, 3.9, 0)), rgb(120, 255, 90), M.Neon)
		fire(brew, rgb(140, 255, 90), rgb(60, 140, 40), 4)
		Build.light(brew, rgb(140, 255, 90), 24, 2)
		tree(parent, back + Vector3.new(-14, 0, 2), 20, rng, rgb(70, 40, 90))
		tree(parent, back + Vector3.new(14, 0, 2), 20, rng, rgb(70, 40, 90))
	end
end

-- Volcano (Infernal Forge) ----------------------------------------------------------------

local function volcano(parent: Instance, room: Room, isBoss: boolean, rng: Random)
	local lava = rgb(255, 110, 30)
	local half = room.Size / 2
	-- Lava channels along both walls
	for _, side in { -1, 1 } do
		local channel = Build.block(parent, "LavaChannel", Vector3.new(5, 0.4, room.Size - 10), CFrame.new(room.Center + Vector3.new(side * (half - 3.5), 0.05, 0)), lava, M.Neon)
		noCollide(channel)
		fire(channel, rgb(255, 140, 40), rgb(200, 40, 10), 6)
		Build.light(channel, lava, 30, 2)
		Build.block(parent, "ChannelRim", Vector3.new(1, 1, room.Size - 10), CFrame.new(room.Center + Vector3.new(side * (half - 6.5), 0.5, 0)), rgb(40, 35, 35), M.Basalt)
	end
	-- Obsidian spikes and forge pillars in the corners
	for _, corner in corners(room, 8) do
		Build.block(parent, "ForgePillar", Vector3.new(4, 22, 4), CFrame.new(corner + Vector3.new(0, 11, 0)), rgb(50, 40, 40), M.Basalt)
		for i = 0, 3 do
			noCollide(Build.block(parent, "PillarGlow", Vector3.new(4.1, 0.4, 4.1), CFrame.new(corner + Vector3.new(0, 4 + i * 5, 0)), lava, M.Neon))
		end
		for _ = 1, 3 do
			local p = corner + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			local h = rng:NextNumber(3, 6)
			Build.block(parent, "ObsidianSpike", Vector3.new(1.2, h, 1.2), CFrame.new(p + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), rng:NextNumber(0, 3), math.rad(rng:NextNumber(-15, 15))), rgb(25, 20, 30), M.Glass)
		end
	end
	-- Anvils and hanging chains
	for _, spot in sideSpots(room, 10, 2) do
		local p = spot.Position
		Build.block(parent, "AnvilBase", Vector3.new(1.6, 2, 1.6), CFrame.new(p + Vector3.new(0, 1, 0)), rgb(60, 60, 65), M.Metal)
		Build.block(parent, "Anvil", Vector3.new(1.8, 0.9, 3.6), CFrame.new(p + Vector3.new(0, 2.4, 0)), rgb(70, 70, 75), M.Metal)
	end
	for _ = 1, 6 do
		local p = room.Center + Vector3.new(rng:NextNumber(-half + 8, half - 8), 17, rng:NextNumber(-half + 8, half - 8))
		noCollide(Build.block(parent, "Chain", Vector3.new(0.4, 10, 0.4), CFrame.new(p), rgb(50, 45, 45), M.Metal))
		noCollide(Build.block(parent, "Hook", Vector3.new(1, 1, 0.3), CFrame.new(p - Vector3.new(0, 5.3, 0)), rgb(50, 45, 45), M.Metal))
	end
	-- Embers drifting up
	particlesOver(parent, room, 1, rgb(255, 150, 50), 20, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(20, 20),
	})
	if isBoss then
		-- Lavafalls down the back wall and a giant anvil throne
		local back = room.Center + Vector3.new(0, 0, half - 1.5)
		for _, x in { -20, 0, 20 } do
			local fall = noCollide(Build.block(parent, "Lavafall", Vector3.new(6, 22, 1), CFrame.new(back + Vector3.new(x, 11, 0)), lava, M.Neon))
			fire(fall, rgb(255, 140, 40), rgb(200, 40, 10), 8)
		end
		Build.block(parent, "GreatAnvil", Vector3.new(14, 4, 7), CFrame.new(back + Vector3.new(0, 2, -8)), rgb(55, 50, 55), M.Metal)
	end
end

-- Void (Abyssal Rift) -----------------------------------------------------------------

local function void(parent: Instance, room: Room, isBoss: boolean, rng: Random)
	local glow = rgb(190, 110, 255)
	local half = room.Size / 2
	-- Rune circle on the floor
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local r = half * 0.55
		noCollide(Build.block(parent, "Rune", Vector3.new(1.4, 0.1, 0.4), CFrame.new(room.Center + Vector3.new(math.cos(angle) * r, 0.05, math.sin(angle) * r)) * CFrame.Angles(0, -angle, 0), glow, M.Neon))
	end
	-- Crystal clusters along the walls
	for _, spot in sideSpots(room, 3, 3) do
		for i = 1, 4 do
			local height = rng:NextNumber(4, 10)
			local crystal = Build.block(parent, "VoidCrystal", Vector3.new(1.3, height, 1.3), CFrame.new(spot.Position + Vector3.new(rng:NextNumber(-1.5, 1.5), height / 2 - 0.5, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, 6), math.rad(rng:NextNumber(-25, 25))), if i == 1 then glow else rgb(40, 25, 70), if i == 1 then M.Neon else M.Glass)
			crystal.Transparency = 0.1
		end
		local lamp = noCollide(Build.block(parent, "CrystalLight", Vector3.one, CFrame.new(spot.Position + Vector3.new(0, 4, 0)), glow, M.SmoothPlastic))
		lamp.Transparency = 1
		Build.light(lamp, glow, 20, 1.3)
	end
	-- Floating rocks
	for _ = 1, 10 do
		local p = room.Center + Vector3.new(rng:NextNumber(-half + 4, half - 4), rng:NextNumber(10, 19), rng:NextNumber(-half + 4, half - 4))
		local rock = noCollide(Build.block(parent, "FloatingRock", Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1, 2.5), rng:NextNumber(2, 4)), CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)), rgb(35, 25, 45), M.Slate))
		rock.Name = "FloatingRock"
	end
	-- Rifts in the corners
	for _, corner in corners(room, 5) do
		local rift = noCollide(Build.cylinder(parent, "Rift", 6, 0.2, CFrame.new(corner + Vector3.new(0, 6, 0)) * CFrame.Angles(math.rad(90), 0, 0), rgb(5, 0, 10), M.SmoothPlastic))
		rift.Name = "Rift"
		noCollide(Build.cylinder(parent, "RiftRing", 6.6, 0.15, CFrame.new(corner + Vector3.new(0, 6, 0.05)) * CFrame.Angles(math.rad(90), 0, 0), glow, M.Neon))
	end
	-- Drifting motes
	particlesOver(parent, room, 18, glow, 14, {
		EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(5, 7),
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(25, 25),
	})
	if isBoss then
		throne(parent, room, rgb(25, 15, 40), glow, M.Glass)
		for i = 0, 2 do
			noCollide(Build.cylinder(parent, "HaloRing", 10 + i * 4, 0.3, CFrame.new(room.Center + Vector3.new(0, 16 + i * 1.5, half - 5)) * CFrame.Angles(math.rad(90), 0, 0), glow, M.Neon)).Transparency = 0.3 + i * 0.2
		end
	end
end

-- Halloween (Haunted Manor) -------------------------------------------------------------

local function jackOLantern(parent: Instance, position: Vector3, size: number, glow: Color3)
	local body = Build.ball(parent, "Pumpkin", size, position + Vector3.new(0, size * 0.42, 0), rgb(240, 120, 20), M.SmoothPlastic)
	noCollide(Build.block(parent, "PumpkinStem", Vector3.new(0.2, 0.4, 0.2) * size, CFrame.new(body.CFrame.Position + Vector3.new(0, size * 0.55, 0)), rgb(70, 100, 40), M.Wood))
	noCollide(Build.block(parent, "PumpkinGrin", Vector3.new(size * 0.5, size * 0.1, 0.1), CFrame.new(body.CFrame.Position + Vector3.new(0, -size * 0.12, -size * 0.49)), glow, M.Neon))
	for _, side in { -1, 1 } do
		noCollide(Build.block(parent, "PumpkinEye", Vector3.new(size * 0.16, size * 0.14, 0.1), CFrame.new(body.CFrame.Position + Vector3.new(side * size * 0.18, size * 0.1, -size * 0.48)) * CFrame.Angles(0, 0, math.rad(side * 15)), glow, M.Neon))
	end
	Build.light(body, glow, size * 6, 1.2)
end

local function halloween(parent: Instance, room: Room, isBoss: boolean, rng: Random)
	local orange = rgb(255, 130, 30)
	local purple = rgb(150, 70, 220)
	local wood = rgb(60, 40, 35)
	local half = room.Size / 2

	-- Wainscoting along the walls
	for _, side in { -1, 1 } do
		Build.block(parent, "Wainscot", Vector3.new(0.4, 5, room.Size - 2), CFrame.new(room.Center + Vector3.new(side * (half - 0.2), 2.5, 0)), wood, M.WoodPlanks)
		noCollide(Build.block(parent, "WainscotTrim", Vector3.new(0.5, 0.3, room.Size - 2), CFrame.new(room.Center + Vector3.new(side * (half - 0.25), 5, 0)), rgb(110, 80, 40), M.Wood))
	end

	-- Haunted portraits whose eyes glow
	for _, spot in sideSpots(room, 0.5, 2) do
		local p = spot.Position + Vector3.new(0, 10, 0)
		local facing = CFrame.lookAt(p, p - Vector3.new(spot.Side, 0, 0))
		Build.block(parent, "PortraitFrame", Vector3.new(4.6, 6, 0.3), facing, rgb(150, 110, 40), M.Metal)
		Build.block(parent, "Portrait", Vector3.new(4, 5.4, 0.35), facing, rgb(30, 25, 35), M.Fabric)
		noCollide(Build.block(parent, "PortraitFace", Vector3.new(1.6, 2, 0.4), facing * CFrame.new(0, 0.6, 0), rgb(120, 105, 95), M.Fabric))
		for _, x in { -0.35, 0.35 } do
			noCollide(Build.block(parent, "PortraitEye", Vector3.new(0.25, 0.15, 0.45), facing * CFrame.new(x, 0.9, 0), rgb(255, 60, 60), M.Neon))
		end
	end

	-- Candelabras with purple flames
	for _, spot in sideSpots(room, 5, 2) do
		local p = spot.Position + Vector3.new(0, 0, if rng:NextNumber() < 0.5 then -6 else 6)
		Build.cylinder(parent, "CandelabraBase", 1.2, 0.4, CFrame.new(p + Vector3.new(0, 0.2, 0)), rgb(40, 35, 40), M.Metal)
		Build.cylinder(parent, "CandelabraStem", 0.3, 5, CFrame.new(p + Vector3.new(0, 2.7, 0)), rgb(40, 35, 40), M.Metal)
		for _, x in { -0.7, 0, 0.7 } do
			local candle = noCollide(Build.cylinder(parent, "Candle", 0.3, 0.8, CFrame.new(p + Vector3.new(x, 5.6, 0)), rgb(230, 225, 205), M.SmoothPlastic))
			fire(candle, purple, rgb(80, 20, 120), 0.8)
		end
		local lamp = noCollide(Build.block(parent, "CandleLight", Vector3.one, CFrame.new(p + Vector3.new(0, 6, 0)), purple, M.SmoothPlastic))
		lamp.Transparency = 1
		Build.light(lamp, purple, 18, 1.2)
	end

	-- Jack-o'-lanterns and cobwebs in the corners
	for _, corner in corners(room, 4) do
		for _ = 1, 3 do
			jackOLantern(parent, corner + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5)), rng:NextNumber(1.4, 2.6), orange)
		end
		local web = noCollide(Build.block(parent, "Cobweb", Vector3.new(8, 8, 0.05), CFrame.new(corner + Vector3.new(0, 19, 0)), rgb(230, 230, 235), M.Fabric))
		web.Transparency = 0.7
		local toCenter = (room.Center - corner) * Vector3.new(1, 0, 1)
		web.CFrame = CFrame.lookAt(corner + Vector3.new(0, 19, 0), corner + Vector3.new(0, 19, 0) + toCenter) * CFrame.Angles(0, 0, math.rad(45))
	end

	-- A chandelier
	local chandelier = room.Center + Vector3.new(0, 17, 0)
	noCollide(Build.block(parent, "ChandelierChain", Vector3.new(0.3, 5, 0.3), CFrame.new(chandelier + Vector3.new(0, 2.5, 0)), rgb(40, 35, 40), M.Metal))
	noCollide(Build.cylinder(parent, "Chandelier", 6, 0.4, CFrame.new(chandelier), rgb(40, 35, 40), M.Metal))
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		local candle = noCollide(Build.cylinder(parent, "Candle", 0.3, 0.8, CFrame.new(chandelier + Vector3.new(math.cos(angle) * 2.6, 0.6, math.sin(angle) * 2.6)), rgb(230, 225, 205), M.SmoothPlastic))
		fire(candle, orange, rgb(200, 60, 10), 0.8)
	end
	local chandelierLight = noCollide(Build.block(parent, "ChandelierLight", Vector3.one, CFrame.new(chandelier - Vector3.new(0, 1, 0)), orange, M.SmoothPlastic))
	chandelierLight.Transparency = 1
	Build.light(chandelierLight, orange, 30, 1.6)

	-- Creeping fog
	local fog = noCollide(Build.block(parent, "Fog", Vector3.new(room.Size - 6, 0.2, room.Size - 6), CFrame.new(room.Center + Vector3.new(0, 0.3, 0)), rgb(0, 0, 0), M.SmoothPlastic))
	fog.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Color = ColorSequence.new(rgb(160, 140, 190))
	e.Size = NumberSequence.new(4, 7)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.86), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = 7
	e.Speed = NumberRange.new(0.5, 1)
	e.SpreadAngle = Vector2.new(180, 0)
	e.Parent = fog

	if isBoss then
		-- The Pumpkin King's throne: a giant jack-o'-lantern
		local back = room.Center + Vector3.new(0, 0, half - 8)
		Build.block(parent, "ThroneStep", Vector3.new(20, 1, 10), CFrame.new(back + Vector3.new(0, 0.5, 0)), rgb(40, 30, 45), M.Slate)
		jackOLantern(parent, back + Vector3.new(0, 1, 2), 10, purple)
		for _, x in { -14, 14 } do
			local base = back + Vector3.new(x, 0, 0)
			Build.cylinder(parent, "DeadTrunk", 2, 18, CFrame.new(base + Vector3.new(0, 9, 0)), rgb(45, 35, 35), M.Wood)
			for i = 1, 4 do
				noCollide(Build.block(parent, "DeadBranch", Vector3.new(0.6, 6, 0.6), CFrame.new(base + Vector3.new(0, 12 + i, 0)) * CFrame.Angles(0, i * 1.6, math.rad(45)) * CFrame.new(0, 2.8, 0), rgb(45, 35, 35), M.Wood))
			end
		end
		-- Hanging cages
		for _, x in { -24, 24 } do
			local cage = room.Center + Vector3.new(x, 12, 0)
			noCollide(Build.block(parent, "CageChain", Vector3.new(0.3, 8, 0.3), CFrame.new(cage + Vector3.new(0, 6, 0)), rgb(40, 35, 40), M.Metal))
			for _, offset in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
				noCollide(Build.block(parent, "CageBar", Vector3.new(0.2, 4, 0.2), CFrame.new(cage + offset * 1.2), rgb(40, 35, 40), M.Metal))
			end
			noCollide(Build.ball(parent, "CageSkull", 1, cage - Vector3.new(0, 1.5, 0), rgb(230, 225, 205), M.SmoothPlastic))
		end
	end
end

local DECORATORS = { Crypt = crypt, Temple = temple, Ice = ice, Forest = forest, Volcano = volcano, Void = void, Halloween = halloween }

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
	elseif style == "Forest" then
		return rgb(70, 110, 45), M.Grass, 0
	elseif style == "Volcano" then
		return rgb(60, 45, 40), M.CrackedLava, 0
	elseif style == "Void" then
		return rgb(120, 60, 200), M.ForceField, 0.1
	elseif style == "Halloween" then
		return rgb(70, 45, 35), M.WoodPlanks, 0
	end
	return rgb(70, 45, 30), M.WoodPlanks, 0
end

return DungeonDecor
