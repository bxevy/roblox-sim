-- Difficulty picker shown while standing on a dungeon portal pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local PortalPanel = {}

local TIER_NAMES = { "Common", "Uncommon", "Uncommon", "Rare", "Rare", "Epic", "Epic", "Legendary" }

function PortalPanel.new(gui: ScreenGui, setDifficulty: (difficultyId: string) -> ())
	local self = {}

	local frame = Util.panel(gui, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(270, 60 + #Config.DifficultyOrder * 62 + 40),
		Visible = false,
	})
	local title = Util.text(frame, {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 32),
	})

	local buttons: { [string]: TextButton } = {}
	for i, difficultyId in Config.DifficultyOrder do
		local button = Util.button(frame, {
			Position = UDim2.fromOffset(10, 48 + (i - 1) * 62),
			Size = UDim2.new(1, -20, 0, 56),
			TextScaled = false,
			TextSize = 16,
			TextWrapped = true,
		})
		button.Activated:Connect(function()
			setDifficulty(difficultyId)
		end)
		buttons[difficultyId] = button
	end

	local footer = Util.text(frame, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.new(1, -20, 0, 30),
		TextColor3 = Color3.fromRGB(255, 220, 150),
	})

	function self.Update(info)
		frame.Visible = info ~= nil
		if not info then
			return
		end
		title.Text = info.DisplayName
		for _, entry in info.Difficulties do
			local difficulty = Config.Difficulties[entry.Id]
			local button = buttons[entry.Id]
			local selected = info.Difficulty == entry.Id
			local lowTier, highTier = entry.LootTiers[1], entry.LootTiers[#entry.LootTiers]
			local loot = if lowTier == highTier then TIER_NAMES[lowTier] else `{TIER_NAMES[lowTier]}-{TIER_NAMES[highTier]}`
			if entry.Unlocked then
				local tierText = if lowTier == highTier then `T{lowTier}` else `T{lowTier}-{highTier}`
				button.Text = `{difficulty.DisplayName}{if selected then "  (selected)" else ""}\nLoot: {tierText} {loot}`
				button.BackgroundColor3 = if selected then difficulty.Color:Lerp(Color3.new(0, 0, 0), 0.35) else Util.ButtonColor
				button.TextColor3 = if selected then Color3.new(1, 1, 1) else difficulty.Color
			else
				button.Text = `{difficulty.DisplayName} - LOCKED\nReach level {entry.Level}`
				button.BackgroundColor3 = Color3.fromRGB(40, 36, 44)
				button.TextColor3 = Color3.fromRGB(130, 130, 140)
			end
		end
		footer.Text = if info.Countdown
			then `Starting in {info.Countdown}  ({info.PartySize}/{Config.Party.MaxSize})`
			else "Waiting for players..."
	end

	return self
end

return PortalPanel
