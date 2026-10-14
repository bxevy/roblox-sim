--!strict
-- 3D creature portraits in the interface (ViewportFrames). Portraits can slowly turn;
-- one shared loop updates the visible ones.

local RunService = game:GetService("RunService")

local CreatureModels = require(script.Parent.Parent.Visuals.CreatureModels)
local Theme = require(script.Parent.Theme)

local Viewport = {}

type Spinner = { Frame: ViewportFrame, Model: Model, Speed: number }
local spinners: { Spinner } = {}

local PORTRAIT_TURN = 20 -- degrees
local eggs: { { Frame: ViewportFrame, Model: Model } } = {}

-- Creates a portrait. `silhouette` draws an undiscovered creature as a dark shape.
function Viewport.Creature(
	parent: Instance,
	speciesId: string,
	props: { [string]: any }?,
	options: { Spin: boolean?, Stage: number?, Silhouette: boolean?, Mutation: string? }?
): ViewportFrame
	local opts: { Spin: boolean?, Stage: number?, Silhouette: boolean?, Mutation: string? } = options or {}
	local frame = Theme.Make("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(170, 170, 190),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.4, -1),
	})
	for key, value in props or {} :: { [string]: any } do
		(frame :: any)[key] = value
	end
	local ok, model = pcall(CreatureModels.Build, speciesId, opts.Stage, opts.Mutation)
	if ok then
		for _, d in model:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
				d:Destroy()
			elseif opts.Silhouette and d:IsA("BasePart") then
				d.Color = Color3.fromRGB(20, 22, 32)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
		local world = Instance.new("WorldModel")
		world.Parent = frame
		model.Parent = world
		local _, size = model:GetBoundingBox()
		local radius = math.max(size.X, size.Y, size.Z)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		-- PivotTo moves every part (welds don't update positions inside a ViewportFrame).
		-- Creatures face -Z (the way they walk) and the camera is on the -Z side, so a small
		-- turn shows the face at a three-quarter angle.
		model:PivotTo(CFrame.Angles(0, math.rad(PORTRAIT_TURN), 0))
		camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.35, -radius * 2.6), Vector3.new(0, 0, 0))
		camera.Parent = frame
		frame.CurrentCamera = camera
		if opts.Spin then
			table.insert(spinners, { Frame = frame, Model = model, Speed = 0.6 })
		end
	end
	frame.Parent = parent
	return frame
end

-- An egg portrait (a spotted ellipsoid that wobbles).
function Viewport.Egg(parent: Instance, color: Color3, spots: Color3, props: { [string]: any }?): ViewportFrame
	local frame = Theme.Make("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(170, 170, 190),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.4, -1),
	})
	for key, value in props or {} :: { [string]: any } do
		(frame :: any)[key] = value
	end
	local world = Instance.new("WorldModel")
	world.Parent = frame
	local model = Instance.new("Model")
	local shell = Instance.new("Part")
	shell.Name = "Root"
	shell.Anchored = true
	shell.Size = Vector3.new(2, 2.6, 2)
	shell.Color = color
	shell.Material = Enum.Material.SmoothPlastic
	shell.CFrame = CFrame.new()
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	shell.Parent = model
	for i = 1, 5 do
		local a = i * 1.3
		local spot = Instance.new("Part")
		spot.Shape = Enum.PartType.Ball
		spot.Anchored = true
		spot.Size = Vector3.new(0.45, 0.45, 0.45)
		spot.Color = spots
		spot.CFrame = CFrame.new(math.cos(a) * 0.9, (i - 3) * 0.35, math.sin(a) * 0.9)
		spot.Parent = model
	end
	model.PrimaryPart = shell
	model.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, -6), Vector3.zero)
	camera.Parent = frame
	frame.CurrentCamera = camera
	table.insert(eggs, { Frame = frame, Model = model })
	frame.Parent = parent
	return frame
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i = #eggs, 1, -1 do
		local e = eggs[i]
		if not e.Frame.Parent then
			table.remove(eggs, i)
		elseif e.Frame.Visible and not Theme.ReducedMotion then
			e.Model:PivotTo(CFrame.Angles(0, t * 0.6, math.sin(t * 3 + i) * 0.08))
		end
	end
	for i = #spinners, 1, -1 do
		local s = spinners[i]
		if not s.Frame.Parent then
			table.remove(spinners, i)
		elseif s.Frame.Visible and s.Model.PrimaryPart and not Theme.ReducedMotion then
			s.Model:PivotTo(
				CFrame.Angles(0, math.rad(PORTRAIT_TURN) + math.sin(t * s.Speed) * 0.7, 0)
					* CFrame.new(0, math.abs(math.sin(t * 2.2)) * 0.15, 0)
			)
		end
	end
end)

return Viewport
