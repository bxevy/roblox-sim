-- Background music that follows where you are (town, training grounds, each dungeon
-- theme, boss fights), and the lighting mood inside each dungeon theme.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local FADE = TweenInfo.new(1.5)
local TRAINING_BOUNDS = { MinX = -50, MaxX = 50, MinZ = 58, MaxZ = 150 }

-- Lighting per dungeon style (only changed on this player's screen).
local MOODS = {
	Crypt = { Ambient = Color3.fromRGB(60, 78, 66), OutdoorAmbient = Color3.fromRGB(40, 55, 45), Tint = Color3.fromRGB(205, 235, 210), Brightness = 1 },
	Temple = { Ambient = Color3.fromRGB(95, 80, 55), OutdoorAmbient = Color3.fromRGB(80, 65, 45), Tint = Color3.fromRGB(255, 235, 200), Brightness = 1.4 },
	Ice = { Ambient = Color3.fromRGB(75, 95, 125), OutdoorAmbient = Color3.fromRGB(70, 90, 120), Tint = Color3.fromRGB(210, 230, 255), Brightness = 1.4 },
	Forest = { Ambient = Color3.fromRGB(60, 75, 55), OutdoorAmbient = Color3.fromRGB(45, 60, 45), Tint = Color3.fromRGB(215, 235, 205), Brightness = 1.1 },
	Volcano = { Ambient = Color3.fromRGB(110, 60, 45), OutdoorAmbient = Color3.fromRGB(90, 45, 35), Tint = Color3.fromRGB(255, 215, 190), Brightness = 1.3 },
	Halloween = { Ambient = Color3.fromRGB(75, 50, 80), OutdoorAmbient = Color3.fromRGB(55, 35, 65), Tint = Color3.fromRGB(240, 215, 255), Brightness = 0.9 },
	Void = { Ambient = Color3.fromRGB(60, 45, 85), OutdoorAmbient = Color3.fromRGB(45, 30, 70), Tint = Color3.fromRGB(225, 205, 255), Brightness = 1 },
}

local Audio = {}

local tracks: { [string]: Sound } = {}
local current: string? = nil
local musicOn = true
local dungeon: { Style: string, Boss: boolean }? = nil
local townLighting = nil
local appliedMood: string? = nil

local function getTrack(key: string): Sound?
	local id = Config.Audio.Music[key]
	if not id then
		return nil
	end
	-- Keyed by sound id so areas sharing a track share one Sound.
	if not tracks[id] then
		local sound = Instance.new("Sound")
		sound.Name = `Music_{key}`
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		tracks[id] = sound
	end
	return tracks[id]
end

local function play(key: string)
	if key == current then
		return
	end
	-- Areas sharing the same track keep playing without restarting.
	local oldTrack = current and getTrack(current)
	local newTrack = getTrack(key)
	current = key
	if oldTrack == newTrack then
		return
	end
	if oldTrack then
		local fade = TweenService:Create(oldTrack, FADE, { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			if oldTrack ~= getTrack(current :: string) then
				oldTrack:Stop()
			end
		end)
	end
	if newTrack then
		if not newTrack.IsPlaying then
			newTrack:Play()
		end
		TweenService:Create(newTrack, FADE, { Volume = if musicOn then Config.Audio.MusicVolume else 0 }):Play()
	end
end

local function effect(className: string): Instance?
	return Lighting:FindFirstChildOfClass(className)
end

local function applyMood(style: string?)
	if style == appliedMood then
		return
	end
	appliedMood = style
	local colorCorrection = effect("ColorCorrectionEffect") :: ColorCorrectionEffect?
	if not townLighting then
		townLighting = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			Tint = if colorCorrection then colorCorrection.TintColor else Color3.new(1, 1, 1),
		}
	end
	local mood = (style and MOODS[style]) or townLighting
	TweenService:Create(Lighting, FADE, { Ambient = mood.Ambient, OutdoorAmbient = mood.OutdoorAmbient, Brightness = mood.Brightness }):Play()
	if colorCorrection then
		TweenService:Create(colorCorrection, FADE, { TintColor = mood.Tint }):Play()
	end
end

local function inTraining(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local p = root.Position
	local b = TRAINING_BOUNDS
	return p.X > b.MinX and p.X < b.MaxX and p.Z > b.MinZ and p.Z < b.MaxZ
end

local function update()
	if dungeon then
		applyMood(dungeon.Style)
		play(if dungeon.Boss then "Boss" else dungeon.Style)
	else
		applyMood(nil)
		play(if inTraining() then "Training" else "Town")
	end
end

-- Called with the info the server sends alongside the dungeon status text.
function Audio.SetDungeon(info: { Style: string, Boss: boolean }?)
	dungeon = info
	update()
end

function Audio.ToggleMusic(): boolean
	musicOn = not musicOn
	local track = current and getTrack(current)
	if track then
		TweenService:Create(track, TweenInfo.new(0.5), { Volume = if musicOn then Config.Audio.MusicVolume else 0 }):Play()
	end
	return musicOn
end

function Audio.Start()
	task.spawn(function()
		while true do
			update()
			task.wait(1)
		end
	end)
end

return Audio
