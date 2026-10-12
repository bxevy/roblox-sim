-- Prestige and skills.
--
-- Prestige: at max level, reset to level 1 for a permanent XP/coin bonus, bonus skill
-- points and the next prestige emblem. Gear, coins and skills are kept.
-- Skills: spend skill points on upgrades at the Skill Sanctum in the training grounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local Sfx = require(script.Parent.Parent.Sfx)

-- In the training grounds, south-west of the sparring ring.
local SANCTUM_CENTER = Vector3.new(-30, 0, 132)
local SANCTUM_RANGE = 30 -- you must be this close to buy skills

local ProgressionService = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local function onPrestige(player: Player): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	if player:GetAttribute("InDungeon") then
		return false, "You can't prestige inside a dungeon"
	end
	if data.Prestige >= Config.Prestige.Max then
		return false, "You've reached the highest prestige!"
	end
	if data.Level < Config.MaxLevel then
		return false, `Reach level {Config.MaxLevel} to prestige`
	end

	data.Prestige += 1
	data.Level = 1
	data.XP = 0
	data.SkillPoints += Config.Prestige.SkillPoints
	PlayerService.AddStat(player, "PrestigeCount")
	PlayerService.RefreshStats(player, true)
	PlayerService.Push(player)

	local emblem = Cosmetics.Emblems[data.Prestige]
	for _, other in Players:GetPlayers() do
		PlayerService.Notify(other, `{player.DisplayName} reached Prestige {Cosmetics.Roman(data.Prestige)} ({emblem.Name})!`, emblem.Outer)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Sfx.play("LevelUp", root, 2)
	end
	return true
end

local function onUpgradeSkill(player: Player, skillId: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	local skill = type(skillId) == "string" and Config.Skills[skillId]
	if not data or not skill then
		return false, "Unknown skill"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - SANCTUM_CENTER).Magnitude > SANCTUM_RANGE then
		return false, "Visit the Skill Sanctum in the training grounds to train"
	end
	local rank = data.Skills[skillId] or 0
	if rank >= skill.MaxRank then
		return false, "Already maxed"
	end
	local cost = Config.SkillCost(rank)
	if data.SkillPoints < cost then
		return false, `Needs {cost} skill point{if cost == 1 then "" else "s"}`
	end
	data.SkillPoints -= cost
	data.Skills[skillId] = rank + 1
	PlayerService.RefreshStats(player)
	PlayerService.Push(player)
	Sfx.play("Heal", root)
	return true
end

-- The Skill Sanctum: a rune circle with glowing pillars and an altar.
local function buildSanctum()
	local sanctum = Instance.new("Model")
	sanctum.Name = "SkillSanctum"
	local c = SANCTUM_CENTER
	local stone = rgb(95, 92, 100)

	Build.cylinder(sanctum, "SanctumFloor", 24, 0.6, CFrame.new(c + Vector3.new(0, 0.3, 0)), stone, M.Slate)
	Build.cylinder(sanctum, "RuneRing", 20, 0.65, CFrame.new(c + Vector3.new(0, 0.32, 0)), rgb(110, 160, 255), M.Neon).Transparency = 0.6
	Build.cylinder(sanctum, "SanctumInner", 18.5, 0.7, CFrame.new(c + Vector3.new(0, 0.35, 0)), stone, M.Slate)

	-- One pillar per skill color, in a circle
	for i, skillId in Config.SkillOrder do
		local angle = (i - 1) / #Config.SkillOrder * math.pi * 2
		local p = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 10.5
		Build.block(sanctum, "Pillar", Vector3.new(1.4, 6, 1.4), CFrame.new(p + Vector3.new(0, 3, 0)), stone, M.Cobblestone)
		local crystal = Build.block(sanctum, "Crystal", Vector3.new(0.9, 1.6, 0.9), CFrame.new(p + Vector3.new(0, 6.9, 0)) * CFrame.Angles(0, math.rad(45), math.rad(45)), Config.Skills[skillId].Color, M.Neon)
		crystal.CanCollide = false
		Build.light(crystal, Config.Skills[skillId].Color, 10, 1)
	end

	-- Altar with a glowing tome
	Build.block(sanctum, "Altar", Vector3.new(3.4, 3, 2.4), CFrame.new(c + Vector3.new(0, 1.8, 0)), rgb(70, 66, 75), M.Marble)
	local tome = Build.block(sanctum, "Tome", Vector3.new(1.8, 0.35, 1.3), CFrame.new(c + Vector3.new(0, 3.5, 0)) * CFrame.Angles(math.rad(-15), 0, 0), rgb(90, 40, 120), M.Fabric)
	local pages = Build.block(sanctum, "Pages", Vector3.new(1.6, 0.1, 1.1), tome.CFrame * CFrame.new(0, 0.22, 0), rgb(255, 245, 210), M.Neon)
	Build.light(pages, rgb(200, 180, 255), 16, 2)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(rgb(200, 180, 255))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.25, 0)
	sparkles.Lifetime = NumberRange.new(1.5, 2.5)
	sparkles.Rate = 12
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.Acceleration = Vector3.new(0, 1.5, 0)
	sparkles.Parent = pages

	local sign = Build.block(sanctum, "SanctumSign", Vector3.new(8, 1.6, 0.3), CFrame.lookAt(c + Vector3.new(0, 9, -11.2), c + Vector3.new(0, 9, -20)), rgb(45, 35, 55), M.WoodPlanks)
	Build.label(sign, "SKILL SANCTUM", rgb(200, 180, 255))
	for _, x in { -3.6, 3.6 } do
		Build.block(sanctum, "SignPost", Vector3.new(0.4, 9, 0.4), CFrame.new(c + Vector3.new(x, 4.5, -11)), rgb(62, 42, 28), M.Wood)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Train Skills"
	prompt.ObjectText = "Skill Sanctum"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pages
	prompt.Triggered:Connect(function(player)
		Remotes.OpenSkills:FireClient(player)
	end)

	sanctum.Parent = workspace
end

function ProgressionService.Start()
	buildSanctum()
	Remotes.Prestige.OnServerInvoke = onPrestige
	Remotes.UpgradeSkill.OnServerInvoke = onUpgradeSkill
end

return ProgressionService
