-- Quest log (J): the current story quest and today's 3 daily quests, with Claim buttons.

local Util = require(script.Parent.Util)

local QuestWindow = {}

local GOLD = Color3.fromRGB(255, 210, 80)

-- claim(kind, index) asks the server to hand out the reward.
function QuestWindow.new(gui: ScreenGui, claim: (kind: string, index: number?) -> ())
	local self: any = {}
	local quests = nil

	local window, body
	window, body = Util.window(gui, "Quests", Vector2.new(520, 520), function()
		window.Visible = false
	end)
	local list = Util.list(body)

	local function rewardText(reward): string
		local parts = {}
		if reward.XP then
			table.insert(parts, `{reward.XP} XP`)
		end
		if reward.Gold then
			table.insert(parts, `{reward.Gold} coins`)
		end
		if reward.SkillPoints then
			table.insert(parts, `{reward.SkillPoints} skill pt`)
		end
		return table.concat(parts, "  +  ")
	end

	local function questRow(order: number, quest, kind: string, accent: Color3)
		local done = quest.Progress >= quest.Target
		local row = Util.panel(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 96),
			BackgroundColor3 = Util.ButtonColor,
			BackgroundTransparency = 0,
		})
		Util.make("UIStroke", row, { Color = accent, Thickness = if done and not quest.Claimed then 2 else 0 })
		Util.text(row, {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -130, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = accent,
			Text = quest.Title,
		})
		Util.text(row, {
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -130, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			Text = quest.Description,
		})
		Util.text(row, {
			Position = UDim2.fromOffset(10, 52),
			Size = UDim2.new(1, -130, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = GOLD,
			Text = `Reward: {rewardText(quest.Reward)}`,
		})
		local barBack = Util.make("Frame", row, {
			Position = UDim2.fromOffset(10, 74),
			Size = UDim2.new(1, -130, 0, 14),
			BackgroundColor3 = Color3.fromRGB(25, 22, 30),
			BorderSizePixel = 0,
		})
		Util.corner(barBack, 6)
		local fill = Util.make("Frame", barBack, {
			Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Target, 0, 1), 1),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		})
		Util.corner(fill, 6)
		Util.text(barBack, { Size = UDim2.fromScale(1, 1), Text = `{math.floor(quest.Progress)} / {quest.Target}`, ZIndex = 2 })

		local button = Util.button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(100, 44),
			BackgroundColor3 = if quest.Claimed then Color3.fromRGB(70, 70, 70) elseif done then Color3.fromRGB(60, 150, 70) else Color3.fromRGB(70, 65, 80),
			AutoButtonColor = done and not quest.Claimed,
			Text = if quest.Claimed then "Claimed" elseif done then "Claim!" else "In progress",
			TextScaled = false,
			TextSize = 17,
		})
		button.Activated:Connect(function()
			if done and not quest.Claimed then
				claim(kind, quest.Index)
			end
		end)
	end

	function self.Render(newQuests)
		quests = newQuests or quests
		if not quests or not window.Visible then
			return
		end
		Util.clear(list)
		Util.text(list, { LayoutOrder = 0, Size = UDim2.new(1, -10, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 220, 140), Text = "Story" })
		if quests.Story then
			local story = table.clone(quests.Story)
			story.Title = `{story.Index}/{story.Count}: {story.Title}`
			questRow(1, story, "Story", Color3.fromRGB(255, 200, 90))
		else
			Util.text(list, { LayoutOrder = 1, Size = UDim2.new(1, -10, 0, 30), Text = "Every story quest complete. Legendary!", TextColor3 = Color3.fromRGB(200, 200, 210) })
		end
		local hours = math.floor(quests.ResetIn / 3600)
		local minutes = math.floor(quests.ResetIn % 3600 / 60)
		Util.text(list, {
			LayoutOrder = 2,
			Size = UDim2.new(1, -10, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(140, 200, 255),
			Text = `Daily quests  (new ones in {hours}h {minutes}m)`,
		})
		for i, daily in quests.Daily do
			questRow(2 + i, daily, "Daily", Color3.fromRGB(110, 190, 255))
		end
	end

	function self.Toggle()
		window.Visible = not window.Visible
		self.Render(nil)
	end

	function self.Open()
		window.Visible = true
		self.Render(nil)
	end

	return self
end

return QuestWindow
