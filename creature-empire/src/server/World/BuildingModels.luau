--!strict
-- Builds each building's model for its current level. Higher levels add machinery and
-- decoration, so upgrades are visible. Models are built from parts so the game runs
-- without imported assets; replace a builder with a cloned model from ServerStorage to
-- use hand-made art (see docs/ASSETS.md).
--
-- Conventions every model follows (client code relies on them):
--   PrimaryPart "Base"         invisible part covering the footprint, centre on the floor
--   Attachments "WorkSpotN"     where worker N stands (under Base)
--   Tag "CE_Spin" (Model)       client spins it: attributes SpinSpeed (deg/s), SpinAxis "Y"|"Z"
--   Tag "CE_Bob" (Part)         client bobs it up and down: attribute BobHeight
--   Parts named "Petal"         farm crops; the client brightens them as storage fills
--   Part "FillGauge"            silo fill level; attribute MaxHeight

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local Parts = require(script.Parent.Parts)

local BuildingModels = {}

local C = {
	Wood = Color3.fromRGB(125, 88, 58),
	DarkWood = Color3.fromRGB(88, 62, 42),
	Stone = Color3.fromRGB(150, 146, 140),
	DarkStone = Color3.fromRGB(105, 102, 100),
	Soil = Color3.fromRGB(92, 66, 46),
	Leaf = Color3.fromRGB(80, 160, 70),
	Petal = Color3.fromRGB(150, 205, 255),
	Gold = Color3.fromRGB(240, 190, 70),
	Crystal = Color3.fromRGB(120, 220, 255),
	Cloth1 = Color3.fromRGB(220, 80, 70),
	Cloth2 = Color3.fromRGB(245, 235, 210),
	Copper = Color3.fromRGB(190, 120, 80),
}

type Ctx = {
	Model: Model,
	Base: BasePart,
	CF: CFrame, -- footprint centre on the floor, rotated
	W: number, -- footprint width (studs, local X)
	D: number, -- footprint depth (studs, local Z)
	Level: number,
}

local function at(ctx: Ctx, x: number, y: number, z: number): CFrame
	return ctx.CF * CFrame.new(x, y, z)
end

local function block(
	ctx: Ctx,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	decor: boolean?
): BasePart
	local props = { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic }
	return if decor then Parts.Decor(ctx.Model, props) else Parts.Part(ctx.Model, props)
end

