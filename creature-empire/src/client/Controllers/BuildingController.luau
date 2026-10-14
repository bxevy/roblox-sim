--!strict
-- Interaction with buildings in the world, plus their live feedback:
--   * Proximity prompts (keyboard E/F, gamepad X/Y, touch tap): Collect / Manage / Trade on
--     your own buildings, Inspect on other players' plots (read-only).
--   * A storage bubble over each of your production buildings, extrapolated between server
--     updates from the server-provided rate (display only; the server decides amounts).
--   * Farm petals glow brighter as storage fills; the silo gauge shows how full it is.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared.Config.BuildingConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)
local Production = require(Shared.Util.Production)
local PlazaConfig = require(Shared.Config.PlazaConfig)
local StateController = require(script.Parent.StateController)
local EffectsController = require(script.Parent.EffectsController)
local AudioController = require(script.Parent.AudioController)

local localPlayer = Players.LocalPlayer

local BuildingController = {}

-- Set by Main: open the building panel / the visitor inspect window.
BuildingController.OpenPanel = function(_buildingId: string) end
BuildingController.OpenInspect = function(_ownerUserId: number) end
BuildingController.OpenSpin = function() end

-- Confetti over an empire that was just cheered.
function BuildingController.CheerFx(ownerUserId: number)
	local plots = game:GetService("Workspace"):FindFirstChild("PlayerPlots")
	for _, plot in plots and plots:GetChildren() or {} do
		if plot:GetAttribute("OwnerUserId") == ownerUserId then
			local buildings = plot:FindFirstChild("Buildings")
			local core = buildings and buildings:FindFirstChild("core")
			if core and core:IsA("Model") and core.PrimaryPart then
				local position = core.PrimaryPart.Position + Vector3.new(0, 10, 0)
				EffectsController.Burst(position, Color3.fromRGB(255, 210, 90), 50, { Speed = 16 })
				EffectsController.Burst(position, Color3.fromRGB(150, 220, 255), 30, { Speed = 12 })
				AudioController.Play("QuestComplete", position)
			end
		end
	end
end
BuildingController.Notify = function(_message: string, _kind: string) end

type Tracked = {
	Model: Model,
	Id: string,
	Type: string,
	Owned: boolean,
	Bubble: BillboardGui?,
	BubbleText: TextLabel?,
	BubbleFill: Frame?,
	Petals: { BasePart },
	Gauge: BasePart?,
	GaugeBase: CFrame?,
}

local tracked: { [Model]: Tracked } = {}

-- Predicted stored amount for one of my buildings right now.
function BuildingController.PredictedStored(buildingId: string): (number, number, string?)
	local buildings = StateController.Get("Buildings")
	local info = buildings and buildings.List and buildings.List[buildingId]
	if not info or not info.Output then
		return 0, 0, nil
	end
	local stored = info.Stored[info.Output] or 0
	-- No extrapolation while inputs have run out (the server paused it).
	local rate = if info.Starved then 0 else info.PerSecond or 0
	local predicted = math.min(stored + rate * StateController.Age("Buildings"), info.Capacity or 0)
	return predicted, info.Capacity or 0, info.Output
end

local function prompt(
	parent: Instance,
	action: string,
	objectText: string,
	key: Enum.KeyCode,
	gamepad: Enum.KeyCode,
	order: number
): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = objectText
	p.KeyboardKeyCode = key
	p.GamepadKeyCode = gamepad
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.UIOffset = Vector2.new(0, order * 72)
	p.Style = Enum.ProximityPromptStyle.Default
	p.Parent = parent
	return p
end

local function makeBubble(t: Tracked, color: Color3)
	local base = t.Model.PrimaryPart :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "StorageBubble"
	gui.Size = UDim2.fromOffset(130, 44)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = base
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 200, 255)
	stroke.Transparency = 0.6
	stroke.Parent = frame
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -12, 0, 24)
	text.Position = UDim2.fromOffset(6, 3)
	text.BackgroundTransparency = 1
	text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = frame
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(1, -16, 0, 7)
	barBack.Position = UDim2.new(0, 8, 1, -12)
	barBack.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	barBack.Parent = frame
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.Parent = barBack
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	gui.Parent = base
	t.Bubble = gui
	t.BubbleText = text
	t.BubbleFill = fill
end

