-- Class selection window. Opens automatically until you pick a class.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local ClassPicker = {}

local ABILITY_KEYS = { "Q", "E" }

function ClassPicker.new(gui: ScreenGui, choose: (classId: string) -> ())
	local self = {}
	local hasClass = false

	local window, body
	window, body = Util.window(gui, "Choose your class", Vector2.new(640, 340), function()
		if hasClass then
			window.Visible = false
		end
	end)

	local count = #Config.ClassOrder
	local cards: { [string]: TextButton } = {}
	for i, classId in Config.ClassOrder do
		local class = Config.Classes[classId]
		local card = Util.button(body, {
			Position = UDim2.new((i - 1) / count, 4, 0, 0),
			Size = UDim2.new(1 / count, -8, 1, 0),
			BackgroundColor3 = Util.ButtonColor,
			Text = "",
		})
		Util.padding(card, 10)
		Util.make("UIStroke", card, { Color = class.Color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		Util.text(card, {
			Size = UDim2.new(1, 0, 0, 32),
			TextColor3 = class.Color,
			Text = class.DisplayName,
		})
		local abilityNames = {}
		for k, abilityId in class.Abilities do
			table.insert(abilityNames, `[{ABILITY_KEYS[k]}] {Config.Abilities[abilityId].DisplayName}`)
		end
		Util.text(card, {
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 1, -40),
			TextScaled = false,
			TextSize = 15,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = `{class.Description}\n\nWeapon: {class.WeaponType}\nHealth x{class.HealthMultiplier}\nDamage x{class.DamageMultiplier}\nSpeed x{class.SpeedMultiplier}\n\n{table.concat(abilityNames, "\n")}`,
		})
		card.Activated:Connect(function()
			choose(classId)
		end)
		cards[classId] = card
	end

	function self.Render(state)
		hasClass = state.Class ~= nil
		for classId, card in cards do
			card.BackgroundColor3 = if state.Class == classId then Color3.fromRGB(50, 90, 55) else Util.ButtonColor
		end
		if not hasClass then
			window.Visible = true
		end
	end

	function self.Open()
		window.Visible = true
	end

	function self.Close()
		window.Visible = false
	end

	return self
end

return ClassPicker
