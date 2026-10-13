--!strict
-- Client-only visual effects: floating numbers, bursts, ability flashes, upgrade
-- construction sparkle, and the ambient motion of tagged world parts (spinning windmills,
-- bobbing crystals). Nothing here affects game state.
--
-- Respects settings: Vfx "Off" skips bursts and ambient motion, "Reduced" halves particle
-- counts, ReducedMotion stops bobbing/spinning and tones down popups.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetConfig = require(Shared.Config.AssetConfig)
local StateController = require(script.Parent.StateController)

local EffectsController = {}

local settings = { Vfx = "Full", ReducedMotion = false }
local ACTIVE_RANGE = 220 -- ambient motion only near the camera
local MAX_POPUPS = 24
local popupCount = 0

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "ClientEffects"
effectsFolder.Parent = Workspace

function EffectsController.Settings()
	return settings
end

local function particleScale(): number
	return if settings.Vfx == "Off" then 0 elseif settings.Vfx == "Reduced" then 0.5 else 1
end

-- Floating text that rises and fades (e.g. "+12 ✿").
function EffectsController.Popup(position: Vector3, text: string, color: Color3?)
	if popupCount >= MAX_POPUPS then
		return
	end
	popupCount += 1
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = effectsFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local rise = if settings.ReducedMotion then 1.5 else 4
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = CFrame.new(position + Vector3.new(0, rise, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.25, function()
		popupCount -= 1
		anchor:Destroy()
	end)
end

-- A one-shot particle burst.
function EffectsController.Burst(position: Vector3, color: Color3, count: number, options: { [string]: any }?)
	local scale = particleScale()
	if scale <= 0 then
		return
	end
	local opts: { [string]: any } = options or {}
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = opts.Texture or AssetConfig.Particles.Default
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = opts.LightEmission or 0.8
	emitter.Size = NumberSequence.new(opts.Size or 0.6, 0)
	emitter.Lifetime = NumberRange.new(0.5, opts.Lifetime or 1)
	emitter.Speed = NumberRange.new(opts.SpeedMin or 4, opts.Speed or 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = opts.Acceleration or Vector3.new(0, -8, 0)
	emitter.Drag = 2
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(math.max(1, math.floor(count * scale)))
	Debris:AddItem(attachment, 2.5)
end

-- An expanding ring of light on the ground (ability casts, upgrades).
function EffectsController.Ring(position: Vector3, color: Color3, radius: number)
	if settings.Vfx == "Off" then
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = effectsFolder
	local info =
		TweenInfo.new(if settings.ReducedMotion then 0.3 else 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 1)
end

-- Upgrade / construction: rising sparkles and a ring around the building.
function EffectsController.Construct(model: Model)
	local base = model.PrimaryPart
	if not base then
		return
	end
	local size = base.Size
	local radius = math.max(size.X, size.Z) / 2
	EffectsController.Ring(base.Position + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 220, 120), radius + 2)
	EffectsController.Burst(base.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 230, 150), 40, {
		Acceleration = Vector3.new(0, 6, 0),
		Speed = 8,
		Lifetime = 1.4,
	})
	EffectsController.Burst(base.Position + Vector3.new(0, 1, 0), Color3.fromRGB(200, 190, 170), 20, {
		Texture = AssetConfig.Particles.Smoke,
		Size = 2,
		LightEmission = 0,
		Acceleration = Vector3.new(0, 2, 0),
	})
end

-- Ambient motion for tagged parts --------------------------------------------------------

type Spinner = { Model: Model, Base: CFrame, Speed: number, Axis: string }
type Bobber = { Part: BasePart, Base: CFrame, Height: number, Phase: number }

local spinners: { [Instance]: Spinner } = {}
local bobbers: { [Instance]: Bobber } = {}

local function trackSpinner(model: Instance)
	if model:IsA("Model") and model.PrimaryPart then
		spinners[model] = {
			Model = model,
			Base = model:GetPivot(),
			Speed = (model:GetAttribute("SpinSpeed") :: number?) or 30,
			Axis = (model:GetAttribute("SpinAxis") :: string?) or "Y",
		}
	end
end

local function trackBobber(part: Instance)
	if part:IsA("BasePart") then
		bobbers[part] = {
			Part = part,
			Base = part.CFrame,
			Height = (part:GetAttribute("BobHeight") :: number?) or 0.5,
			Phase = math.random() * math.pi * 2,
		}
	end
end

local function startAmbientMotion()
	for _, model in CollectionService:GetTagged("CE_Spin") do
		trackSpinner(model)
	end
	for _, part in CollectionService:GetTagged("CE_Bob") do
		trackBobber(part)
	end
	CollectionService:GetInstanceAddedSignal("CE_Spin"):Connect(function(model)
		task.defer(trackSpinner, model) -- wait for children to replicate
	end)
	CollectionService:GetInstanceRemovedSignal("CE_Spin"):Connect(function(model)
		spinners[model] = nil
	end)
	CollectionService:GetInstanceAddedSignal("CE_Bob"):Connect(trackBobber)
	CollectionService:GetInstanceRemovedSignal("CE_Bob"):Connect(function(part)
		bobbers[part] = nil
	end)

	local frame = 0
	RunService.RenderStepped:Connect(function()
		frame += 1
		if settings.ReducedMotion or settings.Vfx == "Off" or frame % 2 == 1 then
			return -- 30 updates per second is plenty for slow ambient motion
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		for instance, spin in spinners do
			if not instance.Parent then
				spinners[instance] = nil
			elseif (spin.Base.Position - camPos).Magnitude < ACTIVE_RANGE then
				local angle = math.rad(spin.Speed * t)
				local rotation = if spin.Axis == "Z" then CFrame.Angles(0, 0, angle) else CFrame.Angles(0, angle, 0)
				spin.Model:PivotTo(spin.Base * rotation)
			end
		end
		for instance, bob in bobbers do
			if not instance.Parent then
				bobbers[instance] = nil
			elseif (bob.Base.Position - camPos).Magnitude < ACTIVE_RANGE then
				bob.Part.CFrame = bob.Base
					* CFrame.new(0, math.sin(t * 1.4 + bob.Phase) * bob.Height, 0)
					* CFrame.Angles(0, t * 0.3, 0)
			end
		end
	end)
end

function EffectsController.Start()
	StateController.OnChanged("Settings", function(newSettings)
		settings = newSettings
	end)
	startAmbientMotion()
end

return EffectsController
