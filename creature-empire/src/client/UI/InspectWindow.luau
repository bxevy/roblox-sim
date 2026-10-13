--!strict
-- Read-only view of another player's empire (visitors cannot change anything).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RarityConfig = require(Shared.Config.RarityConfig)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)
local Viewport = require(script.Parent.Viewport)

local InspectWindow = {}

function InspectWindow.new(ctx: any)
	local win = Window.new(ctx.Gui, "Empire", "⌕", Vector2.new(560, 520), ctx.Close)
	Theme.List(win.Body, 10)

	local function render(ownerUserId: number)
		Window.Clear(win.Body)
		Theme.Text(win.Body, "Loading…", 16)
		local ok, result = ctx.Request("InspectPlot", ownerUserId)
		Window.Clear(win.Body)
		if not ok then
			Theme.Text(win.Body, tostring(result), 16)
			return
		end
		win.SetTitle(result.Name .. "'s Empire")
		local summary = Window.Section(win.Body, nil, 1)
		Theme.Text(
			summary,
			`Empire tier <b>{result.CoreTier}</b> · {result.PlacedBuildings} buildings placed · {result.Discovered} species discovered`,
			16
		)
		Theme.Text(summary, "You're visiting. You can look around, but only the owner can build or manage here.", 13, {
			TextColor3 = Theme.Colors.Muted,
		})
		local creatures = Window.Section(win.Body, "CREATURES", 2)
		local grid = Theme.Make(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
			creatures
		)
		Theme.Make(
			"UIGridLayout",
			{ CellSize = UDim2.fromOffset(150, 150), CellPadding = UDim2.fromOffset(8, 8) },
			grid
		)
		for _, c in result.Creatures do
			local rarity = RarityConfig.Get(c.Rarity)
			local cell = Theme.Make("Frame", { BackgroundColor3 = Theme.Colors.PanelSunken }, grid)
			Theme.Corner(cell, 10)
			Theme.Stroke(cell, rarity.Color, 0.5)
			local art = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 100) }, cell)
			Viewport.Creature(art, c.Species)
			Theme.Text(cell, `<b>{c.Name}</b> Lv {c.Level}`, 14, {
				Position = UDim2.fromOffset(8, 102),
				Size = UDim2.new(1, -16, 0, 18),
				AutomaticSize = Enum.AutomaticSize.None,
			})
			Theme.Text(cell, RarityConfig.Label(c.Rarity), 12, {
				Position = UDim2.fromOffset(8, 122),
				Size = UDim2.new(1, -16, 0, 16),
				AutomaticSize = Enum.AutomaticSize.None,
				TextColor3 = rarity.Color,
			})
		end
	end

	return {
		Root = win.Root,
		Open = function(ownerUserId: any)
			task.spawn(render, ownerUserId)
		end,
	}
end

return InspectWindow
