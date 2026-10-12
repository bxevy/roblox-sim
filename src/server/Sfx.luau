-- Plays sound effects from Config.Audio.Sfx in the world, so everyone nearby hears them.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Sfx = {}

-- `at` is a part to attach the sound to, or a world position.
function Sfx.play(name: string, at: BasePart | Vector3, volumeScale: number?)
	local def = Config.Audio.Sfx[name]
	if not def then
		return
	end
	local parent: Instance
	if typeof(at) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = at
		attachment.Parent = workspace.Terrain
		Debris:AddItem(attachment, 4)
		parent = attachment
	else
		parent = at
	end

	local sound = Instance.new("Sound")
	sound.SoundId = def[1]
	sound.Volume = def[2] * (volumeScale or 1)
	sound.PlaybackSpeed = def[3] * (0.95 + math.random() * 0.1)
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sfx
