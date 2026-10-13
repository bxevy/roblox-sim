--!strict
-- Plays sounds by key from AssetConfig.Sounds, with randomised pitch so repeated sounds
-- don't feel mechanical. Keys with no asset id are silently skipped. Volumes follow the
-- player's Music / Sfx settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AssetConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.AssetConfig)
local StateController = require(script.Parent.StateController)

local AudioController = {}

local sfxVolume = 0.8
local musicVolume = 0.5
local rng = Random.new()
local music: Sound? = nil
local pool: { Sound } = {}
local MAX_ACTIVE = 16

local function volumeFor(category: string): number
	return if category == "Music" or category == "Ambience" then musicVolume else sfxVolume
end

-- Plays `key`. With `position`, the sound plays in 3D at that point.
function AudioController.Play(key: string, position: Vector3?)
	local def = AssetConfig.Sounds[key]
	if not def or def.Id == "" then
		return
	end
	local volume = def.Volume * volumeFor(def.Category)
	if volume <= 0.001 or #pool >= MAX_ACTIVE then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = volume
	sound.PlaybackSpeed = rng:NextNumber(def.Pitch[1], def.Pitch[2])
	local holder: Instance = SoundService
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain
		sound.RollOffMaxDistance = 90
		sound.Parent = attachment
		holder = attachment
	else
		sound.Parent = SoundService
	end
	table.insert(pool, sound)
	sound.Ended:Once(function()
		local index = table.find(pool, sound)
		if index then
			table.remove(pool, index)
		end
		if holder ~= SoundService then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end)
	sound:Play()
	task.delay(10, function()
		-- Safety net for sounds that never fire Ended (failed loads).
		if sound.Parent then
			local index = table.find(pool, sound)
			if index then
				table.remove(pool, index)
			end
			if holder ~= SoundService then
				holder:Destroy()
			else
				sound:Destroy()
			end
		end
	end)
end

local function startMusic()
	local def = AssetConfig.Sounds.MusicEmpire
	if not def or def.Id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = def.Id
	sound.Looped = true
	sound.Volume = def.Volume * musicVolume
	sound.Parent = SoundService
	sound:Play()
	music = sound
end

function AudioController.Start()
	StateController.OnChanged("Settings", function(settings)
		sfxVolume = settings.Sfx
		musicVolume = settings.Music
		if music then
			music.Volume = AssetConfig.Sounds.MusicEmpire.Volume * musicVolume
		end
	end)
	startMusic()
end

return AudioController
