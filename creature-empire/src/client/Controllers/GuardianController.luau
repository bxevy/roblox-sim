--!strict
-- Draws guardian fights and sends attack input. The server decides everything; this shows
-- the giant guardian, its health, telegraphed slam circles (they fill up until impact,
-- on the shared server clock), slams, hits and defeat.
--
-- Controls near the arena: 1 / R1 = Attack, 2 / L1 = Special (also on-screen buttons).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local Remotes = require(Shared.Remotes)
local CreatureModels = require(script.Parent.Parent.Visuals.CreatureModels)
local StateController = require(script.Parent.StateController)
local EffectsController = require(script.Parent.EffectsController)
local AudioController = require(script.Parent.AudioController)

local localPlayer = Players.LocalPlayer

local GuardianController = {}

-- Hooks for the HUD.
GuardianController.OnNearChanged = function(_near: boolean, _info: any?) end
GuardianController.OnHealth = function(_info: any) end
GuardianController.Notify = function(_message: string, _kind: string) end

type View = {
	Id: string,
	Anchor: Instance,
	Model: Model?,
	Position: Vector3,
	Radius: number,
	Height: number,
	Highlight: Highlight?,
}

local views: { [string]: View } = {}
local near: View? = nil
local cooldowns = { Attack = 0, Special = 0 }
local SCALE = 3

local function info(view: View): any
	local anchor = view.Anchor
	return {
		Id = view.Id,
		Name = anchor:GetAttribute("Name"),
		Health = anchor:GetAttribute("Health") or 0,
		MaxHealth = anchor:GetAttribute("MaxHealth") or 1,
		Phase = anchor:GetAttribute("Phase") or 1,
		Alive = anchor:GetAttribute("Alive") ~= false,
		RespawnAt = anchor:GetAttribute("RespawnAt") or 0,
	}
end

local function build(view: View)
	if view.Model then
		return
	end
	local species = view.Anchor:GetAttribute("Species") :: string?
	if not species or not CreatureConfig.Species[species] then
		return
	end
	local model = CreatureModels.Build(species, 3)
	model:ScaleTo(SCALE)
	view.Height = ((model:GetAttribute("Height") :: number?) or 2) * SCALE
	model:PivotTo(CFrame.new(view.Position + Vector3.new(0, view.Height, 0)))
	model.Name = "Guardian_" .. view.Id
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.Parent = model
	view.Highlight = highlight
	view.Model = model
	-- Only shown while alive (a defeated guardian is away until it respawns).
	model.Parent = if view.Anchor:GetAttribute("Alive") ~= false then Workspace else nil
end

local function telegraph(position: Vector3, radius: number, impactAt: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 80, 40)
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.15, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	local fill = ring:Clone()
	fill.Transparency = 0.25
	fill.Size = Vector3.new(0.2, 0.5, 0.5)
	fill.Parent = Workspace
	local remaining = math.max(impactAt - Workspace:GetServerTimeNow(), 0.1)
	TweenService:Create(
		fill,
		TweenInfo.new(remaining, Enum.EasingStyle.Linear),
		{ Size = Vector3.new(0.2, radius * 2, radius * 2) }
	):Play()
	task.delay(remaining + 0.05, function()
		ring:Destroy()
		fill:Destroy()
	end)
end

