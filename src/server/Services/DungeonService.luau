-- Lobby portals, parties, and dungeon runs.
--
-- Stand on a portal pad -> after a countdown everyone on it is sent into a fresh copy of
-- that dungeon. Each dungeon is a line of rooms joined by corridors. Clearing a room opens
-- the next door; the last room holds the boss. Beat the boss for XP, gold and a weapon.
-- If everyone in the party dies, the run fails.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Dungeons = require(ReplicatedStorage.Shared.Dungeons)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)

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
	local door = block(
		parent,
		"Door",
		Vector3.new(CORRIDOR_WIDTH, WALL_HEIGHT, 2),
		CFrame.new(x, WALL_HEIGHT / 2, zMid),
		Color3.fromRGB(70, 45, 30),
		Enum.Material.WoodPlanks
	)
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
		z += size
		if i < #sizes then
			table.insert(run.Doors, buildCorridor(run.Folder, x, z, theme))
			z += CORRIDOR_LENGTH
		end
	end
end

-- Run lifecycle --------------------------------------------------------------

local function setStatus(run: Run, text: string?)
	for player in run.Players do
		Remotes.DungeonStatus:FireClient(player, text)
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

local function rollLoot(def: Dungeons.DungeonDef): string
	local total = 0
	for _, entry in def.Loot do
		total += entry.Weight
	end
	local roll = math.random() * total
	for _, entry in def.Loot do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Weapon
		end
	end
	return def.Loot[#def.Loot].Weapon
end

local function winRun(run: Run)
	if run.Ended then
		return
	end
	run.Ended = true
	local def = run.Def
	setStatus(run, `{def.DisplayName} - CLEARED!`)
	notifyRun(run, "VICTORY!", Color3.fromRGB(255, 220, 80))

	for player in run.Players do
		PlayerService.AddXP(player, def.Rewards.XP)
		PlayerService.AddGold(player, def.Rewards.Gold)

		local weaponId = rollLoot(def)
		local weapon = Weapons.Defs[weaponId]
		local color = Config.Rarities[weapon.Rarity]
		task.delay(1.5, function()
			if PlayerService.GiveWeapon(player, weaponId) then
				PlayerService.Notify(player, `You found: {weapon.DisplayName} ({weapon.Rarity})!`, color)
			else
				PlayerService.AddGold(player, Config.DuplicateWeaponGold)
				PlayerService.Notify(player, `Duplicate {weapon.DisplayName} - +{Config.DuplicateWeaponGold} Gold`, color)
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
	local power = run.Def.Power
	for player in run.Players do
		PlayerService.AddXP(player, enemy.Def.XP * power)
		PlayerService.AddGold(player, enemy.Def.Gold * power)
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
		Power = run.Def.Power,
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
	run.Remaining = 0

	if index == #run.Rooms then
		setStatus(run, `{def.DisplayName} - BOSS`)
		notifyRun(run, `{Enemies[def.Boss].DisplayName} awaits...`, Color3.fromRGB(255, 90, 90))
		spawnInRoom(run, index, def.Boss, room.Center + Vector3.new(0, 0, room.Size / 4))
		return
	end

	setStatus(run, `{def.DisplayName} - Room {index - 1}/{combatRooms}`)
	local spread = room.Size / 2 - 8
	for enemyId, count in def.Rooms[index - 1] do
		for _ = 1, count do
			local offset = Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
			spawnInRoom(run, index, enemyId, room.Center + offset)
		end
	end
end

local function startRun(def: Dungeons.DungeonDef, party: { Player })
	local slot = 1
	while runsBySlot[slot] do
		slot += 1
	end

	local folder = Instance.new("Folder")
	folder.Name = `{def.DisplayName} #{slot}`
	folder.Parent = dungeonsFolder

	local run: Run = {
		Def = def,
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
			run.Connections[player] = humanoid.Died:Connect(function()
				PlayerService.Notify(player, "You were defeated!", Color3.fromRGB(255, 80, 80))
				leaveRun(run, player)
				if next(run.Players) == nil then
					failRun(run)
				end
			end)
			local x = (i - (#party + 1) / 2) * 5
			teleport(player, entry.Center + Vector3.new(x, 4, -entry.Size / 4), Vector3.zAxis)
		end
	end

	if next(run.Players) == nil then
		failRun(run)
		return
	end

	setStatus(run, def.DisplayName)
	notifyRun(run, `Entering {def.DisplayName}... get ready!`)
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
	Def: Dungeons.DungeonDef,
	Pad: BasePart,
	Label: TextLabel,
	Countdown: number?,
	Warned: { [Player]: boolean },
}

local portals: { Portal } = {}

local function buildLobby()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	local sign = block(lobby, "Sign", Vector3.new(30, 8, 1), CFrame.new(0, 14, -62), Color3.fromRGB(60, 45, 35), Enum.Material.WoodPlanks)
	local title = billboard(sign, UDim2.fromOffset(500, 80), Vector3.new(0, 0, 0))
	title.Parent.MaxDistance = 300
	title.Text = Config.GameName:upper()
	title.TextColor3 = Color3.fromRGB(255, 210, 90)

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
		infoLabel.Text = `Level {def.MinLevel}+`

		table.insert(portals, {
			Def = def,
			Pad = pad,
			Label = infoLabel,
			Countdown = nil,
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

local function updatePortal(portal: Portal)
	local def = portal.Def
	local party = {}
	local onPad = {}
	for _, player in playersOnPad(portal.Pad) do
		onPad[player] = true
		if PlayerService.GetLevel(player) < def.MinLevel then
			if not portal.Warned[player] then
				portal.Warned[player] = true
				PlayerService.Notify(player, `You need to be level {def.MinLevel} for {def.DisplayName}`, Color3.fromRGB(255, 90, 90))
			end
		elseif #party < Config.Party.MaxSize then
			table.insert(party, player)
		end
	end
	for player in portal.Warned do
		if not onPad[player] then
			portal.Warned[player] = nil
		end
	end

	if #party == 0 then
		portal.Countdown = nil
		portal.Label.Text = `Level {def.MinLevel}+`
		return
	end

	portal.Countdown = (portal.Countdown or Config.Party.Countdown + 1) - 1
	if portal.Countdown <= 0 then
		portal.Countdown = nil
		portal.Label.Text = `Level {def.MinLevel}+`
		task.spawn(startRun, def, party)
	else
		portal.Label.Text = `Starting in {portal.Countdown}\n{#party}/{Config.Party.MaxSize} players`
	end
end

function DungeonService.Start()
	buildLobby()

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
