--!strict
-- Builds the map pieces the game needs from code, so a fresh Baseplate place just works.
-- Feel free to replace these with hand-built models in Studio later.

local Players = game:GetService("Players")

local GameService = require(script.Parent.GameService)

local WorldService = {}

local SELL_PAD_POSITION = Vector3.new(0, 0.6, -25)
local SELL_DEBOUNCE = 1

local function makeLabel(parent: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
end

local function buildSellPad()
	local pad = Instance.new("Part")
	pad.Name = "SellPad"
	pad.Anchored = true
	pad.Size = Vector3.new(12, 1, 12)
	pad.Position = SELL_PAD_POSITION
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(80, 220, 100)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Parent = workspace
	makeLabel(pad, "SELL")

	local lastSell: { [Player]: number } = {}
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastSell[player] or 0) < SELL_DEBOUNCE then
			return
		end
		lastSell[player] = now
		GameService.Sell(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSell[player] = nil
	end)
end

function WorldService.Start()
	buildSellPad()
end

return WorldService
