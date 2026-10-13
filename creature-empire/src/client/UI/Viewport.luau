--!strict
-- 3D creature portraits in the interface (ViewportFrames). Portraits can slowly turn;
-- one shared loop updates the visible ones.

local RunService = game:GetService("RunService")

local CreatureModels = require(script.Parent.Parent.Visuals.CreatureModels)
local Theme = require(script.Parent.Theme)

local Viewport = {}

type Spinner = { Frame: ViewportFrame, Model: Model, Speed: number }
local spinners: { Spinner } = {}

-- Creates a portrait. `silhouette` draws an undiscovered creature as a dark shape.
function Viewport.Creature(
	parent: Instance,
	speciesId: string,
	props: { [string]: any }?,
	options: { Spin: boolean?, Stage: number?, Silhouette: boolean? }?
): ViewportFrame
	local opts: { Spin: boolean?, Stage: number?, Silhouette: boolean? } = options or {}
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
	local ok, model = pcall(CreatureModels.Build, speciesId, opts.Stage)
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
		local root = model.PrimaryPart :: BasePart
		root.CFrame = CFrame.Angles(0, math.rad(200), 0)
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

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i = #spinners, 1, -1 do
		local s = spinners[i]
		if not s.Frame.Parent then
			table.remove(spinners, i)
		elseif s.Frame.Visible and s.Model.PrimaryPart and not Theme.ReducedMotion then
			local root = s.Model.PrimaryPart :: BasePart
			root.CFrame = CFrame.Angles(0, math.rad(200) + math.sin(t * s.Speed) * 0.7, 0)
				* CFrame.new(0, math.abs(math.sin(t * 2.2)) * 0.15, 0)
		end
	end
end)

return Viewport
