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
	-- The kit's orange button is a dull brown-orange; the mockup's is bright, so these two
	-- are drawn (glossy, with a light rim) in the family colour.
	Emberkin = { Card = Color3.fromRGB(110, 46, 20), Button = "Danger", ButtonColor = Color3.fromRGB(245, 130, 25) },
	Crystalkin = {
		Card = Color3.fromRGB(24, 58, 104),
		Button = "Danger",
		ButtonColor = Color3.fromRGB(35, 185, 235),
	},
}

function StarterSelect.new(ctx: any)
	local root = Theme.Panel(ctx.Gui, {
		Name = "StarterSelect",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.94, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 10,
	})
	Theme.Skin(root, "LargeFrame")
	Theme.Make("UISizeConstraint", { MaxSize = Vector2.new(880, 640) }, root)
	-- Inside the frame's vines (drawn near full size, like the mockup).
	local rootPad = Theme.Padding(root, 44, 40)
	rootPad.PaddingBottom = UDim.new(0, 40)
	local list = Theme.List(root, 6, nil, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Top

	-- Title on the banner
	local banner = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
	}, root)
	-- No banner picture: like the mockup, the title sits under the frame's top ornament.
	local heading = Theme.Text(banner, "Welcome to your empire!", 32, {
		FontFace = Theme.Title,
		TextColor3 = Color3.fromRGB(255, 234, 176), -- warm cream, as in the mockup
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	Theme.Make("UIStroke", { Color = Color3.fromRGB(46, 24, 8), Thickness = 2.5 }, heading)
	Theme.Text(root, "Choose a partner creature. You'll meet the other two soon.", 15, {
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	})

	local cards = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, root)
	Theme.List(cards, 12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)

	local busy = false
	for index, speciesId in CreatureConfig.Starters do
		local species = CreatureConfig.Species[speciesId]
		local family = CreatureConfig.Families[species.Family]
		local rarity = RarityConfig.Get(species.Rarity)
		local look: Look = FAMILY_LOOK[species.Family] or { Card = Theme.Colors.PanelRaised, Button = "Primary" }
		-- The kit's wooden vine card frame (as in the mockup) with the family's colour glowing
		-- inside it. The shell holds the frame and the tint; the content stacks in its own
		-- frame, so the list layout never moves them.
		local shell = Theme.Make("ImageLabel", {
			Image = "",
			BackgroundColor3 = look.Card,
			Size = UDim2.fromOffset(252, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
		}, cards)
		Theme.Corner(shell, 12)
		Theme.Stroke(shell, family.Color, 0, 3)
		Theme.Gradient(shell, 1, 0.45)
		local framed = Theme.Skin(shell, "CardFrame", 0.6) ~= nil
		if framed then
			local tint = Theme.Make("Frame", {
				Name = "Tint",
				BackgroundColor3 = look.Card,
				BackgroundTransparency = 0.15,
				Position = UDim2.fromOffset(22, 22),
				Size = UDim2.new(1, -44, 1, -44),
				ZIndex = 0,
			}, shell)
			Theme.Corner(tint, 8)
			Theme.Gradient(tint, 1, 0.35)
		end
		local card = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, shell)
		Theme.Padding(card, if framed then 28 else 10, if framed then 28 else 10)
		Theme.List(card, 5, nil, Enum.HorizontalAlignment.Center)
		-- A glow in the family colour behind the creature.
		local art = Theme.Make("Frame", {
			BackgroundColor3 = family.Color,
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 0, 124),
		}, card)
		Theme.Gradient(art, 1, 0.35)
		Theme.Corner(art, 10)
		Viewport.Creature(art, speciesId, nil, { Spin = true })
		local nameLabel = Theme.Text(card, species.Name, 25, {
			FontFace = Theme.Heavy,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Theme.Make("UIStroke", { Color = Color3.fromRGB(30, 16, 6), Thickness = 2 }, nameLabel)
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
			Size = UDim2.new(1, 0, 0, 44),
			TextSize = 17,
			FontFace = Theme.Heavy,
		})
		if look.ButtonColor then
			-- Glossy pill: bright colour, lighter top, a pale glowing rim.
			choose:SetAttribute("BaseColor", look.ButtonColor)
			choose.BackgroundColor3 = look.ButtonColor
			local corner = choose:FindFirstChildOfClass("UICorner")
			if corner then
				corner.CornerRadius = UDim.new(0.5, 0)
			end
			local rim = choose:FindFirstChildOfClass("UIStroke")
			if rim then
				rim.Color = look.ButtonColor:Lerp(Color3.new(1, 1, 0.85), 0.6)
				rim.Transparency = 0
				rim.Thickness = 2.5
			end
			local shine = choose:FindFirstChildOfClass("UIGradient")
			if shine then
				shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.72))
			end
			choose.TextStrokeTransparency = 0.2
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
