--!strict
-- Client side of explorable regions:
--   * travel prompts on gates (CE_Gate)
--   * the basin's mood: lighting, colour grading and drifting ash (stronger in eruptions)
--   * vents (CE_Vent) glowing as a warning, then erupting, on the shared server clock
--   * gathering prompts on resource deposits (CE_Node), dimmed while a deposit recovers
-- Everything that matters (heat, yields, cooldowns) is decided by the server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RegionConfig = require(Shared.Config.RegionConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local AssetConfig = require(Shared.Config.AssetConfig)
local Format = require(Shared.Util.Format)
local StateController = require(script.Parent.StateController)
local EffectsController = require(script.Parent.EffectsController)
local AudioController = require(script.Parent.AudioController)

local localPlayer = Players.LocalPlayer

local RegionController = {}

RegionController.Notify = function(_message: string, _kind: string) end

local mood: { Atmosphere: Atmosphere?, Color: ColorCorrectionEffect? } = {}
local original: { [string]: any } = {}
local ash: ParticleEmitter? = nil
local ashPart: Part? = nil
local currentRegion: string? = nil

local function region(): RegionConfig.Region?
	return if currentRegion then RegionConfig.Regions[currentRegion] else nil
end

-- Mood -----------------------------------------------------------------------------------

local function setupMood()
	-- Made by the server's WorldBuilder; wait briefly in case they haven't replicated yet.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Lighting:WaitForChild("Atmosphere", 10)
	local grade = Lighting:WaitForChild("CE_Grade", 10)
	mood.Atmosphere = if atmosphere and atmosphere:IsA("Atmosphere") then atmosphere else nil
	mood.Color = if grade and grade:IsA("ColorCorrectionEffect") then grade else nil
	if mood.Atmosphere then
		original.AtmosphereColor = mood.Atmosphere.Color
		original.AtmosphereDecay = mood.Atmosphere.Decay
		original.AtmosphereDensity = mood.Atmosphere.Density
	end
	if mood.Color then
		original.Tint = mood.Color.TintColor
		original.Saturation = mood.Color.Saturation
	end

	ashPart = Instance.new("Part")
	local part = ashPart :: Part
	part.Name = "AshEmitter"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(80, 1, 80)
	part.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = AssetConfig.Particles.Default
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 170, 120), Color3.fromRGB(90, 80, 80))
	emitter.LightEmission = 0.4
	emitter.Size = NumberSequence.new(0.25, 0.1)
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Acceleration = Vector3.new(1, -1.5, 0.5)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Enabled = false
	emitter.Parent = part
	ash = emitter
end

local function applyMood(regionId: string?, eruption: boolean)
	local info = TweenInfo.new(1.5)
	local inBasin = regionId == "Emberfall"
	if mood.Atmosphere then
		TweenService:Create(mood.Atmosphere, info, {
			Color = if inBasin
				then (if eruption then Color3.fromRGB(255, 120, 80) else Color3.fromRGB(230, 150, 120))
				else original.AtmosphereColor,
			Decay = if inBasin then Color3.fromRGB(110, 50, 40) else original.AtmosphereDecay,
			Density = if inBasin then (if eruption then 0.5 else 0.38) else original.AtmosphereDensity,
		}):Play()
	end
	if mood.Color then
		TweenService:Create(mood.Color, info, {
			TintColor = if inBasin
				then (if eruption then Color3.fromRGB(255, 200, 180) else Color3.fromRGB(255, 228, 210))
				else original.Tint,
		}):Play()
	end
	if ash then
		local vfx = EffectsController.Settings().Vfx
		ash.Enabled = inBasin and vfx ~= "Off"
		ash.Rate = (if eruption then 120 else 40) * (if vfx == "Reduced" then 0.4 else 1)
	end
end

-- Gates -------------------------------------------------------------------------------------

local function setupGate(portal: Instance)
	if not portal:IsA("BasePart") then
		return
	end
	local destination = portal:GetAttribute("Destination") :: string?
	local regionId = portal:GetAttribute("Region") :: string?
	local regionDef = regionId and RegionConfig.Regions[regionId]
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if destination == "Home" then "Return home" else "Travel"
	prompt.ObjectText = if destination == "Home" then "Your empire" else (regionDef and regionDef.Name or "")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal
	prompt.Triggered:Connect(function()
		local ok, result = StateController.Request("Travel", destination or "Home")
		if not ok then
			RegionController.Notify(result, "Error")
		end
	end)
end

-- Vents --------------------------------------------------------------------------------------

type VentFx = { Mouth: BasePart, Index: number, Fire: ParticleEmitter, Light: PointLight }
local vents: { VentFx } = {}

