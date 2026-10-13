--!strict
-- The always-on HUD: wallet, empire tier, quest tracker, menu buttons, creature bar,
-- placement controls and the loading / save-status indicators.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared.Config.BuildingConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RegionConfig = require(Shared.Config.RegionConfig)
local WorldEventConfig = require(Shared.Config.WorldEventConfig)
local WorldEvent = require(Shared.Util.WorldEvent)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)

local Hud = {}

function Hud.new(ctx: any)
	local State = ctx.Controllers.State
	local Placement = ctx.Controllers.Placement
	local gui: ScreenGui = ctx.Gui

	------------------------------------------------------------------ Wallet (top centre)
	local wallet = Theme.Make("Frame", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, gui)
	Theme.List(wallet, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)

	type Pill = { Frame: Frame, Label: TextLabel, Value: number }
	local pills: { [string]: Pill } = {}
	local function pill(id: string, order: number): Pill
		local def = ResourceConfig[id]
		local frame = Theme.Panel(wallet, {
			Name = id,
			Size = UDim2.fromOffset(0, 44),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
		})
		Theme.Padding(frame, 0, 14)
		Theme.List(frame, 8, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Center
		Theme.Text(frame, def.Icon, 22, {
			FontFace = Theme.Heavy,
			TextColor3 = def.Color,
			Size = UDim2.fromOffset(22, 30),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local label = Theme.Text(frame, "0", 20, {
			FontFace = Theme.Heavy,
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			TextWrapped = false,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		-- Screen readers / colour-blind players: the name is part of the hover text.
		frame:SetAttribute("Tooltip", def.Name)
		local p = { Frame = frame, Label = label, Value = 0 }
		pills[id] = p
		return p
	end
	pill("Gold", 1)
	pill("Moonpetal", 2)
	local essencePill = pill("Essence", 3)
	essencePill.Frame.Visible = false
	-- Crystal materials only appear once you have some, to keep the bar short.
	local crystalPills = { pill("RawCrystal", 4), pill("RefinedCrystal", 5) }
	for _, p in crystalPills do
		p.Frame.Visible = false
	end
	-- Later currencies, also shown once you have some.
	local laterPills: { [string]: Pill } = { Insight = pill("Insight", 6), EmpireShards = pill("EmpireShards", 7) }
	for _, p in laterPills do
		p.Frame.Visible = false
	end

	local function flash(p: Pill, color: Color3)
		local stroke = p.Frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = color
			stroke.Transparency = 0.1
			TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 0.82, Color = Theme.Colors.Border }):Play()
		end
	end

	State.OnChanged("Wallet", function(w)
		for id, p in pills do
			local amount = w.Currencies[id] or w.Resources[id] or 0
			local capacity = w.Capacity and w.Capacity[id]
			local text = Format.Number(amount)
			if capacity then
				text ..= `<font color="#{Theme.Colors.Muted:ToHex()}" size="15"> / {Format.Number(capacity)}</font>`
				if amount >= capacity then
					text =
						`<font color="#{Theme.Colors.Warning:ToHex()}">{Format.Number(amount)}</font><font color="#{Theme.Colors.Muted:ToHex()}" size="15"> / {Format.Number(
							capacity
						)} FULL</font>`
				end
			end
			p.Label.Text = text
			if amount > p.Value then
				flash(p, ResourceConfig[id].Color)
			end
			p.Value = amount
		end
		essencePill.Frame.Visible = (w.Currencies.Essence or 0) > 0
		crystalPills[1].Frame.Visible = (w.Resources.RawCrystal or 0) >= 1
		crystalPills[2].Frame.Visible = (w.Resources.RefinedCrystal or 0) >= 1
		for id, p in laterPills do
			p.Frame.Visible = (w.Currencies[id] or 0) >= 1
		end
	end)

	------------------------------------------------------------------ Empire (top left)
	local empire = Theme.Panel(gui, {
		Name = "Empire",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Theme.Padding(empire, 10, 14)
	Theme.List(empire, 6)
	local empireTitle = Theme.Text(empire, "Empire · Tier 1", 18, { FontFace = Theme.Heavy })
	local empireNext = Theme.Text(empire, "", 14, { TextColor3 = Theme.Colors.Muted })
	local _, setEmpireBar = Theme.Bar(empire, Theme.Colors.Gold, 6)
	local saveStatus = Theme.Text(empire, "", 13, { TextColor3 = Theme.Colors.Warning, Visible = false })

	local function refreshEmpire()
		local buildings = State.Get("Buildings")
		local w = State.Get("Wallet")
		local core = buildings and buildings.List and buildings.List.core
		if not core then
			return
		end
		empireTitle.Text = `Empire · Tier {core.Level}`
		local cost = core.NextCost and core.NextCost.Gold
		if cost then
			local gold = w and w.Currencies.Gold or 0
			empireNext.Text = `Next tier: {Format.Number(math.min(gold, cost))} / {Format.Number(cost)} gold`
			setEmpireBar(gold / cost)
		else
			empireNext.Text = "Highest tier reached for now."
			setEmpireBar(1)
		end
	end
	State.OnChanged("Buildings", refreshEmpire)
	State.OnChanged("Wallet", refreshEmpire)
	State.OnStatus(function(status)
		saveStatus.Visible = status == "Unsaved"
		saveStatus.Text = "Studio test: progress is not saved"
	end)

	------------------------------------------------------------------ Quest tracker (left)
	local tracker = Theme.Panel(gui, {
		Name = "QuestTracker",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.42, 0),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	Theme.Padding(tracker, 12, 14)
	Theme.List(tracker, 6)
	local questHeader =
		Theme.Text(tracker, "", 13, { FontFace = Theme.Bold, TextColor3 = Theme.Colors.Primary, LayoutOrder = 1 })
	local questTitle = Theme.Text(tracker, "", 19, { FontFace = Theme.Heavy, LayoutOrder = 2 })
	local questText = Theme.Text(tracker, "", 15, { TextColor3 = Theme.Colors.Muted, LayoutOrder = 3 })
	local questBarHolder =
		Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 }, tracker)
	local questBar, setQuestBar = Theme.Bar(questBarHolder, Theme.Colors.Primary, 8)
	questBar.Position = UDim2.fromOffset(0, 5)
	questBar.Size = UDim2.new(1, -60, 0, 8)
	local questCount = Theme.Text(questBarHolder, "", 14, {
		FontFace = Theme.Bold,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(56, 18),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local claim = Theme.Button(
		tracker,
		"Claim reward",
		"Gold",
		{ Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 5, Visible = false }
	)
	local claimPulse: Tween? = nil
	claim.Activated:Connect(function()
		local ok, result = ctx.Request("ClaimQuest")
		if not ok then
			ctx.Notify(result, "Error")
		end
	end)

	State.OnChanged("Quests", function(q: any)
		local step = q.Step
		tracker.Visible = step ~= nil and (step.Kind ~= "ChooseStarter" or q.Claimable)
		if not step then
			return
		end
		questHeader.Text = `QUEST {q.Index} OF {q.Total}`
		questTitle.Text = step.Title
		questText.Text = step.Description
		setQuestBar(q.Progress / step.Amount)
		questCount.Text = `{Format.Number(q.Progress)}/{Format.Number(step.Amount)}`
		claim.Visible = q.Claimable
		if claimPulse then
			claimPulse:Cancel()
			claimPulse = nil
		end
		if q.Claimable and not Theme.ReducedMotion then
			local scale = claim:FindFirstChildOfClass("UIScale") :: UIScale
			claimPulse = TweenService:Create(
				scale,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.05 }
			);
			(claimPulse :: Tween):Play()
		end
	end)

	------------------------------------------------------------------ Menu (right)
	local menu = Theme.Make("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Size = UDim2.fromOffset(150, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, gui)
	Theme.List(menu, 8, nil, Enum.HorizontalAlignment.Right)
	local keyboard = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	local function menuButton(glyph: string, label: string, key: string, windowName: string, order: number)
		local button = Theme.Button(
			menu,
			`{glyph}  {label}` .. (if keyboard then `  <font size="13" color="#9aa6c4">[{key}]</font>` else ""),
			"Secondary",
			{
				Size = UDim2.fromOffset(150, 44),
				LayoutOrder = order,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
		)
		Theme.Padding(button, 0, 14)
		button.Activated:Connect(function()
			ctx.Controllers.UI.Toggle(windowName)
		end)
		return button
	end
	menuButton("❦", "Creatures", "C", "Creatures", 1)
	menuButton("⌂", "Build", "B", "Build", 2)
	menuButton("✎", "Quests", "J", "Quests", 3)
	menuButton("▤", "Inventory", "G", "Inventory", 4)
	menuButton("✈", "Map", "M", "Map", 5)
	menuButton("☺", "Players", "U", "Players", 6)
	menuButton("♛", "Rankings", "L", "Leaderboards", 7)
	menuButton("⚙", "Settings", "P", "Settings", 8)

	------------------------------------------------------------------ Creature bar (bottom)
	local bar = Theme.Make("Frame", {
		Name = "CreatureBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(0, 112),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, gui)
	Theme.List(bar, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)

	type Slot = {
		Frame: Frame,
		Ability: TextButton,
		Level: TextLabel,
		Task: TextLabel,
		Species: string,
		ReadyAt: number,
		AbilityName: string,
	}
	local slots: { [string]: Slot } = {}

	local function makeSlot(info: any): Slot
		local species = CreatureConfig.Species[info.Species]
		local rarity = RarityConfig.Get(species.Rarity)
		local frame = Theme.Panel(bar, {
			Name = info.Id,
			Size = UDim2.fromOffset(96, 112),
			LayoutOrder = info.ObtainedAt or 0,
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = rarity.Color
		stroke.Transparency = 0.5
		local portrait = Theme.Make("ImageButton", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 62),
			Image = "",
			Selectable = true,
		}, frame)
		Viewport.Creature(portrait, info.Species, { Size = UDim2.fromScale(1, 1) })
		portrait.Activated:Connect(function()
			ctx.Open("Creatures", info.Id)
		end)
		local level = Theme.Text(frame, "", 12, {
			FontFace = Theme.Bold,
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(40, 14),
			AutomaticSize = Enum.AutomaticSize.None,
		})
		local taskLabel = Theme.Text(frame, "", 11, {
			TextColor3 = Theme.Colors.Muted,
			Position = UDim2.fromOffset(4, 60),
			Size = UDim2.new(1, -8, 0, 14),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		})
		local ability = Theme.Button(frame, "", "Primary", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -5),
			Size = UDim2.new(1, -10, 0, 28),
			TextSize = 13,
		})
		local slot: Slot = {
			Frame = frame,
			Ability = ability,
			Level = level,
			Task = taskLabel,
			Species = info.Species,
			ReadyAt = 0,
			AbilityName = species.Active.Name,
		}
		ability.Activated:Connect(function()
			if os.clock() < slot.ReadyAt then
				ctx.Notify(`{slot.AbilityName} is recharging.`, "Info")
				return
			end
			local ok, result = ctx.Request("UseAbility", info.Id)
			if not ok then
				ctx.Notify(result, "Error")
			end
		end)
		return slot
	end

	State.OnChanged("Creatures", function(creatures)
		local seen = {}
		local count = 0
		for id, info in creatures.List do
			count += 1
			if count > 8 then
				break
			end
			seen[id] = true
			local slot = slots[id]
			if not slot then
				slot = makeSlot(info)
				slots[id] = slot
			end
			slot.Level.Text = "Lv " .. info.Level
			slot.Task.Text = if info.Assignment then info.Task else "Idle"
			slot.ReadyAt = os.clock() + info.AbilityReadyIn
		end
		for id, slot in slots do
			if not seen[id] then
				slot.Frame:Destroy()
				slots[id] = nil
			end
		end
		bar.Visible = count > 0 and not Placement.IsActive()
	end)

	-- Cooldown text ticks locally from the server's "ready in" value.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, slot in slots do
				local remaining = slot.ReadyAt - now
				if remaining > 0 then
					slot.Ability.Text = "⟳ " .. Format.Duration(remaining)
					Theme.SetStyle(slot.Ability, "Ghost")
				else
					slot.Ability.Text = "⚡ " .. slot.AbilityName
					Theme.SetStyle(slot.Ability, "Primary")
				end
			end
		end
	end)

	------------------------------------------------------------------ Placement bar
	local placeBar = Theme.Panel(gui, {
		Name = "PlacementBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 20,
	})
	Theme.Padding(placeBar, 12, 16)
	Theme.List(placeBar, 8, nil, Enum.HorizontalAlignment.Center)
	local placeTitle =
		Theme.Text(placeBar, "", 19, { FontFace = Theme.Heavy, TextXAlignment = Enum.TextXAlignment.Center })
	local placeHint =
		Theme.Text(placeBar, "", 15, { TextColor3 = Theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center })
	local placeButtons = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44) }, placeBar)
	Theme.List(placeButtons, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	local rotate = Theme.Button(placeButtons, "⟳ Rotate", "Secondary", { Size = UDim2.fromOffset(130, 42) })
	local confirm = Theme.Button(placeButtons, "✔ Place", "Primary", { Size = UDim2.fromOffset(130, 42) })
	local cancel = Theme.Button(placeButtons, "✕ Cancel", "Danger", { Size = UDim2.fromOffset(130, 42) })
	rotate.Activated:Connect(Placement.Rotate)
	confirm.Activated:Connect(Placement.Confirm)
	cancel.Activated:Connect(Placement.Cancel)

	local function controlsHint(): string
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Tap the ground to move it, then press Place."
		elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
			return "Aim with the camera. Y rotate · A place · B cancel."
		end
		return "Move the mouse to aim. R rotate · Click place · X cancel."
	end

	Placement.OnStateChanged = function(isActive: boolean, info: any)
		placeBar.Visible = isActive
		bar.Visible = not isActive and next(slots) ~= nil
		if not isActive or not info then
			return
		end
		local def = BuildingConfig[info.Type]
		placeTitle.Text = (if info.Moving then "Moving: " else "Placing: ") .. def.Name
		if info.Reason then
			placeHint.Text = `<font color="#{Theme.Colors.Danger:ToHex()}">✖ {info.Reason}</font>`
		else
			placeHint.Text = (if info.Valid then "✔ Looks good. " else "") .. controlsHint()
		end
		Theme.SetEnabled(confirm, info.Valid)
	end
	Placement.Notify = ctx.Notify

	------------------------------------------------------------------ Region (heat, eruption, home)
	local localPlayer = Players.LocalPlayer
	local regionPanel = Theme.Panel(gui, {
		Name = "RegionPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	Theme.Padding(regionPanel, 8, 12)
	Theme.List(regionPanel, 4)
	local regionTitle = Theme.Text(regionPanel, "", 15, { FontFace = Theme.Heavy })
	local heatRow = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16) }, regionPanel)
	local heatBar, setHeat = Theme.Bar(heatRow, Color3.fromRGB(255, 120, 50), 12)
	heatBar.Size = UDim2.new(1, -110, 0, 12)
	heatBar.Position = UDim2.fromOffset(0, 2)
	local heatText = Theme.Text(heatRow, "", 13, {
		FontFace = Theme.Bold,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(105, 16),
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local eruptionText = Theme.Text(regionPanel, "", 12, { TextColor3 = Theme.Colors.Muted })
	local homeButton =
		Theme.Button(regionPanel, "⌂ Return home", "Secondary", { Size = UDim2.new(1, 0, 0, 32), TextSize = 14 })
	homeButton.Activated:Connect(function()
		local ok, result = ctx.Request("Travel", "Home")
		if not ok then
			ctx.Notify(result, "Error")
		end
	end)
	local function refreshRegion()
		local regionId = localPlayer:GetAttribute("Region") :: string?
		local region = regionId and regionId ~= "" and RegionConfig.Regions[regionId] or nil
		regionPanel.Visible = region ~= nil
		if not region then
			return
		end
		regionTitle.Text = region.Name
		local heat = (localPlayer:GetAttribute("Heat") :: number?) or 0
		setHeat(heat / region.Heat.Max)
		local word = if heat >= 80 then "SCORCHING" elseif heat >= 50 then "Hot" else "Warm"
		heatText.Text = `♨ {word} {math.floor(heat)}%`
		heatText.TextColor3 = if heat >= 80
			then Theme.Colors.Danger
			elseif heat >= 50 then Theme.Colors.Warning
			else Theme.Colors.Text
		local now = Workspace:GetServerTimeNow()
		if RegionConfig.EruptionActive(region, now) then
			eruptionText.Text =
				`<font color="#{Theme.Colors.Danger:ToHex()}"><b>ERUPTION</b></font> · ends in {Format.Duration(
					region.Eruption.Duration - now % region.Eruption.Period
				)}`
		else
			eruptionText.Text =
				`Next eruption in {Format.Duration(RegionConfig.NextEruptionIn(region, now))} · cool off in the blue pools`
		end
	end
	localPlayer:GetAttributeChangedSignal("Heat"):Connect(refreshRegion)
	localPlayer:GetAttributeChangedSignal("Region"):Connect(refreshRegion)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshRegion()
		end
	end)

	------------------------------------------------------------------ Guardian combat bar
	local Guardian = ctx.Controllers.Guardian
	local combat = Theme.Panel(gui, {
		Name = "CombatBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -134),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	Theme.Padding(combat, 10, 14)
	Theme.List(combat, 6, nil, Enum.HorizontalAlignment.Center)
	local bossName = Theme.Text(combat, "", 18, { FontFace = Theme.Heavy, TextXAlignment = Enum.TextXAlignment.Center })
	local _, setBoss = Theme.Bar(combat, Theme.Colors.Danger, 14)
	local bossText =
		Theme.Text(combat, "", 13, { TextColor3 = Theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center })
	local combatButtons = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42) }, combat)
	Theme.List(combatButtons, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	local attackButton = Theme.Button(combatButtons, "", "Primary", { Size = UDim2.fromOffset(190, 40), TextSize = 15 })
	local specialButton = Theme.Button(combatButtons, "", "Gold", { Size = UDim2.fromOffset(190, 40), TextSize = 15 })
	attackButton.Activated:Connect(function()
		Guardian.Attack("Attack")
	end)
	specialButton.Activated:Connect(function()
		Guardian.Attack("Special")
	end)
	local companionHint =
		Theme.Text(combat, "", 12, { TextColor3 = Theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center })
	local function companionInfo(): any
		local creatures = State.Get("Creatures")
		for _, c in creatures and creatures.List or {} do
			if c.Companion then
				return c
			end
		end
		return nil
	end
	Guardian.OnNearChanged = function(isNear: boolean, info: any?)
		combat.Visible = isNear
		if info then
			Guardian.OnHealth(info)
		end
	end
	local lastBoss: any = nil
	Guardian.OnHealth = function(info: any)
		lastBoss = info
		bossName.Text = info.Name or "Guardian"
		if info.Alive then
			setBoss(info.Health / math.max(info.MaxHealth, 1))
			local phaseText = if info.Phase >= 3 then "ENRAGED" elseif info.Phase == 2 then "Furious" else "Watchful"
			bossText.Text =
				`{Format.Number(info.Health)} / {Format.Number(info.MaxHealth)} · {phaseText} · dodge the glowing circles!`
		else
			setBoss(0)
			bossText.Text =
				`Defeated · returns in {Format.Duration(math.max(info.RespawnAt - Workspace:GetServerTimeNow(), 0))}`
		end
	end
	local keys = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	task.spawn(function()
		while true do
			task.wait(0.2)
			if combat.Visible then
				if lastBoss and not lastBoss.Alive then
					Guardian.OnHealth(lastBoss) -- keep the respawn countdown ticking
				end
				local companion = companionInfo()
				local cds = Guardian.Cooldowns()
				local now = os.clock()
				local support = false
				if companion then
					local species = CreatureConfig.Species[companion.Species]
					support = species and (species.Family == "Verdant" or species.Family == "Tideborn") or false
					companionHint.Text =
						`Fighting with {companion.Name} (Lv {companion.Level}). Water and crystal creatures hit harder; fire creatures barely scratch her.`
				else
					companionHint.Text = "You need a companion: open Creatures and choose “Take with me”."
				end
				local a = cds.Attack - now
				local sp = cds.Special - now
				attackButton.Text = if a > 0
					then `⟳ {string.format("%.1f", a)}s`
					else "⚔ Attack" .. (if keys then " [1]" else "")
				specialButton.Text = if sp > 0
					then `⟳ {math.ceil(sp)}s`
					else (if support then "❄ Cool allies" else "✦ Special") .. (if keys then " [2]" else "")
				Theme.SetEnabled(attackButton, a <= 0 and companion ~= nil)
				Theme.SetEnabled(specialButton, sp <= 0 and companion ~= nil)
			end
		end
	end)

	------------------------------------------------------------------ World event (top right)
	local eventPanel = Theme.Panel(gui, {
		Name = "WorldEvent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 56),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Theme.Padding(eventPanel, 8, 12)
	Theme.List(eventPanel, 4)
	local eventTitle = Theme.Text(eventPanel, "", 15, { FontFace = Theme.Heavy })
	local eventText = Theme.Text(eventPanel, "", 13, { TextColor3 = Theme.Colors.Muted })
	local eventBarFrame, setEventBar = Theme.Bar(eventPanel, Theme.Colors.Primary, 8)
	local eventFolder = ReplicatedStorage:WaitForChild("WorldEvent", 30)
	task.spawn(function()
		while eventFolder do
			local kind = eventFolder:GetAttribute("Kind") :: string?
			local now = Workspace:GetServerTimeNow()
			local def = if kind and kind ~= "" then WorldEventConfig.Events[kind] else nil
			if def then
				local left = math.max(((eventFolder:GetAttribute("EndsAt") :: number?) or now) - now, 0)
				eventTitle.Text =
					`<font color="#{def.Color:ToHex()}">{def.Glyph}</font> {def.Name} · {Format.Duration(left)}`
				eventPanel.BackgroundTransparency = 0.05
				if kind == "Bloom" then
					local progress = (eventFolder:GetAttribute("Progress") :: number?) or 0
					local goal = math.max((eventFolder:GetAttribute("Goal") :: number?) or 1, 1)
					eventText.Text =
						`Server goal: {Format.Number(progress)} / {Format.Number(goal)} moonpetals collected. Collect at your farms to help!`
					eventBarFrame.Visible = true
					setEventBar(progress / goal)
				elseif kind == "EmberRift" then
					local teams = (eventFolder:GetAttribute("Teams") :: number?) or 0
					local joinLeft = left - WorldEventConfig.Rift.JoinCutoff
					eventText.Text = `{teams} team{if teams == 1 then "" else "s"} in the rift (+{math.floor(
						WorldEvent.RiftBonus(teams + 1) * 100
					)}% chance if you join).` .. (if joinLeft > 0
						then ` Join from your Expedition Portal within {Format.Duration(joinLeft)}.`
						else " Too late to join this one.")
					eventBarFrame.Visible = false
				else
					eventText.Text = def.Description
					eventBarFrame.Visible = false
				end
			else
				local nextKind = eventFolder:GetAttribute("NextKind") :: string?
				local nextDef = nextKind and WorldEventConfig.Events[nextKind]
				local nextAt = (eventFolder:GetAttribute("NextAt") :: number?) or now
				eventTitle.Text = if nextDef
					then `<font color="#9aa6c4">Next event:</font> {nextDef.Glyph} {nextDef.Name}`
					else "World events"
				eventText.Text = `Starts in {Format.Duration(math.max(nextAt - now, 0))}`
				eventBarFrame.Visible = false
			end
			task.wait(0.5)
		end
	end)

	------------------------------------------------------------------ Loading veil
	local veil = Theme.Make("Frame", {
		Name = "Loading",
		BackgroundColor3 = Color3.fromRGB(10, 14, 24),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
	}, ctx.Overlay)
	local veilText = Theme.Text(veil, "Loading your empire…", 26, {
		FontFace = Theme.Heavy,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 101,
	})
	State.OnStatus(function(status, message)
		if status == "Ready" or status == "Unsaved" then
			TweenService:Create(veil, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(veilText, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			task.delay(0.5, function()
				veil.Visible = false
			end)
		elseif status == "Failed" then
			veil.Visible = true
			veil.BackgroundTransparency = 0
			veilText.TextTransparency = 0
			veilText.Text = message or "Something went wrong loading your empire. Please rejoin."
		end
	end)
end

return Hud
