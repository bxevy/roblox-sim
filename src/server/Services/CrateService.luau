-- Crates: bought at the Crate Shrine in town with Gold. Godly armor only comes from here.
--
-- Each crate rolls a rarity from its odds (Config.Crates). A Godly roll gives a random
-- piece of the crate's Godly set; other rarities give a random dungeon armor piece of that
-- rarity. Duplicates (including Godly ones) refund part of the price.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local Sfx = require(script.Parent.Parent.Sfx)

local SHRINE_POSITION = Vector3.new(-40, 0, 29)

local CrateService = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local function rollRarity(crate): string
	local roll = math.random()
	for _, entry in crate.Odds do
		roll -= entry.Chance
		if roll <= 0 then
			return entry.Rarity
		end
	end
	return crate.Odds[#crate.Odds].Rarity
end

local function pickPiece(crate, rarity: string): Items.ArmorDef?
	if rarity == "Godly" then
		local set = Items.ArmorSets[crate.Set]
		local slot = Items.ArmorSlots[math.random(#Items.ArmorSlots)]
		return Items.Armors[set.Pieces[slot]]
	end
	local pool = Items.LootArmorsOfRarity(rarity)
	return if #pool > 0 then pool[math.random(#pool)] else nil
end

local function onOpenCrate(player: Player, crateId: unknown)
	local crate = type(crateId) == "string" and Config.Crates[crateId]
	if not crate then
		return false, "Unknown crate"
	end
	if player:GetAttribute("InDungeon") then
		return false, "Crates can only be opened in town"
	end
	if not PlayerService.SpendGold(player, crate.Price) then
		return false, `You need {crate.Price} Gold`
	end

	PlayerService.AddStat(player, "CratesOpened")
	local rarity = rollRarity(crate)
	local piece = pickPiece(crate, rarity)
	if not piece then
		PlayerService.AddGold(player, crate.Price)
		return false, "Nothing to win right now - refunded"
	end

	local isNew = PlayerService.GiveItem(player, "Armor", piece.Id)
	local refund = 0
	if not isNew then
		refund = math.floor(crate.Price * Config.CrateDuplicateRefund)
		PlayerService.AddGold(player, refund)
	end

	if piece.Rarity == "Godly" then
		-- Let the reveal animation finish before telling everyone.
		task.delay(4.5, function()
			for _, other in Players:GetPlayers() do
				PlayerService.Notify(other, `{player.DisplayName} unboxed GODLY {piece.DisplayName}!`, Config.Rarities.Godly)
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				Sfx.play("LevelUp", root, 1.5)
			end
		end)
	end

	return true, {
		Id = piece.Id,
		DisplayName = piece.DisplayName,
		Rarity = piece.Rarity,
		Slot = piece.Slot,
		IsNew = isNew,
		Refund = refund,
	}
end

-- A display crate: a box with trim, a lid and an emblem.
local function displayCrate(parent: Instance, cframe: CFrame, body: Color3, trim: Color3, glow: Color3, label: string)
	Build.block(parent, "Crate", Vector3.new(5, 4, 4), cframe * CFrame.new(0, 2.4, 0), body, M.WoodPlanks)
	for _, y in { 0.6, 4.2 } do
		Build.block(parent, "CrateBand", Vector3.new(5.2, 0.4, 4.2), cframe * CFrame.new(0, y, 0), trim, M.Metal)
	end
	for _, x in { -2.45, 2.45 } do
		Build.block(parent, "CrateCorner", Vector3.new(0.4, 4, 4.2), cframe * CFrame.new(x, 2.4, 0), trim, M.Metal)
	end
	local lid = Build.block(parent, "CrateLid", Vector3.new(5.3, 0.6, 4.3), cframe * CFrame.new(0, 4.7, 0), body, M.WoodPlanks)
	local gem = Build.block(parent, "CrateEmblem", Vector3.new(1.4, 1.4, 0.2), cframe * CFrame.new(0, 2.4, -2.05) * CFrame.Angles(0, 0, math.rad(45)), glow, M.Neon)
	Build.light(gem, glow, 14, 2)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(glow)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Lifetime = NumberRange.new(1, 1.5)
	sparkles.Rate = 8
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.Parent = lid
	local sign = Build.block(parent, "CrateSign", Vector3.new(5, 1, 0.2), cframe * CFrame.new(0, 6.2, -1.5), rgb(40, 30, 25), M.WoodPlanks)
	Build.label(sign, label, glow)
end

local function buildShrine()
	local shrine = Instance.new("Model")
	shrine.Name = "CrateShrine"
	-- Faces east (+X), toward the plaza.
	local base = CFrame.lookAt(SHRINE_POSITION, SHRINE_POSITION + Vector3.xAxis)
	local stone = rgb(70, 65, 70)

	Build.block(shrine, "Dais", Vector3.new(18, 1, 10), base * CFrame.new(0, 0.5, 0), stone, M.Slate)
	Build.block(shrine, "DaisTrim", Vector3.new(18.4, 0.3, 10.4), base * CFrame.new(0, 1.05, 0), rgb(200, 160, 60), M.Metal)
	for _, x in { -8, 8 } do
		Build.block(shrine, "Pillar", Vector3.new(1.4, 12, 1.4), base * CFrame.new(x, 6.5, 3.5), stone, M.Cobblestone)
		local brazier = Build.block(shrine, "Brazier", Vector3.new(1.8, 0.6, 1.8), base * CFrame.new(x, 12.8, 3.5), rgb(200, 160, 60), M.Metal)
		local fire = Instance.new("Fire")
		fire.Color = rgb(255, 80, 160)
		fire.SecondaryColor = rgb(120, 40, 255)
		fire.Size = 3
		fire.Parent = brazier
		Build.light(brazier, rgb(255, 100, 200), 22, 2)
	end
	Build.block(shrine, "Lintel", Vector3.new(18, 1.2, 1.6), base * CFrame.new(0, 13.1, 3.5), stone, M.Cobblestone)
	local sign = Build.block(shrine, "ShrineSign", Vector3.new(12, 2, 0.3), base * CFrame.new(0, 13.1, 2.6), rgb(30, 22, 30), M.WoodPlanks)
	Build.label(sign, "CRATE SHRINE", Config.Rarities.Godly)

	displayCrate(shrine, base * CFrame.new(-4, 1.2, 0), rgb(30, 26, 30), rgb(90, 20, 20), rgb(255, 50, 20), "Black Dragon")
	displayCrate(shrine, base * CFrame.new(4, 1.2, 0), rgb(160, 30, 35), rgb(230, 180, 60), rgb(255, 170, 205), "Shogun's Oath")

	local promptPart = Build.block(shrine, "PromptAnchor", Vector3.new(1, 1, 1), base * CFrame.new(0, 3, -3), stone, M.SmoothPlastic)
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Crates"
	prompt.ObjectText = "Crate Shrine"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	prompt.Triggered:Connect(function(player)
		Remotes.OpenCrates:FireClient(player)
	end)

	shrine.Parent = workspace
end

function CrateService.Start()
	buildShrine()
	Remotes.OpenCrate.OnServerInvoke = onOpenCrate
end

return CrateService
