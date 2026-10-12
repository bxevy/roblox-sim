-- Skills window: spend skill points on permanent upgrades. Opened at the Skill Sanctum in
-- the training grounds (upgrades only work there); viewable anywhere from the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local SkillsWindow = {}

function SkillsWindow.new(gui: ScreenGui, upgrade: (skillId: string) -> ())
	local self: any = {}
	local lastState = nil

	local window, body
	window, body = Util.window(gui, "Skills", Vector2.new(540, 560), function()
		window.Visible = false
	end)
	local pointsLabel = Util.text(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -54, 0, 14),
		Size = UDim2.fromOffset(200, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(200, 180, 255),
	})
	Util.text(body, {
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Color3.fromRGB(180, 180, 195),
		Text = "Earn 1 point per level (plus story quests and prestige). Train at the Skill Sanctum.",
	})
	local list = Util.list(body, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28) })

	function self.Render(state)
		lastState = state or lastState
		state = lastState
		if not state or not window.Visible then
			return
		end
		pointsLabel.Text = `{state.SkillPoints} skill point{if state.SkillPoints == 1 then "" else "s"}`
		Util.clear(list)
		for order, skillId in Config.SkillOrder do
			local skill = Config.Skills[skillId]
			local rank = state.Skills[skillId] or 0
			local maxed = rank >= skill.MaxRank
			local cost = Config.SkillCost(rank)
			local row = Util.panel(list, {
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, 50),
				BackgroundColor3 = Util.ButtonColor,
				BackgroundTransparency = 0,
			})
			Util.make("Frame", row, { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = skill.Color, BorderSizePixel = 0 })
			Util.text(row, {
				Position = UDim2.fromOffset(14, 4),
				Size = UDim2.new(0.45, -14, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = skill.Color,
				Text = `{skill.DisplayName}  {rank}/{skill.MaxRank}`,
			})
			Util.text(row, {
				Position = UDim2.fromOffset(14, 28),
				Size = UDim2.new(0.6, -14, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(210, 210, 220),
				Text = `{skill.Description} per rank`,
			})
			-- Rank pips
			for i = 1, skill.MaxRank do
				Util.make("Frame", row, {
					Position = UDim2.new(0.45, (i - 1) * 12, 0, 10),
					Size = UDim2.fromOffset(9, 9),
					BackgroundColor3 = if i <= rank then skill.Color else Color3.fromRGB(35, 32, 40),
					BorderSizePixel = 0,
				})
			end
			local affordable = not maxed and state.SkillPoints >= cost
			local button = Util.button(row, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(110, 36),
				BackgroundColor3 = if maxed then Color3.fromRGB(70, 70, 70) elseif affordable then Color3.fromRGB(110, 70, 190) else Color3.fromRGB(60, 55, 70),
				TextScaled = false,
				TextSize = 16,
				Text = if maxed then "MAX" else `Train ({cost} pt)`,
			})
			button.Activated:Connect(function()
				if not maxed then
					upgrade(skillId)
				end
			end)
		end
	end

	function self.Open()
		window.Visible = true
		self.Render(nil)
	end

	function self.Toggle()
		window.Visible = not window.Visible
		self.Render(nil)
	end

	return self
end

return SkillsWindow
