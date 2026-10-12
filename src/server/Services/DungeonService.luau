-- Lobby portals, parties, and dungeon runs.
--
-- Stand on a portal pad and pick a difficulty -> after a countdown everyone on it who has
-- unlocked that difficulty is sent into a fresh copy of the dungeon. Each dungeon is a line of rooms joined by corridors. Clearing a room opens
-- the next door; the last room holds the boss. Beat the boss for XP, gold and an item
-- (a weapon for your class, or armor) from that difficulty's loot tiers.
-- If everyone in the party dies, the run fails.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Dungeons = require(ReplicatedStorage.Shared.Dungeons)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Items = require(ReplicatedStorage.Shared.Items)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)
local DungeonDecor = require(script.Parent.Parent.DungeonDecor)
local Sfx = require(script.Parent.Parent.Sfx)

-- Layout (studs)
local ENTRY_ROOM_SIZE = 40
local ROOM_SIZE = 64
local BOSS_ROOM_SIZE = 90
local CORRIDOR_LENGTH = 24
local CORRIDOR_WIDTH = 14
local WALL_HEIGHT = 22
local WALL_THICKNESS = 2
local RUN_ORIGIN_X = 2000 -- dungeons are built far away from the lobby
local RUN_SPACING = 600

local LOBBY_SPAWN = Vector3.new(0, 4, 0)
local PORTAL_Z = -45
local PORTAL_SPACING = 32

local START_DELAY = 3
local RETURN_DELAY = 8

local DungeonService = {}

type Room = {
	Center: Vector3, -- floor-level center
	Size: number,
}

type Run = {
	Def: Dungeons.DungeonDef,
	Phase: string, -- "Rooms" | "Boss" | "Done": tells the client which music to play
	DifficultyId: string,
	HealthMultiplier: number,
	DamageMultiplier: number,
	RewardMultiplier: number,
	Slot: number,
	Folder: Folder,
	Rooms: { Room },
	Doors: { BasePart }, -- Doors[i] sits between Rooms[i] and Rooms[i + 1]
	Players: { [Player]: true },
	Connections: { [Player]: RBXScriptConnection },
	Enemies: { [EnemyService.Enemy]: true },
	Remaining: number,
	Ended: boolean,
}

local runsBySlot: { [number]: Run } = {}
local playerRun: { [Player]: Run } = {}

local dungeonsFolder = Instance.new("Folder")
dungeonsFolder.Name = "Dungeons"
dungeonsFolder.Parent = workspace

-- Building helpers ---------------------------------------------------------

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function torch(parent: Instance, position: Vector3, color: Color3)
	local flame = block(parent, "Torch", Vector3.new(0.8, 1.2, 0.8), CFrame.new(position), color, Enum.Material.Neon)
	flame.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 26
	light.Brightness = 2
	light.Parent = flame
end

