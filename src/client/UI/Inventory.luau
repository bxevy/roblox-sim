-- Gear window: owned weapons and armor, click to equip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local WeaponMoves = require(ReplicatedStorage.Shared.WeaponMoves)
local Util = require(script.Parent.Util)

local CLASS_FOR_TYPE = { Sword = "Warrior", Staff = "Mage", Bow = "Ranger", Dagger = "Assassin", Tome = "Healer", Mace = "Treasurer" }

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

	local function row(order: number, title: string, subtitle: string, titleColor: Color3, equipped: boolean, usable: boolean, onClick: () -> (), detail: string?)
		local button = Util.button(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, if detail then 96 else 56),
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
		if detail then
			Util.text(button, {
				Position = UDim2.fromOffset(10, 52),
				Size = UDim2.new(1, -20, 0, 38),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				TextColor3 = Color3.fromRGB(170, 200, 255),
				TextTransparency = if usable then 0 else 0.4,
				Text = detail,
			})
		end
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
					local moves = WeaponMoves.Combos[weapon.Combo]
					local detail = `Combo: {moves.DisplayName} ({#moves.Steps} hits)\n[R] {weapon.Skill.Name}: {weapon.Skill.Description}`
					row(order, `{weapon.DisplayName}{if equipped then "  (equipped)" else ""}`, `T{weapon.Tier} {weapon.Rarity} | {table.concat(parts, " | ")}`, Config.Rarities[weapon.Rarity], equipped, usable, function()
						if usable and not equipped then
							equip("Weapon", id)
						end
					end, detail)
				end
			end
		else
			-- Armor grouped by set: a header (with set bonus) then the pieces you own.
			local order = 0
			for _, setId in Items.ArmorSetOrder do
				local set = Items.ArmorSets[setId]
				local owned = 0
				for _, pieceId in set.Pieces do
					if state.Armors[pieceId] then
						owned += 1
					end
				end
				if owned > 0 then
					order += 1
					local active = state.FullSet == setId
					Util.text(list, {
						LayoutOrder = order,
						Size = UDim2.new(1, -10, 0, 40),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Config.Rarities[set.Rarity],
						TextScaled = false,
						TextSize = 17,
						TextWrapped = true,
						Text = `{set.DisplayName} ({set.Rarity}) {owned}/4\nSet bonus{if active then " ACTIVE" else ""}: {set.SetBonus.Description}`,
					})
					for _, slot in Items.ArmorSlots do
						local pieceId = set.Pieces[slot]
						if state.Armors[pieceId] then
							order += 1
							local piece = Items.Armors[pieceId]
							local equipped = state.Equipped[slot] == pieceId
							row(order, `{piece.DisplayName}{if equipped then "  (equipped)" else ""}`, `{slot} | +{piece.Health} HP | {string.format("%.1f", piece.Defense * 100)}% defense`, Config.Rarities[piece.Rarity], equipped, true, function()
								equip("Armor", pieceId)
							end)
						end
					end
				end
			end
			if order == 0 then
				Util.text(list, { Size = UDim2.new(1, -10, 0, 40), Text = "No armor yet - clear dungeons or open crates!", TextColor3 = Color3.fromRGB(180, 180, 190) })
			end
		end
	end

	function self.Toggle()
		window.Visible = not window.Visible
	end

	return self
end

return Inventory
