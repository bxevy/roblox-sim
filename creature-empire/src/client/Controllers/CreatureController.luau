--!strict
-- Renders and animates every creature on every plot. The server only publishes what a
-- creature is (Plot/Creatures/<id> attributes: Species, Assignment, ...); this controller
-- decides how it looks and moves. Output never depends on any of this.
--
-- One RenderStepped loop drives all creatures with a small state machine:
--   Idle -> (wander inside the habitat, play idle actions)
--   MovingToJob -> Working (hop/peck at the work spot, harvest pops each cycle)
--   Returning (assignment removed: walk back to the habitat, then Idle)
-- Distance tiers keep it cheap: near creatures update every frame, mid-range every 4th
-- frame with no particles, and far creatures have no model at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Util.Format)
local AssetConfig = require(Shared.Config.AssetConfig)
local Grid = require(Shared.Util.Grid)
local Path = require(Shared.Util.Path)
local PlotConfig = require(Shared.Config.PlotConfig)
local BuildingConfig = require(Shared.Config.BuildingConfig)
local CreatureModels = require(script.Parent.Parent.Visuals.CreatureModels)
local StateController = require(script.Parent.StateController)
local EffectsController = require(script.Parent.EffectsController)
local AudioController = require(script.Parent.AudioController)

local NEAR = 110
local FAR = 260
local MAX_MODELS = 60 -- hard cap on rendered creatures

local localPlayer = Players.LocalPlayer

type Entity = {
	Id: string,
	Anchor: Instance,
	Plot: Folder?, -- nil for wild creatures
	Species: string,
	Stage: number,
	Model: Model?,
	Height: number,
	Floating: boolean,
	Position: Vector3, -- ground point under the creature
	Yaw: number,
	State: "Idle" | "MovingToJob" | "Working" | "Returning" | "Following" | "Away",
	Wild: boolean,
	Home: Vector3?, -- wild creatures wander around their spawn point
	GroundY: number?, -- ground height when not on the plot (wild, following)
	Target: Vector3?,
	FaceTarget: Vector3?,
	Pause: number, -- seconds left before the next wander
	Action: string?,
	ActionTime: number,
	HopPhase: number,
	Walking: boolean, -- moved last frame (followers wait for some slack before starting again)
	WalkBob: number, -- current hop height, eased down after stopping
	WalkRoll: number, -- current waddle lean, eased in and out
	WalkLean: number, -- current forward tip, eased in and out
	WorkTimer: number,
	Speed: number,
	HopHeight: number,
	Owned: boolean,
	Visible: boolean,
	LastStepSound: number,
	Ground: { X: number, Z: number, Y: number, At: number }?, -- last ground probe
	Waypoints: { Vector3 }?, -- path around buildings to Target (nil = walk straight)
	PathFor: Vector3?, -- the Target the waypoints lead to
	PathVersion: number,
	SmoothY: number?, -- ground height eased between probes (no popping on steps)
	Tracks: { [string]: AnimationTrack }?, -- rigged custom models: Idle / Walk / Work
	AnimState: string?,
}

local CreatureController = {}

local entities: { [string]: Entity } = {}
local modelsFolder = Instance.new("Folder")
modelsFolder.Name = "CreatureModels"
modelsFolder.Parent = Workspace
local rng = Random.new()
local modelCount = 0

local function plotOrigin(plot: Folder): CFrame
	return (plot:GetAttribute("Origin") :: CFrame?) or CFrame.new()
end

local function buildingModel(plot: Folder, id: string): Model?
	local buildings = plot:FindFirstChild("Buildings")
	local model = buildings and buildings:FindFirstChild(id)
	return if model and model:IsA("Model") and model.PrimaryPart then model else nil
end

local function habitatPoint(entity: Entity): Vector3
	if entity.Wild and entity.Home then
		return entity.Home + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
	end
	local plot = entity.Plot :: Folder
	-- Each creature calls one of the plot's habitats home (picked by its id, so it stays
	-- the same), which spreads them across every habitat you build.
	local habitats = {}
	local buildings = plot:FindFirstChild("Buildings")
	local children: { Instance } = if buildings then buildings:GetChildren() else {}
	for _, model in children do
		if model:IsA("Model") and model.PrimaryPart and model:GetAttribute("BuildingType") == "Habitat" then
			table.insert(habitats, model)
		end
	end
	table.sort(habitats, function(a, b)
		return a.Name < b.Name
	end)
	local hash = 0
	for i = 1, #entity.Id do
		hash = (hash * 31 + string.byte(entity.Id, i)) % 100003
	end
	local habitat: Model? = habitats[hash % math.max(#habitats, 1) + 1]
	if habitat and habitat.PrimaryPart then
		local base = habitat.PrimaryPart
		local half = base.Size * 0.5 - Vector3.new(2.5, 0, 2.5)
		local offset = Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z * 0.3))
		return (base.CFrame * CFrame.new(offset)).Position
	end
	return (plotOrigin(plot) * CFrame.new(20, 0, 70)).Position
