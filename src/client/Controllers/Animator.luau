-- Plays the code-driven animations from WeaponMoves on any character, and smooth
-- client-side movement for leaps and dashes.
--
-- Each animation adds rotations on top of the character's joints (Motor6D C0, or the
-- attachment of an AnimationConstraint joint), so it layers over Roblox's own walk/idle
-- animations and needs no uploaded assets. Joint changes made here are only seen by this
-- client: your own moves play the moment you act, and the server tells us when other
-- players act (Remotes.PlayMove).
--
-- Smoothness:
--   * keyframes are joined with Catmull-Rom splines, so joints keep their speed through
--     each key instead of stopping and starting;
--   * rotations blend as quaternions (CFrame:Lerp), always taking the short way round;
--   * a new move cross-fades out of whatever pose the old one was in, and every move eases
--     back to the rest pose at the end.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponMoves = require(ReplicatedStorage.Shared.WeaponMoves)

local BLEND_IN = 0.09
local BLEND_OUT = 0.2

-- Pose key -> the body part each joint moves (R15 first, then R6). Joints are found by the
-- part they drive, so this works with classic Motor6D joints and with the newer
-- AnimationConstraint joints (Roblox's avatar joint upgrade).
local JOINT_PARTS = {
	RS = { "RightUpperArm", "Right Arm" },
	LS = { "LeftUpperArm", "Left Arm" },
	RE = { "RightLowerArm" },
	LE = { "LeftLowerArm" },
	W = { "UpperTorso" },
	N = { "Head" },
	R = { "LowerTorso", "Torso" },
}

local Animator = {}

-- A joint we can offset: Motor6D.C0, or an AnimationConstraint's first attachment
-- (which plays the same role as C0).
type Joint = { Get: () -> CFrame, Set: (CFrame) -> () }

type Rig = {
	Character: Model,
	Joints: { [string]: Joint },
	Base: { [string]: CFrame },
	Offsets: { [string]: CFrame }, -- what's applied right now (relative to Base)
	BlendFrom: { [string]: CFrame },
	Anim: WeaponMoves.Animation?,
	Started: number,
	Speed: number,
}

local rigs: { [Model]: Rig } = {}
local warned = false

local function findJoint(character: Model, partNames: { string }): Joint?
	for _, partName in partNames do
		local part = character:FindFirstChild(partName)
		if part then
			for _, inst in character:GetDescendants() do
				if inst:IsA("Motor6D") and inst.Part1 == part then
					local motor = inst
					return {
						Get = function()
							return motor.C0
						end,
						Set = function(cf)
							motor.C0 = cf
						end,
					}
				elseif inst:IsA("AnimationConstraint") and inst.Attachment1 and inst.Attachment1.Parent == part and inst.Attachment0 then
					local attachment = inst.Attachment0 :: Attachment
					return {
						Get = function()
							return attachment.CFrame
						end,
						Set = function(cf)
							attachment.CFrame = cf
						end,
					}
				end
			end
		end
	end
	return nil
end

local function getRig(character: Model): Rig?
	local rig = rigs[character]
	if rig then
		return rig
	end
	local joints, base, offsets = {}, {}, {}
	local found = false
	for key, parts in JOINT_PARTS do
		local joint = findJoint(character, parts)
		if joint then
			joints[key] = joint
			base[key] = joint.Get()
			offsets[key] = CFrame.identity
			found = true
		end
	end
	if not found then
		if not warned then
			warned = true
			warn("[Animator] No character joints found; weapon animations can't play")
		end
		return nil
	end
	rig = {
		Character = character,
		Joints = joints,
		Base = base,
		Offsets = offsets,
		BlendFrom = {},
		Anim = nil,
		Started = 0,
		Speed = 1,
	}
	rigs[character] = rig
	return rig
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Catmull-Rom between p1 and p2 (p0 and p3 are the neighbours), u in 0..1.
local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: number): Vector3
	local u2, u3 = u * u, u * u * u
	return 0.5 * ((2 * p1) + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (3 * p1 - p0 - 3 * p2 + p3) * u3)
end

