-- Potion shop window (opened from the shop stall in the lobby).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local Shop = {}

function Shop.new(gui: ScreenGui, buy: (potionId: string) -> ())
	local self = {}

	local window, body
	window, body = Util.window(gui, "Potion Shop", Vector2.new(440, 420), function()
		window.Visible = false
	end)
	local goldLabel = Util.text(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -54, 0, 14),
		Size = UDim2.fromOffset(140, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 210, 80),
	})
	local list = Util.list(body)

	local countLabels: { [string]: TextLabel } = {}
	for order, potionId in Config.PotionOrder do
		local potion = Config.Potions[potionId]
		local row = Util.panel(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 60),
			BackgroundColor3 = Util.ButtonColor,
			BackgroundTransparency = 0,
		})
		local swatch = Util.make("Frame", row, {
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.fromOffset(28, 40),
			BackgroundColor3 = potion.Color,
		})
		Util.corner(swatch, 8)
		Util.text(row, {
			Position = UDim2.fromOffset(46, 6),
			Size = UDim2.new(1, -160, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `[{order}] {potion.DisplayName}`,
		})
		Util.text(row, {
			Position = UDim2.fromOffset(46, 32),
			Size = UDim2.new(1, -160, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = potion.Description,
		})
		countLabels[potionId] = Util.text(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -104, 0, 18),
			Size = UDim2.fromOffset(40, 24),
			TextColor3 = Color3.fromRGB(200, 200, 210),
		})
		local buyButton = Util.button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(90, 40),
			BackgroundColor3 = Color3.fromRGB(60, 140, 70),
			Text = `{potion.Price} G`,
		})
		buyButton.Activated:Connect(function()
			buy(potionId)
		end)
	end

	function self.Render(state)
		goldLabel.Text = `{state.Gold} Gold`
		for potionId, label in countLabels do
			label.Text = `x{state.Potions[potionId] or 0}`
		end
	end

	function self.Open()
		window.Visible = true
	end

	return self
end

return Shop
