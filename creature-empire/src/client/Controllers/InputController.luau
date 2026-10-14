--!strict
-- Keyboard and gamepad shortcuts for the interface. Touch players use the on-screen
-- buttons; every action here also has a button.
--   C / D-pad up      Creatures
--   B / D-pad left    Build
--   J / D-pad right   Quests
--   P / D-pad down    Settings
--   G                 Inventory
--   M                 World map
--   U                 Players (visit, trade, collaborators)
--   L                 Leaderboards
--   K                 Shop
--   Shift / L3        sprint (SprintController)
--   B (gamepad)       close the open window

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local InputController = {}

function InputController.Start(ui: any, placement: any)
	local bindings = {
		[Enum.KeyCode.C] = "Creatures",
		[Enum.KeyCode.B] = "Build",
		[Enum.KeyCode.J] = "Quests",
		[Enum.KeyCode.P] = "Settings",
		[Enum.KeyCode.G] = "Inventory",
		[Enum.KeyCode.M] = "Map",
		[Enum.KeyCode.U] = "Players",
		[Enum.KeyCode.L] = "Leaderboards",
		[Enum.KeyCode.K] = "Shop",
		[Enum.KeyCode.DPadUp] = "Creatures",
		[Enum.KeyCode.DPadLeft] = "Build",
		[Enum.KeyCode.DPadRight] = "Quests",
		[Enum.KeyCode.DPadDown] = "Settings",
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or placement.IsActive() then
			return
		end
		local window = bindings[input.KeyCode]
		if window then
			ui.Toggle(window)
		end
	end)

	-- Gamepad B closes windows (only while one is open, so it doesn't steal B otherwise).
	local bound = false
	task.spawn(function()
		while true do
			task.wait(0.2)
			local open = ui.Current() ~= nil
			if open and not bound then
				bound = true
				ContextActionService:BindActionAtPriority("CE_CloseWindow", function(_, state)
					if state == Enum.UserInputState.Begin then
						ui.Close()
					end
					return Enum.ContextActionResult.Sink
				end, false, 2000, Enum.KeyCode.ButtonB)
			elseif not open and bound then
				bound = false
				ContextActionService:UnbindAction("CE_CloseWindow")
			end
		end
	end)
end

return InputController
