-- Townsfolk: villagers who stroll between spots in town and chat, plus guards and
-- shopkeepers who stay at their posts. Bodies come from Roblox's default R15 character,
-- dressed with simple part-built clothes and hats.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Build = require(ServerScriptService.Server.Build)

local TownsfolkService = {}

local rgb = Color3.fromRGB
local M = Enum.Material

-- Roblox's own default R15 animations.
local IDLE_ANIMATION = "rbxassetid://507766666"
local WALK_ANIMATION = "rbxassetid://507777826"
local WALK_SPEED = 7

local SKIN = { rgb(234, 184, 146), rgb(204, 142, 105), rgb(160, 110, 80), rgb(245, 205, 170), rgb(124, 92, 70) }

-- Open spots in town that villagers walk between.
local WAYPOINTS = {
	Vector3.new(-30, 0, -22),
	Vector3.new(-22, 0, -4),
	Vector3.new(-26, 0, 22),
	Vector3.new(-36, 0, 36),
	Vector3.new(-14, 0, 40),
	Vector3.new(21, 0, 12),
	Vector3.new(24, 0, 12),
	Vector3.new(22, 0, -16),
	Vector3.new(14, 0, -33),
	Vector3.new(-16, 0, -33),
	Vector3.new(0, 0, 40),
	Vector3.new(-40, 0, -28),
	Vector3.new(40, 0, -26),
	Vector3.new(28, 0, 38),
	Vector3.new(-42, 0, 6),
}

type NpcDef = {
	Name: string,
	Shirt: Color3,
	Pants: Color3,
	Hat: string?, -- "Straw" | "Hood" | "Cap" | "Helmet" | "Feather"
	HatColor: Color3?,
	Apron: boolean?,
	Spear: boolean?,
	Lines: { string }?,
	-- Static NPCs stand at Post facing LookAt. Wanderers have no Post.
	Post: Vector3?,
	LookAt: Vector3?,
}

local NPCS: { NpcDef } = {
	{ Name = "Farmer Gregor", Shirt = rgb(120, 85, 50), Pants = rgb(70, 90, 50), Hat = "Straw", Lines = { "Fine weather for the harvest!", "Them skeletons trampled my turnips again." } },
	{ Name = "Baker Matilda", Shirt = rgb(170, 60, 60), Pants = rgb(120, 40, 40), Hat = "Cap", HatColor = rgb(240, 240, 235), Apron = true, Lines = { "Fresh bread! Well... it was this morning.", "Adventurers always come back hungry." } },
	{ Name = "Merchant Osric", Shirt = rgb(100, 50, 130), Pants = rgb(50, 40, 60), Hat = "Feather", HatColor = rgb(120, 30, 40), Lines = { "Gold talks, friend.", "I hear the Sunken Temple is full of treasure." } },
	{ Name = "Old Wilhelmina", Shirt = rgb(110, 105, 100), Pants = rgb(80, 75, 70), Hat = "Hood", HatColor = rgb(90, 85, 80), Lines = { "In my day the Bone King knew his place.", "Mind the red circles, dearie." } },
	{ Name = "Bard Finnick", Shirt = rgb(60, 140, 70), Pants = rgb(200, 180, 60), Hat = "Feather", HatColor = rgb(40, 100, 50), Lines = { "Shall I sing of your victories? Get some first!", "La la la... ahem." } },
	{ Name = "Squire Edwin", Shirt = rgb(150, 150, 160), Pants = rgb(60, 50, 40), Lines = { "One day I'll clear the Frozen Keep!", "Have you tried the training dummies?" } },
	{ Name = "Herbalist Rowan", Shirt = rgb(70, 110, 60), Pants = rgb(60, 50, 40), Hat = "Hood", HatColor = rgb(50, 90, 50), Lines = { "Potions are cheaper than funerals.", "A Swiftness Potion keeps you out of trouble." } },
	{ Name = "Fisherman Bram", Shirt = rgb(60, 90, 140), Pants = rgb(70, 60, 50), Hat = "Straw", Lines = { "The fountain has no fish. I checked.", "Smells like adventure. Or fish." } },

	-- Posted characters
	{ Name = "Town Guard", Shirt = rgb(150, 30, 35), Pants = rgb(50, 50, 55), Hat = "Helmet", Spear = true, Post = Vector3.new(-8, 0, 47), LookAt = Vector3.new(-8, 0, 0) },
	{ Name = "Town Guard", Shirt = rgb(150, 30, 35), Pants = rgb(50, 50, 55), Hat = "Helmet", Spear = true, Post = Vector3.new(8, 0, 47), LookAt = Vector3.new(8, 0, 0) },
	{ Name = "Barkeep Hilda", Shirt = rgb(140, 90, 50), Pants = rgb(90, 50, 40), Apron = true, Hat = "Cap", HatColor = rgb(200, 60, 60), Post = Vector3.new(-48, 0, -13), LookAt = Vector3.new(0, 0, -13), Lines = { "Ale's on the house for anyone who beats the Pharaoh!" } },
	{ Name = "Smith Gunnar", Shirt = rgb(70, 60, 55), Pants = rgb(50, 45, 40), Apron = true, Post = Vector3.new(38, 0, -35), LookAt = Vector3.new(38, 0, -45), Lines = { "Good steel never lies.", "Bring me Dragonscale and I'll make you a legend." } },
	{ Name = "Sir Aldric, Drill Master", Shirt = rgb(40, 60, 130), Pants = rgb(50, 50, 55), Hat = "Helmet", Post = Vector3.new(-8, 0, 76), LookAt = Vector3.new(0, 0, 76), Lines = { "Hit the dummies! Watch your damage per second!", "Shift to sprint, C to dodge. Use them!" } },
}