local function billboard(parent: BasePart, size: UDim2, offset: Vector3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 150
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return label
end

-- Builds a square room. `openSouth`/`openNorth` leave a gap in that wall for a corridor.
-- Rooms run along +Z, so "north" is +Z.
local function buildRoom(parent: Instance, room: Room, theme, openSouth: boolean, openNorth: boolean)
	local c, s = room.Center, room.Size
	local half = s / 2
	block(parent, "Floor", Vector3.new(s, 2, s), CFrame.new(c - Vector3.new(0, 1, 0)), theme.Floor, theme.FloorMaterial)

	local wallY = c.Y + WALL_HEIGHT / 2
	local function wall(x: number, z: number, sizeX: number, sizeZ: number)
		block(parent, "Wall", Vector3.new(sizeX, WALL_HEIGHT, sizeZ), CFrame.new(c.X + x, wallY, c.Z + z), theme.Wall, theme.WallMaterial)
	end

	-- East and west walls
	wall(-half - WALL_THICKNESS / 2, 0, WALL_THICKNESS, s + WALL_THICKNESS * 2)
	wall(half + WALL_THICKNESS / 2, 0, WALL_THICKNESS, s + WALL_THICKNESS * 2)

	-- North and south walls, with a doorway gap if needed
	for _, side in { { -1, openSouth }, { 1, openNorth } } do
		local z = side[1] * (half + WALL_THICKNESS / 2)
		if side[2] then
			local segment = (s - CORRIDOR_WIDTH) / 2
			wall(-(CORRIDOR_WIDTH / 2 + segment / 2), z, segment, WALL_THICKNESS)
			wall(CORRIDOR_WIDTH / 2 + segment / 2, z, segment, WALL_THICKNESS)
		else
			wall(0, z, s, WALL_THICKNESS)
		end
	end

	-- Ceiling, so dungeons are dark and lit only by their torches
	block(parent, "Ceiling", Vector3.new(s + WALL_THICKNESS * 2, 2, s + WALL_THICKNESS * 2), CFrame.new(c + Vector3.new(0, WALL_HEIGHT + 1, 0)), theme.Wall, theme.WallMaterial)

	-- Torches along the side walls
	for _, x in { -half + 1.5, half - 1.5 } do
		for _, z in { -half / 2, half / 2 } do
			torch(parent, Vector3.new(c.X + x, c.Y + 9, c.Z + z), theme.Torch)
		end
	end
end

-- Corridor from z0 to z0 + CORRIDOR_LENGTH, with a door in the middle. Returns the door.
local function buildCorridor(parent: Instance, x: number, z0: number, theme): BasePart
	local zMid = z0 + CORRIDOR_LENGTH / 2
	block(parent, "Floor", Vector3.new(CORRIDOR_WIDTH, 2, CORRIDOR_LENGTH), CFrame.new(x, -1, zMid), theme.Floor, theme.FloorMaterial)
	for _, side in { -1, 1 } do
		block(
			parent,
			"Wall",
			Vector3.new(WALL_THICKNESS, WALL_HEIGHT, CORRIDOR_LENGTH),
			CFrame.new(x + side * (CORRIDOR_WIDTH / 2 + WALL_THICKNESS / 2), WALL_HEIGHT / 2, zMid),
			theme.Wall,
			theme.WallMaterial
		)
	end
	block(parent, "Ceiling", Vector3.new(CORRIDOR_WIDTH + WALL_THICKNESS * 2, 2, CORRIDOR_LENGTH), CFrame.new(x, WALL_HEIGHT + 1, zMid), theme.Wall, theme.WallMaterial)
	local color, material, transparency = DungeonDecor.doorLook(theme.Style)
	local door = block(parent, "Door", Vector3.new(CORRIDOR_WIDTH, WALL_HEIGHT, 2), CFrame.new(x, WALL_HEIGHT / 2, zMid), color, material)
	door.Transparency = transparency
	return door
end

local function buildDungeon(run: Run)
	local def = run.Def
	local theme = def.Theme
	local x = RUN_ORIGIN_X + run.Slot * RUN_SPACING

	local sizes = { ENTRY_ROOM_SIZE }
	for _ = 1, #def.Rooms do
		table.insert(sizes, ROOM_SIZE)
	end
	table.insert(sizes, BOSS_ROOM_SIZE)

	local z = 0
	for i, size in sizes do
		local room = { Center = Vector3.new(x, 0, z + size / 2), Size = size }
		table.insert(run.Rooms, room)
		buildRoom(run.Folder, room, theme, i > 1, i < #sizes)
		DungeonDecor.decorate(theme.Style, run.Folder, room, i == #sizes, run.Slot * 100 + i)
		z += size
		if i < #sizes then
			table.insert(run.Doors, buildCorridor(run.Folder, x, z, theme))
			z += CORRIDOR_LENGTH
		end
	end
end

-- Run lifecycle --------------------------------------------------------------

local function setStatus(run: Run, text: string?)
	local info = { Style = run.Def.Theme.Style, Boss = run.Phase == "Boss" }
	for player in run.Players do
		Remotes.DungeonStatus:FireClient(player, text, info)
	end
end

local function notifyRun(run: Run, message: string, color: Color3?)
	for player in run.Players do
		PlayerService.Notify(player, message, color)
	end
end

local function partyList(run: Run): { Player }
	local list = {}
	for player in run.Players do
		table.insert(list, player)
	end
	return list
end

local function openDoor(door: BasePart)
	Sfx.play("Door", door)
	door.CanCollide = false
	local tween = TweenService:Create(door, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		CFrame = door.CFrame - Vector3.new(0, WALL_HEIGHT, 0),
	})
	tween:Play()
	tween.Completed:Once(function()
		door:Destroy()
	end)
end

local function teleport(player: Player, position: Vector3, lookDirection: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.lookAt(position, position + lookDirection))
	end
end

local function cleanupRun(run: Run)
	for enemy in run.Enemies do
		EnemyService.Despawn(enemy)
	end
	run.Folder:Destroy()
	runsBySlot[run.Slot] = nil
end

local function leaveRun(run: Run, player: Player)
	if not run.Players[player] then
		return
	end
	Remotes.DungeonStatus:FireClient(player, nil)
	player:SetAttribute("InDungeon", nil)
	run.Players[player] = nil
	playerRun[player] = nil
	local connection = run.Connections[player]
	if connection then
		connection:Disconnect()
		run.Connections[player] = nil
	end
end

local function failRun(run: Run)
	if run.Ended then
		return
	end
	run.Ended = true
	cleanupRun(run)
end

local function pickWeighted<T>(weights: { [T]: number }): T
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = math.random() * total
	local last
	for key, weight in weights do
		last = key
		roll -= weight
		if roll <= 0 then
			return key
		end
	end
	return last
end

-- Rolls one item for a player: a weapon for their class (60%) or armor (40%).
local function rollLoot(player: Player, run: Run): (string, string)
	local settings = run.Def.Difficulties[run.DifficultyId]
	local tier = pickWeighted(settings.Loot)
	local class = PlayerService.GetClass(player)
	if class and math.random() < 0.6 then
		local options = Items.WeaponsOfType(class.WeaponType, tier)
		if #options > 0 then
			return "Weapon", options[math.random(#options)].Id
		end
	end
	local options = Items.ArmorsOfTier(tier)
	return "Armor", options[math.random(#options)].Id
end

local function winRun(run: Run)
	if run.Ended then
		return
	end
	run.Ended = true
	run.Phase = "Done"
	local def = run.Def
	setStatus(run, `{def.DisplayName} ({run.DifficultyId}) - CLEARED!`)
	notifyRun(run, "VICTORY!", Color3.fromRGB(255, 220, 80))

	for player in run.Players do
		PlayerService.AddStat(player, "DungeonsCleared")
		PlayerService.AddXP(player, def.Rewards.XP * run.RewardMultiplier)
		PlayerService.AddGold(player, def.Rewards.Gold * run.RewardMultiplier)

		-- Ultra-rare Mythic drop, rolled separately from the normal item.
		if math.random() < Config.MythicDrop.Chance and PlayerService.GiveItem(player, "Weapon", Config.MythicDrop.Weapon) then
			local mythic = Items.Weapons[Config.MythicDrop.Weapon]
			for _, other in Players:GetPlayers() do
				PlayerService.Notify(other, `{player.DisplayName} found the MYTHIC {mythic.DisplayName}!`, Config.Rarities.Mythic)
			end
		end

		local kind, itemId = rollLoot(player, run)
		local item: any = if kind == "Weapon" then Items.Weapons[itemId] else Items.Armors[itemId]
		local color = Config.Rarities[item.Rarity]
		task.delay(1.5, function()
			if PlayerService.GiveItem(player, kind, itemId) then
				PlayerService.Notify(player, `You found: {item.DisplayName} ({item.Rarity})!`, color)
			else
				local gold = Config.DuplicateGoldPerTier * item.Tier
				PlayerService.AddGold(player, gold)
				PlayerService.Notify(player, `Duplicate {item.DisplayName} - +{gold} Gold`, color)
			end
		end)
	end

	task.delay(RETURN_DELAY, function()
		for _, player in partyList(run) do
			leaveRun(run, player)
			teleport(player, LOBBY_SPAWN + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)), Vector3.zAxis * -1)
		end
		cleanupRun(run)
	end)
end

local activateRoom: (run: Run, index: number) -> ()

local function onEnemyDied(run: Run, roomIndex: number, enemy: EnemyService.Enemy)
	if run.Ended then
		return
	end
	run.Enemies[enemy] = nil
	local multiplier = run.Def.Power * run.RewardMultiplier
	for player in run.Players do
		PlayerService.AddStat(player, "EnemiesKilled")
		if enemy.Def.Boss then
			PlayerService.AddStat(player, "BossesKilled")
		end
		PlayerService.AddXP(player, enemy.Def.XP * multiplier)
		PlayerService.AddGold(player, enemy.Def.Gold * multiplier)
	end

	run.Remaining -= 1
	if run.Remaining > 0 then
		return
	end
	if roomIndex == #run.Rooms then
		winRun(run)
	else
		openDoor(run.Doors[roomIndex])
		activateRoom(run, roomIndex + 1)
	end
end

local function spawnInRoom(run: Run, roomIndex: number, enemyId: string, position: Vector3)
	local enemy
	enemy = EnemyService.Spawn(enemyId, {
		HealthMultiplier = run.HealthMultiplier,
		DamageMultiplier = run.DamageMultiplier,
		Position = position,
		Parent = run.Folder,
		GetTargets = function()
			return partyList(run)
		end,
		OnDied = function()
			onEnemyDied(run, roomIndex, enemy)
		end,
	})
	run.Enemies[enemy] = true
	run.Remaining += 1
end

-- Spawns the enemies for a room. Room 1 is the safe entry room; the last room is the boss.
activateRoom = function(run: Run, index: number)
	if run.Ended then
		return
	end
	local def = run.Def
	local room = run.Rooms[index]
	local combatRooms = #def.Rooms
	local title = `{def.DisplayName} ({run.DifficultyId})`
	run.Remaining = 0

	if index == #run.Rooms then
		run.Phase = "Boss"
		setStatus(run, `{title} - BOSS`)
		notifyRun(run, `{Enemies[def.Boss].DisplayName} awaits...`, Color3.fromRGB(255, 90, 90))
		spawnInRoom(run, index, def.Boss, room.Center + Vector3.new(0, 0, room.Size / 4))
		return
	end

	setStatus(run, `{title} - Room {index - 1}/{combatRooms}`)
	local spread = room.Size / 2 - 8
	for enemyId, count in def.Rooms[index - 1] do
		for _ = 1, count do
			local offset = Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
			spawnInRoom(run, index, enemyId, room.Center + offset)
		end
	end
end

local function startRun(def: Dungeons.DungeonDef, difficultyId: string, party: { Player })
	local slot = 1
	while runsBySlot[slot] do
		slot += 1
	end

	local folder = Instance.new("Folder")
	folder.Name = `{def.DisplayName} {difficultyId} #{slot}`
	folder.Parent = dungeonsFolder

	local difficulty = Config.Difficulties[difficultyId]
	local run: Run = {
		Def = def,
		Phase = "Rooms",
		DifficultyId = difficultyId,
		HealthMultiplier = def.Power * difficulty.Health,
		DamageMultiplier = def.Power * difficulty.Damage,
		RewardMultiplier = difficulty.Rewards,
		Slot = slot,
		Folder = folder,
		Rooms = {},
		Doors = {},
		Players = {},
		Connections = {},
		Enemies = {},
		Remaining = 0,
		Ended = false,
	}
	runsBySlot[slot] = run
	buildDungeon(run)

	local entry = run.Rooms[1]
	for i, player in party do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			run.Players[player] = true
			playerRun[player] = run
			player:SetAttribute("InDungeon", true)
			run.Connections[player] = humanoid.Died:Connect(function()
				PlayerService.Notify(player, "You were defeated!", Color3.fromRGB(255, 80, 80))
				PlayerService.AddStat(player, "Deaths")
				leaveRun(run, player)
				if next(run.Players) == nil then
					failRun(run)
				end
			end)
			local x = (i - (#party + 1) / 2) * 5
			teleport(player, entry.Center + Vector3.new(x, 4, -entry.Size / 4), Vector3.zAxis)
			CombatService.DrawWeapon(player)
		end
	end

	if next(run.Players) == nil then
		failRun(run)
		return
	end

	setStatus(run, `{def.DisplayName} ({difficultyId})`)
	notifyRun(run, `Entering {def.DisplayName} on {difficultyId}... get ready!`, difficulty.Color)
	task.delay(START_DELAY, function()
		if run.Ended then
			return
		end
		openDoor(run.Doors[1])
		activateRoom(run, 2)
	end)
end

-- Lobby & portals ------------------------------------------------------------

type Portal = {
	Id: string,
	Def: Dungeons.DungeonDef,
	Pad: BasePart,
	Label: TextLabel,
	DifficultyId: string,
	Countdown: number?,
	OnPad: { [Player]: true },
	Warned: { [Player]: string }, -- player -> difficulty they were last warned about
}

local portals: { Portal } = {}

local function buildLobby()
	-- The town around the portals is built by HubService.
	local lobby = Instance.new("Folder")
	lobby.Name = "Portals"
	lobby.Parent = workspace

	local count = #Dungeons.Order
	for i, dungeonId in Dungeons.Order do
		local def = Dungeons.Defs[dungeonId]
		local x = (i - (count + 1) / 2) * PORTAL_SPACING
		local color = def.Theme.Torch

		local pad = block(lobby, `{dungeonId}Pad`, Vector3.new(14, 1, 14), CFrame.new(x, 0.5, PORTAL_Z), color, Enum.Material.Neon)
		pad.Transparency = 0.3
		for _, side in { -1, 1 } do
			block(lobby, "Pillar", Vector3.new(2, 16, 2), CFrame.new(x + side * 8, 8, PORTAL_Z - 7), def.Theme.Wall, def.Theme.WallMaterial)
		end
		local beam = block(lobby, "Arch", Vector3.new(18, 2, 2), CFrame.new(x, 17, PORTAL_Z - 7), def.Theme.Wall, def.Theme.WallMaterial)
		torch(lobby, Vector3.new(x, 15.5, PORTAL_Z - 5.8), color)

		local nameLabel = billboard(beam, UDim2.fromOffset(260, 50), Vector3.new(0, 4.5, 0))
		nameLabel.Text = def.DisplayName
		nameLabel.TextColor3 = color

		local infoLabel = billboard(pad, UDim2.fromOffset(240, 60), Vector3.new(0, 5, 0))

		table.insert(portals, {
			Id = dungeonId,
			Def = def,
			Pad = pad,
			Label = infoLabel,
			DifficultyId = "Easy",
			Countdown = nil,
			OnPad = {},
			Warned = {},
		})
	end
end

local function playersOnPad(pad: BasePart): { Player }
	local found = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not playerRun[player] then
			local offset = root.Position - pad.Position
			if math.abs(offset.X) <= Config.Party.PadRadius and math.abs(offset.Z) <= Config.Party.PadRadius and offset.Y < 8 then
				table.insert(found, player)
			end
		end
	end
	return found
end

local function idleText(def: Dungeons.DungeonDef): string
	return `Level {def.Difficulties.Easy.Level}+`
end

-- What the portal panel on the client shows while you stand on a pad.
local function portalInfo(portal: Portal, player: Player, partySize: number)
	local level = PlayerService.GetLevel(player)
	local difficulties = {}
	for _, difficultyId in Config.DifficultyOrder do
		local settings = portal.Def.Difficulties[difficultyId]
		local tiers = {}
		for tier in settings.Loot do
			table.insert(tiers, tier)
		end
		table.sort(tiers)
		table.insert(difficulties, {
			Id = difficultyId,
			Level = settings.Level,
			Unlocked = level >= settings.Level,
			LootTiers = tiers,
		})
	end
	return {
		DungeonId = portal.Id,
		DisplayName = portal.Def.DisplayName,
		Difficulty = portal.DifficultyId,
		Difficulties = difficulties,
		Countdown = portal.Countdown,
		PartySize = partySize,
	}
end

local function updatePortal(portal: Portal)
	local def = portal.Def
	local requiredLevel = def.Difficulties[portal.DifficultyId].Level
	local party = {}
	local onPad = {}

	for _, player in playersOnPad(portal.Pad) do
		onPad[player] = true
		local reason
		if not PlayerService.GetClass(player) then
			reason = "Choose a class first!"
		elseif PlayerService.GetLevel(player) < requiredLevel then
			reason = `{def.DisplayName} on {portal.DifficultyId} needs level {requiredLevel}`
		end
		if reason then
			if portal.Warned[player] ~= portal.DifficultyId then
				portal.Warned[player] = portal.DifficultyId
				PlayerService.Notify(player, reason, Color3.fromRGB(255, 90, 90))
			end
		elseif #party < Config.Party.MaxSize then
			table.insert(party, player)
		end
	end

	-- Players who stepped off the pad: hide their portal panel.
	for player in portal.OnPad do
		if not onPad[player] then
			portal.Warned[player] = nil
			if player.Parent then
				Remotes.PortalUpdate:FireClient(player, nil)
			end
		end
	end
	portal.OnPad = onPad

	if next(onPad) == nil then
		portal.DifficultyId = "Easy"
	end

	if #party == 0 then
		portal.Countdown = nil
		portal.Label.Text = idleText(def)
	else
		portal.Countdown = (portal.Countdown or Config.Party.Countdown + 1) - 1
		if portal.Countdown <= 0 then
			portal.Countdown = nil
			portal.Label.Text = idleText(def)
			task.spawn(startRun, def, portal.DifficultyId, party)
			return
		end
		portal.Label.Text = `{portal.DifficultyId} - starting in {portal.Countdown}\n{#party}/{Config.Party.MaxSize} players`
	end

	for player in onPad do
		Remotes.PortalUpdate:FireClient(player, portalInfo(portal, player, #party))
	end
end

local function onSetDifficulty(player: Player, difficultyId: unknown): (boolean, string?)
	if type(difficultyId) ~= "string" or not Config.Difficulties[difficultyId] then
		return false, "Unknown difficulty"
	end
	for _, portal in portals do
		if portal.OnPad[player] then
			local required = portal.Def.Difficulties[difficultyId].Level
			if PlayerService.GetLevel(player) < required then
				return false, `Reach level {required} to unlock {difficultyId}`
			end
			if portal.DifficultyId ~= difficultyId then
				portal.DifficultyId = difficultyId
				portal.Countdown = nil -- restart the countdown so everyone sees the change
				for other in portal.OnPad do
					PlayerService.Notify(other, `{player.DisplayName} set difficulty to {difficultyId}`, Config.Difficulties[difficultyId].Color)
				end
			end
			return true
		end
	end
	return false, "Stand on a portal first"
end

-- Admin tool: defeats every enemy in the player's current dungeon room.
function DungeonService.KillRoom(player: Player): boolean
	local run = playerRun[player]
	if not run or run.Ended then
		return false
	end
	for enemy in run.Enemies do
		if not enemy.Dead then
			enemy.Humanoid.Health = 0
		end
	end
	return true
end

function DungeonService.Start()
	buildLobby()
	Remotes.SetDifficulty.OnServerInvoke = onSetDifficulty

	Players.PlayerRemoving:Connect(function(player)
		local run = playerRun[player]
		if run then
			leaveRun(run, player)
			if next(run.Players) == nil then
				failRun(run)
			end
		end
	end)

	task.spawn(function()
		while true do
			for _, portal in portals do
				updatePortal(portal)
			end
			task.wait(1)
		end
	end)
end

return DungeonService
