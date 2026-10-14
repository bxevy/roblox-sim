--!strict
-- Befriending a wild creature: shows the exact chance (and why) before you throw a lure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureConfig = require(Shared.Config.CreatureConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Encounter = require(Shared.Util.Encounter)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)
local Viewport = require(script.Parent.Viewport)

local BefriendWindow = {}

function BefriendWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Befriend", "❂", Vector2.new(460, 520), ctx.Close)
	Theme.List(win.Body, 8, nil, Enum.HorizontalAlignment.Center)

	local function render(wildId: string, speciesId: string)
		Window.Clear(win.Body)
		local species = CreatureConfig.Species[speciesId]
		if not species then
			return
		end
		local rarity = RarityConfig.Get(species.Rarity)
		local art = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(180, 160) }, win.Body)
		local known = (State.Get("Collection") or {})[speciesId] ~= nil
		Viewport.Creature(art, speciesId, nil, { Spin = true })
		Theme.Text(
			win.Body,
			`Wild {species.Name}`,
			24,
			{ FontFace = Theme.Heavy, TextXAlignment = Enum.TextXAlignment.Center }
		)
		Theme.Chip(win.Body, RarityConfig.Label(species.Rarity), rarity.Color)
		if not known then
			Theme.Chip(win.Body, "★ Not in your journal yet", Theme.Colors.Gold)
		end
		-- Same calculation the server uses.
		local creatures = State.Get("Creatures")
		local companion = nil
		for _, c in creatures and creatures.List or {} do
			if c.Companion then
				companion = c
			end
		end
		local chance = Encounter.BefriendChance(
			speciesId,
			if companion then { Species = companion.Species, Level = companion.Level, Stage = companion.Stage } else nil
		)
		Theme.Text(
			win.Body,
			`Chance to befriend: <b>{math.floor(chance * 100 + 0.5)}%</b>`,
			20,
			{ TextXAlignment = Enum.TextXAlignment.Center }
		)
		local why = if companion
			then `With {companion.Name} beside you` .. (if CreatureConfig.Species[companion.Species].Family
					== species.Family
				then " (same family: +15%)"
				else "") .. ". Lucky companions help too."
			else "Tip: a companion of the same family adds +15%."
		Theme.Text(win.Body, why, 13, { TextColor3 = Theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center })
		local wallet = State.Get("Wallet")
		local lures = wallet and wallet.Resources.EmberLure or 0
		Theme.Text(win.Body, `Ember Lures: {lures}. Win or lose, the creature leaves afterwards.`, 13, {
			TextColor3 = Theme.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local throw = Theme.Button(win.Body, "❂ Throw a lure", "Primary", { Size = UDim2.fromOffset(240, 44) })
		Theme.SetEnabled(throw, lures >= 1)
		throw.Activated:Connect(function()
			if throw:GetAttribute("Disabled") then
				ctx.Notify("Craft Ember Lures at the plaza Trading Post (5 Emberstone + 10 Moonpetals).", "Error")
				return
			end
			Theme.SetEnabled(throw, false)
			local ok, result = ctx.Request("Befriend", wildId)
			ctx.Close()
			if not ok then
				ctx.Notify(result, "Error")
			end
			-- On a miss the server sends the "ran off" message.
		end)
	end

	return {
		Root = win.Root,
		Open = function(arg: any)
			render(arg.WildId, arg.Species)
		end,
	}
end

return BefriendWindow
