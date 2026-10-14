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

-- Card colours and button style per family (the mockup: green, orange, crystal blue).
type Look = { Card: Color3, Button: string, ButtonColor: Color3? }
local FAMILY_LOOK: { [string]: Look } = {
	Verdant = { Card = Color3.fromRGB(38, 92, 40), Button = "Primary" },
	Emberkin = { Card = Color3.fromRGB(110, 46, 20), Button = "Gold" },
	Crystalkin = { Card = Color3.fromRGB(24, 58, 104), Button = "Danger", ButtonColor = Color3.fromRGB(40, 190, 230) },
}

function StarterSelect.new(ctx: any)
	local root = Theme.Panel(ctx.Gui, {
		Name = "StarterSelect",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0.94, 0, 0.84, 0),
		Visible = false,
		ZIndex = 10,
	})
	Theme.Skin(root, "LargeFrame")
	Theme.Make("UISizeConstraint", { MaxSize = Vector2.new(820, 540) }, root)
	Theme.Padding(root, 22)
	local list = Theme.List(root, 6, nil, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Top

	-- Title on the banner
	local banner = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
	}, root)
	Theme.Skin(banner, "HeaderBanner")
	Theme.Text(banner, "Welcome to your empire!", 28, {
		FontFace = Theme.Title,
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeColor3 = Theme.Colors.TextShadow,
		TextStrokeTransparency = 0.2,
	})
	Theme.Text(root, "Choose a partner creature. You'll meet the other two soon.", 15, {
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	})

	local cards = Theme.Make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -82),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollBarThickness = 4,
		LayoutOrder = 3,
		Selectable = false,
	}, root)
	Theme.List(cards, 12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)

	local busy = false
	for index, speciesId in CreatureConfig.Starters do
		local species = CreatureConfig.Species[speciesId]
		local family = CreatureConfig.Families[species.Family]
		local rarity = RarityConfig.Get(species.Rarity)
		local look: Look = FAMILY_LOOK[species.Family] or { Card = Theme.Colors.PanelRaised, Button = "Primary" }
		local card = Theme.Make("Frame", {
			BackgroundColor3 = look.Card,
			Size = UDim2.fromOffset(236, 372),
			LayoutOrder = index,
		}, cards)
		Theme.Corner(card, 14)
		Theme.Stroke(card, family.Color, 0.1, 3)
		Theme.Gradient(card, 1, 0.55)
		Theme.Padding(card, 10)
		Theme.List(card, 5, nil, Enum.HorizontalAlignment.Center)
		local art = Theme.Make("Frame", {
			BackgroundColor3 = family.Color,
			BackgroundTransparency = 0.75,
			Size = UDim2.new(1, 0, 0, 120),
		}, card)
		Theme.Corner(art, 10)
		Viewport.Creature(art, speciesId, nil, { Spin = true })
		Theme.Text(card, species.Name, 22, {
			FontFace = Theme.Title,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = Theme.Colors.TextShadow,
			TextStrokeTransparency = 0.2,
		})
		local chips = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22) }, card)
		Theme.List(chips, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		Theme.Chip(chips, family.Glyph .. " " .. family.Name, family.Color, { TextSize = 12 })
		Theme.Chip(chips, RarityConfig.Label(species.Rarity), rarity.Color, { TextSize = 12 })
		Theme.Text(card, species.Description, 12, { TextXAlignment = Enum.TextXAlignment.Center })
		local best, bestValue = nil, 0
		for jobId, value in species.JobAffinity do
			if value > bestValue then
				best, bestValue = jobId, value
			end
		end
		Theme.Text(
			card,
			`<b>Best at:</b> {best and JobConfig[best].Name or "?"} · Farming {Format.Percent(
				species.JobAffinity.Farmer or 0
			)}`,
			12
		)
		Theme.Text(card, `<b>{species.Active.Name}:</b> {species.Active.Description}`, 11, {
			TextColor3 = Theme.Colors.Muted,
		})
		local choose = Theme.Button(card, "Choose " .. species.Name, look.Button :: any, {
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 15,
		})
		if look.ButtonColor then
			choose:SetAttribute("BaseColor", look.ButtonColor)
			choose.BackgroundColor3 = look.ButtonColor
		end
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
