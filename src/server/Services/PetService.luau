-- Pets: builds the equipped pet from parts and keeps it floating beside its owner.
-- The pet is held in place by physics constraints and simulated by its owner's client,
-- so it moves smoothly for everyone. (The owner's client also makes it bob up and down,
-- see client Controllers/Pets.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local ANCHOR_NAME = "PetAnchor"
local ANCHOR_OFFSET = Vector3.new(2.6, 1.4, 2.2) -- beside and slightly behind you

local PetService = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local petModels: { [Player]: Model } = {}
local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

-- Model building -----------------------------------------------------------------

type Builder = { Model: Model, Body: Part }

local function part(b: Builder, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or M.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = b.Body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = b.Body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = b.Model
	return p
end

local function eyes(b: Builder, y: number, z: number, spacing: number, size: number, color: Color3)
	for _, side in { -1, 1 } do
		part(b, "Eye", Vector3.new(size, size, 0.06), CFrame.new(side * spacing, y, z), color, M.Neon)
	end
end

local function light(p: BasePart, color: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1
	l.Parent = p
end

local LOOKS: { [string]: (Builder, Pets.PetDef) -> () } = {
	Cat = function(b, def)
		local fur, dark = def.Colors[1], def.Colors[2]
		b.Body.Size = Vector3.new(0.9, 0.7, 1.3)
		b.Body.Color = fur
		part(b, "Head", Vector3.new(0.8, 0.7, 0.7), CFrame.new(0, 0.4, -0.75), fur)
		for _, side in { -1, 1 } do
			part(b, "Ear", Vector3.new(0.2, 0.3, 0.12), CFrame.new(side * 0.25, 0.85, -0.75) * CFrame.Angles(0, 0, math.rad(side * -15)), dark)
			part(b, "Leg", Vector3.new(0.2, 0.35, 0.2), CFrame.new(side * 0.3, -0.45, -0.4), fur)
			part(b, "Leg", Vector3.new(0.2, 0.35, 0.2), CFrame.new(side * 0.3, -0.45, 0.4), fur)
		end
		part(b, "Tail", Vector3.new(0.15, 0.15, 0.9), CFrame.new(0, 0.4, 0.95) * CFrame.Angles(math.rad(50), 0, 0), fur)
		eyes(b, 0.48, -1.11, 0.18, 0.16, def.Glow)
	end,
	Bat = function(b, def)
		local body, wing = def.Colors[1], def.Colors[2]
		b.Body.Shape = Enum.PartType.Ball
		b.Body.Size = Vector3.one * 0.9
		b.Body.Color = body
		for _, side in { -1, 1 } do
			part(b, "Wing", Vector3.new(1.1, 0.06, 0.7), CFrame.new(side * 0.85, 0.15, 0) * CFrame.Angles(0, 0, math.rad(side * 20)), wing)
			part(b, "WingTip", Vector3.new(0.6, 0.06, 0.4), CFrame.new(side * 1.45, 0.4, 0.1) * CFrame.Angles(0, 0, math.rad(side * 40)), wing)
			part(b, "Ear", Vector3.new(0.15, 0.3, 0.1), CFrame.new(side * 0.2, 0.5, -0.1), body)
		end
		eyes(b, 0.1, -0.44, 0.15, 0.13, def.Glow)
	end,
	Slime = function(b, def)
		local yellow, orange, white = def.Colors[1], def.Colors[2], def.Colors[3]
		b.Body.Size = Vector3.new(1.2, 0.5, 1.2)
		b.Body.Color = yellow
		part(b, "Middle", Vector3.new(0.95, 0.45, 0.95), CFrame.new(0, 0.45, 0), orange)
		part(b, "Top", Vector3.new(0.65, 0.4, 0.65), CFrame.new(0, 0.85, 0), white)
		eyes(b, 0.5, -0.49, 0.2, 0.15, rgb(30, 25, 25))
		light(b.Body, def.Glow, 6)
	end,
	Ghost = function(b, def)
		local white = def.Colors[1]
		b.Body.Shape = Enum.PartType.Ball
		b.Body.Size = Vector3.one * 1.2
		b.Body.Color = white
		b.Body.Transparency = 0.15
		for i = 1, 3 do
			local wisp = part(b, "Wisp", Vector3.new(0.9 - i * 0.2, 0.35, 0.7 - i * 0.15), CFrame.new(0, -0.45 - i * 0.25, 0.1 * i), white)
			wisp.Transparency = 0.15 + i * 0.2
		end
		eyes(b, 0.15, -0.58, 0.2, 0.2, rgb(20, 20, 30))
		part(b, "Mouth", Vector3.new(0.18, 0.22, 0.06), CFrame.new(0, -0.15, -0.58), rgb(20, 20, 30))
		light(b.Body, def.Glow, 8)
	end,
	Pup = function(b, def)
		local bone, dark = def.Colors[1], def.Colors[2]
		b.Body.Size = Vector3.new(0.8, 0.6, 1.3)
		b.Body.Color = bone
		for i = -1, 1 do
			part(b, "Rib", Vector3.new(0.85, 0.08, 0.1), CFrame.new(0, 0.1, i * 0.3), dark)
		end
		part(b, "Head", Vector3.new(0.7, 0.65, 0.7), CFrame.new(0, 0.35, -0.8), bone)
		part(b, "Snout", Vector3.new(0.4, 0.3, 0.35), CFrame.new(0, 0.2, -1.25), bone)
		for _, side in { -1, 1 } do
			part(b, "Ear", Vector3.new(0.15, 0.35, 0.25), CFrame.new(side * 0.3, 0.6, -0.75) * CFrame.Angles(0, 0, math.rad(side * 30)), dark)
			part(b, "Leg", Vector3.new(0.18, 0.4, 0.18), CFrame.new(side * 0.25, -0.45, -0.4), bone)
			part(b, "Leg", Vector3.new(0.18, 0.4, 0.18), CFrame.new(side * 0.25, -0.45, 0.4), bone)
		end
		part(b, "Tail", Vector3.new(0.12, 0.12, 0.6), CFrame.new(0, 0.35, 0.85) * CFrame.Angles(math.rad(40), 0, 0), bone)
		eyes(b, 0.45, -1.16, 0.16, 0.13, def.Glow)
	end,
	Pumpkin = function(b, def)
		local orange, stem = def.Colors[1], def.Colors[2]
		b.Body.Shape = Enum.PartType.Ball
		b.Body.Size = Vector3.one * 1.3
		b.Body.Color = orange
		for i = 0, 2 do
			part(b, "Rib", Vector3.new(0.08, 1.33, 1.33), CFrame.Angles(0, i / 3 * math.pi, 0), orange:Lerp(rgb(150, 60, 10), 0.35), M.SmoothPlastic, Enum.PartType.Cylinder)
		end
		part(b, "Stem", Vector3.new(0.15, 0.35, 0.15), CFrame.new(0, 0.75, 0), stem, M.Wood)
		for _, side in { -1, 1 } do
			part(b, "Eye", Vector3.new(0.25, 0.2, 0.06), CFrame.new(side * 0.25, 0.15, -0.64) * CFrame.Angles(0, 0, math.rad(side * 15)), def.Glow, M.Neon)
		end
		part(b, "Grin", Vector3.new(0.6, 0.12, 0.06), CFrame.new(0, -0.2, -0.63), def.Glow, M.Neon)
		local fire = Instance.new("Fire")
		fire.Color = def.Glow
		fire.SecondaryColor = rgb(255, 80, 20)
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = b.Body
		light(b.Body, def.Glow, 12)
	end,
}

local function buildPet(def: Pets.PetDef, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = def.DisplayName
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.one
	body.Material = M.SmoothPlastic
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.CFrame = at
	body.Parent = model
	model.PrimaryPart = body
	local look = LOOKS[def.Look] or LOOKS.Ghost
	look({ Model = model, Body = body }, def)

	-- Name tag in the pet's rarity color
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 20)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	gui.MaxDistance = 40
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = Config.Rarities[def.Rarity] or Color3.new(1, 1, 1)
	label.Text = def.DisplayName
	label.Parent = gui
	return model
end

-- Following ----------------------------------------------------------------------

local function removePet(player: Player)
	local old = petModels[player]
	if old then
		old:Destroy()
		petModels[player] = nil
	end
end

local function spawnPet(player: Player)
	removePet(player)
	local data = PlayerService.GetData(player)
	local def = data and data.EquippedPet and Pets.Defs[data.EquippedPet]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not root then
		return
	end
	local anchor = root:FindFirstChild(ANCHOR_NAME) :: Attachment?
	if not anchor then
		anchor = Instance.new("Attachment")
		anchor.Name = ANCHOR_NAME
		anchor.Position = ANCHOR_OFFSET
		anchor.Parent = root
	end
	local model = buildPet(def, root.CFrame * CFrame.new(ANCHOR_OFFSET))
	local body = model.PrimaryPart :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Parent = body
	local align = Instance.new("AlignPosition")
	align.Attachment0 = attachment
	align.Attachment1 = anchor
	align.Responsiveness = 18
	align.MaxForce = 1e6
	align.Parent = body
	local turn = Instance.new("AlignOrientation")
	turn.Attachment0 = attachment
	turn.Attachment1 = anchor
	turn.Responsiveness = 12
	turn.MaxTorque = 1e6
	turn.Parent = body
	model.Parent = folder
	pcall(function()
		body:SetNetworkOwner(player)
	end)
	petModels[player] = model
end

local function onEquipPet(player: Player, petId: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	if petId == nil or petId == false then
		data.EquippedPet = nil
	elseif type(petId) == "string" and data.Pets[petId] then
		data.EquippedPet = petId
	else
		return false, "You don't own that pet"
	end
	spawnPet(player)
	PlayerService.RefreshStats(player)
	PlayerService.Push(player)
	return true
end

function PetService.Refresh(player: Player)
	spawnPet(player)
end

function PetService.Start()
	Remotes.EquipPet.OnServerInvoke = onEquipPet
	PlayerService.OnCharacterReady(function(player)
		spawnPet(player)
	end)
	Players.PlayerRemoving:Connect(removePet)
end

return PetService