local function track(model: Instance, owned: boolean, helper: boolean?)
	if not model:IsA("Model") then
		return
	end
	local base = model.PrimaryPart or model:WaitForChild("Base", 5)
	if not base or not base:IsA("BasePart") then
		return
	end
	local id = model:GetAttribute("BuildingId") :: string? or model.Name
	local typeId = model:GetAttribute("BuildingType") :: string? or model.Name
	local def = BuildingConfig[typeId]
	if not def then
		return
	end
	local t: Tracked = { Model = model, Id = id, Type = typeId, Owned = owned, Petals = {} }

	local output = Production.OutputOf(def)
	local outputDef = output and ResourceConfig[output] or ResourceConfig.Moonpetal
	if owned then
		if def.Recipe then
			local collect = prompt(base, "Collect", def.Name, Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0)
			collect.Triggered:Connect(function()
				local ok, result = StateController.Request("Collect", id)
				if ok then
					AudioController.Play("Collect", base.Position)
					EffectsController.Popup(
						base.Position + Vector3.new(0, 6, 0),
						"+" .. Format.Number(result) .. " " .. outputDef.Icon,
						outputDef.Color
					)
					EffectsController.Burst(
						base.Position + Vector3.new(0, 2, 0),
						outputDef.Color,
						20,
						{ Acceleration = Vector3.new(0, 8, 0) }
					)
				else
					BuildingController.Notify(result, "Error")
				end
			end)
			makeBubble(t, outputDef.Color)
		end
		local action = if typeId == "TradingPost" then "Trade" elseif def.Locked then "Inspect" else "Manage"
		local manage = prompt(base, action, def.Name, Enum.KeyCode.F, Enum.KeyCode.ButtonY, if def.Recipe then 1 else 0)
		manage.Triggered:Connect(function()
			BuildingController.OpenPanel(id)
		end)
	else
		local ownerId = model:GetAttribute("OwnerUserId") :: number?
		local inspect = prompt(base, "Inspect empire", def.Name, Enum.KeyCode.F, Enum.KeyCode.ButtonY, 0)
		inspect.MaxActivationDistance = 12
		inspect.Triggered:Connect(function()
			if ownerId then
				BuildingController.OpenInspect(ownerId)
			end
		end)
		-- Collaborators collect for the owner (into the owner's silo).
		if helper and def.Recipe and ownerId then
			local collect = prompt(base, "Collect for owner", def.Name, Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0)
			collect.Triggered:Connect(function()
				local ok, result = StateController.Request("CollectFor", ownerId, id)
				if ok then
					AudioController.Play("Collect", base.Position)
					EffectsController.Popup(
						base.Position + Vector3.new(0, 6, 0),
						"+" .. Format.Number(result) .. " " .. outputDef.Icon .. " (for owner)",
						outputDef.Color
					)
				else
					BuildingController.Notify(result, "Error")
				end
			end)
		end
		-- Anyone can cheer at someone else's Empire Core.
		if typeId == "EmpireCore" and ownerId then
			local cheer = prompt(base, "Cheer!", "Boost their creatures", Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0.5)
			cheer.MaxActivationDistance = 14
			cheer.Triggered:Connect(function()
				local ok, result = StateController.Request("Cheer", ownerId)
				if ok then
					BuildingController.Notify(
						if result and result.Gift
							then "Cheered! Their creatures work faster for 10 minutes. +50 gold thank-you gift."
							else "Cheered! Their creatures work faster for 10 minutes.",
						"Success"
					)
				else
					BuildingController.Notify(result, "Error")
				end
			end)
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "Petal" then
			table.insert(t.Petals, descendant)
		elseif descendant:IsA("BasePart") and descendant.Name == "FillGauge" then
			t.Gauge = descendant
			t.GaugeBase = descendant.CFrame
		end
	end
	tracked[model] = t
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Folder") then
		return
	end
	local buildings = plot:WaitForChild("Buildings", 10)
	if not buildings then
		return
	end
	local function owned(): boolean
		return plot:GetAttribute("OwnerUserId") == localPlayer.UserId
	end
	local function helper(): boolean
		local list = plot:GetAttribute("Collaborators") :: string?
		return list ~= nil and string.find(list, "," .. localPlayer.UserId .. ",", 1, true) ~= nil
	end
	local function refreshAll()
		for model, t in tracked do
			if model.Parent == buildings then
				for _, child in (model.PrimaryPart :: BasePart):GetChildren() do
					if child:IsA("ProximityPrompt") or child.Name == "StorageBubble" then
						child:Destroy()
					end
				end
				tracked[model] = nil
				task.spawn(track, model, owned(), helper())
			end
			local _ = t
		end
	end
	for _, model in buildings:GetChildren() do
		task.spawn(track, model, owned(), helper())
	end
	buildings.ChildAdded:Connect(function(model)
		task.wait() -- let the model's descendants replicate
		track(model, owned(), helper())
	end)
	buildings.ChildRemoved:Connect(function(model)
		tracked[model :: Model] = nil
	end)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshAll)
	plot:GetAttributeChangedSignal("Collaborators"):Connect(refreshAll)
end

