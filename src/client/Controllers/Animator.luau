-- Plays the code-driven weapon animations from WeaponMoves on any character.
--
-- Each animation adds rotations on top of the character's joints (Motor6D C0), so it
-- layers over Roblox's own walk/idle animations and needs no uploaded assets. Joint
-- changes made here are only seen by this client: your own moves play the moment you
-- click, and the server tells us when other players attack (Remotes.PlayMove).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponMoves = require(ReplicatedStorage.Shared.WeaponMoves)

local BLEND_IN = 0.06
local BLEND_OUT = 0.14

-- Pose key -> joint names (R15 first, then R6)
local JOINTS = {
	RS = { "RightUpperArm.RightShoulder", "Torso.Right Shoulder" },
	LS = { "LeftUpperArm.LeftShoulder", "Torso.Left Shoulder" },
	RE = { "RightLowerArm.RightElbow" },
	LE = { "LeftLowerArm.LeftElbow" },
	W = { "UpperTorso.Waist" },
	N = { "Head.Neck", "Torso.Neck" },
	R = { "LowerTorso.Root", "HumanoidRootPart.RootJoint" },
}

local Animator = {}

type Playing = {
	Token: number,
	Motors: { [string]: Motor6D },
	Base: { [Motor6D]: CFrame },
}
local playing: { [Model]: Playing } = {}
local token = 0

local function findMotor(character: Model, paths: { string }): Motor6D?
	for _, path in paths do
		local partName, jointName = string.match(path, "^(.-)%.(.+)$")
		local part = character:FindFirstChild(partName :: string)
		local motor = part and part:FindFirstChild(jointName :: string)
		if motor and motor:IsA("Motor6D") then
			return motor
		end
	end
	return nil
end

local function easeInOut(t: number): number
	return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
end

-- The pose (degrees / studs per key) at time t (0..1) through the animation.
local function sample(anim: WeaponMoves.Animation, t: number): WeaponMoves.Pose
	local keys = anim.Keys
	if t <= keys[1].T then
		return keys[1].Pose
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.T then
			local alpha = easeInOut((t - a.T) / math.max(b.T - a.T, 1e-3))
			local pose = {}
			for name, value in a.Pose do
				pose[name] = value:Lerp(b.Pose[name] or Vector3.zero, alpha)
			end
			for name, value in b.Pose do
				if not a.Pose[name] then
					pose[name] = Vector3.zero:Lerp(value, alpha)
				end
			end
			return pose
		end
	end
	return keys[#keys].Pose
end

-- Rotation is around the parent part's axes at the joint, so the same numbers work for
-- R15 and R6 rigs.
local function applyPose(state: Playing, pose: WeaponMoves.Pose, weight: number)
	local offset = (pose.RP or Vector3.zero) * weight
	for key, motor in state.Motors do
		local base = state.Base[motor]
		local rotation = (pose[key] or Vector3.zero) * weight
		local rot = CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		local position = if key == "R" then base.Position + offset else base.Position
		motor.C0 = CFrame.new(position) * rot * base.Rotation
	end
end

local function restore(character: Model)
	local state = playing[character]
	if state then
		for motor, base in state.Base do
			if motor.Parent then
				motor.C0 = base
			end
		end
		playing[character] = nil
	end
end

function Animator.Play(character: Model?, animName: string?)
	local anim = animName and WeaponMoves.Animations[animName]
	if not character or not anim then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Starting a new move cancels the old one (back to the original joints first).
	restore(character)
	token += 1
	local state: Playing = { Token = token, Motors = {}, Base = {} }
	for key, paths in JOINTS do
		local motor = findMotor(character, paths)
		if motor then
			state.Motors[key] = motor
			state.Base[motor] = motor.C0
		end
	end
	playing[character] = state

	local started = os.clock()
	local total = BLEND_IN + anim.Duration + BLEND_OUT
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if playing[character] ~= state or not character.Parent then
			connection:Disconnect()
			return
		end
		local elapsed = os.clock() - started
		if elapsed >= total then
			connection:Disconnect()
			restore(character)
			return
		end
		if elapsed < BLEND_IN then
			applyPose(state, sample(anim, 0), elapsed / BLEND_IN)
		elseif elapsed < BLEND_IN + anim.Duration then
			applyPose(state, sample(anim, (elapsed - BLEND_IN) / anim.Duration), 1)
		else
			local fade = 1 - (elapsed - BLEND_IN - anim.Duration) / BLEND_OUT
			applyPose(state, sample(anim, 1), fade * fade)
		end
	end)
end

function Animator.Start()
	Remotes.PlayMove.OnClientEvent:Connect(function(character: Model?, animName: string?)
		Animator.Play(character, animName)
	end)
	-- Forget characters that leave (respawns, players leaving).
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			playing[player.Character] = nil
		end
	end)
end

return Animator