local function shake(strength: number)
	local settings = StateController.Get("Settings")
	if settings and (not settings.CameraShake or settings.ReducedMotion) then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	task.spawn(function()
		for i = 1, 8 do
			local amount = strength * (1 - i / 8)
			camera.CFrame *= CFrame.new(math.random(-10, 10) / 10 * amount, math.random(-10, 10) / 10 * amount, 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

function GuardianController.Attack(kind: "Attack" | "Special")
	if not near then
		return
	end
	local now = os.clock()
	if now < cooldowns[kind] then
		return
	end
	cooldowns[kind] = now + (if kind == "Special" then CombatConfig.Special.Cooldown else CombatConfig.Attack.Cooldown)
	task.spawn(function()
		local ok, result = StateController.Request("GuardianAttack", kind)
		if not ok then
			cooldowns[kind] = 0
			GuardianController.Notify(result, "Error")
		end
	end)
end

function GuardianController.Cooldowns(): { Attack: number, Special: number }
	return cooldowns
end

local function addAnchor(anchor: Instance)
	local position = anchor:GetAttribute("Position") :: Vector3?
	if not position then
		return
	end
	local view: View = {
		Id = anchor.Name,
		Anchor = anchor,
		Model = nil,
		Position = position,
		Radius = (anchor:GetAttribute("ArenaRadius") :: number?) or 40,
		Height = 6,
		Highlight = nil,
	}
	views[anchor.Name] = view
	anchor.AttributeChanged:Connect(function(attribute)
		if near == view then
			GuardianController.OnHealth(info(view))
		end
		if attribute == "Alive" then
			local alive = anchor:GetAttribute("Alive") ~= false
			if view.Model then
				view.Model.Parent = if alive then Workspace else nil
			end
			if alive and near == view then
				GuardianController.Notify(`{anchor:GetAttribute("Name")} has returned to the caldera!`, "Error")
			end
		end
	end)
end

function GuardianController.Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Guardians", 30)
		if not folder then
			return
		end
		for _, anchor in folder:GetChildren() do
			addAnchor(anchor)
		end
		folder.ChildAdded:Connect(function(anchor)
			task.defer(addAnchor, anchor)
		end)
	end)

	Remotes.Events.GameEvent.OnClientEvent:Connect(function(name: string, payload: any)
		local view = payload and payload.Guardian and views[payload.Guardian]
		if name == "GuardianTelegraph" then
			if near then
				telegraph(payload.Position, payload.Radius, payload.ImpactAt)
			end
		elseif name == "GuardianSlam" and view then
			EffectsController.Ring(
				payload.Position + Vector3.new(0, 0.5, 0),
				Color3.fromRGB(255, 120, 40),
				payload.Radius + 3
			)
			EffectsController.Burst(
				payload.Position + Vector3.new(0, 1, 0),
				Color3.fromRGB(255, 140, 60),
				40,
				{ Speed = 18 }
			)
			if near == view then
				shake(0.8)
				AudioController.Play("AbilityCast", payload.Position)
			end
		elseif name == "GuardianHit" and view and view.Model and view.Model.PrimaryPart then
			local position = view.Model.PrimaryPart.Position + Vector3.new(0, view.Height * 0.6, 0)
			local family = CreatureConfig.Families[payload.Family]
			EffectsController.Popup(
				position + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)),
				`-{payload.Damage}`,
				if payload.Special then Color3.fromRGB(255, 220, 90) else Color3.new(1, 1, 1)
			)
			EffectsController.Burst(
				position,
				family and family.Color or Color3.new(1, 1, 1),
				if payload.Special then 40 else 12,
				{ Speed = 14 }
			)
			if payload.Support then
				EffectsController.Ring(
					Vector3.new(position.X, view.Position.Y + 0.6, position.Z),
					Color3.fromRGB(120, 230, 255),
					CombatConfig.Special.CoolRadius
				)
			end
			if view.Highlight then
				view.Highlight.FillTransparency = 0.5
				TweenService:Create(view.Highlight, TweenInfo.new(0.25), { FillTransparency = 1 }):Play()
			end
		elseif name == "GuardianDefeated" and view and near == view then
			GuardianController.Notify(
				`{view.Anchor:GetAttribute("Name")} is defeated! She'll return in a few minutes.`,
				"Reward"
			)
			if view.Model and view.Model.PrimaryPart then
				EffectsController.Burst(
					view.Model.PrimaryPart.Position,
					Color3.fromRGB(255, 200, 120),
					80,
					{ Speed = 22, Lifetime = 2 }
				)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not near then
			return
		end
		if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.ButtonR1 then
			GuardianController.Attack("Attack")
		elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.ButtonL1 then
			GuardianController.Attack("Special")
		end
	end)

	RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local nowNear: View? = nil
		local t = os.clock()
		for _, view in views do
			local distance = if root
				then (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(
					view.Position.X,
					0,
					view.Position.Z
				)).Magnitude
				else math.huge
			if distance < 250 then
				build(view)
			end
			local alive = view.Anchor:GetAttribute("Alive") ~= false
			if view.Model and view.Model.PrimaryPart and alive then
				-- Slow, heavy breathing and turning toward the nearest challenger.
				local facing = if root and distance < view.Radius + 30
					then math.atan2(-(root.Position.X - view.Position.X), -(root.Position.Z - view.Position.Z))
					else t * 0.1
				view.Model.PrimaryPart.CFrame = CFrame.new(
					view.Position + Vector3.new(0, view.Height + math.sin(t * 1.5) * 0.4, 0)
				) * CFrame.Angles(0, facing, 0)
			end
			-- Same reach the server allows for attacks (arena radius + 15).
			if distance <= view.Radius + 15 and root and math.abs(root.Position.Y - view.Position.Y) < 30 then
				nowNear = view
			end
		end
		if nowNear ~= near then
			near = nowNear
			GuardianController.OnNearChanged(near ~= nil, if near then info(near) else nil)
		end
	end)
end

return GuardianController