local function keyValue(anim: WeaponMoves.Animation, index: number, joint: string): Vector3
	local keys = anim.Keys
	local key = keys[math.clamp(index, 1, #keys)]
	return key.Pose[joint] or Vector3.zero
end

-- Degrees (or studs, for RP) of one joint at time t (0..1).
local function sampleJoint(anim: WeaponMoves.Animation, joint: string, t: number): Vector3
	local keys = anim.Keys
	if t <= keys[1].T then
		return keyValue(anim, 1, joint)
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.T then
			local u = (t - a.T) / math.max(b.T - a.T, 1e-3)
			return catmull(keyValue(anim, i - 1, joint), keyValue(anim, i, joint), keyValue(anim, i + 1, joint), keyValue(anim, i + 2, joint), u)
		end
	end
	return keyValue(anim, #keys, joint)
end

local function offsetFor(anim: WeaponMoves.Animation, key: string, t: number): CFrame
	local degrees = sampleJoint(anim, key, t)
	local rotation = CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
	if key == "R" then
		return CFrame.new(sampleJoint(anim, "RP", t)) * rotation
	end
	return rotation
end

-- Rotation is around the parent part's axes at the joint, so the same numbers work for
-- R15 and R6 rigs.
local function apply(rig: Rig)
	for key, joint in rig.Joints do
		local base = rig.Base[key]
		local offset = rig.Offsets[key]
		joint.Set(CFrame.new(base.Position + offset.Position) * offset.Rotation * base.Rotation)
	end
end

local function step(rig: Rig, now: number)
	local anim = rig.Anim
	if not anim then
		return
	end
	local elapsed = (now - rig.Started) * rig.Speed
	local duration = anim.Duration
	if elapsed >= duration + BLEND_OUT then
		for key in rig.Joints do
			rig.Offsets[key] = CFrame.identity
		end
		rig.Anim = nil
		apply(rig)
		return
	end
	for key in rig.Joints do
		local offset
		if elapsed < duration then
			offset = offsetFor(anim, key, elapsed / duration)
			if elapsed < BLEND_IN then
				-- Cross-fade out of whatever pose we were in
				offset = (rig.BlendFrom[key] or CFrame.identity):Lerp(offset, smoothstep(elapsed / BLEND_IN))
			end
		else
			-- Ease back to rest
			offset = offsetFor(anim, key, 1):Lerp(CFrame.identity, smoothstep((elapsed - duration) / BLEND_OUT))
		end
		rig.Offsets[key] = offset
	end
	apply(rig)
end

-- `speed` stretches or squeezes the move (1 = as authored).
function Animator.Play(character: Model?, animName: string?, speed: number?)
	local anim = animName and WeaponMoves.Animations[animName]
	if not character or not anim then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local rig = getRig(character)
	if not rig then
		return
	end
	for key, offset in rig.Offsets do
		rig.BlendFrom[key] = offset
	end
	rig.Anim = anim
	rig.Started = os.clock()
	rig.Speed = speed or 1
end

-- Smooth movement of your own character (the server tells us where to go when an
-- ability leaps or dashes; your client owns your character's physics, so moving it here
-- looks smooth for everyone).
--   motion = { Kind = "Leap" | "Dash", Target = Vector3, Height = number?, Duration = number }
function Animator.Move(motion: { [string]: any }?)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not motion or not root or typeof(motion.Target) ~= "Vector3" then
		return
	end
	local start = root.Position
	local target = Vector3.new(motion.Target.X, start.Y, motion.Target.Z)
	local flat = target - start
	local facing = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	local height = if motion.Kind == "Leap" then motion.Height or 10 else 0
	local duration = math.max(motion.Duration or 0.3, 0.05)
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			connection:Disconnect()
			return
		end
		local t = math.min((os.clock() - began) / duration, 1)
		-- Dashes ease out; leaps move evenly across with a smooth arc
		local along = if motion.Kind == "Dash" then 1 - (1 - t) ^ 3 else smoothstep(t) * 0.3 + t * 0.7
		local position = start:Lerp(target, along) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
		root.CFrame = CFrame.lookAt(position, position + facing)
		root.AssemblyLinearVelocity = Vector3.zero
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

function Animator.Start()
	Remotes.PlayMove.OnClientEvent:Connect(function(character: Model?, animName: string?)
		Animator.Play(character, animName)
	end)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for character, rig in rigs do
			if not character.Parent then
				rigs[character] = nil
			else
				step(rig, now)
			end
		end
	end)
	-- Forget characters that leave (respawns, players leaving).
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			rigs[player.Character] = nil
		end
	end)
end

return Animator
