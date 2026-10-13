--!strict
-- Building placement mode: a ghost preview that snaps to the plot grid, turns green or red
-- using the same rules as the server (Shared/Util/Grid), rotates, and is confirmed or
-- cancelled. The server re-validates everything when the request arrives.
--
-- Controls:
--   Mouse/keyboard: move the mouse, R rotate, click to place, X or right-click to cancel.
--   Touch: tap the ground to move the preview, then use the on-screen Rotate/Place/Cancel.
--   Gamepad: the preview follows the centre of the screen; Y rotate, A place, B cancel.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared.Config.BuildingConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local Grid = require(Shared.Util.Grid)
local StateController = require(script.Parent.StateController)

local localPlayer = Players.LocalPlayer

local PlacementController = {}

-- Hooks set by the UI.
PlacementController.OnStateChanged = function(
	_active: boolean,
	_info: { Type: string, Valid: boolean, Reason: string? }?
)
end
PlacementController.Notify = function(_message: string, _kind: string) end

local active: { Type: string, Rot: number, X: number, Z: number, Valid: boolean, Reason: string? }? = nil
local ghost: Model? = nil
local ghostParts: { BasePart } = {}
local renderConnection: RBXScriptConnection? = nil
local mouseConnection: RBXScriptConnection? = nil
local touchPoint: Vector2? = nil
local busy = false

local VALID = Color3.fromRGB(90, 230, 150)
local INVALID = Color3.fromRGB(240, 90, 90)

