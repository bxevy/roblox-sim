--!strict
-- Hand-made models that replace the code-built ones. Put a Model in
--   ReplicatedStorage/Assets/Buildings/<BuildingType>      (or <BuildingType>_<level>)
--   ReplicatedStorage/Assets/World/<Piece>                 (FenceSegment, PathSegment, Tree, Rock, Lamp, SpinWheel)
-- and it is used automatically (see docs/ASSETS.md). Models can be built or imported in
-- Studio in any position, size or rotation: they are measured, resized to fit and placed
-- with their bottom centre on the ground.
--
-- Optional model attributes:
--   Facing    number   degrees to turn the model so its front faces the right way
--   KeepSize  boolean  don't resize to fit (only applies where fitting happens)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomModels = {}

local function normalize(text: string): string
	return string.lower((string.gsub(text, "[%s_%-]", "")))
end

-- Imported meshes sometimes arrive as a single MeshPart rather than a Model: wrap those
-- (once) so everything else can treat them as models.
local wrapped: { [Instance]: Model } = {}
local function asModel(item: Instance): Model?
	if item:IsA("Model") then
		return item
	end
	if item:IsA("BasePart") then
		local existing = wrapped[item]
		if existing then
			return existing
		end
		local model = Instance.new("Model")
		model.Name = item.Name
		for key, value in item:GetAttributes() do
			model:SetAttribute(key, value)
		end
		item:Clone().Parent = model
		wrapped[item] = model
		return model
	end
	return nil
end

local announced: { [string]: boolean } = {}

-- Everyday names also accepted for buildings (a model called "Shop" is the Trading Post).
CustomModels.Aliases = {
	TradingPost = { "Shop", "Store", "Market", "MarketStall", "Trading" },
	ResourceSilo = { "Silo", "Storage" },
	MoonpetalFarm = { "Farm", "PetalFarm" },
	EmpireCore = { "Core" },
	Habitat = { "CreatureHabitat", "House", "Home" },
	ExpeditionPortal = { "Portal" },
	ResearchStation = { "Research", "Lab", "Observatory" },
	CourierPost = { "Courier", "Depot" },
	CrystalMine = { "Mine" },
	CrystalSmelter = { "Smelter", "Furnace" },
	EssenceCondenser = { "Condenser" },
	EvolutionChamber = { "Evolution" },
	Hatchery = { "Nest", "Incubator", "HatchStand", "EggStand" },
	FenceSegment = { "Fence" },
	PathSegment = { "Path", "GravelPath", "Gravel", "PathTile" },
} :: { [string]: { string } }

