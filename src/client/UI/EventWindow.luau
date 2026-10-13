-- Halloween event window (K, or the pumpkin altar in town): candies, time left, the
-- Halloween Crate with its full odds, an opening reveal, your pets and the limited class.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(script.Parent.Util)

local EventWindow = {}

local ORANGE = Color3.fromRGB(255, 140, 30)
local PURPLE = Color3.fromRGB(150, 80, 220)
local event = Config.Events.Halloween
local crate = event.Crate

local function entryName(entry): string
	if entry.Kind == "Class" then
		return `{Config.Classes[entry.Id].DisplayName} (CLASS)`
	elseif entry.Kind == "Armor" then
		return `{Items.ArmorSets[entry.Id].DisplayName} armor piece`
	end
	return `{Pets.Defs[entry.Id].DisplayName} (pet)`
end

local function entryRarity(entry): string
	if entry.Kind == "Class" then
		return Config.Classes[entry.Id].Rarity
	elseif entry.Kind == "Armor" then
		return Items.ArmorSets[entry.Id].Rarity
	end
	return Pets.Defs[entry.Id].Rarity
end

local function formatOdds(chance: number): string
	local percent = chance * 100
	local text = if percent >= 10 then string.format("%.0f", percent) else string.format("%.2f", percent)
	return (text:gsub("%.?0+$", "")) .. "%"
end

local function timeLeft(): string
	local seconds = math.max(0, event.EndsAt - os.time())
	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds % 86400 / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if days > 0 then
		return `{days}d {hours}h left`
	end
	return `{hours}h {minutes}m left`
end