local function myPlot(): Folder?
	local plots = Workspace:FindFirstChild("PlayerPlots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == localPlayer.UserId then
			return plot :: Folder
		end
	end
	return nil
end

local function footprints(): { [string]: Grid.Footprint }
	local map = {}
	for id, def in BuildingConfig do
		map[id] = def.Footprint
	end
	return map
end

local function buildGhost(typeId: string)
	local def = BuildingConfig[typeId]
	local model = Instance.new("Model")
	model.Name = "PlacementGhost"
	local w, d = def.Footprint.X * PlotConfig.CellSize, def.Footprint.Z * PlotConfig.CellSize
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.Size = Vector3.new(w, 0.3, d)
	base.Material = Enum.Material.Neon
	base.Transparency = 0.55
	base.Parent = model
	model.PrimaryPart = base
	-- A simple massing block so the size reads in 3D.
	local body = Instance.new("Part")
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Size = Vector3.new(w - 1, 2, d - 1)
	body.Material = Enum.Material.ForceField
	body.Transparency = 0.2
	body.CFrame = base.CFrame * CFrame.new(0, 1.1, 0)
	body.Parent = model
	-- Arrow showing the front.
	local arrow = Instance.new("WedgePart")
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.Size = Vector3.new(2, 0.4, 2)
	arrow.Material = Enum.Material.Neon
	arrow.CFrame = base.CFrame * CFrame.new(0, 0.3, -d / 2 - 1.2) * CFrame.Angles(0, math.pi, 0)
	arrow.Parent = model
	ghostParts = { base, body, arrow }
	model.Parent = Workspace
	ghost = model
end

local function aimRay(): Ray?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local screen: Vector2
	if UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") then
		screen = camera.ViewportSize / 2
	elseif touchPoint then
		screen = touchPoint
	else
		screen = UserInputService:GetMouseLocation()
	end
	return camera:ViewportPointToRay(screen.X, screen.Y)
end

local function update()
	if not active or not ghost then
		return
	end
	local plot = myPlot()
	local ray = aimRay()
	if not plot or not ray then
		return
	end
	local ground = plot:FindFirstChild("Ground")
	local floor = ground and ground:FindFirstChild("Floor")
	if not floor then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { floor }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not result then
		return
	end
	local origin = plot:GetAttribute("Origin") :: CFrame
	local localPos = origin:PointToObjectSpace(result.Position)
	local def = BuildingConfig[active.Type]
	local sx, sz = Grid.Rotated(def.Footprint, active.Rot)
	-- Centre the footprint on the cursor.
	local cx, cz =
		Grid.CellAt(localPos.X - (sx - 1) * PlotConfig.CellSize / 2, localPos.Z - (sz - 1) * PlotConfig.CellSize / 2)
	active.X, active.Z = cx, cz

	local buildings = StateController.Get("Buildings")
	local list = buildings and buildings.List or {}
	local occupancy = Grid.Occupancy(list, footprints())
	local ok, reason = Grid.CanPlace(occupancy, def.Footprint, cx, cz, active.Rot)
	local limits = buildings and buildings.Limits and buildings.Limits[active.Type]
	if ok and limits and limits.Owned >= limits.Limit then
		ok, reason = false, "Upgrade the Empire Core to build more."
	end
	local changed = ok ~= active.Valid or reason ~= active.Reason
	active.Valid, active.Reason = ok, reason

	local center = Grid.LocalCenter(def.Footprint, cx, cz, active.Rot)
	local cf = origin * CFrame.new(center) * CFrame.Angles(0, -active.Rot * math.pi / 2, 0)
	ghost:PivotTo(cf * CFrame.new(0, 0.2, 0))
	for _, part in ghostParts do
		part.Color = if ok then VALID else INVALID
	end
	if changed then
		PlacementController.OnStateChanged(true, { Type = active.Type, Valid = ok, Reason = reason })
	end
end

function PlacementController.IsActive(): boolean
	return active ~= nil
end

function PlacementController.Cancel()
	if not active then
		return
	end
	active = nil
	touchPoint = nil
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if mouseConnection then
		mouseConnection:Disconnect()
		mouseConnection = nil
	end
	ContextActionService:UnbindAction("CE_PlaceRotate")
	ContextActionService:UnbindAction("CE_PlaceConfirm")
	ContextActionService:UnbindAction("CE_PlaceCancel")
	PlacementController.OnStateChanged(false, nil)
end

function PlacementController.Rotate()
	if active then
		active.Rot = (active.Rot + 1) % 4
		update()
	end
end

function PlacementController.Confirm()
	if not active or busy then
		return
	end
	if not active.Valid then
		PlacementController.Notify(active.Reason or "You can't place that there.", "Error")
		return
	end
	busy = true
	local ok, result = StateController.Request("PlaceBuilding", active.Type, active.X, active.Z, active.Rot)
	busy = false
	if ok then
		PlacementController.Cancel()
	else
		PlacementController.Notify(result, "Error")
	end
end

function PlacementController.Begin(typeId: string)
	PlacementController.Cancel()
	if not myPlot() then
		PlacementController.Notify("Your plot is still loading.", "Error")
		return
	end
	active = { Type = typeId, Rot = 0, X = 0, Z = 0, Valid = false, Reason = nil }
	buildGhost(typeId)
	renderConnection = RunService.RenderStepped:Connect(update)

	ContextActionService:BindActionAtPriority("CE_PlaceRotate", function(_, state)
		if state == Enum.UserInputState.Begin then
			PlacementController.Rotate()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	-- Gamepad A / keys go through ContextActionService so they don't also jump; mouse
	-- clicks use UserInputService so clicks on interface buttons (Cancel!) never place.
	ContextActionService:BindActionAtPriority("CE_PlaceConfirm", function(_, state)
		if state == Enum.UserInputState.Begin then
			PlacementController.Confirm()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonA)
	mouseConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			PlacementController.Confirm()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			PlacementController.Cancel()
		end
	end)
	ContextActionService:BindActionAtPriority("CE_PlaceCancel", function(_, state)
		if state == Enum.UserInputState.Begin then
			PlacementController.Cancel()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.X, Enum.KeyCode.ButtonB)

	PlacementController.OnStateChanged(true, { Type = typeId, Valid = false, Reason = nil })
end

function PlacementController.Start()
	-- Touch: a tap on the world (not on UI) moves the preview.
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if active and not processed then
			touchPoint = position
		end
	end)
	-- Leaving the game or dying cancels placement cleanly.
	localPlayer.CharacterRemoving:Connect(function()
		PlacementController.Cancel()
	end)
end

return PlacementController