-- The template for `name` in Assets/<category>, preferring a per-level variant
-- (<name>_<level>, then lower levels, then plain <name>). Names are matched ignoring
-- capitals, spaces, dashes and underscores, so "fence segment" finds FenceSegment.
function CustomModels.Find(category: string, name: string, level: number?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	if not folder then
		return nil
	end
	local byName: { [string]: Instance } = {}
	for _, child in folder:GetChildren() do
		byName[normalize(child.Name)] = child
	end
	local candidates = {}
	if level then
		for l = level, 2, -1 do
			table.insert(candidates, normalize(name .. l))
		end
	end
	table.insert(candidates, normalize(name))
	local aliases: { string } = CustomModels.Aliases[name] or {}
	for _, alias in aliases do
		if level then
			for l = level, 2, -1 do
				table.insert(candidates, normalize(alias .. l))
			end
		end
		table.insert(candidates, normalize(alias))
	end
	for _, key in candidates do
		local item = byName[key]
		local model = item and asModel(item)
		if model then
			local tag = category .. "/" .. key
			if not announced[tag] then
				announced[tag] = true
				print(`[CE][Assets] Using your model "{(item :: Instance).Name}" for {category} › {name}`)
			end
			return model
		end
	end
	return nil
end

-- Startup check: names in the asset folders that match nothing the game looks for.
function CustomModels.ReportUnknown(known: { [string]: { string } })
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return
	end
	for category, names in known do
		local folder = assets:FindFirstChild(category)
		local valid = {}
		for _, n in names do
			valid[normalize(n)] = true
			local aliases: { string } = CustomModels.Aliases[n] or {}
			for _, alias in aliases do
				valid[normalize(alias)] = true
			end
		end
		for _, child in folder and folder:GetChildren() or {} do
			local key = normalize((string.gsub(child.Name, "_?%d+$", "")))
			if child:IsA("StringValue") then
				continue -- folder READMEs
			end
			if not valid[key] then
				warn(
					`[CE][Assets] "{child.Name}" in Assets › {category} doesn't match anything. Use one of: {table.concat(
						names,
						", "
					)}`
				)
			elseif not child:IsA("Model") and not child:IsA("BasePart") then
				warn(`[CE][Assets] "{child.Name}" in Assets › {category} must be a Model (or a MeshPart).`)
			end
		end
	end
end

-- World-aligned bounds of a model's parts: centre and size.
function CustomModels.Bounds(model: Model): (Vector3, Vector3)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min
	local any = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			any = true
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						min = min:Min(corner)
						max = max:Max(corner)
					end
				end
			end
		end
	end
	if not any then
		return Vector3.zero, Vector3.zero
	end
	return (min + max) / 2, max - min
end

export type PlaceOptions = {
	Fit: Vector3?, -- largest size allowed (X/Z footprint; Y optional, 0 = any height)
	Scale: number?, -- extra uniform scale after fitting
	Anchored: boolean?, -- default true
}

-- Clones `template`, fits and places it with its bottom centre at `cf` (and cf's
-- rotation, plus the model's Facing attribute). Returns the placed model.
function CustomModels.Place(template: Model, parent: Instance, cf: CFrame, options: PlaceOptions?): Model
	local opts: PlaceOptions = options or {}
	local model = template:Clone()
	model.PrimaryPart = nil -- the pivot below decides placement
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = opts.Anchored ~= false
		end
	end
	local _, size = CustomModels.Bounds(model)
	local factor = 1
	if opts.Fit and model:GetAttribute("KeepSize") ~= true and size.X > 0 and size.Z > 0 then
		-- Footprints are measured after turning by Facing, so a long model fits a long plot.
		local facingDeg = (model:GetAttribute("Facing") :: number?) or 0
		local turned = math.abs(math.cos(math.rad(facingDeg))) < 0.5
		local sx, sz = if turned then size.Z else size.X, if turned then size.X else size.Z
		factor = math.min(opts.Fit.X / sx, opts.Fit.Z / sz)
		if opts.Fit.Y > 0 and size.Y > 0 then
			factor = math.min(factor, opts.Fit.Y / size.Y)
		end
	end
	factor *= opts.Scale or 1
	if math.abs(factor - 1) > 1e-3 and factor > 0 then
		model:ScaleTo(model:GetScale() * factor)
	end
	local center, box = CustomModels.Bounds(model)
	local facing = math.rad((model:GetAttribute("Facing") :: number?) or 0)
	model.WorldPivot = CFrame.new(center - Vector3.new(0, box.Y / 2, 0)) * CFrame.Angles(0, -facing, 0)
	model:PivotTo(cf)
	model:SetAttribute("CustomModel", template.Name)
	model.Parent = parent
	return model
end

-- Lays copies of a path piece (built along its X axis, its width along Z) end to end on
-- the floor from `from` to `to` (both relative to `origin`), each sized to `width` studs
-- wide and stretched slightly so the copies fill the whole length.
function CustomModels.Tile(template: Model, parent: Instance, origin: CFrame, from: Vector3, to: Vector3, width: number)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local direction = (to - from).Unit
	local _, size = CustomModels.Bounds(template)
	local turned = math.abs(math.cos(math.rad((template:GetAttribute("Facing") :: number?) or 0))) < 0.5
	local pieceLength = if turned then size.Z else size.X
	local pieceWidth = if turned then size.X else size.Z
	local baseScale = if template:GetAttribute("KeepSize") == true or pieceWidth <= 0 then 1 else width / pieceWidth
	local segLength = math.max(pieceLength * baseScale, 0.5)
	local count = math.max(math.floor(length / segLength + 0.5), 1)
	local along = CFrame.fromMatrix(Vector3.zero, direction, Vector3.yAxis)
	for i = 0, count - 1 do
		local p = from + direction * (length * (i + 0.5) / count)
		CustomModels.Place(template, parent, origin * CFrame.new(p.X, p.Y, p.Z) * along, {
			Scale = baseScale * (length / count) / segLength,
		})
	end
end

return CustomModels