end

-- Work spot for this creature: its index among workers at the building.
local function workSpot(entity: Entity, buildingId: string): (Vector3?, Vector3?)
	if not entity.Plot then
		return nil, nil
	end
	local model = buildingModel(entity.Plot, buildingId)
	if not model or not model.PrimaryPart then
		return nil, nil
	end
	local workers = {}
	local creatures = (entity.Plot :: Folder):FindFirstChild("Creatures")
	if creatures then
		for _, anchor in creatures:GetChildren() do
			if anchor:GetAttribute("Assignment") == buildingId then
				table.insert(workers, anchor.Name)
			end
		end
	end
	table.sort(workers)
	local index = table.find(workers, entity.Id) or 1
	local attachment = model.PrimaryPart:FindFirstChild("WorkSpot" .. index)
		or model.PrimaryPart:FindFirstChild("WorkSpot1")
	local center = model.PrimaryPart.Position
	if attachment and attachment:IsA("Attachment") then
		return attachment.WorldPosition, center
	end
	return center + model.PrimaryPart.CFrame.LookVector * -(model.PrimaryPart.Size.Z / 2 + 2), center
end

-- Pathfinding -------------------------------------------------------------------------------
-- Each plot's building cells come from the building models' grid attributes. Paths are
-- worked out on that grid (Shared/Util/Path) only for creatures near the camera.

type PlotGrid = { Version: number, Cells: { [string]: string }, Dirty: boolean }
local replansThisFrame = 0
local MAX_REPLANS_PER_FRAME = 3 -- spread path searches over frames (no hitches)
local plotGrids: { [Instance]: PlotGrid } = {}

local function gridFor(plot: Folder): PlotGrid
	local existing = plotGrids[plot]
	local g: PlotGrid
	if existing then
		g = existing
	else
		local fresh: PlotGrid = { Version = 0, Cells = {}, Dirty = true }
		g = fresh
		plotGrids[plot] = fresh
		local folder = plot:FindFirstChild("Buildings")
		if folder then
			local function dirty()
				fresh.Dirty = true
			end
			folder.ChildAdded:Connect(dirty)
			folder.ChildRemoved:Connect(dirty)
		end
	end
	if g.Dirty then
		g.Dirty = false
		g.Version += 1
		local records = {}
		local footprints = {}
		local buildings = plot:FindFirstChild("Buildings")
		local models: { Instance } = if buildings then buildings:GetChildren() else {}
		for _, model in models do
			local typeId = model:GetAttribute("BuildingType") :: string?
			local x, z = model:GetAttribute("CellX") :: number?, model:GetAttribute("CellZ") :: number?
			local def = typeId and BuildingConfig[typeId]
			if def and x and z then
				records[model.Name] = { Type = typeId, X = x, Z = z, Rot = (model:GetAttribute("Rot") :: number?) or 0 }
				footprints[typeId :: string] = def.Footprint
			end
		end
		g.Cells = Grid.Occupancy(records, footprints)
	end
	return g
end

local function toCell(plot: Folder, world: Vector3): Path.Cell
	local localPos = plotOrigin(plot):PointToObjectSpace(world)
	local x, z = Grid.CellAt(localPos.X, localPos.Z)
	return { X = x, Z = z }
end

local function cellCenter(plot: Folder, cell: Path.Cell): Vector3
	local size = PlotConfig.CellSize
	return plotOrigin(plot):PointToWorldSpace(Vector3.new((cell.X + 0.5) * size, 0, (cell.Z + 0.5) * size))
end

