--!strict
-- Trading with another player. The server owns the session; this window shows both offers,
-- lets you edit yours, and shows the ready ticks and the final countdown. Any change to
-- either offer clears both ticks, so you always confirm exactly what you'll get.
-- Trade invites appear as a small card with Accept / Decline.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SocialConfig = require(Shared.Config.SocialConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)
local Viewport = require(script.Parent.Viewport)

local TradeWindow = {}

function TradeWindow.new(ctx: any)
	local State = ctx.Controllers.State
	-- The window can't be closed while trading (other windows would cancel it): the ✕
	-- button cancels the trade instead.
	local module: any = nil
	local win = Window.new(ctx.Gui, "Trade", "⇄", Vector2.new(760, 640), function()
		if module and module.Modal then
			ctx.Request("TradeCancel")
		else
			ctx.Close()
		end
	end)
	Theme.List(win.Body, 10)

	local session: any = nil -- last TradeState from the server
	local myCreatures: { string } = {}
	local myResources: { [string]: number } = {}
	local picking = false
	local sendQueued = false
	local closingFromServer = false

	local function send()
		if sendQueued then
			return
		end
		sendQueued = true
		task.delay(0.25, function()
			sendQueued = false
			local ok, result = ctx.Request("TradeOffer", { Creatures = myCreatures, Resources = myResources })
			if not ok then
				ctx.Notify(result, "Error")
				-- Back to what the server has.
				if session then
					myCreatures = {}
					for _, c in session.Mine.Creatures do
						table.insert(myCreatures, c.Id)
					end
					myResources = table.clone(session.Mine.Resources)
				end
			end
		end)
	end

	local function creatureCard(parent: Instance, c: any, onRemove: (() -> ())?)
		local species = CreatureConfig.Species[c.Species]
		local rarity = RarityConfig.Get(species and species.Rarity or "Common")
		local row = Window.Row(parent, 50)
		local face = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46) }, row)
		Viewport.Creature(face, c.Species, nil, { Stage = c.Stage, Mutation = c.Mutation })
		local mutation = c.Mutation and MutationConfig.Mutations[c.Mutation]
		Theme.Text(
			row,
			`<font color="#{rarity.Color:ToHex()}">{rarity.Glyph}</font> <b>{Theme.Escape(c.Name)}</b>`
				.. (if species and c.Name ~= species.Name then ` <font color="#9aa6c4">({species.Name})</font>` else "")
				.. ` Lv {c.Level}`
				.. (if mutation then ` {mutation.Glyph}` else ""),
			14,
			{
				Size = UDim2.new(1, if onRemove then -150 else -60, 1, 0),
				AutomaticSize = Enum.AutomaticSize.None,
				TextYAlignment = Enum.TextYAlignment.Center,
			}
		)
		if onRemove then
			local remove = Theme.Button(row, "Remove", "Secondary", { Size = UDim2.fromOffset(90, 32), TextSize = 13 })
			remove.Activated:Connect(onRemove)
		end
	end

	local function render()
		Window.Clear(win.Body)
		if not session then
			Theme.Text(win.Body, "Not trading. Open the Players window (U) to invite someone.", 15)
			return
		end
		win.SetTitle("Trade with " .. session.Partner)
		local wallet = State.Get("Wallet")
		local columns = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
		}, win.Body)
		Theme.List(columns, 10, Enum.FillDirection.Horizontal)
		local function column(title: string, ready: boolean): Frame
			local frame = Window.Section(columns, (if ready then "✔ " else "") .. title, 1)
			frame.Size = UDim2.new(0.5, -5, 0, 0)
			return frame
		end
		local mine = column("YOU OFFER" .. (if session.MyReady then " · READY" else ""), session.MyReady)
		local theirs = column(
			`{string.upper(session.Partner)} OFFERS` .. (if session.TheirReady then " · READY" else ""),
			session.TheirReady
		)

		-- Your side: creatures
		for _, c in session.Mine.Creatures do
			creatureCard(mine, c, function()
				local index = table.find(myCreatures, c.Id)
				if index then
					table.remove(myCreatures, index)
					send()
				end
			end)
		end
		if #myCreatures < SocialConfig.Trade.MaxCreatures then
			local add = Theme.Button(mine, if picking then "Done choosing" else "+ Add a creature", "Ghost", {
				Size = UDim2.new(1, 0, 0, 36),
				TextSize = 14,
			})
			add.Activated:Connect(function()
				picking = not picking
				render()
			end)
		end
		if picking then
			local creatures = State.Get("Creatures")
			local any = false
			for id, c in creatures and creatures.List or {} do
				if not table.find(myCreatures, id) then
					local tradable = c.Tradable and not c.Expedition and not c.Companion
					local row = Window.Row(mine, 34)
					Theme.Text(row, `{c.Name} Lv {c.Level}`, 13, {
						Size = UDim2.new(1, -100, 1, 0),
						AutomaticSize = Enum.AutomaticSize.None,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextColor3 = if tradable then Theme.Colors.Text else Theme.Colors.Muted,
					})
					local pick = Theme.Button(row, if tradable then "Add" else "Can't", "Primary", {
						Size = UDim2.fromOffset(90, 30),
						TextSize = 13,
					})
					Theme.SetEnabled(pick, tradable)
					pick.Activated:Connect(function()
						if not tradable then
							ctx.Notify(
								if c.Companion
									then "Stop it following you first."
									elseif c.Expedition then "It's away on an expedition."
									else "Starter, quest and gift creatures can't be traded.",
								"Error"
							)
							return
						end
						table.insert(myCreatures, id)
						if #myCreatures >= SocialConfig.Trade.MaxCreatures then
							picking = false
						end
						send()
					end)
					any = true
				end
			end
			if not any then
				Theme.Text(mine, "No other creatures.", 13, { TextColor3 = Theme.Colors.Muted })
			end
		end
		-- Your side: resources (type an amount)
		for _, id in SocialConfig.Trade.Resources do
			local def = ResourceConfig[id]
			local have = wallet and (wallet.Currencies[id] or wallet.Resources[id]) or 0
			if have >= 1 or (myResources[id] or 0) > 0 then
				local row = Window.Row(mine, 34)
				Theme.Text(
					row,
					`{def.Icon} {def.Name} <font color="#9aa6c4">(have {Format.Number(math.floor(have))})</font>`,
					13,
					{
						Size = UDim2.new(1, -110, 1, 0),
						AutomaticSize = Enum.AutomaticSize.None,
						TextYAlignment = Enum.TextYAlignment.Center,
					}
				)
				local box = Theme.Make("TextBox", {
					Size = UDim2.fromOffset(100, 30),
					BackgroundColor3 = Theme.Colors.PanelSunken,
					TextColor3 = Theme.Colors.Text,
					FontFace = Theme.Font,
					TextSize = 14,
					PlaceholderText = "0",
					Text = if (myResources[id] or 0) > 0 then tostring(myResources[id]) else "",
					ClearTextOnFocus = false,
				}, row)
				Theme.Corner(box, 6)
				box.FocusLost:Connect(function()
					local amount = math.floor(tonumber(box.Text) or 0)
					amount = math.clamp(amount, 0, math.floor(have))
					if amount > 0 then
						myResources[id] = amount
					else
						myResources[id] = nil
					end
					box.Text = if amount > 0 then tostring(amount) else ""
					send()
				end)
			end
		end

		-- Their side
		for _, c in session.Theirs.Creatures do
			creatureCard(theirs, c, nil)
		end
		for id, amount in session.Theirs.Resources do
			local def = ResourceConfig[id]
			Theme.Text(theirs, `{def and def.Icon or ""} {Format.Number(amount)} {def and def.Name or id}`, 15)
		end
		if #session.Theirs.Creatures == 0 and next(session.Theirs.Resources) == nil then
			Theme.Text(theirs, "Nothing yet.", 14, { TextColor3 = Theme.Colors.Muted })
		end

		-- Status and buttons
		local footer = Window.Section(win.Body, nil, 2)
		if session.Message then
			Theme.Text(footer, "⚠ " .. session.Message, 14, { TextColor3 = Theme.Colors.Warning })
		end
		local countdown = Theme.Text(footer, "", 15, { FontFace = Theme.Bold, TextColor3 = Theme.Colors.Gold })
		if session.CountdownEnds then
			task.spawn(function()
				while countdown.Parent and session and session.CountdownEnds do
					local left = math.max(session.CountdownEnds - Workspace:GetServerTimeNow(), 0)
					countdown.Text = `Both ready! Trading in {math.ceil(left)}… (any change cancels)`
					task.wait(0.1)
				end
			end)
		else
			countdown.Text = "Check both offers, then press Ready. Any change clears both ticks."
			countdown.TextColor3 = Theme.Colors.Muted
		end
		local row = Window.Row(footer, 44)
		local ready = Theme.Button(
			row,
			if session.MyReady then "Not ready" else "✔ Ready",
			if session.MyReady then "Secondary" else "Primary",
			{
				Size = UDim2.fromOffset(180, 40),
			}
		)
		ready.Activated:Connect(function()
			local ok, result = ctx.Request("TradeReady", not session.MyReady)
			if not ok then
				ctx.Notify(result, "Error")
			end
		end)
		local cancel = Theme.Button(row, "Cancel trade", "Danger", { Size = UDim2.fromOffset(160, 40) })
		cancel.Activated:Connect(function()
			ctx.Request("TradeCancel")
		end)
	end

	-- Invite card (outside the window system, so it shows over whatever is open).
	local invite = Theme.Panel(ctx.Overlay, {
		Name = "TradeInvite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 50,
	})
	Theme.Padding(invite, 12)
	Theme.List(invite, 8)
	local inviteText = Theme.Text(invite, "", 16)
	local inviteRow = Window.Row(invite, 40)
	local accept = Theme.Button(inviteRow, "Accept", "Primary", { Size = UDim2.fromOffset(150, 36) })
	local decline = Theme.Button(inviteRow, "Decline", "Secondary", { Size = UDim2.fromOffset(150, 36) })
	local inviteFrom: number? = nil
	accept.Activated:Connect(function()
		invite.Visible = false
		if inviteFrom then
			local ok, result = ctx.Request("TradeRespond", inviteFrom, true)
			if not ok then
				ctx.Notify(result, "Error")
			end
		end
	end)
	decline.Activated:Connect(function()
		invite.Visible = false
		if inviteFrom then
			ctx.Request("TradeRespond", inviteFrom, false)
		end
	end)

	Remotes.Events.GameEvent.OnClientEvent:Connect(function(name: string, payload: any)
		if name == "TradeInvite" then
			inviteFrom = payload.FromUserId
			inviteText.Text = `<b>{payload.FromName}</b> wants to trade with you.`
			invite.Visible = true
			local from = payload.FromUserId
			task.delay(payload.Seconds or 30, function()
				if inviteFrom == from then
					invite.Visible = false
				end
			end)
		elseif name == "TradeState" then
			local first = session == nil
			session = payload
			if first then
				-- A new session: start from what the server has (empty).
				myCreatures, myResources, picking = {}, {}, false
			end
			module.Modal = false -- let it open over whatever window is showing
			if not ctx.IsOpen("Trade") then
				ctx.Close()
				ctx.Open("Trade")
			else
				render()
			end
			module.Modal = true
		elseif name == "TradeClosed" then
			session = nil
			myCreatures, myResources, picking = {}, {}, false
			ctx.Notify(payload.Reason, if payload.Reason == "Trade complete!" then "Reward" else "Info")
			module.Modal = false
			if ctx.IsOpen("Trade") then
				closingFromServer = true
				ctx.Close()
				closingFromServer = false
			end
		end
	end)

	module = {
		Root = win.Root,
		Modal = false,
		Open = function()
			render()
		end,
		OnClose = function()
			-- Only reachable when the trade has ended (the window is modal while trading).
			if session and not closingFromServer then
				ctx.Request("TradeCancel")
			end
		end,
	}
	return module
end

return TradeWindow
