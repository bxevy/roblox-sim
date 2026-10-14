--!strict
-- The Spin Wheel window (opened at the wheel in the plaza): the wheel, the free-spin
-- timer, running boosts and every prize with its exact odds. The server picks the prize;
-- this window only turns the wheel to it.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SpinConfig = require(Shared.Config.SpinConfig)
local AssetConfig = require(Shared.Config.AssetConfig)
local Spin = require(Shared.Util.Spin)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local SpinWindow = {}

-- What the behaviour needs from a look (drawn or the creator's art).
type Parts = {
	Root: GuiObject,
	Wheel: GuiObject, -- turned to the prize
	Free: GuiButton,
	Buy: GuiButton,
	ShowFree: (ready: boolean, label: string) -> (),
	ShowBuy: (visible: boolean, enabled: boolean, price: number) -> (),
	ShowResult: (text: string, prize: SpinConfig.Prize?) -> (),
	ShowBoosts: (text: string) -> (),
	ShowNote: (text: string) -> (),
}

local WHEEL = 300 -- pixels across
local RAYS = 10 -- strips per segment (they fan out to fill it)
-- The frame picture is this much wider than the face picture (both are cut from the same
-- art, see art/ and docs/ASSETS.md), so it is drawn bigger to line up around the face.
local FRAME_SCALE = 1.334

local function percent(chance: number): string
	local value = chance * 100
	-- Exact: whole numbers as "32%", the rest with one decimal ("2.5%", "0.5%").
	return if math.abs(value - math.round(value)) < 0.001
		then string.format("%.0f%%", value)
		else string.format("%.1f%%", value)
end

-- Shows an uploaded picture. Image ids load directly; a Decal id doesn't, so if it fails
-- to load, fall back to the asset's thumbnail (which works for both).
local function showImage(label: ImageLabel, id: number)
	local content = `rbxassetid://{id}`
	label.Image = content
	task.spawn(function()
		ContentProvider:PreloadAsync({ content }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success and label.Parent then
				label.Image = `rbxthumb://type=Asset&id={id}&w=420&h=420`
			end
		end)
	end)
end

-- The drawn window (fallback when the creator's Spin Wheel pictures can't load).
local function buildDrawn(ctx: any): Parts
	local win = Window.new(ctx.Gui, "Spin Wheel", "●", Vector2.new(540, 680), ctx.Close)
	Theme.List(win.Body, 10, nil, Enum.HorizontalAlignment.Center)

	------------------------------------------------------------------ The wheel
	local faceId = AssetConfig.CreatorImages.SpinWheelFace
	local frameId = AssetConfig.CreatorImages.SpinWheelFrame
	local face = if faceId then `rbxassetid://{faceId}` else ""
	local frameArt = if frameId then `rbxassetid://{frameId}` else ""
	local holder = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = if frameArt ~= ""
			then UDim2.fromOffset(WHEEL * FRAME_SCALE, WHEEL * FRAME_SCALE)
			else UDim2.fromOffset(WHEEL + 40, WHEEL + 40),
		LayoutOrder = 1,
	}, win.Body)
	local wheel = Theme.Make("Frame", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, if frameArt ~= "" then 0 else 6),
		Size = UDim2.fromOffset(WHEEL, WHEEL),
		BackgroundColor3 = Color3.fromRGB(250, 200, 60),
		BackgroundTransparency = if face ~= "" then 1 else 0,
	}, holder)
	Theme.Corner(wheel, WHEEL)

	local count = #SpinConfig.Prizes
	local slice = 360 / count
	if face ~= "" then
		-- The creator's wheel picture turns as one piece.
		showImage(
			Theme.Make("ImageLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}, wheel),
			faceId :: number
		)
	else
		Theme.Stroke(wheel, Color3.fromRGB(110, 70, 30), 0, 5)
		-- A ray is a strip the height of the wheel, turned around the wheel's centre; only
		-- its top half is painted, so many rays fan out into a coloured slice.
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
				Position = UDim2.fromOffset(0, 9),
				Size = UDim2.new(1, 0, 0.5, -9),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = zIndex,
			}, strip)
			return strip
		end
		local rayWidth = math.ceil(math.pi * WHEEL / (count * RAYS)) + 3
		for index, prize in SpinConfig.Prizes do
			local start = (index - 1) * slice + SpinConfig.WheelOffset
			for k = 0, RAYS - 1 do
				ray(start + (k + 0.5) * slice / RAYS, rayWidth, prize.Color, 2)
			end
			ray(start, 4, Color3.fromRGB(90, 55, 25), 3) -- divider
			-- The prize, two lines reading outwards along the middle of its slice.
			local spoke = Theme.Make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Rotation = start + slice / 2,
				ZIndex = 4,
			}, wheel)
			local dragon = prize.Kind == "Creature"
			Theme.Text(spoke, prize.Short, if dragon then 15 else 19, {
				FontFace = Theme.Heavy,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.fromOffset(92, 44),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				LineHeight = 0.9,
				TextColor3 = if dragon then Color3.fromRGB(200, 120, 255) else Color3.new(1, 1, 1),
				TextStrokeColor3 = Color3.fromRGB(40, 25, 10),
				TextStrokeTransparency = 0,
				ZIndex = 4,
			})
		end
	end
	if frameArt ~= "" then
		-- The creator's frame (rim, vines, centre flower and pointer) stays still on top.
		showImage(
			Theme.Make("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 5,
			}, holder),
			frameId :: number
		)
	else
		-- Hub stays still while the wheel turns.
		local hub = Theme.Make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 6),
			Size = UDim2.fromOffset(54, 54),
			BackgroundColor3 = Color3.fromRGB(250, 205, 70),
			ZIndex = 5,
		}, holder)
		Theme.Corner(hub, 54)
		Theme.Stroke(hub, Color3.fromRGB(110, 70, 30), 0, 4)
		Theme.Gradient(hub, 1, 0.75)
	end
	Theme.Text(holder, "▼", 40, {
		Visible = frameArt == "", -- the frame art has its own pointer
		FontFace = Theme.Heavy,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(44, 40),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(235, 60, 60),
		TextStrokeColor3 = Color3.fromRGB(60, 10, 10),
		TextStrokeTransparency = 0,
		ZIndex = 6,
	})

	------------------------------------------------------------------ Button and result
	local button = Theme.Button(win.Body, "Spin!", "Gold", {
		Size = UDim2.fromOffset(260, 52),
		TextSize = 22,
		LayoutOrder = 2,
	})
	-- An extra spin for Robux: shown only where Roblox allows paid random items (the server
	-- says so in the Spin state), always right above the exact odds.
	local buy = Theme.Button(win.Body, "Spin for 199 Robux", "Primary", {
		Size = UDim2.fromOffset(260, 46),
		TextSize = 19,
		LayoutOrder = 2,
		Visible = false,
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
	local oddsNote = Theme.Text(
		odds,
		`One free spin every {math.floor(SpinConfig.FreeEvery / 60)} minutes.`,
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

	return {
		Root = win.Root,
		Wheel = wheel,
		Free = button,
		Buy = buy,
		ShowFree = function(ready: boolean, label: string)
			button.Text = label
			Theme.SetEnabled(button, ready)
		end,
		ShowBuy = function(visible: boolean, enabled: boolean, price: number)
			buy.Visible = visible
			buy.Text = `Spin for {price} Robux`
			Theme.SetEnabled(buy, enabled)
		end,
		ShowResult = function(text: string, _prize: SpinConfig.Prize?)
			result.Text = text
		end,
		ShowBoosts = function(text: string)
			boosts.Text = text
			boosts.Visible = text ~= ""
		end,
		ShowNote = function(text: string)
			oddsNote.Text = text
		end,
	}
end

-- The creator's Spin Wheel sheet (art/ui-spin): every piece at its real shape, placed at
-- fixed spots (checked in a preview against the art), on a stage scaled to fit the screen.
local STAGE = Vector2.new(780, 600) -- the panel picture (281x216) at this size
local WHEEL_ART = 290
local WHEEL_AT = Vector2.new(255, 290) -- wheel centre on the stage
local RIGHT_X = 440 -- the right-hand column (odds, result, boosts)

-- The prize icons from the sheet, per prize.
local PRIZE_ICON: { [string]: string } = {
	Gold500 = "IconGold500",
	Gold1000 = "IconGold1000",
	Gold2500 = "IconGold2500",
	Gold5000 = "IconGold5000",
	CoinBoost = "IconCoins2x",
	Essence25 = "IconEssence",
	LuckBoost = "IconLuck",
	BlackDragon = "IconDragon",
}

-- The odds painted on the creator's odds box. It's shown only while the real odds are
-- exactly these; otherwise the odds are written in text, so the window never shows
-- odds the wheel doesn't use.
local PAINTED_ODDS: { [string]: number } = {
	Gold500 = 32,
	Gold1000 = 20,
	CoinBoost = 15,
	Essence25 = 15,
	Gold2500 = 10,
	Gold5000 = 5,
	LuckBoost = 2.5,
	BlackDragon = 0.5,
}

local function paintedOddsMatch(): boolean
	for _, entry in Spin.Odds() do
		local painted = PAINTED_ODDS[entry.Prize.Id]
		if not painted or math.abs(painted - entry.Chance * 100) > 0.001 then
			return false
		end
	end
	return true
end

local function canUseArt(): boolean
	for _, name in { "SpinPanel", "WheelFace", "SpinFreeButton", "WheelPointer" } do
		if not Theme.KitImage(name) then
			return false
		end
	end
	return true
end

local function piece(parent: Instance, name: string, props: { [string]: any }, part: Rect?): ImageLabel
	local image = Theme.Make("ImageLabel", { BackgroundTransparency = 1, ZIndex = 12 }, parent)
	for key, value in props do
		(image :: any)[key] = value
	end
	Theme.KitApply(image, name, part)
	return image
end

local function pictureButton(parent: Instance, name: string, props: { [string]: any }): ImageButton
	local button = Theme.Make("ImageButton", { BackgroundTransparency = 1, ZIndex = 14 }, parent)
	for key, value in props do
		(button :: any)[key] = value
	end
	Theme.KitApply(button, name)
	local pop = Theme.Make("UIScale", {}, button)
	button.MouseEnter:Connect(function()
		if not button:GetAttribute("Disabled") then
			pop.Scale = 1.05
		end
	end)
	button.MouseLeave:Connect(function()
		pop.Scale = 1
	end)
	button.Activated:Connect(function()
		Theme.OnClick()
	end)
	return button
end

local function setPictureEnabled(button: ImageButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	button.ImageColor3 = if enabled then Color3.new(1, 1, 1) else Color3.fromRGB(120, 120, 120)
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Theme.Make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Theme.Bold,
		TextColor3 = Color3.fromRGB(245, 235, 215),
		TextSize = 15,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
	}, parent)
	for key, value in props do
		(label :: any)[key] = value
	end
	Theme.Make("UIStroke", { Color = Color3.fromRGB(40, 20, 8), Thickness = 1.5 }, label)
	return label
end

local function buildArt(ctx: any): Parts
	local root = Theme.Make("Frame", {
		Name = "SpinWheelWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	}, ctx.Gui)
	local stage = Theme.Make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(STAGE.X, STAGE.Y),
		BackgroundTransparency = 1,
		Active = true, -- clicks on the panel don't fall through to the dimmer (which closes)
		ZIndex = 10,
	}, root)
	local fit = Theme.Make("UIScale", { Name = "Fit" }, stage)
	local function refit()
		local screen = ctx.Gui.AbsoluteSize
		local guiScale = ctx.Gui:FindFirstChildOfClass("UIScale")
		local g = if guiScale then guiScale.Scale else 1
		if screen.X > 0 and screen.Y > 0 then
			-- Room for the banner sticking out above the panel.
			fit.Scale = math.min(1, screen.X * 0.94 / (STAGE.X * g), screen.Y * 0.84 / (STAGE.Y * g))
		end
	end
	ctx.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	task.defer(refit)

	piece(stage, "SpinPanel", { Size = UDim2.fromScale(1, 1), ZIndex = 10 })
	-- The banner across the top edge (the uploaded picture has a hairline down its left
	-- edge, so the first 2 pixels are left out).
	local headerArt = Rect.new(2, 0, 310, 82)
	piece(stage, "SpinHeader", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -46),
		Size = UDim2.fromOffset(430, math.floor(82 * 430 / 308)),
		ZIndex = 15,
	}, headerArt)
	local close = pictureButton(stage, "SpinClose", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -14),
		Size = UDim2.fromOffset(70, 52),
		ZIndex = 16,
	})
	close.Activated:Connect(ctx.Close)

	-- The wheel turns as one picture; the hub and pointer stay still on top.
	local wheel = Theme.Make("Frame", {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(WHEEL_AT.X, WHEEL_AT.Y),
		Size = UDim2.fromOffset(WHEEL_ART, WHEEL_ART),
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, stage)
	piece(wheel, "WheelFace", { Size = UDim2.fromScale(1, 1), ZIndex = 11 })
	if Theme.KitImage("WheelHub") then
		piece(stage, "WheelHub", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(WHEEL_AT.X, WHEEL_AT.Y),
			Size = UDim2.fromOffset(84, 84),
			ZIndex = 13,
		})
	end
	-- (the uploaded pointer has a hairline along its top: the first 2 rows are left out)
	piece(stage, "WheelPointer", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(WHEEL_AT.X, WHEEL_AT.Y - WHEEL_ART / 2 - 34),
		Size = UDim2.fromOffset(88, math.floor(52 * 88 / 68)),
		ZIndex = 13,
	}, Rect.new(0, 2, 68, 54))

	local free = pictureButton(stage, "SpinFreeButton", {
		Name = "SpinFree",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(WHEEL_AT.X, 444),
		Size = UDim2.fromOffset(260, math.floor(56 * 260 / 179)),
	})
	-- While the free spin is waiting, a dark tag over the button says how long.
	local wait = text(free, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0.62, 0),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(35, 22, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		FontFace = Theme.Heavy,
		Visible = false,
		ZIndex = 15,
	})
	Theme.Corner(wait, 12)

	local buy = pictureButton(stage, "SpinRobuxButton", {
		Name = "SpinRobux",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(RIGHT_X + 142, 444),
		Size = UDim2.fromOffset(260, math.floor(56 * 260 / 182)),
		Visible = false,
	})

	-- The odds: the creator's painted box while it's exact, otherwise written out.
	local oddsTop = 78
	if paintedOddsMatch() and Theme.KitImage("OddsBox") then
		piece(stage, "OddsBox", {
			Position = UDim2.fromOffset(RIGHT_X, oddsTop),
			Size = UDim2.fromOffset(285, math.floor(206 * 285 / 293)),
			ZIndex = 12,
		})
	else
		local list = Theme.Make("Frame", {
			BackgroundColor3 = Color3.fromRGB(45, 28, 16),
			BackgroundTransparency = 0.2,
			Position = UDim2.fromOffset(RIGHT_X, oddsTop),
			Size = UDim2.fromOffset(285, 200),
			ZIndex = 12,
		}, stage)
		Theme.Corner(list, 12)
		Theme.Padding(list, 10, 14)
		Theme.List(list, 2)
		text(list, { Text = "<b>PRIZES AND EXACT ODDS</b>", TextSize = 15, Size = UDim2.new(1, 0, 0, 20) })
		for _, entry in Spin.Odds() do
			text(list, {
				Text = `<font color="#{entry.Prize.Color:ToHex()}">■</font> {entry.Prize.Name} · {percent(
					entry.Chance
				)}`,
				TextSize = 13,
				Size = UDim2.new(1, 0, 0, 18),
			})
		end
	end

	-- Result (with the prize's picture), running boosts, and the small print.
	local resultIcon = Theme.Make("ImageLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(RIGHT_X + 8, 296),
		Size = UDim2.fromOffset(48, 44),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 14,
	}, stage)
	local result = text(stage, {
		Position = UDim2.fromOffset(RIGHT_X + 62, 294),
		Size = UDim2.fromOffset(285 - 62, 48),
		TextSize = 19,
		FontFace = Theme.Heavy,
		TextColor3 = Color3.fromRGB(255, 230, 150),
	})
	local boosts = text(stage, {
		Position = UDim2.fromOffset(RIGHT_X + 8, 346),
		Size = UDim2.fromOffset(277, 20),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 210, 90),
	})
	local note = text(stage, {
		Position = UDim2.fromOffset(RIGHT_X + 8, 370),
		Size = UDim2.fromOffset(277, 60),
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	return {
		Root = root,
		Wheel = wheel,
		Free = free,
		Buy = buy,
		ShowFree = function(ready: boolean, label: string)
			setPictureEnabled(free, ready)
			wait.Visible = not ready
			wait.Text = label
		end,
		ShowBuy = function(visible: boolean, enabled: boolean, _price: number)
			buy.Visible = visible
			setPictureEnabled(buy, enabled)
		end,
		ShowResult = function(message: string, prize: SpinConfig.Prize?)
			result.Text = message
			local icon = prize and PRIZE_ICON[prize.Id]
			resultIcon.Visible = icon ~= nil and Theme.KitImage(icon) ~= nil
			if icon and resultIcon.Visible then
				Theme.KitApply(resultIcon, icon)
			end
		end,
		ShowBoosts = function(message: string)
			boosts.Text = message
		end,
		ShowNote = function(message: string)
			note.Text = message
		end,
	}
end
-- Everything the two looks share: the free-spin timer, boosts, the Robux spin, and turning
-- the wheel to the prize the server picked.
local function wire(ctx: any, parts: Parts)
	local State = ctx.Controllers.State
	local slice = 360 / #SpinConfig.Prizes
	local spinning = false
	local play: (number) -> ()

	local function refresh()
		local spin = State.Get("Spin")
		local now = Workspace:GetServerTimeNow()
		local wait = Spin.FreeIn(spin and spin.NextFreeAt or 0, now)
		if not spinning then
			if wait > 0 then
				parts.ShowFree(false, `Next free spin in {Format.Duration(wait)}`)
			else
				parts.ShowFree(true, "Spin for free!")
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
		parts.ShowBoosts(table.concat(lines, "   "))
		local canBuy = spin ~= nil and spin.CanBuy == true
		parts.ShowBuy(canBuy, not spinning, spin and spin.Price or 199)
		local every = `One free spin every {math.floor(SpinConfig.FreeEvery / 60)} minutes.`
		parts.ShowNote(
			if canBuy then every .. " Extra spins bought with Robux use exactly the same prizes and odds." else every
		)
	end

	parts.Free.Activated:Connect(function()
		if spinning or parts.Free:GetAttribute("Disabled") then
			return
		end
		spinning = true
		parts.ShowFree(false, "Spinning…")
		parts.ShowResult("", nil)
		local ok, data = ctx.Request("Spin")
		if not ok then
			spinning = false
			ctx.Notify(data, "Error")
			refresh()
			return
		end
		play(data.Index :: number)
	end)

	-- A bought spin: the prize is already granted; turn the wheel to it.
	Remotes.Events.GameEvent.OnClientEvent:Connect(function(name: string, payload: any)
		if name ~= "SpinResult" or type(payload) ~= "table" or not SpinConfig.Prizes[payload.Index] then
			return
		end
		if not ctx.IsOpen("Spin") then
			ctx.Open("Spin")
		end
		spinning = true
		parts.ShowFree(false, "Spinning…")
		parts.ShowBuy(true, false, State.Get("Spin") and State.Get("Spin").Price or 199)
		parts.ShowResult("", nil)
		play(payload.Index)
	end)

	parts.Buy.Activated:Connect(function()
		if spinning or parts.Buy:GetAttribute("Disabled") then
			return
		end
		local ok, message = ctx.Request("BuySpin")
		if not ok then
			ctx.Notify(message, "Error")
		end
	end)

	-- Turns the wheel to a prize the server already picked and granted.
	function play(index: number)
		local prize = SpinConfig.Prizes[index]
		-- Turn so the prize's slice stops under the pointer, after a few full turns.
		local middle = (index - 0.5) * slice + SpinConfig.WheelOffset
		local current = parts.Wheel.Rotation % 360
		parts.Wheel.Rotation = current
		local wobble = (math.random() - 0.5) * slice * 0.6 -- land anywhere inside the slice
		local target = current + 360 * 5 + ((-middle - current) % 360) + wobble
		local seconds = if Theme.ReducedMotion then 1 else SpinConfig.AnimationSeconds
		TweenService:Create(
			parts.Wheel,
			TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Rotation = target }
		):Play()
		task.delay(seconds, function()
			spinning = false
			parts.ShowResult(
				if prize.Kind == "Creature"
					then `<font color="#ff5060">YOU WON THE {string.upper(prize.Name)}!</font>`
					else `You won {prize.Name}!`,
				prize
			)
			ctx.Notify(`Spin Wheel: {prize.Name}!`, "Reward")
			ctx.Controllers.Audio.Play(if prize.Kind == "Creature" then "QuestComplete" else "Collect")
			refresh()
		end)
	end

	State.OnChanged("Spin", refresh)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if ctx.IsOpen("Spin") then
				refresh()
			end
		end
	end)

	return refresh
end

function SpinWindow.new(ctx: any)
	local parts = if canUseArt() then buildArt(ctx) else buildDrawn(ctx)
	local refresh = wire(ctx, parts)
	return {
		Root = parts.Root,
		Open = function()
			refresh()
		end,
	}
end

return SpinWindow