local folder: Folder

-- Appearance -------------------------------------------------------------------

local function attach(target: BasePart, part: BasePart, offset: CFrame)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = target.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
end

local function dress(model: Model, def: NpcDef)
	local head = model:FindFirstChild("Head") :: BasePart?
	local lowerTorso = model:FindFirstChild("LowerTorso") :: BasePart?
	local upperTorso = model:FindFirstChild("UpperTorso") :: BasePart?
	if not head or not lowerTorso or not upperTorso then
		return
	end

	-- Tunic hem over the hips and a belt
	local hem = Build.block(model, "Tunic", Vector3.new(lowerTorso.Size.X + 0.25, 1.1, lowerTorso.Size.Z + 0.25), CFrame.new(), def.Shirt, M.Fabric)
	attach(lowerTorso, hem, CFrame.new(0, -0.25, 0))
	local belt = Build.block(model, "Belt", Vector3.new(lowerTorso.Size.X + 0.3, 0.25, lowerTorso.Size.Z + 0.3), CFrame.new(), rgb(70, 45, 30), M.Leather)
	attach(lowerTorso, belt, CFrame.new(0, lowerTorso.Size.Y / 2, 0))

	if def.Apron then
		local apron = Build.block(model, "Apron", Vector3.new(1.4, 2, 0.1), CFrame.new(), rgb(235, 230, 220), M.Fabric)
		attach(upperTorso, apron, CFrame.new(0, -0.6, -upperTorso.Size.Z / 2 - 0.08))
	end

	local hatColor = def.HatColor or rgb(200, 170, 90)
	local top = head.Size.Y / 2
	if def.Hat == "Straw" then
		local brim = Build.cylinder(model, "HatBrim", head.Size.X * 2, 0.15, CFrame.new(), rgb(220, 190, 110), M.Fabric)
		attach(head, brim, CFrame.new(0, top - 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local crown = Build.cylinder(model, "HatCrown", head.Size.X * 0.9, 0.6, CFrame.new(), rgb(220, 190, 110), M.Fabric)
		attach(head, crown, CFrame.new(0, top + 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif def.Hat == "Hood" then
		local hood = Build.ball(model, "Hood", head.Size.X * 1.35, Vector3.zero, hatColor, M.Fabric)
		attach(head, hood, CFrame.new(0, 0.15, 0.18))
		local cape = Build.block(model, "Cape", Vector3.new(upperTorso.Size.X, upperTorso.Size.Y + 0.8, 0.15), CFrame.new(), hatColor, M.Fabric)
		attach(upperTorso, cape, CFrame.new(0, -0.3, upperTorso.Size.Z / 2 + 0.1))
	elseif def.Hat == "Cap" then
		local cap = Build.cylinder(model, "Cap", head.Size.X * 1.05, 0.5, CFrame.new(), hatColor, M.Fabric)
		attach(head, cap, CFrame.new(0, top - 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif def.Hat == "Feather" then
		local cap = Build.cylinder(model, "Cap", head.Size.X * 1.1, 0.45, CFrame.new(), hatColor, M.Fabric)
		attach(head, cap, CFrame.new(0, top, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local feather = Build.block(model, "Feather", Vector3.new(0.15, 1.4, 0.4), CFrame.new(), rgb(240, 240, 230), M.Fabric)
		attach(head, feather, CFrame.new(0.45, top + 0.6, 0.2) * CFrame.Angles(math.rad(-25), 0, math.rad(-15)))
	elseif def.Hat == "Helmet" then
		local helmet = Build.cylinder(model, "Helmet", head.Size.X * 1.15, head.Size.Y * 0.7, CFrame.new(), rgb(150, 150, 160), M.Metal)
		attach(head, helmet, CFrame.new(0, top - head.Size.Y * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local nose = Build.block(model, "NoseGuard", Vector3.new(0.2, 0.8, 0.15), CFrame.new(), rgb(150, 150, 160), M.Metal)
		attach(head, nose, CFrame.new(0, 0.05, -head.Size.Z / 2 - 0.08))
		local tabard = Build.block(model, "Tabard", Vector3.new(1.2, upperTorso.Size.Y + 1, 0.1), CFrame.new(), def.Shirt, M.Fabric)
		attach(upperTorso, tabard, CFrame.new(0, -0.4, -upperTorso.Size.Z / 2 - 0.08))
	end

	if def.Spear then
		local hand = model:FindFirstChild("RightHand") :: BasePart?
		if hand then
			local shaft = Build.block(model, "Spear", Vector3.new(0.25, 9, 0.25), CFrame.new(), rgb(110, 75, 45), M.Wood)
			attach(hand, shaft, CFrame.new(0, 1.5, 0))
			local tip = Build.block(model, "SpearTip", Vector3.new(0.15, 1.2, 0.5), CFrame.new(), rgb(190, 195, 205), M.Metal)
			attach(hand, tip, CFrame.new(0, 6.5, 0))
		end
	end
end

local function makeCharacter(def: NpcDef, index: number): Model?
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[(index % #SKIN) + 1]
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = def.Shirt
	description.LeftLegColor = def.Pants
	description.RightLegColor = def.Pants

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Townsfolk] Couldn't create a character:", model)
		return nil
	end
	model.Name = def.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = def.Name
	humanoid.NameDisplayDistance = 45
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = WALK_SPEED
	-- Don't let the default Animate script (if any) fight our animations; it can't run here anyway.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	dress(model, def)
	return model
end

-- Speech & animation -----------------------------------------------------------

local function speechBubble(head: BasePart): (string) -> ()
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 50
	gui.Enabled = false
	gui.Parent = head

	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = rgb(250, 245, 230)
	bubble.TextColor3 = rgb(40, 30, 20)
	bubble.Font = Enum.Font.Fantasy
	bubble.TextScaled = true
	bubble.TextWrapped = true
	bubble.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = bubble

	local token = 0
	return function(line: string)
		token += 1
		local myToken = token
		bubble.Text = line
		gui.Enabled = true
		task.delay(4, function()
			if token == myToken then
				gui.Enabled = false
			end
		end)
	end
end

local function setupAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local function load(id: string): AnimationTrack?
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		return if ok then track else nil
	end
	local idle, walk = load(IDLE_ANIMATION), load(WALK_ANIMATION)
	if idle then
		idle.Looped = true
		idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if not walk then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk.Looped = true
				walk:Play(0.2)
			end
			walk:AdjustSpeed(speed / 12)
		elseif walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)
end

-- Walking ----------------------------------------------------------------------------

local function waitForMove(humanoid: Humanoid, timeout: number)
	local done = false
	local connection = humanoid.MoveToFinished:Connect(function()
		done = true
	end)
	local elapsed = 0
	while not done and elapsed < timeout do
		elapsed += task.wait(0.1)
	end
	connection:Disconnect()
end

local function walkTo(humanoid: Humanoid, root: BasePart, goal: Vector3)
	local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 6 })
	local ok = pcall(function()
		path:ComputeAsync(root.Position, goal)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			humanoid:MoveTo(waypoint.Position)
			waitForMove(humanoid, 4)
		end
	else
		humanoid:MoveTo(goal)
		waitForMove(humanoid, 8)
	end
end

local function wander(model: Model, def: NpcDef, say: (string) -> (), rng: Random)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	while model.Parent and humanoid.Health > 0 do
		local goal = WAYPOINTS[rng:NextInteger(1, #WAYPOINTS)] + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		walkTo(humanoid, root, goal)
		if def.Lines and rng:NextNumber() < 0.45 then
			say(def.Lines[rng:NextInteger(1, #def.Lines)])
		end
		task.wait(rng:NextNumber(3, 9))
	end
end

local function standGuard(model: Model, def: NpcDef, say: (string) -> (), rng: Random)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	if not def.Lines then
		return
	end
	while model.Parent do
		task.wait(rng:NextNumber(12, 25))
		say(def.Lines[rng:NextInteger(1, #def.Lines)])
	end
end

function TownsfolkService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Townsfolk"
	folder.Parent = workspace

	for index, def in NPCS do
		task.spawn(function()
			local model = makeCharacter(def, index)
			if not model then
				return
			end
			local rng = Random.new(index * 7919)
			local start = def.Post or WAYPOINTS[rng:NextInteger(1, #WAYPOINTS)]
			local lookAt = def.LookAt or (start + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			local height = humanoid.HipHeight + (model:FindFirstChild("HumanoidRootPart") :: BasePart).Size.Y / 2
			local position = start + Vector3.new(0, height + 0.3, 0)
			model:PivotTo(CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)))
			model.Parent = folder

			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
			if not def.Post then
				root:SetNetworkOwner(nil)
			end
			setupAnimations(humanoid)
			local say = speechBubble(model:FindFirstChild("Head") :: BasePart)
			if def.Post then
				standGuard(model, def, say, rng)
			else
				wander(model, def, say, rng)
			end
		end)
	end
end

return TownsfolkService
