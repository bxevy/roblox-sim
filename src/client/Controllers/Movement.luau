-- Sprint (hold Shift) and dodge (C). The server tracks stamina and grants the brief
-- immunity; the dash itself is played here because the client moves its own character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Animator = require(script.Parent.Animator)

local player = Players.LocalPlayer

local Movement = {}

local lastDodge = 0
local playSfx: (string) -> () = function() end

function Movement.SetSprint(on: boolean)
	Remotes.SetSprint:FireServer(on)
end

function Movement.Dodge()
	local settings = Config.Movement
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - lastDodge < settings.DodgeCooldown or (player:GetAttribute("Stamina") or 0) < settings.DodgeCost then
		return
	end
	lastDodge = now
	Remotes.Dodge:FireServer()
	playSfx("Dodge")
	Animator.Play(character, "Dodge")

	-- Dash in the direction you're moving, or hop backwards if standing still.
	local direction = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	direction = direction.Unit

	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "DodgeAttachment"
		attachment.Parent = root
	end
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * settings.DodgeSpeed
	velocity.MaxForce = 1e6
	velocity.Parent = root

	-- Quick fade so it reads as a dodge
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0.5
		end
	end
	task.delay(settings.DodgeDuration, function()
		velocity:Destroy()
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
	end)
end

function Movement.Start(sfx: (string) -> ())
	playSfx = sfx
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			Movement.SetSprint(true)
		elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
			Movement.Dodge()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			Movement.SetSprint(false)
		end
	end)
end

return Movement
