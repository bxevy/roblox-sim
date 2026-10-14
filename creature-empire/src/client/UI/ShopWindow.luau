--!strict
-- The optional shop (MonetizationConfig): cosmetics and convenience only, with the price
-- and exactly what you get. Items whose ids aren't configured show as "coming soon".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

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

function ShopWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Shop", "⚡", Vector2.new(560, 560), ctx.Close)
	Theme.List(win.Body, 10)

	local function itemCard(order: number, glyph: string, name: string, description: string): Frame
		local card = Window.Section(win.Body, nil, order)
		Theme.Text(card, `<b>{glyph} {name}</b>`, 18)
		Theme.Text(card, description, 14, { TextColor3 = Theme.Colors.Muted })
		return card
	end

	local rendering = 0
	local function render()
		rendering += 1
		local mine = rendering
		-- Fetch prices first (this can yield), then draw once; a newer render wins.
		for _, pass in MonetizationConfig.Passes do
			if pass.Id ~= 0 then
				price(Enum.InfoType.GamePass, pass.Id)
			end
		end
		for _, product in MonetizationConfig.Products do
			if product.Id ~= 0 then
				price(Enum.InfoType.Product, product.Id)
			end
		end
		if mine ~= rendering then
			return
		end
		Window.Clear(win.Body)
		local shop = State.Get("Shop") or { Passes = {}, BoostUntil = 0 }
		local intro = Window.Section(win.Body, nil, 0)
		Theme.Text(
			intro,
			"Everything here is optional. Nothing random is ever sold, and everything that helps you can also be earned by playing.",
			14
		)
		local order = 1
		for key, pass in MonetizationConfig.Passes do
			local card = itemCard(order, pass.Glyph, pass.Name, pass.Description)
			order += 1
			local owned = shop.Passes[key] == true
			local configured = pass.Id ~= 0
			local cost = if configured and not owned then price(Enum.InfoType.GamePass, pass.Id) else nil
			local button = Theme.Button(
				card,
				if owned then "✔ Owned" elseif not configured then "Coming soon" else `Buy · {cost or "?"} R$`,
				"Gold",
				{ Size = UDim2.fromOffset(200, 38) }
			)
			Theme.SetEnabled(button, configured and not owned)
			button.Activated:Connect(function()
				if configured and not owned then
					MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
				end
			end)
		end
		for _, product in MonetizationConfig.Products do
			local card = itemCard(order, product.Glyph, product.Name, product.Description)
			order += 1
			local configured = product.Id ~= 0
			if product.Kind == "Boost" then
				local left = math.max((shop.BoostUntil or 0) - os.time(), 0)
				if left > 0 then
					Theme.Text(card, `Active: {Format.Duration(left)} left.`, 14, { TextColor3 = Theme.Colors.Success })
				end
			end
			local full = product.Kind == "Boost"
				and (shop.BoostUntil or 0) - os.time() > MonetizationConfig.Boost.MaxSeconds - product.Seconds
			local cost = if configured then price(Enum.InfoType.Product, product.Id) else nil
			local button = Theme.Button(
				card,
				if not configured then "Coming soon" elseif full then "Boost is full" else `Buy · {cost or "?"} R$`,
				"Primary",
				{ Size = UDim2.fromOffset(200, 38) }
			)
			Theme.SetEnabled(button, configured and not full)
			button.Activated:Connect(function()
				if configured and not full then
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
				end
			end)
		end
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
