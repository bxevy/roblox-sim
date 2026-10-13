-- Crate window: pick a crate, pay, and watch a spinning reel land on your prize.
-- The server decides the prize; the reel is just the reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Util = require(script.Parent.Util)

local TILE_WIDTH = 116
local TILE_GAP = 6
local REEL_TILES = 46
local WIN_INDEX = 40
local SPIN_TIME = 4.2

local CrateWindow = {}

-- open(crateId) asks the server; returns (ok, resultOrError).
function CrateWindow.new(gui: ScreenGui, open: (crateId: string) -> (boolean, any), onResult: (result: any) -> ())
	local self: any = {}
	local spinning = false

	local window, body
	window, body = Util.window(gui, "Crate Shrine", Vector2.new(700, 520), function()
		if not spinning then
			window.Visible = false
		end
	end)
	local goldLabel = Util.text(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -54, 0, 14),
		Size = UDim2.fromOffset(160, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 210, 80),
	})

	-- Crate cards ------------------------------------------------------------------
	local openButtons: { TextButton } = {}
	local count = #Config.CrateOrder
	for i, crateId in Config.CrateOrder do
		local crate = Config.Crates[crateId]
		local set = Items.ArmorSets[crate.Set]
		local card = Util.panel(body, {
			Position = UDim2.new((i - 1) / count, 4, 0, 0),
			Size = UDim2.new(1 / count, -8, 0, 250),
			BackgroundColor3 = Util.ButtonColor,
			BackgroundTransparency = 0,
		})
		Util.stroke(card, crate.Color, 0, 2)
		Util.text(card, {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 0, 30),
			TextColor3 = crate.Color,
			Text = crate.DisplayName,
		})
		Util.text(card, {
			Position = UDim2.fromOffset(10, 40),
			Size = UDim2.new(1, -20, 0, 22),
			TextColor3 = Config.Rarities.Godly,
			Text = `Godly set: {set.DisplayName}`,
		})
		Util.text(card, {
			Position = UDim2.fromOffset(10, 64),
			Size = UDim2.new(1, -20, 0, 20),
			TextColor3 = Color3.fromRGB(200, 200, 210),
			Text = set.SetBonus.Description,
		})
		for k, entry in crate.Odds do
			Util.text(card, {
				Position = UDim2.fromOffset(16, 92 + (k - 1) * 24),
				Size = UDim2.new(1, -32, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Config.Rarities[entry.Rarity],
				Text = `{entry.Rarity} armor piece  -  {entry.Chance * 100}%`,
			})
		end
		local button = Util.button(card, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 44),
			BackgroundColor3 = Color3.fromRGB(60, 140, 70),
			Text = `Open - {crate.Price} Gold`,
		})
		button.Activated:Connect(function()
			self.Spin(crateId)
		end)
		table.insert(openButtons, button)
	end

	-- Reel ---------------------------------------------------------------------------
	local reel = Util.panel(body, {
		Position = UDim2.fromOffset(0, 262),
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = Color3.fromRGB(15, 13, 18),
		BackgroundTransparency = 0,
		ClipsDescendants = true,
	})
	local strip = Util.make("Frame", reel, {
		Size = UDim2.new(0, REEL_TILES * (TILE_WIDTH + TILE_GAP), 1, -20),
		Position = UDim2.fromOffset(0, 10),
		BackgroundTransparency = 1,
	})
	-- Centre marker
	Util.make("Frame", reel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 220, 120),
		BorderSizePixel = 0,
		ZIndex = 5,
	})
	local resultLabel = Util.text(body, {
		Position = UDim2.fromOffset(0, 402),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Open a crate to try for Godly armor!",
	})

	local function tile(index: number, piece: Items.ArmorDef)
		local frame = Util.panel(strip, {
			Position = UDim2.fromOffset((index - 1) * (TILE_WIDTH + TILE_GAP), 0),
			Size = UDim2.new(0, TILE_WIDTH, 1, 0),
			BackgroundColor3 = Color3.fromRGB(40, 36, 46),
			BackgroundTransparency = 0,
		})
		Util.make("Frame", frame, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = Config.Rarities[piece.Rarity],
			BorderSizePixel = 0,
		})
		Util.text(frame, {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 20),
			TextColor3 = Config.Rarities[piece.Rarity],
			Text = piece.Rarity,
		})
		Util.text(frame, {
			Position = UDim2.fromOffset(6, 28),
			Size = UDim2.new(1, -12, 1, -44),
			TextScaled = true,
			TextWrapped = true,
			Text = piece.DisplayName,
		})
	end

	-- Filler tiles follow the crate's odds so the reel looks honest.
	local function randomPiece(crate): Items.ArmorDef
		local roll, rarity = math.random(), crate.Odds[#crate.Odds].Rarity
		for _, entry in crate.Odds do
			roll -= entry.Chance
			if roll <= 0 then
				rarity = entry.Rarity
				break
			end
		end
		local pool = if rarity == "Godly" then {} else Items.LootArmorsOfRarity(rarity)
		if rarity == "Godly" then
			for _, pieceId in Items.ArmorSets[crate.Set].Pieces do
				table.insert(pool, Items.Armors[pieceId])
			end
		end
		return pool[math.random(#pool)]
	end

	function self.Spin(crateId: string)
		if spinning then
			return
		end
		spinning = true
		for _, button in openButtons do
			button.AutoButtonColor = false
			button.BackgroundTransparency = 0.5
		end
		resultLabel.Text = "Opening..."
		local ok, result = open(crateId)
		if not ok then
			resultLabel.Text = tostring(result)
			spinning = false
			for _, button in openButtons do
				button.AutoButtonColor = true
				button.BackgroundTransparency = 0
			end
			return
		end

		Util.clear(strip)
		local crate = Config.Crates[crateId]
		for i = 1, REEL_TILES do
			tile(i, if i == WIN_INDEX then Items.Armors[result.Id] else randomPiece(crate))
		end
		strip.Position = UDim2.fromOffset(0, 10)
		local reelWidth = reel.AbsoluteSize.X
		local jitter = math.random(-TILE_WIDTH * 0.35, TILE_WIDTH * 0.35)
		local target = -((WIN_INDEX - 1) * (TILE_WIDTH + TILE_GAP) + TILE_WIDTH / 2 - reelWidth / 2 + jitter)
		local tween = TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(target, 10),
		})
		tween:Play()
		tween.Completed:Wait()

		local color = Config.Rarities[result.Rarity]
		resultLabel.TextColor3 = color
		resultLabel.Text = if result.IsNew
			then `You got {result.Rarity} {result.DisplayName}!`
			else `Duplicate {result.DisplayName} - refunded {result.Refund} Gold`
		onResult(result)
		spinning = false
		for _, button in openButtons do
			button.AutoButtonColor = true
			button.BackgroundTransparency = 0
		end
	end

	function self.Render(state)
		goldLabel.Text = `{state.Gold} Gold`
	end

	function self.Open()
		window.Visible = true
	end

	return self
end

return CrateWindow
