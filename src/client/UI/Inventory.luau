-- Gear window: owned weapons and armor, click to equip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Util = require(script.Parent.Util)

local CLASS_FOR_TYPE = { Sword = "Warrior", Staff = "Mage", Bow = "Ranger" }

local Inventory = {}

function Inventory.new(gui: ScreenGui, equip: (kind: string, id: string) -> ())
	local self: any = {}
	local tab = "Weapon"
	local lastState = nil

	local window, body
	window, body = Util.window(gui, "Gear", Vector2.new(420, 440), function()
		window.Visible = false
	end)

	local tabs = Util.make("Frame", body, { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 })
	local list = Util.list(body, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })

	local tabButtons = {}
	for i, kind in { "Weapon", "Armor" } do
		local button = Util.button(tabs, {
			Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 4, 0, 0),
			Size = UDim2.new(0.5, -4, 1, 0),
			Text = if kind == "Weapon" then "Weapons" else "Armor",
		})
		button.Activated:Connect(function()
			tab = kind
			if lastState then
				self.Render(lastState)
			end
		end)
		tabButtons[kind] = button
	end

	local function row(order: number, title: string, subtitle: string, titleColor: Color3, equipped: boolean, usable: boolean, onClick: () -> ())
		local button = Util.button(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 56),
			BackgroundColor3 = if equipped then Color3.fromRGB(50, 105, 55) elseif usable then Util.ButtonColor else Color3.fromRGB(40, 36, 44),
			Text = "",
			AutoButtonColor = usable,
		})
		Util.text(button, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = titleColor,
			TextTransparency = if usable then 0 else 0.4,
			Text = title,
		})
		Util.text(button, {
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -20, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			TextTransparency = if usable then 0 else 0.4,
			Text = subtitle,
		})
		button.Activated:Connect(onClick)
	end

	function self.Render(state)
		lastState = state
		for kind, button in tabButtons do
			button.BackgroundColor3 = if kind == tab then Color3.fromRGB(110, 75, 40) else Util.ButtonColor
		end
		Util.clear(list)

		local class = state.Class and Config.Classes[state.Class]
		if tab == "Weapon" then
			for order, id in Items.WeaponOrder do
				if state.Weapons[id] then
					local weapon = Items.Weapons[id]
					local usable = class ~= nil and class.WeaponType == weapon.Type
					local equipped = state.Equipped.Weapon == id
					local parts = { `{weapon.Damage} dmg`, `{weapon.Type}` }
					local effect = Items.DescribeEffect(weapon.Effect)
					if effect then
						table.insert(parts, effect)
					end
					if not usable then
						table.insert(parts, `{CLASS_FOR_TYPE[weapon.Type]} only`)
					end
					row(order, `{weapon.DisplayName}{if equipped then "  (equipped)" else ""}`, `T{weapon.Tier} {weapon.Rarity} | {table.concat(parts, " | ")}`, Config.Rarities[weapon.Rarity], equipped, usable, function()
						if usable and not equipped then
							equip("Weapon", id)
						end
					end)
				end
			end
		else
			local any = false
			for order, id in Items.ArmorOrder do
				if state.Armors[id] then
					any = true
					local armor = Items.Armors[id]
					local equipped = state.Equipped.Armor == id
					row(order, `{armor.DisplayName}{if equipped then "  (equipped - click to remove)" else ""}`, `T{armor.Tier} {armor.Rarity} | +{armor.Health} HP | {math.floor(armor.Defense * 100)}% defense`, Config.Rarities[armor.Rarity], equipped, true, function()
						equip("Armor", id)
					end)
				end
			end
			if not any then
				Util.text(list, { Size = UDim2.new(1, -10, 0, 40), Text = "No armor yet - clear dungeons to find some!", TextColor3 = Color3.fromRGB(180, 180, 190) })
			end
		end
	end

	function self.Toggle()
		window.Visible = not window.Visible
	end

	return self
end

return Inventory
