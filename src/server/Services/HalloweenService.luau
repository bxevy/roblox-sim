-- The Halloween event (Config.Events.Halloween): candies, the Halloween Crate, and the
-- spooky event plaza in town.
--
-- Candies come from clearing the event dungeon (DungeonService). The crate costs candies
-- or Robux and can give the limited Pumpkin Warlock class, pieces of the limited
-- Pumpkin Reaper / Vampire Lord armor sets, or a pet. Odds are in the config and shown
-- to players in the event window. Duplicates refund some candies.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local PetService = require(script.Parent.PetService)
local Receipts = require(script.Parent.Parent.Receipts)
local Sfx = require(script.Parent.Parent.Sfx)

local EVENT_ID = "Halloween"
local PLAZA_POSITION = Vector3.new(40, 0, -20)

local HalloweenService = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local ORANGE = rgb(240, 120, 20)
local PURPLE = rgb(130, 60, 200)

local event = Config.Events[EVENT_ID]
local crate = event.Crate
local opening: { [Player]: boolean } = {}

local function isActive(): boolean
	return Config.IsEventActive(EVENT_ID)
end

-- Rolling --------------------------------------------------------------------------

local function rollEntry()
	local roll = math.random()
	for _, entry in crate.Odds do
		roll -= entry.Chance
		if roll <= 0 then
			return entry
		end
	end
	return crate.Odds[#crate.Odds]
end

local function announce(player: Player, text: string, color: Color3)
	task.delay(3.5, function()
		for _, other in Players:GetPlayers() do
			PlayerService.Notify(other, `{player.DisplayName} {text}`, color)
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Sfx.play("LevelUp", root, 1.5)
		end
	end)
end

-- Opens one crate for a player who has already paid. Returns what they got.
local function openCrate(player: Player)
	local data = PlayerService.GetData(player)
	if not data then
		return nil
	end
	PlayerService.AddStat(player, "EventCratesOpened")
	local entry = rollEntry()
	local result = { Kind = entry.Kind, Id = entry.Id, IsNew = true, Refund = 0, DisplayName = "", Rarity = "Common" }

	if entry.Kind == "Class" then
		local class = Config.Classes[entry.Id]
		result.DisplayName = class.DisplayName
		result.Rarity = class.Rarity
		if data.LimitedClasses[entry.Id] then
			result.IsNew = false
		else
			data.LimitedClasses[entry.Id] = true
			task.delay(3.5, function()
				if player.Parent then
					PlayerService.SetClass(player, entry.Id)
				end
			end)
			announce(player, `unboxed the LIMITED {string.upper(class.DisplayName)} CLASS!!!`, Config.Rarities.Limited)
		end
	elseif entry.Kind == "Armor" then
		local set = Items.ArmorSets[entry.Id]
		local slot = Items.ArmorSlots[math.random(#Items.ArmorSlots)]
		local piece = Items.Armors[set.Pieces[slot]]
		result.Id = piece.Id
		result.DisplayName = piece.DisplayName
		result.Rarity = piece.Rarity
		result.IsNew = PlayerService.GiveItem(player, "Armor", piece.Id)
		if result.IsNew and entry.Id == "VampireLord" then
			announce(player, `unboxed {piece.DisplayName}!`, Config.Rarities.Limited)
		end
	else
		local pet = Pets.Defs[entry.Id]
		result.DisplayName = pet.DisplayName
		result.Rarity = pet.Rarity
		if data.Pets[entry.Id] then
			result.IsNew = false
		else
			data.Pets[entry.Id] = true
			if not data.EquippedPet then
				data.EquippedPet = entry.Id
				PetService.Refresh(player)
			end
			if pet.Rarity == "Legendary" then
				announce(player, `hatched the LEGENDARY {pet.DisplayName} pet!`, Config.Rarities.Legendary)
			end
		end
	end

	if not result.IsNew then
		result.Refund = crate.DuplicateRefund
		PlayerService.AddCandies(player, crate.DuplicateRefund)
	end
	PlayerService.Push(player)
	return result
end

local function onOpenCrate(player: Player, currency: unknown)
	if not isActive() then
		return false, "The Halloween event has ended"
	end
	if player:GetAttribute("InDungeon") then
		return false, "Open crates in town"
	end
	if opening[player] then
		return false, "Already opening a crate"
	end
	if currency == "Robux" then
		if crate.RobuxProductId == 0 then
			return false, "Robux crates aren't set up yet (Config.Events.Halloween.Crate.RobuxProductId)"
		end
		MarketplaceService:PromptProductPurchase(player, crate.RobuxProductId)
		return true
	end
	if not PlayerService.SpendCandies(player, crate.CandyCost) then
		return false, `You need {crate.CandyCost} candies`
	end
	opening[player] = true
	local result = openCrate(player)
	task.delay(3, function()
		opening[player] = nil
	end)
	return true, result
end

local function onEquipLimitedClass(player: Player, classId: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	if player:GetAttribute("InDungeon") then
		return false, "Change class in town"
	end
	if type(classId) ~= "string" or not data.LimitedClasses[classId] then
		return false, "You don't own that class"
	end
	PlayerService.SetClass(player, classId)
	return true, `You are now a {Config.Classes[classId].DisplayName}!`
end

-- The event plaza ----------------------------------------------------------------------

local function pumpkin(parent: Instance, position: Vector3, size: number, lit: boolean)
	local body = Build.ball(parent, "Pumpkin", size, position + Vector3.new(0, size * 0.42, 0), ORANGE, M.SmoothPlastic)
	for i = 0, 2 do
		local rib = Build.block(parent, "PumpkinRib", Vector3.new(0.1, size * 1.02, size * 1.02), CFrame.new(body.CFrame.Position) * CFrame.Angles(0, i / 3 * math.pi, 0), rgb(200, 90, 15), M.SmoothPlastic)
		rib.Shape = Enum.PartType.Cylinder
		rib.CanCollide = false
	end
	Build.block(parent, "PumpkinStem", Vector3.new(0.2 * size, 0.35 * size, 0.2 * size), CFrame.new(body.CFrame.Position + Vector3.new(0, size * 0.55, 0)), rgb(70, 100, 40), M.Wood)
	if lit then
		local face = Build.block(parent, "PumpkinGrin", Vector3.new(size * 0.5, size * 0.1, 0.1), CFrame.new(body.CFrame.Position + Vector3.new(0, -size * 0.12, -size * 0.49)), rgb(255, 200, 60), M.Neon)
		face.CanCollide = false
		for _, side in { -1, 1 } do
			local eye = Build.block(parent, "PumpkinEye", Vector3.new(size * 0.16, size * 0.14, 0.1), CFrame.new(body.CFrame.Position + Vector3.new(side * size * 0.18, size * 0.1, -size * 0.48)) * CFrame.Angles(0, 0, math.rad(side * 15)), rgb(255, 200, 60), M.Neon)
			eye.CanCollide = false
		end
		Build.light(body, rgb(255, 160, 50), size * 6, 1.2)
	end
end

local function buildPlaza()
	local plaza = Instance.new("Model")
	plaza.Name = "HalloweenPlaza"
	local c = PLAZA_POSITION
	-- Ground: dark soil with a purple rune ring
	Build.cylinder(plaza, "PlazaGround", 26, 0.14, CFrame.new(c + Vector3.new(0, 0.27, 0)), rgb(55, 40, 35), M.Ground)
	local ring = Build.cylinder(plaza, "RuneRing", 22, 0.1, CFrame.new(c + Vector3.new(0, 0.3, 0)), PURPLE, M.Neon)
	ring.Transparency = 0.5
	Build.cylinder(plaza, "RuneRingInner", 20, 0.12, CFrame.new(c + Vector3.new(0, 0.31, 0)), rgb(55, 40, 35), M.Ground)

	-- The altar: a giant jack-o'-lantern crate
	local altar = c + Vector3.new(0, 0, 2)
	Build.block(plaza, "AltarStep", Vector3.new(9, 1, 7), CFrame.new(altar + Vector3.new(0, 0.5, 0)), rgb(45, 40, 45), M.Slate)
	pumpkin(plaza, altar + Vector3.new(0, 1, 0), 5.5, true)
	local sign = Build.block(plaza, "EventSign", Vector3.new(10, 2.2, 0.3), CFrame.new(altar + Vector3.new(0, 9, 0)), rgb(30, 20, 30), M.WoodPlanks)
	Build.label(sign, "HALLOWEEN EVENT", ORANGE)
	for _, x in { -4.6, 4.6 } do
		Build.block(plaza, "SignPost", Vector3.new(0.4, 9, 0.4), CFrame.new(altar + Vector3.new(x, 4.5, 0)), rgb(40, 30, 25), M.Wood)
	end

	-- Pumpkin patch, a scarecrow, dead trees and candles
	local rng = Random.new(31)
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(7, 12)
		pumpkin(plaza, c + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), rng:NextNumber(1, 2.2), rng:NextNumber() < 0.5)
	end
	local crow = c + Vector3.new(-9, 0, -6)
	Build.block(plaza, "ScarecrowPost", Vector3.new(0.5, 7, 0.5), CFrame.new(crow + Vector3.new(0, 3.5, 0)), rgb(90, 65, 40), M.Wood)
	Build.block(plaza, "ScarecrowArms", Vector3.new(5, 0.4, 0.4), CFrame.new(crow + Vector3.new(0, 5.2, 0)), rgb(90, 65, 40), M.Wood)
	Build.block(plaza, "ScarecrowShirt", Vector3.new(2.2, 2.4, 1), CFrame.new(crow + Vector3.new(0, 4.6, 0)), rgb(120, 60, 50), M.Fabric)
	pumpkin(plaza, crow + Vector3.new(0, 5.8, 0), 1.6, true)
	Build.block(plaza, "ScarecrowHat", Vector3.new(2.2, 0.2, 2.2), CFrame.new(crow + Vector3.new(0, 7.6, 0)), rgb(30, 25, 30), M.Fabric)
	Build.block(plaza, "ScarecrowHatTop", Vector3.new(1, 1.4, 1), CFrame.new(crow + Vector3.new(0, 8.3, 0)) * CFrame.Angles(0, 0, math.rad(12)), rgb(30, 25, 30), M.Fabric)
	for _, offset in { Vector3.new(11, 0, -8), Vector3.new(-12, 0, 6) } do
		local base = c + offset
		Build.cylinder(plaza, "DeadTrunk", 1.2, 9, CFrame.new(base + Vector3.new(0, 4.5, 0)), rgb(50, 40, 35), M.Wood)
		for i = 1, 4 do
			local branch = Build.block(plaza, "DeadBranch", Vector3.new(0.4, 3.5, 0.4), CFrame.new(base + Vector3.new(0, 6 + i * 0.6, 0)) * CFrame.Angles(0, i * 1.6, math.rad(45)) * CFrame.new(0, 1.6, 0), rgb(50, 40, 35), M.Wood)
			branch.CanCollide = false
		end
	end
	-- Purple and orange lanterns floating overhead
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local lantern = Build.ball(plaza, "FloatingLantern", 0.9, c + Vector3.new(math.cos(angle) * 10, 11 + (i % 2) * 1.5, math.sin(angle) * 10), if i % 2 == 0 then ORANGE else PURPLE, M.Neon)
		lantern.CanCollide = false
		Build.light(lantern, lantern.Color, 14, 1)
	end
	-- Fog
	local fogArea = Build.block(plaza, "Fog", Vector3.new(24, 0.2, 24), CFrame.new(c + Vector3.new(0, 0.5, 0)), rgb(0, 0, 0), M.SmoothPlastic)
	fogArea.Transparency = 1
	fogArea.CanCollide = false
	local fog = Instance.new("ParticleEmitter")
	fog.Shape = Enum.ParticleEmitterShape.Box
	fog.Color = ColorSequence.new(rgb(170, 150, 200))
	fog.Size = NumberSequence.new(3, 5)
	fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) })
	fog.Lifetime = NumberRange.new(5, 8)
	fog.Rate = 5
	fog.Speed = NumberRange.new(0.3, 0.8)
	fog.Parent = fogArea

	local promptPart = Build.block(plaza, "PromptAnchor", Vector3.one, CFrame.new(altar + Vector3.new(0, 3, -4)), rgb(0, 0, 0), M.SmoothPlastic)
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Halloween Event"
	prompt.ObjectText = "Halloween Crate"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	prompt.Triggered:Connect(function(player)
		Remotes.OpenEvent:FireClient(player)
	end)

	plaza.Parent = workspace
end

function HalloweenService.Start()
	Remotes.OpenHalloweenCrate.OnServerInvoke = onOpenCrate
	Remotes.EquipLimitedClass.OnServerInvoke = onEquipLimitedClass

	-- Robux crates
	Receipts.Register(function()
		return crate.RobuxProductId
	end, function(player)
		opening[player] = true
		local result = openCrate(player)
		Remotes.HalloweenCrateResult:FireClient(player, result)
		task.delay(3, function()
			opening[player] = nil
		end)
	end)

	-- Tell clients when the event runs (they show the button and countdown)
	workspace:SetAttribute("HalloweenEndsAt", event.EndsAt)
	workspace:SetAttribute("HalloweenActive", isActive())
	task.spawn(function()
		while true do
			task.wait(30)
			workspace:SetAttribute("HalloweenActive", isActive())
		end
	end)

	if isActive() then
		buildPlaza()
	end
	Players.PlayerRemoving:Connect(function(player)
		opening[player] = nil
	end)
end

return HalloweenService
