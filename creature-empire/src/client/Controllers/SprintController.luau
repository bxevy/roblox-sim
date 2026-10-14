--!strict
-- Sprinting: hold Shift on a keyboard, press the left stick (L3) on a gamepad, or tap the
-- Run button on touch screens (the HUD calls Toggle). Only changes your own walk speed.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local SprintController = {}

local WALK_SPEED = 16
local SPRINT_SPEED = 26

local localPlayer = Players.LocalPlayer
local held = false -- Shift is down
local toggled = false -- gamepad / touch toggle

SprintController.OnChanged = function(_running: boolean) end

local function apply()
	local running = held or toggled
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if running then SPRINT_SPEED else WALK_SPEED
	end
	SprintController.OnChanged(running)
end

function SprintController.IsRunning(): boolean
	return held or toggled
end

function SprintController.Toggle()
	toggled = not toggled
	apply()
end

function SprintController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			held = true
			apply()
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			SprintController.Toggle()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			held = false
			apply()
		end
	end)
	-- A new character starts at the speed you were using.
	localPlayer.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		apply()
	end)
	if localPlayer.Character then
		apply()
	end
end

return SprintController
