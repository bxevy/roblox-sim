--!strict
-- The Empire Shop (MonetizationConfig): tabs for Featured, Coins, Essence, Boosts and
-- Passes; a big card for the Meadow Starter Bundle and a grid of item cards, each with its
-- price. Items whose ids aren't configured show "Coming soon".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local SpinConfig = require(Shared.Config.SpinConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)
local Viewport = require(script.Parent.Viewport)

local ShopWindow = {}

local prices: { [string]: number } = {}

local function price(kind: Enum.InfoType, id: number): number?
	local cacheKey = `{kind.Name}:{id}`
	if prices[cacheKey] then
		return prices[cacheKey]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, kind)
	end)
	if ok and info and type(info.PriceInRobux) == "number" then
		prices[cacheKey] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

type Entry = {
	Key: string,
	IsPass: boolean,
	Pass: MonetizationConfig.Pass?,
	Product: MonetizationConfig.Product?,
	Name: string,
	Description: string,
	Glyph: string,
	Color: Color3,
	Tab: string,
	Featured: boolean,
	Id: number,
}

local function entries(): { Entry }
	local list: { Entry } = {}
	for key, pass in MonetizationConfig.Passes do
		table.insert(list, {
			Key = key,
			IsPass = true,
			Pass = pass,
			Name = pass.Name,
			Description = pass.Description,
			Glyph = pass.Glyph,
			Color = pass.Color,
			Tab = pass.Tab :: string,
			Featured = pass.Featured == true,
			Id = pass.Id,
		})
	end
	for key, product in MonetizationConfig.Products do
		table.insert(list, {
			Key = key,
			IsPass = false,
			Product = product,
			Name = product.Name,
			Description = product.Description,
			Glyph = product.Glyph,
			Color = product.Color,
			Tab = product.Tab :: string,
			Featured = product.Featured == true,
			Id = product.Id,
		})
	end
	-- Cheapest-looking first: currency by amount, then boosts, then passes.
	table.sort(list, function(a, b)
		if a.IsPass ~= b.IsPass then
			return not a.IsPass
		end
		local amountA = a.Product and a.Product.Amount or 0
		local amountB = b.Product and b.Product.Amount or 0
		if a.Tab ~= b.Tab then
			return a.Tab < b.Tab
		end
		if amountA ~= amountB then
			return amountA < amountB
		end
		return a.Key < b.Key
	end)
	return list
end

function ShopWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Empire Shop", "●", Vector2.new(780, 620), ctx.Close)
	Theme.List(win.Body, 12)

	local tab: string = "Featured"
	local rendering = 0
	local render: () -> ()

	-- Price button text and whether it can be pressed right now.
	local function buttonState(entry: Entry, shop: any): (string, boolean)
		if entry.Id == 0 then
			return "Coming soon", false
		end
		if entry.IsPass then
			if shop.Passes[entry.Key] == true then
				return "✔ Owned", false
			end
			local cost = price(Enum.InfoType.GamePass, entry.Id)
			return `R$ {cost or "?"}`, true
		end
		local product = entry.Product :: MonetizationConfig.Product
		local now = os.time()
		if product.Kind == "FarmBoost" and product.Seconds then
			if (shop.BoostUntil or 0) - now > MonetizationConfig.Boost.MaxSeconds - product.Seconds then
				return "Boost is full", false
			end
		elseif product.Kind == "LuckBoost" and product.Seconds then
			local spin = State.Get("Spin")
			local luck = spin and spin.Boosts and spin.Boosts.Luck or 0
			if luck - Workspace:GetServerTimeNow() > SpinConfig.MaxBoostSeconds - product.Seconds then
				return "Boost is full", false
			end
		end
		local cost = price(Enum.InfoType.Product, entry.Id)
		return `R$ {cost or "?"}`, true
	end

	local function buy(entry: Entry)
		if entry.IsPass then
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, entry.Id)
		else
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, entry.Id)
		end
	end

	local function priceButton(parent: Instance, entry: Entry, shop: any, big: boolean): TextButton
		local text, enabled = buttonState(entry, shop)
		local button = Theme.Button(parent, text, if big then "Gold" else "Primary", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = if big then UDim2.new(1, -24, 0, 50) else UDim2.new(1, -16, 0, 36),
			TextSize = if big then 22 else 16,
		})
		Theme.SetEnabled(button, enabled)
		button.Activated:Connect(function()
			if not button:GetAttribute("Disabled") then
				buy(entry)
			end
		end)
		return button
	end

	-- A coloured picture tile: the item's glyph (or the bundle's pet) on a soft glow.
	local function art(parent: Instance, entry: Entry, height: number)
		local box = Theme.Make("Frame", {
			BackgroundColor3 = entry.Color:Lerp(Theme.Colors.PanelSunken, 0.55),
			Size = UDim2.new(1, -16, 0, height),
			Position = UDim2.fromOffset(8, 30),
		}, parent)
		Theme.Corner(box, 10)
		Theme.Gradient(box, 1, 0.6)
		local species = entry.Pass and entry.Pass.Grants and entry.Pass.Grants.Species
		if species then
			Viewport.Creature(box, species, { Size = UDim2.fromScale(1, 1) }, { Spin = true })
		else
			Theme.Text(box, entry.Glyph, height * 0.55, {
				FontFace = Theme.Heavy,
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextColor3 = entry.Color:Lerp(Color3.new(1, 1, 1), 0.25),
				TextStrokeTransparency = 0.4,
			})
		end
	end

	local function smallCard(parent: Instance, entry: Entry, shop: any, order: number)
		local card = Theme.Panel(parent, { LayoutOrder = order })
		Theme.Text(card, entry.Name, 16, {
			FontFace = Theme.Bold,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 20),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			TextScaled = true,
		})
		art(card, entry, 92)
		Theme.Text(card, entry.Description, 13, {
			Position = UDim2.fromOffset(8, 126),
			Size = UDim2.new(1, -16, 0, 34),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		priceButton(card, entry, shop, false)
	end

	local function bigCard(parent: Instance, entry: Entry, shop: any)
		local card = Theme.Panel(parent, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
		})
		Theme.Padding(card, 10, 12)
		Theme.List(card, 8, nil, Enum.HorizontalAlignment.Center)
		Theme.Text(card, entry.Name, 22, {
			FontFace = Theme.Title,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = Theme.Colors.TextShadow,
			TextStrokeTransparency = 0.3,
			LayoutOrder = 1,
		})
		local badge = entry.Pass and entry.Pass.Badge
		if badge then
			Theme.Chip(card, badge, Theme.Colors.Gold, { LayoutOrder = 2 })
		end
		local holder = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 170),
			LayoutOrder = 3,
		}, card)
		art(holder, entry, 160)
		local pic = holder:FindFirstChildOfClass("Frame")
		if pic then
			pic.Position = UDim2.fromOffset(8, 5)
		end
		Theme.Text(card, entry.Description, 15, {
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 4,
		})
		local buttonHolder = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 62),
			LayoutOrder = 5,
		}, card)
		priceButton(buttonHolder, entry, shop, true)
	end

	-- Tabs ------------------------------------------------------------------------------
	local tabsRow = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
	}, win.Body)
	Theme.List(tabsRow, 8, Enum.FillDirection.Horizontal)
	local tabButtons: { [string]: TextButton } = {}
	local glyphs = { Featured = "★", Coins = "●", Essence = "✧", Boosts = "⚡", Passes = "♛" }
	for order, tabId in MonetizationConfig.Tabs do
		local id: string = tabId :: any
		local button = Theme.Button(tabsRow, `{glyphs[id] or ""} {id}`, "Secondary", {
			Size = UDim2.fromOffset(if Theme.IsTouch() then 108 else 118, 40),
			LayoutOrder = order,
			TextSize = 16,
		})
		button.Activated:Connect(function()
			tab = id
			task.spawn(render)
		end)
		tabButtons[id] = button
	end

	local content = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, win.Body)
	Theme.List(content, 12)

	render = function()
		rendering += 1
		local mine = rendering
		local list = entries()
		-- Fetch prices first (this can yield), then draw once; a newer render wins.
		for _, entry in list do
			if entry.Id ~= 0 then
				price(if entry.IsPass then Enum.InfoType.GamePass else Enum.InfoType.Product, entry.Id)
			end
		end
		if mine ~= rendering then
			return
		end
		for id, button in tabButtons do
			Theme.SetStyle(button, if id == tab then "Primary" else "Secondary")
		end
		Window.Clear(content)
		local shop = State.Get("Shop") or { Passes = {}, BoostUntil = 0 }

		-- Running boosts
		local now = os.time()
		local running = {}
		if (shop.BoostUntil or 0) > now then
			table.insert(running, `⚡ 2x Farm Speed · {Format.Duration(shop.BoostUntil - now)}`)
		end
		local spin = State.Get("Spin")
		local luck = spin and spin.Boosts and spin.Boosts.Luck or 0
		local serverNow = Workspace:GetServerTimeNow()
		if luck > serverNow then
			table.insert(running, `✦ 2x Luck · {Format.Duration(luck - serverNow)}`)
		end
		if #running > 0 then
			Theme.Text(content, "Active: " .. table.concat(running, "   "), 15, {
				TextColor3 = Theme.Colors.Gold,
				LayoutOrder = 0,
			})
		end

		local shown = {}
		for _, entry in list do
			if (tab == "Featured" and entry.Featured) or entry.Tab == tab then
				table.insert(shown, entry)
			end
		end
		-- The bundle gets the big card at the top of Featured and Passes.
		local bundle: Entry? = nil
		for i, entry in shown do
			if entry.Pass and entry.Pass.Badge then
				bundle = table.remove(shown, i)
				break
			end
		end
		if bundle then
			bigCard(content, bundle, shop)
		end
		if #shown > 0 then
			local grid = Theme.Make("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			}, content)
			Theme.Make("UIGridLayout", {
				CellSize = UDim2.fromOffset(170, 210),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}, grid)
			for order, entry in shown do
				smallCard(grid, entry, shop, order)
			end
		end
		Theme.Text(
			content,
			"Nothing random is ever sold. Gold, Essence and boosts can also be earned by playing.",
			13,
			{ TextColor3 = Theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 9 }
		)
	end

	State.OnChanged("Shop", function()
		if ctx.IsOpen("Shop") then
			task.spawn(render)
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			task.spawn(render) -- prices are fetched (may yield)
		end,
	}
end

return ShopWindow
