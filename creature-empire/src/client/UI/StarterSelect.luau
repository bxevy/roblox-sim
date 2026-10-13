--!strict
-- First-time choice of a starter creature. Modal: it stays until a choice is made.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local JobConfig = require(Shared.Config.JobConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)

local StarterSelect = {}

function StarterSelect.new(ctx: any)
	local root = Theme.Panel(ctx.Gui, {
		Name = "StarterSelect",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.96, 0, 0.9, 0),
		Visible = false,
		ZIndex = 10,
	})
	Theme.Make("UISizeConstraint", { MaxSize = Vector2.new(960, 560) }, root)
	Theme.Padding(root, 18)
	local list = Theme.List(root, 12, nil, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Top

	Theme.Text(
		root,
		"Welcome to your empire!",
		30,
		{ FontFace = Theme.Heavy, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1 }
	)
	Theme.Text(root, "Choose a partner creature. You'll meet the other two soon.", 17, {
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	})

	local cards = Theme.Make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -110),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollBarThickness = 4,
		LayoutOrder = 3,
		Selectable = false,
	}, root)
	Theme.List(cards, 14, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)

	local busy = false
	for index, speciesId in CreatureConfig.Starters do
		local species = CreatureConfig.Species[speciesId]
		local family = CreatureConfig.Families[species.Family]
		local rarity = RarityConfig.Get(species.Rarity)
		local card = Theme.Make("Frame", {
			BackgroundColor3 = Theme.Colors.PanelRaised,
			BackgroundTransparency = 0.2,
			Size = UDim2.fromOffset(290, 400),
			LayoutOrder = index,
		}, cards)
		Theme.Corner(card)
		Theme.Stroke(card, family.Color, 0.45, 2)
		Theme.Padding(card, 12)
		Theme.List(card, 6)
		local art =
			Theme.Make("Frame", { BackgroundColor3 = Theme.Colors.PanelSunken, Size = UDim2.new(1, 0, 0, 150) }, card)
		Theme.Corner(art, 10)
		Viewport.Creature(art, speciesId, nil, { Spin = true })
		Theme.Text(card, species.Name, 24, { FontFace = Theme.Heavy })
		local chips = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24) }, card)
		Theme.List(chips, 6, Enum.FillDirection.Horizontal)
		Theme.Chip(chips, family.Glyph .. " " .. family.Name, family.Color)
		Theme.Chip(chips, RarityConfig.Label(species.Rarity), rarity.Color)
		Theme.Text(card, species.Description, 14, { TextColor3 = Theme.Colors.Muted })
		local best, bestValue = nil, 0
		for jobId, value in species.JobAffinity do
			if value > bestValue then
				best, bestValue = jobId, value
			end
		end
		Theme.Text(
			card,
			`<b>Best at:</b> {best and JobConfig[best].Name or "?"} · <b>Farming:</b> {Format.Percent(
				species.JobAffinity.Farmer or 0
			)}`,
			14
		)
		Theme.Text(card, `<b>⚡ {species.Active.Name}:</b> {species.Active.Description}`, 13)
		local choose = Theme.Button(card, "Choose " .. species.Name, "Primary", { Size = UDim2.new(1, 0, 0, 42) })
		choose.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, result = ctx.Request("ChooseStarter", speciesId)
			busy = false
			if not ok then
				ctx.Notify(result, "Error")
			end
		end)
	end

	return {
		Root = root,
		Modal = true,
		Open = function() end,
	}
end

return StarterSelect
