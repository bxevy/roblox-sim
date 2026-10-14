--!strict
-- The Spin Wheel window (opened at the wheel in the plaza): the wheel, the free-spin
-- timer, running boosts and every prize with its exact odds. The server picks the prize;
-- this window only turns the wheel to it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpinConfig = require(Shared.Config.SpinConfig)
local Spin = require(Shared.Util.Spin)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local SpinWindow = {}

local WHEEL = 280 -- pixels across
local RAYS = 10 -- strips per segment (they fan out to fill it)

local function percent(chance: number): string
	local value = chance * 100
	return if value < 1 then string.format("%.1f%%", value) else string.format("%.0f%%", value)
end

function SpinWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Spin Wheel", "●", Vector2.new(520, 640), ctx.Close)
	Theme.List(win.Body, 10, nil, Enum.HorizontalAlignment.Center)

	------------------------------------------------------------------ The wheel
	local holder = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WHEEL + 20, WHEEL + 30),
		LayoutOrder = 1,
	}, win.Body)
	local wheel = Theme.Make("Frame", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.fromOffset(WHEEL, WHEEL),
		BackgroundColor3 = Color3.fromRGB(240, 190, 70),
	}, holder)
	Theme.Corner(wheel, WHEEL)
	Theme.Stroke(wheel, Color3.fromRGB(120, 80, 20), 0, 3)

	-- A ray is a strip the height of the wheel, turned around the wheel's centre; only its
	-- top half is painted, so many rays fan out into a coloured slice.
	local function ray(angle: number, width: number, color: Color3, zIndex: number)
		local strip = Theme.Make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, width, 1, 0),
			BackgroundTransparency = 1,
			Rotation = angle,
			ZIndex = zIndex,
		}, wheel)
		Theme.Make("Frame", {
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0.5, -6),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = zIndex,
		}, strip)
	end

	local count = #SpinConfig.Prizes
	local slice = 360 / count
	local rayWidth = math.ceil(math.pi * WHEEL / (count * RAYS)) + 3
	for index, prize in SpinConfig.Prizes do
		local start = (index - 1) * slice
		for k = 0, RAYS - 1 do
			ray(start + (k + 0.5) * slice / RAYS, rayWidth, prize.Color, 2)
		end
		ray(start, 3, Color3.fromRGB(40, 30, 20), 3) -- divider
		-- The prize name, reading outwards along the middle of its slice.
		local spoke = Theme.Make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Rotation = start + slice / 2,
			ZIndex = 4,
		}, wheel)
		Theme.Text(spoke, prize.Short, if prize.Kind == "Creature" then 15 else 18, {
			FontFace = Theme.Heavy,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.17),
			Size = UDim2.fromOffset(90, 24),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if prize.Kind == "Creature" then Color3.fromRGB(255, 80, 90) else Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.3,
			TextWrapped = false,
			ZIndex = 4,
		})
	end
	-- Hub and pointer stay still while the wheel turns.
	local hub = Theme.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(240, 190, 70),
		ZIndex = 5,
	}, holder)
	Theme.Corner(hub, 46)
	Theme.Stroke(hub, Color3.fromRGB(120, 80, 20), 0, 3)
	Theme.Text(holder, "▼", 34, {
		FontFace = Theme.Heavy,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(40, 34),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(235, 60, 60),
		TextStrokeTransparency = 0.2,
		ZIndex = 6,
	})

	------------------------------------------------------------------ Button and result
	local button = Theme.Button(win.Body, "Spin!", "Gold", {
		Size = UDim2.fromOffset(260, 52),
		TextSize = 22,
		LayoutOrder = 2,
	})
	local result = Theme.Text(win.Body, "", 18, {
		FontFace = Theme.Heavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
	})
	local boosts = Theme.Text(win.Body, "", 15, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Gold,
		LayoutOrder = 4,
	})

	------------------------------------------------------------------ Odds
	local odds = Window.Section(win.Body, "PRIZES AND EXACT ODDS", 5)
	Theme.Text(
		odds,
		`One free spin every {math.floor(SpinConfig.FreeEvery / 60)} minutes. Spins are always free and never sold.`,
		14,
		{ TextColor3 = Theme.Colors.Muted }
	)
	for _, entry in Spin.Odds() do
		local prize = entry.Prize
		local extra = ""
		if prize.Kind == "Boost" and prize.Boost then
			extra = ` <font color="#{Theme.Colors.Muted:ToHex()}">({SpinConfig.Boosts[prize.Boost].Description})</font>`
		elseif prize.Kind == "Creature" then
			extra = ` <font color="#{Theme.Colors.Muted:ToHex()}">(❖ Mythic creature)</font>`
		end
		Theme.Text(
			odds,
			`<font color="#{prize.Color:Lerp(Color3.new(1, 1, 1), 0.25):ToHex()}">■</font> <b>{prize.Name}</b> · {percent(
				entry.Chance
			)}{extra}`,
			15
		)
	end

	------------------------------------------------------------------ Behaviour
	local spinning = false

	local function refresh()
		local spin = State.Get("Spin")
		local now = Workspace:GetServerTimeNow()
		local wait = Spin.FreeIn(spin and spin.NextFreeAt or 0, now)
		if not spinning then
			if wait > 0 then
				button.Text = `Next free spin in {Format.Duration(wait)}`
				Theme.SetEnabled(button, false)
			else
				button.Text = "Spin for free!"
				Theme.SetEnabled(button, true)
			end
		end
		local lines = {}
		for id, untilTime in spin and spin.Boosts or {} do
			local left = untilTime - now
			local boost = SpinConfig.Boosts[id]
			if boost and left > 0 then
				table.insert(lines, `{boost.Glyph} {boost.Name}: {Format.Duration(left)} left`)
			end
		end
		boosts.Text = table.concat(lines, "   ")
		boosts.Visible = #lines > 0
	end

	button.Activated:Connect(function()
		if spinning or button:GetAttribute("Disabled") then
			return
		end
		spinning = true
		button.Text = "Spinning…"
		Theme.SetEnabled(button, false)
		result.Text = ""
		local ok, data = ctx.Request("Spin")
		if not ok then
			spinning = false
			ctx.Notify(data, "Error")
			refresh()
			return
		end
		local index = data.Index :: number
		local prize = SpinConfig.Prizes[index]
		-- Turn so the prize's slice stops under the pointer, after a few full turns.
		local middle = (index - 0.5) * slice
		local current = wheel.Rotation % 360
		wheel.Rotation = current
		local wobble = (math.random() - 0.5) * slice * 0.6 -- land anywhere inside the slice
		local target = current + 360 * 5 + ((-middle - current) % 360) + wobble
		local seconds = if Theme.ReducedMotion then 1 else SpinConfig.AnimationSeconds
		TweenService
			:Create(
				wheel,
				TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Rotation = target }
			)
			:Play()
		task.delay(seconds, function()
			spinning = false
			result.Text = if prize.Kind == "Creature"
				then `<font color="#ff5060">❖ YOU WON THE {string.upper(prize.Name)}! ❖</font>`
				else `You won {prize.Name}!`
			ctx.Notify(`Spin Wheel: {prize.Name}!`, "Reward")
			ctx.Controllers.Audio.Play(if prize.Kind == "Creature" then "QuestComplete" else "Collect")
			refresh()
		end)
	end)

	State.OnChanged("Spin", refresh)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if ctx.IsOpen("Spin") then
				refresh()
			end
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			refresh()
		end,
	}
end

return SpinWindow
