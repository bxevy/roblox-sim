--!strict
-- Inventory: every currency and material you hold, what it's for, and storage limits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local InventoryWindow = {}

local ORDER = { "Gold", "Essence", "EmpireShards", "Moonpetal", "RawCrystal", "RefinedCrystal" }

function InventoryWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Inventory", "▤", Vector2.new(600, 560), ctx.Close)
	Theme.List(win.Body, 10)

	local function render()
		Window.Clear(win.Body)
		local wallet = State.Get("Wallet")
		if not wallet then
			Theme.Text(win.Body, "Loading…", 16)
			return
		end
		for order, id in ORDER do
			local def = ResourceConfig[id]
			if def and def.Enabled ~= false then -- switched-off items aren't shown
				local isCurrency = def.Kind == "Currency"
				local amount = if isCurrency then wallet.Currencies[id] or 0 else wallet.Resources[id] or 0
				local capacity = wallet.Capacity and wallet.Capacity[id]
				local card = Window.Section(win.Body, nil, order)
				local amountText = Format.Number(math.floor(amount))
					.. (if capacity then ` / {Format.Number(capacity)}` else "")
				Theme.Text(
					card,
					`<font color="#{def.Color:ToHex()}">{def.Icon}</font>  <b>{def.Name}</b>  ·  {amountText}`,
					18
				)
				Theme.Text(card, def.Description, 14, { TextColor3 = Theme.Colors.Muted })
				local notes = {}
				table.insert(
					notes,
					if isCurrency then "Currency (no storage limit)" else "Material (stored in your Resource Silo)"
				)
				if def.SellPrice then
					table.insert(notes, `sells for {def.SellPrice} gold at the Trading Post`)
				end
				Theme.Text(card, table.concat(notes, " · "), 12, { TextColor3 = Theme.Colors.Muted })
				if capacity and capacity > 0 then
					local _, set = Theme.Bar(card, def.Color, 6)
					set(amount / capacity)
				end
			end
		end
	end

	State.OnChanged("Wallet", function()
		if ctx.IsOpen("Inventory") then
			render()
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			render()
		end,
	}
end

return InventoryWindow
