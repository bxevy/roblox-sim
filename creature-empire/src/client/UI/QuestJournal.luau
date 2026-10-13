--!strict
-- Quest journal: the whole onboarding questline with what's done and what's next.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local QuestJournal = {}

local function rewardText(reward: any): string
	local parts = {}
	if reward.Gold then
		table.insert(parts, Format.Number(reward.Gold) .. " gold")
	end
	if reward.Essence then
		table.insert(parts, Format.Number(reward.Essence) .. " essence")
	end
	if reward.Creature == "NextStarter" then
		table.insert(parts, "a new creature friend")
	elseif reward.Creature then
		local species = CreatureConfig.Species[reward.Creature]
		table.insert(parts, species and species.Name or reward.Creature)
	end
	return if #parts > 0 then table.concat(parts, " + ") else "—"
end

function QuestJournal.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Quests", "✎", Vector2.new(560, 560), ctx.Close)
	Theme.List(win.Body, 8)

	local function render()
		Window.Clear(win.Body)
		local q = State.Get("Quests")
		local index = q and q.Index or 1
		Theme.Text(win.Body, "<b>Founding the empire</b> · your first steps", 17, { LayoutOrder = 0 })
		for i, step in QuestConfig.Tutorial do
			local done = i < index
			local currentStep = i == index
			local card = Window.Section(win.Body, nil, i)
			local glyph = if done then "✔" elseif currentStep then "▶" else "○"
			local color = if done
				then Theme.Colors.Success
				elseif currentStep then Theme.Colors.Primary
				else Theme.Colors.Muted
			Theme.Text(card, `<font color="#{color:ToHex()}">{glyph}</font>  <b>{step.Title}</b>`, 16)
			if currentStep or done then
				Theme.Text(card, step.Description, 14, { TextColor3 = Theme.Colors.Muted })
			end
			Theme.Text(card, "Reward: " .. rewardText(step.Reward), 13, { TextColor3 = Theme.Colors.Gold })
			if currentStep and q then
				local _, set = Theme.Bar(card, Theme.Colors.Primary, 6)
				set(q.Progress / step.Amount)
			end
		end
		if index > #QuestConfig.Tutorial then
			Theme.Text(
				win.Body,
				"You've founded your empire! Daily and weekly objectives arrive in a later update.",
				15,
				{
					TextColor3 = Theme.Colors.Success,
					LayoutOrder = 999,
				}
			)
		end
	end

	State.OnChanged("Quests", function()
		if ctx.IsOpen("Quests") then
			render()
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			render()
		end,
	}
end

return QuestJournal