-- Per-frame display updates (cheap: a handful of buildings).
local function update()
	local wallet = StateController.Get("Wallet")
	for model, t in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		if not t.Owned then
			continue
		end
		if t.Bubble and t.BubbleText and t.BubbleFill then
			local stored, capacity, output = BuildingController.PredictedStored(t.Id)
			local resource = output and ResourceConfig[output]
			local alpha = if capacity > 0 then stored / capacity else 0
			local full = capacity > 0 and stored >= capacity - 0.01
			t.BubbleText.Text = (if resource then resource.Icon .. " " else "")
				.. Format.Number(math.floor(stored))
				.. " / "
				.. Format.Number(capacity)
				.. (if full then "  FULL" else "")
			t.BubbleText.TextColor3 = if full then Color3.fromRGB(255, 210, 90) else Color3.new(1, 1, 1)
			t.BubbleFill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
			for _, petal in t.Petals do
				petal.Transparency = 0.75 - 0.7 * alpha
			end
		end
		if t.Gauge and t.GaugeBase and wallet then
			-- Overall fill across every stored material.
			local capacity, amount = 0, 0
			for id, cap in wallet.Capacity or {} do
				capacity += cap
				amount += math.min(wallet.Resources[id] or 0, cap)
			end
			local alpha = if capacity > 0 then math.clamp(amount / capacity, 0, 1) else 0
			local maxHeight = (t.Gauge:GetAttribute("MaxHeight") :: number?) or 6
			local height = math.max(maxHeight * alpha, 0.2)
			t.Gauge.Size = Vector3.new(t.Gauge.Size.X, height, t.Gauge.Size.Z)
			t.Gauge.CFrame = t.GaugeBase * CFrame.new(0, height / 2 - 0.1, 0)
		end
	end
end

-- The plaza stations (Trading Post, Hatchery, Spin Wheel) everyone shares.
local function trackStation(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("PlazaStation") :: string?
	local station = id and PlazaConfig.Stations[id]
	local base = model.PrimaryPart or model:WaitForChild("Base", 5)
	if not station or not base or not base:IsA("BasePart") or base:FindFirstChild("StationPrompt") then
		return
	end
	local p = prompt(base, station.Action, station.Name, Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0)
	p.Name = "StationPrompt"
	p.MaxActivationDistance = 16
	p.Triggered:Connect(function()
		if id == "SpinWheel" then
			BuildingController.OpenSpin()
		else
			BuildingController.OpenPanel("plaza:" .. (id :: string))
		end
	end)
	if id == "SpinWheel" then
		-- Over the wheel: whether your free spin is ready, or how long until it is.
		local gui = Instance.new("BillboardGui")
		gui.Name = "SpinStatus"
		gui.Size = UDim2.fromScale(16, 2.4)
		gui.StudsOffset = Vector3.new(0, 21, 0)
		gui.MaxDistance = 160
		gui.LightInfluence = 0
		gui.Adornee = base
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
		text.TextScaled = true
		text.TextStrokeTransparency = 0.2
		text.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
		text.Parent = gui
		gui.Parent = base
		task.spawn(function()
			while gui.Parent do
				local spin = StateController.Get("Spin")
				local wait = if spin then math.max((spin.NextFreeAt or 0) - Workspace:GetServerTimeNow(), 0) else 0
				if wait <= 0 then
					text.Text = "FREE SPIN READY!"
					text.TextColor3 = Color3.fromRGB(255, 215, 80)
				else
					text.Text = "Next free spin " .. Format.Duration(wait)
					text.TextColor3 = Color3.fromRGB(235, 240, 255)
				end
				task.wait(1)
			end
		end)
	end
end

function BuildingController.Start()
	for _, model in CollectionService:GetTagged("CE_PlazaStation") do
		task.spawn(trackStation, model)
	end
	CollectionService:GetInstanceAddedSignal("CE_PlazaStation"):Connect(function(model)
		task.defer(trackStation, model) -- wait for its parts to replicate
	end)

	local plots = Workspace:WaitForChild("PlayerPlots")
	for _, plot in plots:GetChildren() do
		task.spawn(watchPlot, plot)
	end
	plots.ChildAdded:Connect(watchPlot)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			update()
		end
	end)

	Remotes.Events.GameEvent.OnClientEvent:Connect(function(name, payload)
		if name == "BuildingUpgraded" or name == "BuildingPlaced" then
			AudioController.Play(if name == "BuildingPlaced" then "Place" else "Upgrade")
			-- The new model replicates shortly after the event; play the effect on it.
			task.delay(0.3, function()
				for model, t in tracked do
					if t.Owned and t.Id == payload.Id and model.Parent then
						EffectsController.Construct(model)
					end
				end
			end)
		end
	end)
end

return BuildingController