local function planPath(entity: Entity, target: Vector3)
	local plot = entity.Plot
	if not plot then
		return
	end
	local grid = gridFor(plot)
	local start, goal = toCell(plot, entity.Position), toCell(plot, target)
	local cells = grid.Cells
	-- The buildings the creature starts in and walks to don't block it (habitat, workplace).
	local exempt = {
		[cells[start.X .. "," .. start.Z] or ""] = true,
		[cells[goal.X .. "," .. goal.Z] or ""] = true,
		path = true,
	}
	local function blocked(x: number, z: number): boolean
		if x < -5 or z < -3 or x > PlotConfig.GridX + 4 or z > PlotConfig.GridZ + 4 then
			return true
		end
		local owner = cells[x .. "," .. z]
		return owner ~= nil and not exempt[owner]
	end
	entity.PathFor = target
	entity.PathVersion = grid.Version
	if start.X == goal.X and start.Z == goal.Z then
		entity.Waypoints = nil
		return
	end
	local found = Path.Find(start, goal, blocked, 1500)
	if not found then
		entity.Waypoints = nil -- no way round: walk straight (old behaviour)
		return
	end
	local simplified = Path.Simplify(found, blocked)
	local points = {}
	for i = 2, #simplified - 1 do
		table.insert(points, cellCenter(plot, simplified[i]))
	end
	entity.Waypoints = points
end

local function baseFloorY(entity: Entity): number
	if entity.GroundY then
		return entity.GroundY
	end
	return if entity.Plot then plotOrigin(entity.Plot).Position.Y else 0
end

-- Raycast for the real surface under a creature (habitat floors, paths, building bases,
-- terrain), ignoring creatures and characters. Only surfaces near the expected floor
-- count, so creatures walk across floors but never hop onto roofs.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true
local groundParamsAt = 0
local GROUND_UP = 2.5 -- highest step above the expected floor a creature stands on
local GROUND_DOWN = 4 -- lowest dip below it (terrain hollows)

local function probeGround(entity: Entity, base: number): number
	local now = os.clock()
	if now - groundParamsAt > 1 then
		groundParamsAt = now
		local ignore: { Instance } = { modelsFolder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		groundParams.FilterDescendantsInstances = ignore
	end
	local origin = Vector3.new(entity.Position.X, base + GROUND_UP + 0.5, entity.Position.Z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_UP + GROUND_DOWN + 0.5), 0), groundParams)
	return if hit then hit.Position.Y else base
end

local function floorY(entity: Entity): number
	local base = baseFloorY(entity)
	local probe = entity.Ground
	local now = os.clock()
	if
		not probe
		or math.abs(probe.X - entity.Position.X) + math.abs(probe.Z - entity.Position.Z) > 0.6
		or now - probe.At > 0.5
	then
		probe = { X = entity.Position.X, Z = entity.Position.Z, Y = probeGround(entity, base), At = now }
		entity.Ground = probe
	end
	local target = (probe :: any).Y
	local current = entity.SmoothY or target
	-- Ease toward the probed height (steps up and down smoothly).
	current += (target - current) * 0.35
	if math.abs(target - current) < 0.01 then
		current = target
	end
	entity.SmoothY = current
	return current
end

local function ensureModel(entity: Entity)
	if entity.Model or modelCount >= MAX_MODELS then
		return
	end
	local mutation = entity.Anchor:GetAttribute("Mutation") :: string?
	local ok, model =
		pcall(CreatureModels.Build, entity.Species, entity.Stage, if mutation and mutation ~= "" then mutation else nil)
	if not ok then
		warn("[CE] creature model failed:", model)
		return
	end
	entity.Model = model
	entity.Height = (model:GetAttribute("Height") :: number?) or 1.5
	entity.Floating = model:GetAttribute("Floating") == true
	model.Name = entity.Id
	model.Parent = modelsFolder
	modelCount += 1
	local name = entity.Anchor:GetAttribute("Name")
	local label = Instance.new("BillboardGui")
	label.Name = "NameTag"
	label.Size = UDim2.fromOffset(140, 26)
	label.StudsOffset = Vector3.new(0, entity.Height + 1.4, 0)
	label.MaxDistance = 45
	label.LightInfluence = 0
	label.Adornee = model.PrimaryPart :: BasePart
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	if entity.Wild then
		local species = CreatureConfig.Species[entity.Species]
		local rarity = RarityConfig.Get(species.Rarity)
		text.Text = `Wild {species.Name} · {rarity.Glyph} {rarity.Label}`
		text.TextColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4)
		label.MaxDistance = 80
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Befriend"
		prompt.ObjectText = "Wild " .. species.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function()
			CreatureController.OnBefriend(entity.Id, entity.Species)
		end)
	else
		text.Text = `{name} · Lv {entity.Anchor:GetAttribute("Level") or 1}`
	end
	text.Parent = label
	label.Parent = model

	-- Rigged custom models play their animations (model attributes IdleAnimation /
	-- WalkAnimation / WorkAnimation, or AssetConfig.Animations[species]).
	entity.Tracks = nil
	entity.AnimState = nil
	if model:GetAttribute("Rigged") == true then
		local holder: Instance? = model:FindFirstChildWhichIsA("Humanoid", true)
			or model:FindFirstChildWhichIsA("AnimationController", true)
		if holder then
			local animator = holder:FindFirstChildOfClass("Animator")
			if not animator then
				local made = Instance.new("Animator")
				made.Parent = holder
				animator = made
			end
			local configured: any = AssetConfig.Animations[entity.Species] or {}
			local tracks: { [string]: AnimationTrack } = {}
			for _, kind in { "Idle", "Walk", "Work" } do
				local id = (model:GetAttribute(kind .. "Animation") :: string?) or configured[kind]
				if type(id) == "string" and id ~= "" then
					local animation = Instance.new("Animation")
					animation.AnimationId = id
					local loaded, track = pcall(function()
						return (animator :: Animator):LoadAnimation(animation)
					end)
					if loaded and track then
						track.Looped = true
						tracks[kind] = track
					end
				end
			end
			if next(tracks) then
				entity.Tracks = tracks
			end
		end
	end

	-- Supporter cosmetic: a golden sparkle on the owner's companion.
	local ownerId = entity.Anchor:GetAttribute("OwnerUserId") :: number?
	local owner = if ownerId then Players:GetPlayerByUserId(ownerId) else nil
	if owner and owner:GetAttribute("Supporter") == true and entity.Anchor:GetAttribute("Companion") == true then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "SupporterSparkle"
		sparkle.Texture = AssetConfig.Particles.Default
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 215, 90))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.3, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Rate = 10
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = model.PrimaryPart
	end
