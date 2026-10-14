--!strict
-- Hand-made models that replace the code-built ones. Put a Model in
--   ReplicatedStorage/Assets/Buildings/<BuildingType>      (or <BuildingType>_<level>)
--   ReplicatedStorage/Assets/World/<Piece>                 (FenceSegment, Tree, Rock, Lamp)
-- and it is used automatically (see docs/ASSETS.md). Models can be built or imported in
-- Studio in any position, size or rotation: they are measured, resized to fit and placed
-- with their bottom centre on the ground.
--
-- Optional model attributes:
--   Facing    number   degrees to turn the model so its front faces the right way
--   KeepSize  boolean  don't resize to fit (only applies where fitting happens)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomModels = {}

-- The template for `name` in Assets/<category>, preferring a per-level variant
-- (<name>_<level>, then lower levels, then plain <name>).
function CustomModels.Find(category: string, name: string, level: number?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	if not folder then
		return nil
	end
	if level then
		for l = level, 2, -1 do
			local variant = folder:FindFirstChild(`{name}_{l}`)
			if variant and variant:IsA("Model") then
				return variant
			end
		end
	end
	local model = folder:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
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

return CustomModels