local function setupVent(mouth: Instance)
	if not mouth:IsA("BasePart") then
		return
	end
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = AssetConfig.Particles.Fire
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 20))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new(3, 0.5)
	fire.Lifetime = NumberRange.new(0.8, 1.4)
	fire.Speed = NumberRange.new(18, 26)
	fire.SpreadAngle = Vector2.new(10, 10)
	fire.Rate = 60
	fire.Enabled = false
	fire.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
	fire.Parent = mouth
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 18
	light.Brightness = 0
	light.Parent = mouth
	table.insert(
		vents,
		{ Mouth = mouth, Index = (mouth:GetAttribute("VentIndex") :: number?) or 1, Fire = fire, Light = light }
	)
end

-- Nodes ---------------------------------------------------------------------------------------

type NodeFx = { Model: Model, Id: string, Prompt: ProximityPrompt, Ores: { BasePart } }
local nodes: { NodeFx } = {}

local function setupNode(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local base = model.PrimaryPart or model:WaitForChild("Base", 5)
	if not base or not base:IsA("BasePart") then
		return
	end
	local regionId = model:GetAttribute("Region") :: string?
	local kindId = model:GetAttribute("Kind") :: string?
	local regionDef = regionId and RegionConfig.Regions[regionId]
	local kind = regionDef and kindId and regionDef.NodeKinds[kindId]
	if not kind then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Gather"
	prompt.ObjectText = kind.Name
	prompt.HoldDuration = kind.HoldTime
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	local id = model:GetAttribute("NodeId") :: string
	prompt.Triggered:Connect(function()
		local ok, result = StateController.Request("Gather", id)
		if ok then
			local resource = ResourceConfig[kind.Resource]
			EffectsController.Popup(
				base.Position + Vector3.new(0, 5, 0),
				`+{Format.Number(result)} {resource.Icon}`,
				resource.Color
			)
			EffectsController.Burst(
				base.Position + Vector3.new(0, 2, 0),
				resource.Color,
				25,
				{ Acceleration = Vector3.new(0, 6, 0) }
			)
			AudioController.Play("Collect", base.Position)
		else
			RegionController.Notify(result, "Error")
		end
	end)
	local ores = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Ore" then
			table.insert(ores, d)
		end
	end
	table.insert(nodes, { Model = model, Id = id, Prompt = prompt, Ores = ores })
end

local function refreshNodes()
	local readyAt = StateController.Get("Nodes") or {}
	local now = Workspace:GetServerTimeNow()
	for _, node in nodes do
		local cooling = (readyAt[node.Id] or 0) > now
		node.Prompt.Enabled = not cooling
		for _, ore in node.Ores do
			ore.Transparency = if cooling then 0.7 else 0.1
		end
	end
end

-- Public ----------------------------------------------------------------------------------------

function RegionController.CurrentRegion(): string?
	return currentRegion
end

function RegionController.Start()
	task.spawn(setupMood)
	for _, tag in { "CE_Gate", "CE_Vent", "CE_Node" } do
		local setup = if tag == "CE_Gate" then setupGate elseif tag == "CE_Vent" then setupVent else setupNode
		for _, instance in CollectionService:GetTagged(tag) do
			task.spawn(setup, instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			task.defer(setup, instance)
		end)
	end

	local lastEruption = false
	local function onRegion()
		local value = localPlayer:GetAttribute("Region") :: string?
		currentRegion = if value and value ~= "" then value else nil
		local r = region()
		lastEruption = r ~= nil and RegionConfig.EruptionActive(r, Workspace:GetServerTimeNow())
		applyMood(currentRegion, lastEruption)
	end
	localPlayer:GetAttributeChangedSignal("Region"):Connect(onRegion)
	onRegion()

	StateController.OnChanged("Nodes", refreshNodes)

	local frame = 0
	RunService.RenderStepped:Connect(function()
		frame += 1
		local r = region()
		local camera = Workspace.CurrentCamera
		if ashPart and camera and r then
			ashPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 25, 0))
		end
		if frame % 6 ~= 0 then
			return
		end
		local now = Workspace:GetServerTimeNow()
		if r then
			local eruption = RegionConfig.EruptionActive(r, now)
			if eruption ~= lastEruption then
				lastEruption = eruption
				applyMood(currentRegion, eruption)
				RegionController.Notify(
					if eruption
						then "The basin is erupting! Heat rises faster, and something is circling the Ashen Overlook…"
						else "The eruption has calmed down.",
					if eruption then "Error" else "Info"
				)
			end
			for _, vent in vents do
				local phase = RegionConfig.VentPhase(r, vent.Index, now)
				vent.Fire.Enabled = phase == "Active" and EffectsController.Settings().Vfx ~= "Off"
				vent.Light.Brightness = if phase == "Active"
					then 3
					elseif phase == "Warning" then 1 + math.sin(now * 12)
					else 0
				vent.Mouth.Color = if phase == "Warning"
					then Color3.fromRGB(255, 230, 120)
					else Color3.fromRGB(255, 110, 30)
			end
		end
		if frame % 30 == 0 then
			refreshNodes()
		end
	end)
end

return RegionController