end

-- Plays the right animation for what the creature is doing (rigged custom models only).
local function animate(entity: Entity)
	local tracks = entity.Tracks
	if not tracks then
		return
	end
	local want = if entity.State == "Working"
		then "Work"
		elseif entity.Target ~= nil and entity.Action == nil then "Walk"
		else "Idle"
	if not tracks[want] then
		want = "Idle"
	end
	if entity.AnimState ~= want then
		for kind, track in tracks do
			if kind == want then
				track:Play(0.2)
			else
				track:Stop(0.2)
			end
		end
		entity.AnimState = want
	end
end

local function dropModel(entity: Entity)
	if entity.Model then
		entity.Model:Destroy()
		entity.Model = nil
		modelCount -= 1
	end
end

local function setParticles(entity: Entity, enabled: boolean)
	local model = entity.Model
	if not model then
		return
	end
	local vfx = EffectsController.Settings().Vfx
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Name ~= "Footstep" then
			descendant.Enabled = enabled and vfx ~= "Off"
		end
	end
end

local function speciesIdle(speciesId: string)
	local species = CreatureConfig.Species[speciesId]
	return species and species.Idle
end

local function ownState(entity: Entity): any
	if not entity.Owned then
		return nil
	end
	local creatures = StateController.Get("Creatures")
	return creatures and creatures.List and creatures.List[entity.Id]
end

-- Behaviour -----------------------------------------------------------------------------

local function ownerRoot(entity: Entity): BasePart?
	local ownerId = entity.Anchor:GetAttribute("OwnerUserId") :: number?
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	local character = owner and owner.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local WADDLE_ROLL = 0.1 -- radians of side-to-side lean per step
local WALK_LEAN = 0.06 -- radians of forward tip while walking
local HOP_SCALE = 1.8 -- walking hops are this many times the species' hop height
local FOLLOW_SLACK = 2.5 -- studs a resting follower lets you get away before it walks