local function workSpot(ctx: Ctx, index: number, x: number, z: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "WorkSpot" .. index
	attachment.Position = Vector3.new(x, 0, z)
	attachment.Parent = ctx.Base
end

local function spinner(ctx: Ctx, name: string, hubCF: CFrame, speed: number, axis: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local hub = Parts.Decor(model, { Size = Vector3.new(0.6, 0.6, 0.6), CFrame = hubCF, Transparency = 1 })
	model.PrimaryPart = hub
	model:SetAttribute("SpinSpeed", speed)
	model:SetAttribute("SpinAxis", axis)
	CollectionService:AddTag(model, "CE_Spin")
	model.Parent = ctx.Model
	return model
end

-- Builders ---------------------------------------------------------------------------------

local builders: { [string]: (Ctx) -> () } = {}

builders.EmpireCore = function(ctx)
	local level = ctx.Level
	-- Stepped octagonal base
	Parts.Cylinder(ctx.Model, at(ctx, 0, 0.5, 0), 1, 15, { Color = C.DarkStone, Material = Enum.Material.Slate })
	Parts.Cylinder(ctx.Model, at(ctx, 0, 1.5, 0), 1, 12, { Color = C.Stone, Material = Enum.Material.Cobblestone })
	Parts.Cylinder(ctx.Model, at(ctx, 0, 3.5, 0), 3, 5, { Color = C.Stone, Material = Enum.Material.Marble })
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pillar = at(ctx, math.cos(angle) * 5, 3, math.sin(angle) * 5)
		block(ctx, Vector3.new(1.2, 4, 1.2), pillar, C.Stone, Enum.Material.Marble)
		local brazier = Parts.Ball(ctx.Model, (pillar * CFrame.new(0, 2.4, 0)).Position, 1, {
			Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon,
		})
		if level >= 2 then
			Parts.Light(brazier, Color3.fromRGB(120, 220, 255), 10, 0.8)
		end
	end

	-- The core crystal floats and bobs above the pedestal.
	local crystalHeight = 5 + level * 0.8
	local crystal = Parts.Decor(ctx.Model, {
		Name = "CoreCrystal",
		Size = Vector3.new(2.6, crystalHeight, 2.6),
		CFrame = at(ctx, 0, 6 + crystalHeight / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = C.Crystal,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	crystal:SetAttribute("BobHeight", 0.6)
	CollectionService:AddTag(crystal, "CE_Bob")
	Parts.Light(crystal, C.Crystal, 16 + level * 2, 1.2)

	if level >= 2 then
		for i = 0, 2 do
			local angle = math.rad(i * 120)
			Parts.Decor(ctx.Model, {
				Size = Vector3.new(0.8, 2.6, 0.8),
				CFrame = at(ctx, math.cos(angle) * 1.6, 6.2, math.sin(angle) * 1.6)
					* CFrame.Angles(math.rad(15), angle, 0),
				Color = C.Crystal,
				Material = Enum.Material.Glass,
				Transparency = 0.2,
			})
		end
	end
	if level >= 3 then
		local ring = spinner(ctx, "Orbit", at(ctx, 0, 6 + crystalHeight / 2, 0), 40, "Y")
		for i = 0, 5 do
			local angle = math.rad(i * 60)
			Parts.Ball(
				ring,
				(at(ctx, math.cos(angle) * 3.4, 6 + crystalHeight / 2, math.sin(angle) * 3.4)).Position,
				0.7,
				{
					Color = C.Gold,
					Material = Enum.Material.Neon,
				}
			)
		end
	end
	if level >= 4 then
		for _, x in { -6.5, 6.5 } do
			block(ctx, Vector3.new(0.4, 9, 0.4), at(ctx, x, 4.5, -6.5), C.DarkWood, Enum.Material.Wood)
			block(
				ctx,
				Vector3.new(0.1, 4, 2.4),
				at(ctx, x, 6.5, -5.3),
				Color3.fromRGB(90, 70, 160),
				Enum.Material.Fabric,
				true
			)
		end
	end
	if level >= 5 then
		Parts.Decor(ctx.Model, {
			Name = "Beacon",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(60, 1.2, 1.2),
			CFrame = at(ctx, 0, 6 + crystalHeight + 30, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.Crystal,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CastShadow = false,
		})
	end
	Parts.Label(
		ctx.Base,
		"Empire Core · Tier " .. level,
		{ Offset = Vector3.new(0, 14 + level, 0), Color = Color3.fromRGB(200, 240, 255) }
	)
end

local function plant(ctx: Ctx, x: number, z: number, scale: number)
	block(
		ctx,
		Vector3.new(0.25, 1.2 * scale, 0.25),
		at(ctx, x, 0.9 + 0.6 * scale, z),
		C.Leaf,
		Enum.Material.Grass,
		true
	)
	block(
		ctx,
		Vector3.new(0.9, 0.15, 0.4) * scale,
		at(ctx, x, 1.1 + 0.4 * scale, z) * CFrame.Angles(0, 0, 0.4),
		C.Leaf,
		Enum.Material.Grass,
		true
	)
	local petal = Parts.Ball(ctx.Model, (at(ctx, x, 1.6 + 1.2 * scale, z)).Position, 0.9 * scale, {
		Name = "Petal",
		Color = C.Petal,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	petal:SetAttribute("BaseSize", 0.9 * scale)
end

builders.MoonpetalFarm = function(ctx)
	local level = ctx.Level
	local w, d = ctx.W, ctx.D
	-- Wooden frame
	for _, side in { { 0, -d / 2 + 0.3, w, 0.6 }, { 0, d / 2 - 0.3, w, 0.6 } } do
		block(ctx, Vector3.new(side[3], 0.8, side[4]), at(ctx, side[1], 0.4, side[2]), C.Wood, Enum.Material.Wood)
	end
	for _, x in { -w / 2 + 0.3, w / 2 - 0.3 } do
		block(ctx, Vector3.new(0.6, 0.8, d), at(ctx, x, 0.4, 0), C.Wood, Enum.Material.Wood)
	end

	-- Soil beds: one at level 1, two from level 2.
	local beds = if level >= 2 then 2 else 1
	local bedDepth = (d - 4) / beds
	local rowsPerBed = if level >= 3 then 3 else 2
	for b = 1, beds do
		local bedZ = -d / 2 + 1 + bedDepth * (b - 0.5) + (b - 1) * 1
		block(ctx, Vector3.new(w - 2, 0.6, bedDepth - 0.6), at(ctx, 0, 0.3, bedZ), C.Soil, Enum.Material.Ground)
		for r = 1, rowsPerBed do
			local rowZ = bedZ - bedDepth / 2 + bedDepth * (r - 0.5) / rowsPerBed
			for p = 1, 4 do
				local x = -w / 2 + 2 + (w - 4) * (p - 0.5) / 4
				plant(ctx, x, rowZ, if level >= 5 then 1.25 else 1)
			end
		end
	end
	-- Work spots along the front of each bed / the side paths.
	workSpot(ctx, 1, -w / 2 - 1.5, -d / 4)
	workSpot(ctx, 2, w / 2 + 1.5, -d / 4)
	workSpot(ctx, 3, 0, -d / 2 - 1.5)

	if level >= 3 then
		-- Sprinkler windmill in the back corner.
		local baseCF = at(ctx, w / 2 - 1.5, 0, d / 2 - 1.5)
		block(ctx, Vector3.new(1.4, 8, 1.4), baseCF * CFrame.new(0, 4, 0), C.Wood, Enum.Material.WoodPlanks)
		block(ctx, Vector3.new(2, 1.2, 2), baseCF * CFrame.new(0, 8.4, 0), C.Cloth1, Enum.Material.SmoothPlastic)
		local blades = spinner(ctx, "Windmill", baseCF * CFrame.new(0, 8.4, -1.3), 70, "Z")
		for i = 0, 3 do
			local angle = math.rad(i * 90)
			Parts.Decor(blades, {
				Size = Vector3.new(0.5, 3.4, 0.15),
				CFrame = baseCF * CFrame.new(0, 8.4, -1.3) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.8, 0),
				Color = C.Cloth2,
				Material = Enum.Material.Fabric,
			})
		end
	end
	if level >= 4 then
		for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 } } do
			local cf = at(ctx, corner[1] * (w / 2 - 0.3), 0, corner[2] * (d / 2 - 0.3))
			block(ctx, Vector3.new(0.4, 4, 0.4), cf * CFrame.new(0, 2, 0), C.DarkWood, Enum.Material.Wood)
			local lantern = Parts.Ball(ctx.Model, (cf * CFrame.new(0, 4.3, 0)).Position, 0.9, {
				Color = Color3.fromRGB(255, 230, 160),
				Material = Enum.Material.Neon,
			})
			Parts.Light(lantern, Color3.fromRGB(255, 220, 150), 12, 0.9)
		end
	end
	if level >= 5 then
		-- Glasshouse frame
		for _, x in { -w / 2 + 0.3, w / 2 - 0.3 } do
			for _, z in { -d / 2 + 0.3, d / 2 - 0.3 } do
				block(ctx, Vector3.new(0.3, 6, 0.3), at(ctx, x, 3.8, z), C.Gold, Enum.Material.Metal, true)
			end
		end
		block(ctx, Vector3.new(w, 0.2, d), at(ctx, 0, 6.9, 0), C.Crystal, Enum.Material.Glass, true).Transparency = 0.75
	end
	Parts.Label(ctx.Base, "Moonpetal Farm · Lv " .. level, { Offset = Vector3.new(0, 7, 0), MaxDistance = 60 })
end

builders.ResourceSilo = function(ctx)
	local level = ctx.Level
	local tanks = if level >= 3 then 2 else 1
	local height = 7 + level * 1.4
	for t = 1, tanks do
		local x = if tanks == 1 then 0 else (t - 1.5) * 5.4
		local diameter = if tanks == 1 then 8 else 5.4
		local base = at(ctx, x, 0, 0)
		Parts.Cylinder(ctx.Model, base * CFrame.new(0, height / 2, 0), height, diameter, {
			Color = Color3.fromRGB(205, 200, 190),
			Material = Enum.Material.Concrete,
		})
		Parts.Ball(ctx.Model, (base * CFrame.new(0, height, 0)).Position, diameter, {
			Color = if level >= 5 then C.Crystal else C.Copper,
			Material = if level >= 5 then Enum.Material.Neon else Enum.Material.Metal,
		})
		-- Bands
		for b = 1, 3 do
			Parts.Cylinder(ctx.Model, base * CFrame.new(0, height * b / 4, 0), 0.4, diameter + 0.2, {
				Color = C.Copper,
				Material = Enum.Material.Metal,
			})
		end
		if t == 1 then
			-- Fill gauge window on the front.
			local window = block(
				ctx,
				Vector3.new(1.4, height - 2, 0.3),
				base * CFrame.new(0, height / 2, -diameter / 2 - 0.05),
				Color3.fromRGB(30, 30, 40),
				Enum.Material.Glass,
				true
			)
			window.Transparency = 0.3
			local gauge = block(
				ctx,
				Vector3.new(1.1, 0.2, 0.3),
				base * CFrame.new(0, 1.1, -diameter / 2 - 0.15),
				C.Petal,
				Enum.Material.Neon,
				true
			)
			gauge.Name = "FillGauge"
			gauge:SetAttribute("MaxHeight", height - 2.4)
			gauge:SetAttribute("BottomY", 1)
		end
	end
	Parts.Label(ctx.Base, "Resource Silo · Lv " .. level, { Offset = Vector3.new(0, height + 4, 0), MaxDistance = 60 })
end

builders.TradingPost = function(ctx)
	local w = ctx.W
	block(ctx, Vector3.new(w - 1, 0.4, ctx.D - 1), at(ctx, 0, 0.2, 0), C.DarkWood, Enum.Material.WoodPlanks)
	block(ctx, Vector3.new(w - 3, 3, 1.4), at(ctx, 0, 1.9, -2.2), C.Wood, Enum.Material.WoodPlanks)
	block(ctx, Vector3.new(w - 2.6, 0.3, 1.8), at(ctx, 0, 3.5, -2.2), C.DarkWood, Enum.Material.Wood)
	for _, x in { -w / 2 + 1, w / 2 - 1 } do
		for _, z in { -ctx.D / 2 + 1, ctx.D / 2 - 1 } do
			block(ctx, Vector3.new(0.5, 7, 0.5), at(ctx, x, 3.5, z), C.DarkWood, Enum.Material.Wood)
		end
	end
	-- Striped awning
	local stripes = 6
	for i = 1, stripes do
		local x = -w / 2 + (w * (i - 0.5) / stripes)
		block(
			ctx,
			Vector3.new(w / stripes, 0.25, ctx.D),
			at(ctx, x, 7.2, 0) * CFrame.Angles(math.rad(-10), 0, 0),
			if i % 2 == 0 then C.Cloth1 else C.Cloth2,
			Enum.Material.Fabric,
			true
		)
	end
	-- Goods: crates, a gold scale
	block(ctx, Vector3.new(1.6, 1.6, 1.6), at(ctx, -3.5, 0.8 + 0.4, 2.5), C.Wood, Enum.Material.WoodPlanks)
	block(
		ctx,
		Vector3.new(1.2, 1.2, 1.2),
		at(ctx, -3.3, 2.4, 2.4) * CFrame.Angles(0, 0.4, 0),
		C.Wood,
		Enum.Material.WoodPlanks
	)
	Parts.Ball(ctx.Model, (at(ctx, 2.5, 4.4, -2.2)).Position, 1.1, { Color = C.Gold, Material = Enum.Material.Metal })
	Parts.Ball(ctx.Model, (at(ctx, 1, 4, -2.2)).Position, 0.8, { Color = C.Petal, Material = Enum.Material.Neon })
	Parts.Sign(ctx.Model, at(ctx, 0, 0, ctx.D / 2 + 0.6) * CFrame.Angles(0, math.pi, 0), "TRADING POST", 7)
	workSpot(ctx, 1, 0, 0)
end

local function habitatBase(ctx: Ctx)
	local w, d = ctx.W, ctx.D
	block(ctx, Vector3.new(w, 0.2, d), at(ctx, 0, 0.1, 0), Color3.fromRGB(120, 190, 90), Enum.Material.Grass)
	-- Low fence with a gap at the front
	for i = 0, math.floor(w / 2) do
		local x = -w / 2 + i * 2
		if math.abs(x) > 2 then
			block(ctx, Vector3.new(0.4, 1.6, 0.4), at(ctx, x, 0.8, -d / 2), C.Wood, Enum.Material.Wood, true)
		end
		block(ctx, Vector3.new(0.4, 1.6, 0.4), at(ctx, x, 0.8, d / 2), C.Wood, Enum.Material.Wood, true)
	end
	for _, x in { -w / 2, w / 2 } do
		for i = 0, math.floor(d / 2) do
			block(ctx, Vector3.new(0.4, 1.6, 0.4), at(ctx, x, 0.8, -d / 2 + i * 2), C.Wood, Enum.Material.Wood, true)
		end
	end
	-- Hutches
	for i, x in { -6, 6 } do
		local cf = at(ctx, x, 0, d / 2 - 3.5)
		block(
			ctx,
			Vector3.new(4, 3, 3.5),
			cf * CFrame.new(0, 1.5, 0),
			if i == 1 then C.Cloth2 else C.Wood,
			Enum.Material.WoodPlanks
		)
		block(
			ctx,
			Vector3.new(4.6, 0.4, 2.4),
			cf * CFrame.new(0, 3.4, -0.8) * CFrame.Angles(math.rad(25), 0, 0),
			C.Cloth1,
			Enum.Material.Fabric,
			true
		)
		block(
			ctx,
			Vector3.new(4.6, 0.4, 2.4),
			cf * CFrame.new(0, 3.4, 0.8) * CFrame.Angles(math.rad(-25), 0, 0),
			C.Cloth1,
			Enum.Material.Fabric,
			true
		)
		block(
			ctx,
			Vector3.new(1.6, 1.8, 0.2),
			cf * CFrame.new(0, 0.9, -1.8),
			Color3.fromRGB(40, 30, 25),
			Enum.Material.SmoothPlastic,
			true
		)
	end
	-- Pond
	local pond = Parts.Cylinder(
		ctx.Model,
		at(ctx, 1, 0.25, -1),
		0.3,
		6,
		{ Color = Color3.fromRGB(70, 160, 220), Material = Enum.Material.Glass }
	)
	pond.Transparency = 0.25
	pond.CanCollide = false
	-- Toys: a ball and mushrooms
	Parts.Ball(
		ctx.Model,
		(at(ctx, -4, 0.9, -3)).Position,
		1.4,
		{ Color = Color3.fromRGB(255, 120, 90), Material = Enum.Material.SmoothPlastic }
	)
	for i, offset in { { 7, -4 }, { 8, -2.5 } } do
		Parts.Cylinder(ctx.Model, at(ctx, offset[1], 0.5, offset[2]), 1, 0.4, { Color = C.Cloth2 })
		Parts.Ball(ctx.Model, (at(ctx, offset[1], 1.1, offset[2])).Position, 1.2 - i * 0.2, { Color = C.Cloth1 })
	end
	Parts.Label(ctx.Base, "Creature Habitat · Lv " .. ctx.Level, { Offset = Vector3.new(0, 6, 0), MaxDistance = 60 })
end

builders.Habitat = function(ctx)
	habitatBase(ctx)
	local level, d = ctx.Level, ctx.D
	if level >= 2 then
		local cf = at(ctx, 0, 0, d / 2 - 3)
		block(ctx, Vector3.new(3.5, 2.6, 3), cf * CFrame.new(0, 1.3, 0), C.Wood, Enum.Material.WoodPlanks)
		block(
			ctx,
			Vector3.new(4, 0.4, 3.4),
			cf * CFrame.new(0, 2.8, 0),
			Color3.fromRGB(90, 140, 210),
			Enum.Material.Fabric,
			true
		)
	end
	if level >= 3 then
		local rim = Parts.Cylinder(
			ctx.Model,
			at(ctx, 1, 0.2, -1),
			0.4,
			7.5,
			{ Color = C.Stone, Material = Enum.Material.Cobblestone }
		)
		rim.CanCollide = false
	end
	if level >= 4 then
		local cf = at(ctx, -7, 0, -3)
		block(ctx, Vector3.new(0.5, 6, 0.5), cf * CFrame.new(-1, 3, -1), C.DarkWood, Enum.Material.Wood)
		block(ctx, Vector3.new(0.5, 6, 0.5), cf * CFrame.new(1, 3, 1), C.DarkWood, Enum.Material.Wood)
		block(ctx, Vector3.new(3, 0.4, 3), cf * CFrame.new(0, 4, 0), C.Wood, Enum.Material.WoodPlanks)
		block(
			ctx,
			Vector3.new(1, 0.2, 5),
			cf * CFrame.new(2, 2, 0) * CFrame.Angles(math.rad(-40), 0, 0),
			C.Cloth1,
			Enum.Material.SmoothPlastic,
			true
		)
	end
	if level >= 5 then
		local tree = at(ctx, 7, 0, -3)
		Parts.Cylinder(
			ctx.Model,
			tree * CFrame.new(0, 3, 0),
			6,
			1,
			{ Color = C.DarkWood, Material = Enum.Material.Wood }
		)
		local crown = Parts.Ball(ctx.Model, (tree * CFrame.new(0, 7, 0)).Position, 5, {
			Color = Color3.fromRGB(140, 230, 160),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		})
		Parts.Light(crown, Color3.fromRGB(150, 255, 180), 14, 0.8)
	end
end

local function crystal(ctx: Ctx, cf: CFrame, height: number, color: Color3): BasePart
	local part = block(
		ctx,
		Vector3.new(height * 0.35, height, height * 0.35),
		cf * CFrame.new(0, height / 2, 0),
		color,
		Enum.Material.Glass,
		true
	)
	part.Transparency = 0.15
	return part
end

builders.CrystalMine = function(ctx)
	local level, w, d = ctx.Level, ctx.W, ctx.D
	-- Rocky outcrop with crystals poking out
	block(ctx, Vector3.new(w - 2, 3, d / 2), at(ctx, 0, 1.5, d / 4), C.DarkStone, Enum.Material.Rock)
	block(
		ctx,
		Vector3.new(w / 2, 5, d / 3),
		at(ctx, -2, 2.5, d / 3) * CFrame.Angles(0, 0.3, 0.1),
		C.Stone,
		Enum.Material.Rock
	)
	-- Tunnel mouth
	block(
		ctx,
		Vector3.new(4, 3.2, 0.6),
		at(ctx, 1, 1.6, 0.2),
		Color3.fromRGB(25, 22, 30),
		Enum.Material.SmoothPlastic,
		true
	)
	for _, x in { -1.2, 3.2 } do
		block(ctx, Vector3.new(0.5, 3.6, 0.5), at(ctx, x, 1.8, -0.1), C.Wood, Enum.Material.Wood)
	end
	block(ctx, Vector3.new(5, 0.5, 0.6), at(ctx, 1, 3.7, -0.1), C.Wood, Enum.Material.Wood)
	local count = 3 + level
	for i = 1, count do
		local a = i / count * math.pi * 1.6
		local glow = crystal(
			ctx,
			at(ctx, math.cos(a) * 4 - 1, 2.5, d / 4 + math.sin(a) * 2) * CFrame.Angles(0.3 * math.sin(i), a, 0.25),
			1.6 + (i % 3) * 0.6,
			C.Crystal
		)
		if i == 1 then
			Parts.Light(glow, C.Crystal, 10, 0.7)
		end
	end
	workSpot(ctx, 1, 1, -2)
	workSpot(ctx, 2, -4, -2)
	workSpot(ctx, 3, 5, -2)
	if level >= 3 then
		-- Mine cart on rails
		block(ctx, Vector3.new(0.3, 0.2, d / 2), at(ctx, -5.5, 0.1, -d / 4), C.Copper, Enum.Material.Metal, true)
		block(ctx, Vector3.new(0.3, 0.2, d / 2), at(ctx, -4.5, 0.1, -d / 4), C.Copper, Enum.Material.Metal, true)
		block(ctx, Vector3.new(1.8, 1.2, 2.2), at(ctx, -5, 0.9, -d / 3), C.DarkWood, Enum.Material.WoodPlanks)
		crystal(ctx, at(ctx, -5, 1.4, -d / 3), 0.9, C.Crystal)
	end
	if level >= 4 then
		for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
			block(ctx, Vector3.new(0.3, 3.5, 0.3), at(ctx, x, 1.75, -d / 2 + 0.5), C.DarkWood, Enum.Material.Wood)
			local lamp = Parts.Ball(
				ctx.Model,
				(at(ctx, x, 3.7, -d / 2 + 0.5)).Position,
				0.8,
				{ Color = C.Crystal, Material = Enum.Material.Neon }
			)
			Parts.Light(lamp, C.Crystal, 10, 0.8)
		end
	end
	if level >= 5 then
		local big = crystal(ctx, at(ctx, 3, 3, d / 4), 6, Color3.fromRGB(180, 140, 255))
		big.Material = Enum.Material.Neon
	end
	Parts.Label(ctx.Base, "Crystal Mine · Lv " .. level, { Offset = Vector3.new(0, 8, 0), MaxDistance = 60 })
end

builders.CrystalSmelter = function(ctx)
	local level = ctx.Level
	-- Stone furnace with a glowing mouth and a chimney
	block(ctx, Vector3.new(7, 4, 6), at(ctx, 0, 2, 1), C.DarkStone, Enum.Material.Brick)
	local mouth = block(
		ctx,
		Vector3.new(2.6, 1.8, 0.4),
		at(ctx, 0, 1.4, -2.05),
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon,
		true
	)
	Parts.Light(mouth, Color3.fromRGB(255, 140, 60), 14, 1.2)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 20))
	fire.Size = NumberSequence.new(0.8, 0)
	fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Rate = 12
	fire.Speed = NumberRange.new(1, 2)
	fire.LightEmission = 1
	fire.Parent = mouth
	local chimneys: { number } = if level >= 4 then { -2, 2 } else { 2 }
	for _, x in chimneys do
		block(ctx, Vector3.new(1.4, 5, 1.4), at(ctx, x, 6, 2.5), C.Stone, Enum.Material.Brick)
		local top = block(ctx, Vector3.new(1.6, 0.4, 1.6), at(ctx, x, 8.7, 2.5), C.DarkStone, Enum.Material.Slate)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 130))
		smoke.Size = NumberSequence.new(1, 3)
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Lifetime = NumberRange.new(2, 3)
		smoke.Rate = 3
		smoke.Speed = NumberRange.new(2, 3)
		smoke.Parent = top
	end
	-- Crucible and ingots
	Parts.Cylinder(ctx.Model, at(ctx, 3, 0.8, -2.5), 1.6, 1.6, { Color = C.Copper, Material = Enum.Material.Metal })
	for i = 0, level - 1 do
		block(ctx, Vector3.new(0.6, 0.4, 1.2), at(ctx, -3 + i * 0.8, 0.2, -3), C.Crystal, Enum.Material.Neon, true)
	end
	if level >= 3 then
		block(ctx, Vector3.new(1.2, 1.4, 2), at(ctx, -3.4, 0.7, 1), C.DarkWood, Enum.Material.Leather)
	end
	if level >= 5 then
		local core = Parts.Ball(
			ctx.Model,
			(at(ctx, 0, 4.8, 1)).Position,
			1.6,
			{ Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon }
		)
		core:SetAttribute("BobHeight", 0.3)
		CollectionService:AddTag(core, "CE_Bob")
	end
	workSpot(ctx, 1, 0, -4)
	workSpot(ctx, 2, -3, -4)
	workSpot(ctx, 3, 3, -4)
	Parts.Label(ctx.Base, "Crystal Smelter · Lv " .. level, { Offset = Vector3.new(0, 10, 0), MaxDistance = 60 })
end

builders.EssenceCondenser = function(ctx)
	local level = ctx.Level
	Parts.Cylinder(ctx.Model, at(ctx, 0, 0.5, 0), 1, 8, { Color = C.DarkStone, Material = Enum.Material.Slate })
	Parts.Cylinder(ctx.Model, at(ctx, 0, 1.8, 0), 1.6, 3, { Color = C.Gold, Material = Enum.Material.Metal })
	local orb = Parts.Ball(ctx.Model, (at(ctx, 0, 4.2, 0)).Position, 3, {
		Color = Color3.fromRGB(180, 130, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	orb:SetAttribute("BobHeight", 0.25)
	CollectionService:AddTag(orb, "CE_Bob")
	Parts.Light(orb, Color3.fromRGB(180, 130, 255), 16, 1.2)
	local coils = math.min(level + 1, 4)
	for i = 1, coils do
		local a = i / coils * math.pi * 2
		block(
			ctx,
			Vector3.new(0.4, 4.5, 0.4),
			at(ctx, math.cos(a) * 3, 2.25, math.sin(a) * 3),
			C.Copper,
			Enum.Material.Metal
		)
		Parts.Ball(
			ctx.Model,
			(at(ctx, math.cos(a) * 3, 4.7, math.sin(a) * 3)).Position,
			0.7,
			{ Color = C.Crystal, Material = Enum.Material.Neon }
		)
	end
	if level >= 4 then
		local ring = spinner(ctx, "Rings", at(ctx, 0, 4.2, 0), 50, "Y")
		for i = 0, 7 do
			local a = math.rad(i * 45)
			Parts.Ball(
				ring,
				(at(ctx, math.cos(a) * 2.6, 4.2, math.sin(a) * 2.6)).Position,
				0.4,
				{ Color = C.Gold, Material = Enum.Material.Neon }
			)
		end
	end
	workSpot(ctx, 1, 0, -5)
	workSpot(ctx, 2, -4.5, 0)
	workSpot(ctx, 3, 4.5, 0)
	Parts.Label(ctx.Base, "Essence Condenser · Lv " .. level, { Offset = Vector3.new(0, 8, 0), MaxDistance = 60 })
end

builders.Hatchery = function(ctx)
	-- A straw nest under a little roof, warmed by a lamp, with eggs on display.
	Parts.Cylinder(
		ctx.Model,
		at(ctx, 0, 0.4, 0),
		0.8,
		9,
		{ Color = Color3.fromRGB(200, 170, 100), Material = Enum.Material.Fabric }
	)
	Parts.Cylinder(
		ctx.Model,
		at(ctx, 0, 0.6, 0),
		0.8,
		7,
		{ Color = Color3.fromRGB(170, 140, 80), Material = Enum.Material.Fabric }
	)
	local colors = { Color3.fromRGB(190, 230, 150), Color3.fromRGB(255, 160, 90), Color3.fromRGB(170, 200, 255) }
	for i, color in colors do
		local a = i / #colors * math.pi * 2
		local egg = Parts.Decor(ctx.Model, {
			Name = "DisplayEgg",
			Size = Vector3.new(1.4, 1.8, 1.4),
			CFrame = at(ctx, math.cos(a) * 1.8, 1.8, math.sin(a) * 1.8) * CFrame.Angles(0, 0, 0.1 * i),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = egg
	end
	for _, x in { -4, 4 } do
		block(ctx, Vector3.new(0.5, 6, 0.5), at(ctx, x, 3, 4), C.Wood, Enum.Material.Wood)
	end
	block(
		ctx,
		Vector3.new(10, 0.4, 5),
		at(ctx, 0, 6.2, 2.5) * CFrame.Angles(math.rad(15), 0, 0),
		C.Cloth1,
		Enum.Material.Fabric,
		true
	)
	local lamp = Parts.Ball(
		ctx.Model,
		(at(ctx, 0, 5.2, 2)).Position,
		1,
		{ Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon }
	)
	Parts.Light(lamp, Color3.fromRGB(255, 190, 110), 14, 1)
	workSpot(ctx, 1, 0, -5)
	Parts.Label(ctx.Base, "Hatchery", { Offset = Vector3.new(0, 8, 0), MaxDistance = 60 })
end

builders.EvolutionChamber = function(ctx)
	Parts.Cylinder(ctx.Model, at(ctx, 0, 0.3, 0), 0.6, 15, { Color = C.Stone, Material = Enum.Material.Marble })
	local rune = Parts.Cylinder(
		ctx.Model,
		at(ctx, 0, 0.62, 0),
		0.05,
		8,
		{ Color = Color3.fromRGB(150, 255, 200), Material = Enum.Material.Neon }
	)
	rune.Transparency = 0.4
	rune.CanCollide = false
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local stone = block(
			ctx,
			Vector3.new(1.2, 5 + (i % 2), 0.8),
			at(ctx, math.cos(a) * 6, 2.8, math.sin(a) * 6) * CFrame.Angles(0, -a, 0),
			C.DarkStone,
			Enum.Material.Slate
		)
		local glyph = block(
			ctx,
			Vector3.new(0.6, 0.6, 0.1),
			stone.CFrame * CFrame.new(0, 1, -0.45),
			Color3.fromRGB(150, 255, 200),
			Enum.Material.Neon,
			true
		)
		glyph.Transparency = 0.2
	end
	local motes = spinner(ctx, "Motes", at(ctx, 0, 4, 0), 25, "Y")
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		Parts.Ball(motes, (at(ctx, math.cos(a) * 3, 3.5 + (i % 2), math.sin(a) * 3)).Position, 0.5, {
			Color = Color3.fromRGB(180, 255, 220),
			Material = Enum.Material.Neon,
		})
	end
	workSpot(ctx, 1, 0, 0)
	Parts.Label(ctx.Base, "Evolution Chamber", { Offset = Vector3.new(0, 8, 0), MaxDistance = 60 })
end

builders.ResearchStation = function(ctx)
	local w, d = ctx.W, ctx.D
	block(ctx, Vector3.new(w - 1, 0.6, d - 1), at(ctx, 0, 0.3, 0), C.DarkStone, Enum.Material.Slate)
	-- Half-built dome frame and scaffolding
	for i = 0, 5 do
		local angle = math.rad(i * 30)
		block(
			ctx,
			Vector3.new(0.4, 8, 0.4),
			at(ctx, math.cos(angle) * 5.5, 4, math.sin(angle) * 5.5),
			C.Copper,
			Enum.Material.Metal
		)
	end
	for _, y in { 3, 6 } do
		block(ctx, Vector3.new(w - 2, 0.3, 0.3), at(ctx, 0, y, -d / 2 + 1.2), C.Wood, Enum.Material.Wood, true)
		block(
			ctx,
			Vector3.new(w - 2, 0.2, 1.4),
			at(ctx, 0, y - 0.25, -d / 2 + 1.8),
			C.Wood,
			Enum.Material.WoodPlanks,
			true
		)
	end
	local tarp = block(
		ctx,
		Vector3.new(6, 0.2, 5),
		at(ctx, -3, 5, 2) * CFrame.Angles(0.2, 0, 0.3),
		Color3.fromRGB(70, 110, 160),
		Enum.Material.Fabric,
		true
	)
	tarp.Transparency = 0.1
	local telescope = Parts.Cylinder(
		ctx.Model,
		at(ctx, 3, 3, 3) * CFrame.Angles(0, 0, math.rad(-40)),
		4,
		0.8,
		{ Color = C.Gold, Material = Enum.Material.Metal }
	)
	telescope.CanCollide = false
	Parts.Sign(ctx.Model, at(ctx, 0, 0, -d / 2 - 0.6), "RESEARCH · SOON", 8)
end

-- Public ----------------------------------------------------------------------------------

-- `cf` = footprint centre on the plot floor, already rotated. Returns the model (unparented).
function BuildingModels.Build(typeId: string, level: number, cf: CFrame): Model
	local def = BuildingConfig[typeId]
	assert(def, `Unknown building type {typeId}`)
	local model = Instance.new("Model")
	model.Name = typeId
	local w, d = def.Footprint.X * PlotConfig.CellSize, def.Footprint.Z * PlotConfig.CellSize
	local base = Parts.Part(model, {
		Name = "Base",
		Size = Vector3.new(w, 0.2, d),
		CFrame = cf * CFrame.new(0, 0.1, 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
	})
	model.PrimaryPart = base
	local builder = builders[typeId]
	if builder then
		builder({ Model = model, Base = base, CF = cf, W = w, D = d, Level = level })
	else
		-- Unknown art: a labelled placeholder block so the building is still usable.
		Parts.Part(model, { Size = Vector3.new(w - 1, 3, d - 1), CFrame = cf * CFrame.new(0, 1.5, 0), Color = C.Stone })
		Parts.Label(base, def.Name, { Offset = Vector3.new(0, 5, 0) })
	end
	return model
end

return BuildingModels
