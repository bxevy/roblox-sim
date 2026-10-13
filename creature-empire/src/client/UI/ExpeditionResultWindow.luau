--!strict
-- What happened on an expedition.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared.Config.ExpeditionConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local ExpeditionResultWindow = {}

function ExpeditionResultWindow.new(ctx: any)
	local win = Window.new(ctx.Gui, "Expedition report", "✈", Vector2.new(480, 520), ctx.Close)
	Theme.List(win.Body, 8)

	local function render(result: any)
		Window.Clear(win.Body)
		local destination = ExpeditionConfig.Destinations[result.Destination]
		win.SetTitle(destination and destination.Name or "Expedition report")
		Theme.Text(win.Body, if result.Success then "✔ <b>Success!</b>" else "✖ <b>The team turned back.</b>", 22, {
			TextColor3 = if result.Success then Theme.Colors.Success else Theme.Colors.Warning,
		})
		Theme.Text(
			win.Body,
			`Their chance was {math.floor(result.Chance * 100 + 0.5)}%.`
				.. (if result.Success then "" else " A failed trip still brings back a quarter of the loot."),
			13,
			{
				TextColor3 = Theme.Colors.Muted,
			}
		)
		local log = Window.Section(win.Body, "WHAT HAPPENED", 2)
		for _, text in result.Events do
			Theme.Text(log, "• " .. text, 14)
		end
		if #result.Events == 0 then
			Theme.Text(log, "• An uneventful trip.", 14, { TextColor3 = Theme.Colors.Muted })
		end
		local loot = Window.Section(win.Body, "BROUGHT HOME", 3)
		for resource, amount in result.Rewards do
			local def = ResourceConfig[resource]
			if amount > 0 then
				Theme.Text(loot, `{def and def.Icon or ""} {Format.Number(amount)} {def and def.Name or resource}`, 15)
			end
		end
		for _, speciesId in result.Joined do
			local species = CreatureConfig.Species[speciesId]
			Theme.Text(
				loot,
				`❦ {species and species.Name or speciesId} joined your empire!`,
				15,
				{ TextColor3 = Theme.Colors.Gold }
			)
		end
		if result.SiloFull then
			Theme.Text(loot, "Some materials didn't fit in your silo.", 13, { TextColor3 = Theme.Colors.Warning })
		end
		Theme.Text(
			win.Body,
			`Each creature gained {result.Xp} XP`
				.. (
					if result.RestSeconds > 0
						then ` and needs {Format.Duration(result.RestSeconds)} of rest before the next trip.`
						else ". Rations meant no rest needed."
				),
			13,
			{ TextColor3 = Theme.Colors.Muted, LayoutOrder = 4 }
		)
	end

	return {
		Root = win.Root,
		Open = function(result: any)
			render(result)
		end,
	}
end

return ExpeditionResultWindow