local function decide(entity: Entity)
	if entity.Wild then
		if entity.State ~= "Idle" then
			entity.State = "Idle"
		end
		return
	end
	if entity.Anchor:GetAttribute("Away") == true then
		entity.State = "Away"
		return
	end
	if entity.Anchor:GetAttribute("Companion") == true then
		local root = ownerRoot(entity)
		if root then
			local behind = root.Position - root.CFrame.LookVector * 5 + root.CFrame.RightVector * 3
			if
				(Vector3.new(behind.X, 0, behind.Z) - Vector3.new(entity.Position.X, 0, entity.Position.Z)).Magnitude
				> 60
			then
				entity.Position = Vector3.new(behind.X, 0, behind.Z) -- caught up after a teleport
			end
			entity.GroundY = root.Position.Y - 3
			entity.Target = behind
			entity.FaceTarget = nil
			entity.Action = nil
			entity.State = "Following"
			return
		end
	end
	if entity.State == "Following" or entity.State == "Away" then
		-- Back from following or from an expedition: home to the habitat.
		entity.GroundY = nil
		entity.State = "Idle"
		entity.Target = nil
		local home = habitatPoint(entity)
		if (home - entity.Position).Magnitude > 80 then
			entity.Position = home
		end
	end
	local assignment = entity.Anchor:GetAttribute("Assignment") :: string?
	if assignment and assignment ~= "" then
		local spot, center = workSpot(entity, assignment)
		if spot then
			entity.Target = spot
			entity.FaceTarget = center
			local distance = (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(entity.Position.X, 0, entity.Position.Z)).Magnitude
			entity.State = if distance > 0.6 then "MovingToJob" else "Working"
			return
		end
	end
	if entity.State == "MovingToJob" or entity.State == "Working" then
		entity.State = "Returning"
		entity.Target = habitatPoint(entity)
		entity.FaceTarget = nil
		return
	end
	if entity.State == "Returning" and entity.Target then
		return
	end
	entity.State = "Idle"
end

local IDLE_ACTIONS = { Hop = 0.6, Spin = 0.8, Sniff = 1.4, Look = 1.6, Nap = 3 }

