--!strict
-- Guides new players: while a tutorial step has a `Pointer`, a glowing trail runs from
-- the player to the target building and a bouncing marker floats above it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetConfig = require(Shared.Config.AssetConfig)
local StateController = require(script.Parent.StateController)

local localPlayer = Players.LocalPlayer

local TutorialController = {}

local COLOR = Color3.fromRGB(255, 220, 110)

local beam: Beam? = nil
local startAttachment: Attachment? = nil
local endAttachment: Attachment? = nil
local marker: BillboardGui? = nil
local markerLabel: TextLabel? = nil
local currentTarget: BasePart? = nil

local function myBuildingOfType(typeId: string): BasePart?
	local plots = Workspace:FindFirstChild("PlayerPlots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == localPlayer.UserId then
			local buildings = plot:FindFirstChild("Buildings")
			if not buildings then
				return nil
			end
			-- Prefer the fixed id, then the first of that type (sorted for stability).
			local best: Model? = nil
			for _, model in buildings:GetChildren() do
				if model:GetAttribute("BuildingType") == typeId and model:IsA("Model") then
					if not best or model.Name < best.Name then
						best = model
					end
				end
			end
			return best and best.PrimaryPart
		end
	end
	return nil
end

local function clear()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if startAttachment then
		startAttachment:Destroy()
		startAttachment = nil
	end
	if endAttachment then
		endAttachment:Destroy()
		endAttachment = nil
	end
	if marker then
		marker:Destroy()
		marker = nil
	end
	currentTarget = nil
end

local function pointAt(target: BasePart)
	if currentTarget == target and beam and beam.Parent then
		return
	end
	clear()
	currentTarget = target
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TutorialStart"
	a0.Position = Vector3.new(0, -2.5, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TutorialEnd"
	a1.Position = Vector3.new(0, 1, 0)
	a1.Parent = target
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(COLOR)
	b.LightEmission = 1
	b.Width0 = 0.6
	b.Width1 = 0.6
	b.FaceCamera = true
	b.Texture = AssetConfig.Particles.Default
	b.TextureMode = Enum.TextureMode.Static
	b.TextureLength = 2
	b.TextureSpeed = 1.5
	b.Transparency = NumberSequence.new(0.2)
	b.Segments = 20
	b.CurveSize0 = 4
	b.CurveSize1 = -4
	b.Parent = root
	beam, startAttachment, endAttachment = b, a0, a1

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffset = Vector3.new(0, 14, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "▼"
	label.TextScaled = true
	label.TextColor3 = COLOR
	label.TextStrokeTransparency = 0.2
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	label.Parent = gui
	gui.Parent = target
	marker, markerLabel = gui, label
end

local function refresh()
	local quests = StateController.Get("Quests")
	local step = quests and quests.Step
	if not step or not step.Pointer or quests.Claimable then
		clear()
		return
	end
	local target = myBuildingOfType(step.Pointer)
	if target then
		pointAt(target)
	else
		clear()
	end
end

function TutorialController.Start()
	StateController.OnChanged("Quests", refresh)
	localPlayer.CharacterAdded:Connect(function()
		clear()
		task.wait(1)
		refresh()
	end)
	-- Re-check now and then: target buildings get rebuilt on upgrade.
	task.spawn(function()
		while true do
			task.wait(1.5)
			if currentTarget and not currentTarget.Parent then
				clear()
			end
			refresh()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if marker and markerLabel then
			marker.StudsOffset = Vector3.new(0, 13 + math.abs(math.sin(os.clock() * 3)) * 1.5, 0)
			-- Hide the trail once the player has arrived.
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if beam and root and currentTarget then
				beam.Enabled = (root.Position - currentTarget.Position).Magnitude > 16
			end
		end
	end)
end

return TutorialController
