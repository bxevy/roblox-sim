-- Admin menu: give yourself everything and other testing tools. Only shown to admins;
-- the server re-checks every action (see AdminService).

local Players = game:GetService("Players")

local Util = require(script.Parent.Util)

local AdminPanel = {}

-- run(action, arg?) sends the request and shows the result.
function AdminPanel.new(gui: ScreenGui, run: (action: string, arg: any) -> ())
	local self = {}

	local window, body
	window, body = Util.window(gui, "Admin Menu", Vector2.new(420, 680), function()
		window.Visible = false
	end)

	local giveAll = Util.button(body, {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Color3.fromRGB(200, 150, 40),
		Text = "GIVE ALL ITEMS",
	})
	giveAll.Activated:Connect(function()
		run("GiveAll")
	end)

	local grid = Util.make("Frame", body, {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 5 * 46),
		BackgroundTransparency = 1,
	})
	Util.make("UIGridLayout", grid, {
		CellSize = UDim2.new(0.5, -4, 0, 40),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local buttons = {
		{ "Max Potions", "MaxPotions" },
		{ "+10,000 Gold", "AddGold", 10000 },
		{ "Full Heal", "Heal" },
		{ "God Mode", "God" },
		{ "Clear Room", "KillRoom" },
		{ "Go to Town", "TeleportTown" },
		{ "Go to Training", "TeleportTraining" },
		{ "+10 Skill Points", "SkillPoints" },
		{ "Max Level (Prestige)", "SetLevel", 50 },
		{ "Free Class Roll", "FreeRoll" },
	}
	for order, entry in buttons do
		local button = Util.button(grid, { LayoutOrder = order, TextScaled = false, TextSize = 18, Text = entry[1] })
		button.Activated:Connect(function()
			run(entry[2], entry[3])
		end)
	end

	-- Text input rows: label, placeholder, action
	local function inputRow(y: number, placeholder: string, buttonText: string, action: string)
		local box = Util.make("TextBox", body, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(0.65, -4, 0, 40),
			BackgroundColor3 = Color3.fromRGB(45, 40, 55),
			TextColor3 = Color3.new(1, 1, 1),
			PlaceholderText = placeholder,
			PlaceholderColor3 = Color3.fromRGB(150, 150, 160),
			Font = Util.Font,
			TextSize = 18,
			Text = "",
			ClearTextOnFocus = false,
		})
		Util.corner(box, 8)
		local button = Util.button(body, {
			Position = UDim2.new(0.65, 4, 0, y),
			Size = UDim2.new(0.35, -4, 0, 40),
			BackgroundColor3 = Color3.fromRGB(60, 130, 70),
			TextScaled = false,
			TextSize = 18,
			Text = buttonText,
		})
		button.Activated:Connect(function()
			if box.Text ~= "" then
				run(action, box.Text)
			end
		end)
	end
	inputRow(66 + 5 * 46 + 8, "Level (1-50)", "Set Level", "SetLevel")
	inputRow(66 + 5 * 46 + 56, "Item id, e.g. Dragonfang", "Give Item", "GiveItem")
	inputRow(66 + 5 * 46 + 104, "Prestige (0-10)", "Set Prestige", "SetPrestige")
	inputRow(66 + 5 * 46 + 152, "Class, e.g. Assassin", "Set Class", "SetClass")

	-- Owner only: Creator Rank (level 999 / prestige 999)
	local creator = Util.button(body, {
		Position = UDim2.fromOffset(0, 66 + 5 * 46 + 200),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(170, 50, 160),
		Text = "CREATOR RANK (Lv 999 / Prestige 999)",
		Visible = false,
	})
	creator.Activated:Connect(function()
		run("CreatorRank")
	end)
	local player = Players.LocalPlayer
	local function updateOwner()
		creator.Visible = player:GetAttribute("IsOwner") == true
	end
	player:GetAttributeChangedSignal("IsOwner"):Connect(updateOwner)
	updateOwner()

	Util.text(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Color3.fromRGB(170, 170, 180),
		Text = "Chat: /giveall  /level 20  /gold 5000  /give Dragonfang",
	})

	function self.Toggle()
		window.Visible = not window.Visible
	end

	return self
end

return AdminPanel
