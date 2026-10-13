--!strict
-- The "new creature!" reveal: light gathers, an orb shakes and cracks, then the creature
-- appears with its name, rarity and abilities. "Fast open" or reduced motion skips the
-- build-up. Several rewards in a row are queued.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)

local RevealOverlay = {}

function RevealOverlay.new(ctx: any)
	local State = ctx.Controllers.State
	local Audio = ctx.Controllers.Audio
	local queue: { any } = {}
	local showing = false

	local root = Theme.Make("Frame", {
		Name = "Reveal",
		BackgroundColor3 = Color3.fromRGB(6, 8, 16),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 60,
	}, ctx.Overlay)

	local glow = Theme.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.4,
		ZIndex = 61,
	}, root)
	Theme.Corner(glow, 999)
	local glowGradient = Theme.Make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	}, glow)
	local _ = glowGradient

	local orb = Theme.Make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = Color3.fromRGB(240, 230, 210),
		Text = "",
		ZIndex = 62,
	}, root)
	Theme.Corner(orb, 999)
	Theme.Stroke(orb, Color3.new(1, 1, 1), 0.2, 3)
	local crack = Theme.Make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		FontFace = Theme.Heavy,
		TextSize = 60,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		ZIndex = 63,
	}, orb)

	local portrait = Theme.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
		ZIndex = 62,
	}, root)
	local info = Theme.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 62,
	}, root)
	Theme.List(info, 6, nil, Enum.HorizontalAlignment.Center)

	local continueButton: TextButton

	local function clearInfo()
		for _, child in info:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		for _, child in portrait:GetChildren() do
			child:Destroy()
		end
	end

	local showNext: () -> ()

	local function finish()
		root.Visible = false
		showing = false
		if #queue > 0 then
			showNext()
		end
	end

	local function play(entry: any)
		local species = CreatureConfig.Species[entry.Species]
		if not species then
			finish()
			return
		end
		local rarity = RarityConfig.Get(species.Rarity)
		local family = CreatureConfig.Families[species.Family]
		local settings = State.Get("Settings") or {}
		local fast = settings.FastOpen or settings.ReducedMotion

		clearInfo()
		root.Visible = true
		portrait.Visible = false
		info.Visible = false
		orb.Visible = not fast
		glow.Visible = not fast
		crack.Text = ""
		orb.Size = UDim2.fromOffset(120, 120)
		orb.Rotation = 0

		if not fast then
			-- 1-2: the orb reacts and light gathers around it.
			orb.BackgroundColor3 = family.Color:Lerp(Color3.new(1, 1, 1), 0.6)
			glow.BackgroundColor3 = rarity.Color
			glow.Size = UDim2.fromOffset(40, 40)
			TweenService:Create(
				glow,
				TweenInfo.new(1.6, Enum.EasingStyle.Quad),
				{ Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 0.2 }
			):Play()
			for i = 1, 8 do
				local angle = if i % 2 == 0 then 12 else -12
				TweenService:Create(orb, TweenInfo.new(0.09), { Rotation = angle * (i / 8) }):Play()
				task.wait(0.1 + (8 - i) * 0.015)
			end
			-- 3: cracks and light.
			crack.Text = "✦"
			orb.Rotation = 0
			TweenService:Create(
				orb,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Size = UDim2.fromOffset(160, 160) }
			):Play()
			task.wait(0.35)
			Audio.Play("CreatureObtain")
			orb.Visible = false
			TweenService:Create(glow, TweenInfo.new(0.6), { BackgroundTransparency = 0.85 }):Play()
		else
			Audio.Play("CreatureObtain")
		end

		-- 4-5: the creature emerges with its details.
		portrait.Visible = true
		Viewport.Creature(portrait, entry.Species, nil, { Spin = true })
		Theme.PopIn(portrait)
		info.Visible = true
		if entry.NewDiscovery then
			Theme.Chip(info, "★ NEW DISCOVERY · added to your journal", Theme.Colors.Gold, { LayoutOrder = 0 })
		end
		Theme.Text(
			info,
			species.Name,
			40,
			{ FontFace = Theme.Heavy, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1 }
		)
		local chips =
			Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2 }, info)
		Theme.List(chips, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		Theme.Chip(chips, RarityConfig.Label(species.Rarity), rarity.Color)
		Theme.Chip(chips, family.Glyph .. " " .. family.Name, family.Color)
		Theme.Text(
			info,
			`<b>⚡ {species.Active.Name}</b> · {species.Active.Description}`,
			16,
			{ TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3 }
		)
		Theme.Text(
			info,
			`<b>✦ {species.Passive.Name}</b> · {species.Passive.Description}`,
			16,
			{ TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4 }
		)
		continueButton =
			Theme.Button(info, "Continue", "Primary", { Size = UDim2.fromOffset(200, 44), LayoutOrder = 5 })
		continueButton.Activated:Connect(finish)
		Theme.FocusFirst(info)
	end

	showNext = function()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local entry = table.remove(queue, 1)
		task.spawn(play, entry)
	end

	return {
		Show = function(entry: any)
			table.insert(queue, entry)
			showNext()
		end,
	}
end

return RevealOverlay