local function step(entity: Entity, dt: number, detailed: boolean): CFrame
	decide(entity)
	local idle = speciesIdle(entity.Species)
	local speed = if idle then idle.Speed else 8
	if entity.State == "Following" then
		speed = math.max(speed, 20) -- keep up with a running player
	end
	local hopHeight = if idle then idle.HopHeight else 0.5
	local bob = 0
	local tilt = 0
	local spin = 0
	local walkRoll, walkLean = 0, 0 -- this frame's walk pose (eased into entity.Walk*)

	if entity.State == "Idle" then
		if entity.Action then
			entity.ActionTime -= dt
			local t = entity.ActionTime
			if entity.Action == "Hop" then
				bob = math.abs(math.sin(t * 10)) * (hopHeight + 0.6)
			elseif entity.Action == "Spin" then
				spin = (1 - math.clamp(t / IDLE_ACTIONS.Spin, 0, 1)) * math.pi * 2
			elseif entity.Action == "Sniff" then
				tilt = math.sin(t * 12) * 0.15 + 0.2
			elseif entity.Action == "Look" then
				spin = math.sin(t * 2) * 0.6
			elseif entity.Action == "Nap" then
				tilt = 0.15
				bob = -0.15 + math.sin(t * 2) * 0.05
			end
			if entity.ActionTime <= 0 then
				entity.Action = nil
			end
		elseif entity.Target then
			-- walking to a wander point (handled below)
		else
			entity.Pause -= dt
			if entity.Pause <= 0 then
				if rng:NextNumber() < 0.45 and idle then
					local actions = idle.IdleActions
					entity.Action = actions[rng:NextInteger(1, #actions)]
					entity.ActionTime = IDLE_ACTIONS[entity.Action or ""] or 1
				else
					entity.Target = habitatPoint(entity)
				end
				entity.Pause = rng:NextNumber(1.5, 4.5)
			end
		end
	end

	-- Walking toward a target (wander, job or return), around buildings when close by.
	if entity.Target and entity.State ~= "Working" then
		local target = entity.Target :: Vector3
		if entity.Plot and entity.State ~= "Following" and detailed then
			local grid = gridFor(entity.Plot)
			if entity.PathFor ~= target or entity.PathVersion ~= grid.Version then
				if replansThisFrame < MAX_REPLANS_PER_FRAME then
					replansThisFrame += 1
					planPath(entity, target)
				elseif entity.PathFor ~= target then
					entity.Waypoints = nil -- old route led elsewhere; plan on a later frame
				end
			end
		elseif entity.PathFor ~= target then
			entity.Waypoints = nil
			entity.PathFor = target
		end
		local waypoints = entity.Waypoints
		if waypoints and #waypoints > 0 then
			local next = waypoints[1]
			if
				(Vector3.new(next.X, 0, next.Z) - Vector3.new(entity.Position.X, 0, entity.Position.Z)).Magnitude < 0.6
			then
				table.remove(waypoints, 1)
			end
		end
		local aim = if waypoints and #waypoints > 0 then waypoints[1] else target
		local flatTarget = Vector3.new(aim.X, entity.Position.Y, aim.Z)
		local delta = flatTarget - entity.Position
		local distance = delta.Magnitude
		local finalLeg = not (waypoints and #waypoints > 0)
		-- A follower that has stopped waits until you are a little further away, so it
		-- walks in smooth stretches instead of a step every few frames.
		local resting = entity.State == "Following" and not entity.Walking and distance < FOLLOW_SLACK
		if (distance < 0.3 or resting) and finalLeg then
			entity.Walking = false
			if distance < 0.3 then
				entity.Position = flatTarget
			end
			if entity.State ~= "MovingToJob" then
				entity.Target = nil
				if entity.State == "Returning" then
					entity.State = "Idle"
				end
			end
		else
			entity.Walking = true
			local move = math.min(speed * dt, distance)
			entity.Position += delta.Unit * move
			local desiredYaw = math.atan2(-delta.X, -delta.Z)
			local diff = (desiredYaw - entity.Yaw + math.pi) % (math.pi * 2) - math.pi
			entity.Yaw += diff * math.min(dt * 10, 1)
			-- Hop arc; a landing kicks up a puff and a footstep sound.
			local before = entity.HopPhase
			entity.HopPhase += move / math.max(speed, 1) * 9
			entity.WalkBob = math.abs(math.sin(entity.HopPhase)) * hopHeight * HOP_SCALE
			-- Walk cycle for models without their own animations: lean into each step
			-- (left, right, left...) and tip forward a little, so they waddle along.
			if not entity.Tracks then
				walkRoll = math.sin(entity.HopPhase) * WADDLE_ROLL
				walkLean = WALK_LEAN
			end
			if detailed and math.floor(before / math.pi) ~= math.floor(entity.HopPhase / math.pi) then
				local puff = entity.Model
					and entity.Model.PrimaryPart
					and entity.Model.PrimaryPart:FindFirstChild("FeetAttachment")
				local emitter = puff and puff:FindFirstChild("Footstep") :: ParticleEmitter?
				if emitter and EffectsController.Settings().Vfx ~= "Off" then
					emitter:Emit(2)
				end
				if entity.Owned and os.clock() - entity.LastStepSound > 0.6 then
					entity.LastStepSound = os.clock()
					local species = CreatureConfig.Species[entity.Species]
					if species then
						AudioController.Play(species.Sounds.Move, entity.Position)
					end
				end
			end
		end
	end

	if entity.State == "Working" then
		local mine = ownState(entity)
		local waiting = mine and string.find(mine.Task or "", "Waiting", 1, true) ~= nil
		if entity.FaceTarget then
			local d = entity.FaceTarget - entity.Position
			local desiredYaw = math.atan2(-d.X, -d.Z)
			local diff = (desiredYaw - entity.Yaw + math.pi) % (math.pi * 2) - math.pi
			entity.Yaw += diff * math.min(dt * 6, 1)
		end
		if waiting then
			tilt = 0.12
			bob = math.sin(os.clock() * 2) * 0.05
		else
			local cycle = if mine and mine.CycleTime then mine.CycleTime else 5
			entity.WorkTimer += dt
			local phase = (entity.WorkTimer % cycle) / cycle
			-- Pecking rhythm, with a little hop when a cycle completes.
			tilt = math.max(math.sin(phase * math.pi * 6), 0) * 0.35
			if entity.WorkTimer >= cycle then
				entity.WorkTimer -= cycle
				if
					detailed
					and mine
					and mine.PerSecond
					and mine.PerSecond > 0
					and entity.Model
					and entity.Model.PrimaryPart
				then
					local amount = mine.PerSecond * cycle
					local buildings = StateController.Get("Buildings")
					local building = buildings and mine.Assignment and buildings.List[mine.Assignment]
					local petal = building and building.Output and ResourceConfig[building.Output]
						or ResourceConfig.Moonpetal
					-- Couriers have no output of their own (their deliveries show in the silo).
					local showPopup = not (building and building.Output == nil)
					if showPopup then
						EffectsController.Popup(
							entity.Model.PrimaryPart.Position + Vector3.new(0, entity.Height + 1.5, 0),
							"+" .. Format.Rate(amount) .. " " .. petal.Icon,
							petal.Color
						)
					end
					local species = CreatureConfig.Species[entity.Species]
					if species then
						AudioController.Play(species.Sounds.Work, entity.Position)
					end
				end
			end
			if phase > 0.9 then
				bob = math.sin((phase - 0.9) * 10 * math.pi) * 0.5
			end
		end
	end

	-- Ease the walk pose so starting and stopping never snap: the hop settles to the
	-- ground, the waddle and forward tip fade in and out.
	if entity.State == "Working" or not entity.Target then
		entity.Walking = false
	end
	if not entity.Walking then
		entity.WalkBob *= math.max(1 - dt * 12, 0)
	end
	local ease = math.min(dt * 12, 1)
	entity.WalkRoll += (walkRoll - entity.WalkRoll) * ease
	entity.WalkLean += (walkLean - entity.WalkLean) * ease
	bob += entity.WalkBob
	tilt += entity.WalkLean

	if entity.Floating then
		bob += 0.4 + math.sin(os.clock() * 2 + entity.Position.X) * 0.25
	end

	local y = floorY(entity) + entity.Height + bob
	return CFrame.new(entity.Position.X, y, entity.Position.Z)
		* CFrame.Angles(0, entity.Yaw + spin, 0)
		* CFrame.Angles(-tilt, 0, entity.WalkRoll)
end

-- Tracking anchors ------------------------------------------------------------------------

local function newEntity(anchor: Instance, speciesId: string, plot: Folder?): Entity
	return {
		Id = anchor.Name,
		Anchor = anchor,
		Plot = plot,
		Species = speciesId,
		Stage = (anchor:GetAttribute("Stage") :: number?) or 1,
		Model = nil,
		Height = 1.5,
		Floating = false,
		Position = Vector3.zero,
		Yaw = rng:NextNumber(0, math.pi * 2),
		State = "Idle",
		Wild = plot == nil,
		Home = nil,
		GroundY = nil,
		Target = nil,
		PathVersion = 0,
		FaceTarget = nil,
		Pause = rng:NextNumber(0.5, 2),
		Action = nil,
		ActionTime = 0,
		HopPhase = 0,
		Walking = false,
		WalkBob = 0,
		WalkRoll = 0,
		WalkLean = 0,
		WorkTimer = rng:NextNumber(0, 2),
		Speed = 8,
		HopHeight = 0.5,
		Owned = anchor:GetAttribute("OwnerUserId") == localPlayer.UserId,
		Visible = false,
		LastStepSound = 0,
	}
end

-- Wild creatures: rendered like any other creature, wandering around their spawn point,
-- with a Befriend prompt.
CreatureController.OnBefriend = function(_wildId: string, _speciesId: string) end

local function addWild(anchor: Instance)
	local speciesId = anchor:GetAttribute("Species") :: string?
	local position = anchor:GetAttribute("Position") :: Vector3?
	if not speciesId or not position or not CreatureConfig.Species[speciesId] then
		return
	end
	local entity = newEntity(anchor, speciesId, nil)
	entity.Home = position
	entity.GroundY = position.Y
	entity.Position = Vector3.new(position.X, 0, position.Z)
	entities[entity.Id] = entity
end

local function addEntity(plot: Folder, anchor: Instance)
	local speciesId = anchor:GetAttribute("Species") :: string?
	if not speciesId or not CreatureConfig.Species[speciesId] then
		return
	end
	local entity = newEntity(anchor, speciesId, plot)
	entity.Position = habitatPoint(entity)
	entities[entity.Id] = entity

	anchor.AttributeChanged:Connect(function(attribute)
		if
			attribute == "Stage"
			or attribute == "Name"
			or attribute == "Level"
			or attribute == "Mutation"
			or attribute == "Companion"
		then
			entity.Stage = (anchor:GetAttribute("Stage") :: number?) or 1
			dropModel(entity) -- rebuilt next frame with the new look/label
		end
	end)
end

local function removeEntity(id: string)
	local entity = entities[id]
	if entity then
		dropModel(entity)
		entities[id] = nil
	end
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Folder") then
		return
	end
	local creatures = plot:WaitForChild("Creatures", 10)
	if not creatures then
		return
	end
	for _, anchor in creatures:GetChildren() do
		addEntity(plot, anchor)
	end
	creatures.ChildAdded:Connect(function(anchor)
		task.defer(addEntity, plot, anchor) -- attributes arrive with the instance
	end)
	creatures.ChildRemoved:Connect(function(anchor)
		removeEntity(anchor.Name)
	end)
end

-- Ability visuals --------------------------------------------------------------------------

local function onAbilityFx(payload: any)
	local entity = entities[payload.CreatureId]
	if not entity or not entity.Model or not entity.Model.PrimaryPart then
		return
	end
	local family = CreatureConfig.Families[payload.Family]
	local color = family and family.Color or Color3.new(1, 1, 1)
	local position = entity.Model.PrimaryPart.Position
	EffectsController.Ring(Vector3.new(position.X, baseFloorY(entity) + 0.2, position.Z), color, 10)
	EffectsController.Burst(position, color, 30, { Speed = 12, Acceleration = Vector3.new(0, 4, 0) })
	if payload.BuildingId and entity.Plot then
		local model = buildingModel(entity.Plot, payload.BuildingId)
		if model and model.PrimaryPart then
			EffectsController.Burst(model.PrimaryPart.Position + Vector3.new(0, 2, 0), color, 40, {
				Acceleration = Vector3.new(0, 5, 0),
				Lifetime = 1.6,
			})
		end
	end
	entity.Action = "Spin"
	entity.ActionTime = IDLE_ACTIONS.Spin
	AudioController.Play("AbilityCast", position)
end

-- Where a creature is right now (for UI effects); nil if not rendered.
function CreatureController.GetPosition(creatureId: string): Vector3?
	local entity = entities[creatureId]
	return entity and entity.Model and entity.Model.PrimaryPart and entity.Model.PrimaryPart.Position
end

function CreatureController.Start()
	-- A player becoming a Supporter: rebuild their companion so it gets its sparkle.
	local function watchSupporter(player: Player)
		player:GetAttributeChangedSignal("Supporter"):Connect(function()
			for _, entity in entities do
				if entity.Anchor:GetAttribute("OwnerUserId") == player.UserId then
					dropModel(entity)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watchSupporter)
	for _, player in Players:GetPlayers() do
		watchSupporter(player)
	end
	local plots = Workspace:WaitForChild("PlayerPlots")
	for _, plot in plots:GetChildren() do
		task.spawn(watchPlot, plot)
	end
	plots.ChildAdded:Connect(watchPlot)

	task.spawn(function()
		local wild = Workspace:WaitForChild("WildCreatures", 30)
		if not wild then
			return
		end
		for _, anchor in wild:GetChildren() do
			addWild(anchor)
		end
		wild.ChildAdded:Connect(function(anchor)
			task.defer(addWild, anchor)
		end)
		wild.ChildRemoved:Connect(function(anchor)
			removeEntity(anchor.Name)
		end)
	end)

	Remotes.Events.GameEvent.OnClientEvent:Connect(function(name, payload)
		if name == "AbilityFx" then
			onAbilityFx(payload)
		elseif name == "WildResult" then
			local position = payload.Position :: Vector3
			if payload.Success then
				EffectsController.Burst(position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 150, 200), 40, {
					Acceleration = Vector3.new(0, 6, 0),
					Lifetime = 1.6,
				})
			else
				EffectsController.Burst(position + Vector3.new(0, 1, 0), Color3.fromRGB(150, 140, 130), 20, {
					Texture = "rbxasset://textures/particles/smoke_main.dds",
					Size = 2,
					LightEmission = 0,
				})
			end
		elseif name == "CreatureObtained" then
			task.delay(0.2, function()
				local entity = entities[payload.Id]
				if entity then
					EffectsController.Burst(entity.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 240, 180), 50, {
						Acceleration = Vector3.new(0, 6, 0),
						Lifetime = 1.5,
					})
				end
			end)
		end
	end)

	local frame = 0
	RunService.RenderStepped:Connect(function(dt)
		frame += 1
		replansThisFrame = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		dt = math.min(dt, 0.1)
		for _, entity in entities do
			if entity.State == "Away" or entity.Anchor:GetAttribute("Away") == true then
				-- On an expedition: not on the plot at all.
				if entity.Model then
					dropModel(entity)
				end
				if frame % 30 == 0 then
					decide(entity)
				end
				continue
			end
			local distance = (Vector3.new(entity.Position.X, baseFloorY(entity), entity.Position.Z) - camPos).Magnitude
			if distance > FAR then
				-- Far away: keep the logic cheap and drop the model.
				if entity.Model then
					dropModel(entity)
				end
				if frame % 15 == 0 then
					step(entity, dt * 15, false)
				end
			else
				ensureModel(entity)
				local near = distance <= NEAR
				local interval = if near then 1 else 4
				if frame % interval == 0 then
					local cf = step(entity, dt * interval, near)
					if entity.Model and entity.Model.PrimaryPart then
						entity.Model.PrimaryPart.CFrame = cf
						animate(entity)
					end
				end
				if near ~= entity.Visible then
					entity.Visible = near
					setParticles(entity, near)
				end
			end
		end
	end)
end

return CreatureController