-- actions: Open(currency) -> (ok, result|message), EquipPet(id?), EquipClass(id)
function EventWindow.new(gui: ScreenGui, actions, toast: (string, boolean?) -> ())
	local self: any = {}
	local state = nil
	local revealing = false

	local window, body
	window, body = Util.window(gui, "Halloween Event", Vector2.new(660, 640), function()
		window.Visible = false
	end)

	local hasIcon = event.Icon ~= ""
	if hasIcon then
		Util.make("ImageLabel", body, {
			Size = UDim2.fromOffset(46, 46),
			BackgroundTransparency = 1,
			Image = event.Icon,
		})
	end
	local header = Util.text(body, {
		Position = UDim2.fromOffset(if hasIcon then 54 else 0, 0),
		Size = UDim2.new(1, if hasIcon then -54 else 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = ORANGE,
		Text = "",
	})
	Util.text(body, {
		Position = UDim2.fromOffset(if hasIcon then 54 else 0, 28),
		Size = UDim2.new(1, if hasIcon then -54 else 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 190, 210),
		Text = `Clear the Haunted Manor for {event.CandiesPerClear} candies. Crates: {crate.CandyCost} candies or {crate.RobuxPriceLabel}.`,
	})

	-- Left: crate, odds and reveal --------------------------------------------------
	local left = Util.make("Frame", body, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(0.55, -6, 1, -54), BackgroundTransparency = 1 })
	local reveal = Util.panel(left, {
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundColor3 = Color3.fromRGB(20, 12, 25),
		BackgroundTransparency = 0,
	})
	Util.make("UIStroke", reveal, { Color = ORANGE, Thickness = 2 })
	local revealName = Util.text(reveal, { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 44), Text = "Open a Halloween Crate!" })
	local revealInfo = Util.text(reveal, { Position = UDim2.fromOffset(8, 54), Size = UDim2.new(1, -16, 0, 26), TextColor3 = Color3.fromRGB(200, 200, 210), Text = "" })

	local candyButton = Util.button(left, {
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(0.5, -4, 0, 46),
		BackgroundColor3 = ORANGE,
		Text = `Open ({crate.CandyCost} candies)`,
	})
	local robuxButton = Util.button(left, {
		Position = UDim2.new(0.5, 4, 0, 98),
		Size = UDim2.new(0.5, -4, 0, 46),
		BackgroundColor3 = Color3.fromRGB(40, 160, 90),
		Text = `Open ({crate.RobuxPriceLabel})`,
	})
	Util.text(left, {
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Crate odds",
	})
	local odds = Util.list(left, { Position = UDim2.fromOffset(0, 172), Size = UDim2.new(1, 0, 1, -172) })
	for i, entry in crate.Odds do
		local rarity = entryRarity(entry)
		local row = Util.panel(odds, { LayoutOrder = i, Size = UDim2.new(1, -10, 0, 28), BackgroundColor3 = Util.ButtonColor, BackgroundTransparency = 0 })
		Util.text(row, {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -80, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Config.Rarities[rarity] or Color3.new(1, 1, 1),
			Text = `{entryName(entry)} - {rarity}`,
		})
		Util.text(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.fromOffset(70, 28),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = formatOdds(entry.Chance),
		})
	end

	-- Right: limited class and pets -----------------------------------------------------
	local right = Util.make("Frame", body, { Position = UDim2.new(0.55, 6, 0, 54), Size = UDim2.new(0.45, -6, 1, -54), BackgroundTransparency = 1 })
	local classPanel = Util.panel(right, { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Util.ButtonColor, BackgroundTransparency = 0 })
	Util.make("UIStroke", classPanel, { Color = Config.Rarities.Limited, Thickness = 2 })
	local limitedId = Config.LimitedClassOrder[1]
	local limited = Config.Classes[limitedId]
	Util.text(classPanel, { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 24), TextColor3 = Config.Rarities.Limited, Text = `LIMITED CLASS: {limited.DisplayName}` })
	Util.text(classPanel, {
		Position = UDim2.fromOffset(8, 30),
		Size = UDim2.new(1, -16, 0, 44),
		TextScaled = false,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(215, 215, 225),
		Text = `{limited.Passive}\n[Q] {Config.Abilities[limited.Abilities[1]].DisplayName}  [E] {Config.Abilities[limited.Abilities[2]].DisplayName}`,
	})
	local classButton = Util.button(classPanel, {
		Position = UDim2.new(0, 8, 1, -40),
		Size = UDim2.new(1, -16, 0, 32),
		Text = "",
	})
	classButton.Activated:Connect(function()
		if state and state.LimitedClasses[limitedId] and state.Class ~= limitedId then
			actions.EquipClass(limitedId)
		end
	end)

	Util.text(right, { Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Text = "Your pets" })
	local petList = Util.list(right, { Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 1, -150) })

	-- Reveal: flick through the prizes, then land on what you won.
	local function showResult(result)
		if not result then
			return
		end
		revealing = true
		local names = {}
		for _, entry in crate.Odds do
			table.insert(names, { entryName(entry), Config.Rarities[entryRarity(entry)] })
		end
		local steps = 22
		for i = 1, steps do
			local pick = names[math.random(#names)]
			revealName.Text = pick[1]
			revealName.TextColor3 = pick[2]
			revealInfo.Text = ""
			Util.playSfx("Click")
			task.wait(0.04 + (i / steps) ^ 2 * 0.22)
		end
		local color = Config.Rarities[result.Rarity] or Color3.new(1, 1, 1)
		revealName.Text = result.DisplayName
		revealName.TextColor3 = color
		if result.IsNew then
			revealInfo.Text = `{result.Rarity} {if result.Kind == "Armor" then "armor" elseif result.Kind == "Pet" then "pet" else "CLASS"} - NEW!`
		else
			revealInfo.Text = `Duplicate - +{result.Refund} candies`
		end
		Util.playSfx(if result.Rarity == "Limited" or result.Rarity == "Legendary" then "LevelUp" else "Coins")
		if result.IsNew then
			toast(`You got {result.DisplayName}!`)
		end
		revealing = false
	end

	local function open(currency: string)
		if revealing then
			return
		end
		local ok, result = actions.Open(currency)
		if not ok then
			if type(result) == "string" then
				toast(result, true)
			end
			return
		end
		if currency ~= "Robux" then
			task.spawn(showResult, result)
		end
	end
	candyButton.Activated:Connect(function()
		open("Candies")
	end)
	robuxButton.Activated:Connect(function()
		open("Robux")
	end)
	Remotes.HalloweenCrateResult.OnClientEvent:Connect(function(result)
		window.Visible = true
		task.spawn(showResult, result)
	end)

	local function renderPets()
		Util.clear(petList)
		if not state then
			return
		end
		local order = 0
		for _, petId in Pets.Order do
			if state.Pets[petId] then
				order += 1
				local def = Pets.Defs[petId]
				local equipped = state.EquippedPet == petId
				local row = Util.panel(petList, {
					LayoutOrder = order,
					Size = UDim2.new(1, -10, 0, 50),
					BackgroundColor3 = if equipped then Color3.fromRGB(50, 95, 55) else Util.ButtonColor,
					BackgroundTransparency = 0,
				})
				Util.text(row, { Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -96, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Config.Rarities[def.Rarity], Text = def.DisplayName })
				Util.text(row, { Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -96, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 210), Text = Pets.Describe(def) })
				local button = Util.button(row, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Size = UDim2.fromOffset(80, 32),
					BackgroundColor3 = if equipped then Color3.fromRGB(120, 60, 60) else Color3.fromRGB(60, 130, 70),
					Text = if equipped then "Unequip" else "Equip",
				})
				button.Activated:Connect(function()
					actions.EquipPet(if equipped then nil else petId)
				end)
			end
		end
		if order == 0 then
			Util.text(petList, { Size = UDim2.new(1, -10, 0, 40), TextColor3 = Color3.fromRGB(170, 170, 180), Text = "No pets yet - open a crate!" })
		end
	end

	function self.Render(newState)
		state = newState
		header.Text = `Candies: {state.Candies}    |    {if workspace:GetAttribute("HalloweenActive") then timeLeft() else "Event over"}`
		local owned = state.LimitedClasses[limitedId] == true
		if not owned then
			classButton.Text = "Win it from the crate (0.5%)"
			classButton.BackgroundColor3 = Color3.fromRGB(70, 60, 80)
		elseif state.Class == limitedId then
			classButton.Text = "Equipped"
			classButton.BackgroundColor3 = Color3.fromRGB(50, 95, 55)
		else
			classButton.Text = `Become a {limited.DisplayName}`
			classButton.BackgroundColor3 = PURPLE
		end
		renderPets()
	end

	function self.Toggle()
		window.Visible = not window.Visible
	end
	function self.Open()
		window.Visible = true
	end

	-- Keep the countdown ticking
	task.spawn(function()
		while true do
			task.wait(30)
			if state then
				self.Render(state)
			end
		end
	end)

	return self
end

return EventWindow
