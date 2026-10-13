--!strict
-- The building panel: status, production, workers, synergies, upgrades, and the
-- type-specific sections (Trading Post sales, silo capacity, core tiers, habitat).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared.Config.BuildingConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local JobConfig = require(Shared.Config.JobConfig)
local Production = require(Shared.Util.Production)
local Hatching = require(Shared.Util.Hatching)
local Evolution = require(Shared.Util.Evolution)
local EggConfig = require(Shared.Config.EggConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)
local Viewport = require(script.Parent.Viewport)

local BuildingPanel = {}

-- Human-readable differences between two levels of a building.
local function levelChanges(from: any, to: any): { string }
	local changes = {}
	if to.Slots and to.Slots ~= from.Slots then
		table.insert(changes, `Worker slots {from.Slots or 0} → <b>{to.Slots}</b>`)
	end
	if to.Storage and to.Storage ~= from.Storage then
		table.insert(changes, `Storage {Format.Number(from.Storage or 0)} → <b>{Format.Number(to.Storage)}</b>`)
	end
	if to.CycleTime and to.CycleTime ~= from.CycleTime then
		table.insert(changes, `Growth time {from.CycleTime}s → <b>{to.CycleTime}s</b>`)
	end
	if to.YieldPerCycle and to.YieldPerCycle ~= from.YieldPerCycle then
		table.insert(changes, `Harvest size ×{from.YieldPerCycle} → <b>×{to.YieldPerCycle}</b>`)
	end
	for resource, amount in to.Capacity or {} do
		local before = from.Capacity and from.Capacity[resource] or 0
		if amount ~= before then
			local def = ResourceConfig[resource]
			table.insert(
				changes,
				`{def and def.Name or resource} capacity {Format.Number(before)} → <b>{Format.Number(amount)}</b>`
			)
		end
	end
	for typeId, limit in to.BuildingLimits or {} do
		local before = from.BuildingLimits and from.BuildingLimits[typeId] or 0
		if limit ~= before then
			table.insert(changes, `Max {BuildingConfig[typeId].Name}s {before} → <b>{limit}</b>`)
		end
	end
	if to.EmpireBonus and to.EmpireBonus ~= from.EmpireBonus then
		table.insert(
			changes,
			`Creature yield bonus +{Format.Percent(from.EmpireBonus or 0)} → <b>+{Format.Percent(to.EmpireBonus)}</b>`
		)
	end
	return changes
end

function BuildingPanel.new(ctx: any)
	local State = ctx.Controllers.State
	local Buildings = ctx.Controllers.Building
	local win = Window.new(ctx.Gui, "Building", "⌂", Vector2.new(640, 600), ctx.Close)
	Theme.List(win.Body, 10)

	local buildingId: string? = nil
	local liveStorage: { Label: TextLabel, Set: (number) -> () }? = nil
	local picking = false

	local render: () -> ()

	local function request(name: string, ...: any): (boolean, any)
		local ok, result = ctx.Request(name, ...)
		if not ok then
			ctx.Notify(result, "Error")
		end
		return ok, result
	end

	local function productionSection(info: any, def: any)
		local card = Window.Section(win.Body, "PRODUCTION", 2)
		local output = info.Output and ResourceConfig[info.Output]
		local label = Theme.Text(card, "", 17, { FontFace = Theme.Bold })
		local _, setBar = Theme.Bar(card, output and output.Color or Theme.Colors.Primary, 10)
		liveStorage = { Label = label, Set = setBar }
		local perMinute = info.PerSecond * 60
		Theme.Text(
			card,
			if perMinute > 0
				then `Producing {Format.Rate(perMinute)} {output and output.Name or ""} per minute`
				else "Not producing: assign a creature below.",
			15,
			{ TextColor3 = if perMinute > 0 then Theme.Colors.Success else Theme.Colors.Warning }
		)
		-- Recipes that consume silo materials (smelter, condenser).
		local inputs = {}
		local wallet = State.Get("Wallet")
		for resource, per in info.InputsPerUnit or {} do
			local def2 = ResourceConfig[resource]
			local have = wallet and (wallet.Resources[resource] or wallet.Currencies[resource]) or 0
			table.insert(
				inputs,
				`{Format.Rate(per)} {def2 and def2.Name or resource} (you have {Format.Number(math.floor(have))})`
			)
		end
		if #inputs > 0 then
			Theme.Text(
				card,
				`Uses from your silo, per {output and output.Name or "unit"}: ` .. table.concat(inputs, ", "),
				14,
				{
					TextColor3 = Theme.Colors.Muted,
				}
			)
		end
		if info.Starved then
			Theme.Text(card, "⚠ Paused: not enough materials in your silo. Collect from your mines and farms.", 14, {
				TextColor3 = Theme.Colors.Warning,
			})
		end
		if perMinute > 0 and info.Capacity and not info.Starved then
			local stored = info.Stored[info.Output] or 0
			local seconds = (info.Capacity - stored) / info.PerSecond
			Theme.Text(
				card,
				if seconds > 1
					then `Full in about {Format.Duration(seconds)}`
					else "Storage is full. Collect to keep production going!",
				13,
				{
					TextColor3 = Theme.Colors.Muted,
				}
			)
		end
		for _, buff in info.Buffs or {} do
			Theme.Text(
				card,
				`⚡ {buff.Stat} +{Format.Percent(buff.Value)} for {Format.Duration(buff.Remaining)}`,
				14,
				{ TextColor3 = Theme.Colors.Gold }
			)
		end
		local collect = Theme.Button(card, "Collect", "Primary", { Size = UDim2.fromOffset(180, 38) })
		collect.Activated:Connect(function()
			local ok, amount = request("Collect", info.Id)
			if ok then
				ctx.Notify(`Collected {Format.Number(amount)} {output and output.Name or ""}.`, "Success")
			end
		end)

		-- Workers
		local job = def.Job and JobConfig[def.Job]
		local workers =
			Window.Section(win.Body, `WORKERS ({#info.Assigned}/{info.Slots}) · {job and job.Name or ""}`, 3)
		local creatures = State.Get("Creatures")
		local list = creatures and creatures.List or {}
		local perWorker = {}
		for _, w in info.Workers do
			perWorker[w.CreatureId] = w.PerSecond
		end
		for _, creatureId in info.Assigned do
			local c = list[creatureId]
			if c then
				local row = Window.Row(workers, 48)
				local face = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 44) }, row)
				Viewport.Creature(face, c.Species)
				Theme.Text(
					row,
					`<b>{c.Name}</b> Lv {c.Level} · {Format.Rate((perWorker[creatureId] or 0) * 60)}/min`,
					15,
					{
						Size = UDim2.new(1, -190, 1, 0),
						AutomaticSize = Enum.AutomaticSize.None,
						TextYAlignment = Enum.TextYAlignment.Center,
					}
				)
				local remove =
					Theme.Button(row, "Unassign", "Secondary", { Size = UDim2.fromOffset(120, 34), TextSize = 15 })
				remove.Activated:Connect(function()
					request("AssignCreature", creatureId, nil)
				end)
			end
		end
		for _ = #info.Assigned + 1, info.Slots do
			local empty = Theme.Button(workers, "+ Assign a creature", "Ghost", { Size = UDim2.new(1, 0, 0, 40) })
			empty.Activated:Connect(function()
				picking = not picking
				render()
			end)
		end
		if picking then
			local coreLevel = State.Get("Buildings").List.core.Level
			local candidates = 0
			for id, c in list do
				if c.Assignment ~= info.Id then
					local species = CreatureConfig.Species[c.Species]
					local affinity = if species then CreatureConfig.Affinity(species, c.Stage, def.Job) else 0
					if affinity > 0 then
						candidates += 1
						local worker = Production.WorkerAt(
							{ Buildings = { core = { Level = coreLevel } } } :: any,
							{ Id = id, Species = c.Species, Level = c.Level, Stage = c.Stage } :: any,
							{ Type = info.Type, Level = info.Level } :: any,
							nil
						)
						local rarity = RarityConfig.Get(species.Rarity)
						local row = Window.Row(workers, 44)
						Theme.Text(
							row,
							`<font color="#{rarity.Color:ToHex()}">{rarity.Glyph}</font> <b>{c.Name}</b> · {Format.Percent(
								affinity
							)} skill · ≈ {Format.Rate((worker and worker.PerSecond or 0) * 60)}/min`
								.. (if c.Assignment then " · <i>busy elsewhere</i>" else ""),
							14,
							{
								Size = UDim2.new(1, -130, 1, 0),
								AutomaticSize = Enum.AutomaticSize.None,
								TextYAlignment = Enum.TextYAlignment.Center,
							}
						)
						local assign =
							Theme.Button(row, "Assign", "Primary", { Size = UDim2.fromOffset(120, 34), TextSize = 15 })
						assign.Activated:Connect(function()
							local ok = request("AssignCreature", id, info.Id)
							if ok then
								picking = false
								ctx.Notify(`{c.Name} is heading to work!`, "Success")
							end
						end)
					end
				end
			end
			if candidates == 0 then
				Theme.Text(workers, "No other creature can do this job yet.", 14, { TextColor3 = Theme.Colors.Muted })
			end
		end

		local synergy = Window.Section(win.Body, "SYNERGIES", 4)
		Theme.Text(
			synergy,
			"No active synergies. Certain creature families will boost each other when they work side by side (coming in a later update).",
			14,
			{
				TextColor3 = Theme.Colors.Muted,
			}
		)
	end

	local function upgradeSection(info: any, def: any)
		if #def.Levels <= 1 then
			return
		end
		local card = Window.Section(win.Body, "UPGRADE", 6)
		local current = def.Levels[info.Level]
		local nextLevel = def.Levels[info.Level + 1]
		if not nextLevel then
			Theme.Text(
				card,
				"Fully upgraded. More levels arrive with new updates.",
				15,
				{ TextColor3 = Theme.Colors.Success }
			)
			return
		end
		Theme.Text(card, `Level {info.Level} → <b>{info.Level + 1}</b>`, 18, { FontFace = Theme.Heavy })
		if nextLevel.Description then
			Theme.Text(card, nextLevel.Description, 14, { TextColor3 = Theme.Colors.Muted })
		end
		for _, line in levelChanges(current, nextLevel) do
			Theme.Text(card, "• " .. line, 15)
		end
		local wallet = State.Get("Wallet")
		local affordable = true
		for currency, amount in nextLevel.Cost or {} do
			if (wallet.Currencies[currency] or wallet.Resources[currency] or 0) < amount then
				affordable = false
			end
		end
		local costText = Format.Cost(nextLevel.Cost or {}, ResourceConfig)
		local button = Theme.Button(card, "Upgrade · " .. costText, "Gold", { Size = UDim2.fromOffset(280, 42) })
		if info.UpgradeBlocker then
			Theme.Text(card, "✖ " .. info.UpgradeBlocker, 14, { TextColor3 = Theme.Colors.Warning })
			Theme.SetEnabled(button, false)
		elseif not affordable then
			Theme.Text(card, "Not enough gold yet.", 14, { TextColor3 = Theme.Colors.Muted })
			Theme.SetEnabled(button, false)
		end
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") then
				ctx.Notify(info.UpgradeBlocker or "You need " .. costText .. ".", "Error")
				return
			end
			local ok = request("UpgradeBuilding", info.Id)
			if ok then
				ctx.Notify(`{def.Name} upgraded to level {info.Level + 1}!`, "Reward")
			end
		end)
	end

	local function tradingSection()
		local card = Window.Section(win.Body, "SELL MATERIALS", 2)
		local wallet = State.Get("Wallet")
		local ids = {}
		for id, def in ResourceConfig do
			if def.Kind == "Material" and def.SellPrice then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			local def = ResourceConfig[id]
			local have = wallet and wallet.Resources[id] or 0
			Theme.Text(
				card,
				`<font color="#{def.Color:ToHex()}">{def.Icon}</font> <b>{def.Name}</b>: {Format.Number(have)} · {def.SellPrice} gold each`,
				16
			)
			local row = Window.Row(card, 40)
			for _, amount in { 10, 50 } do
				local b =
					Theme.Button(row, `Sell {amount}`, "Secondary", { Size = UDim2.fromOffset(110, 36), TextSize = 15 })
				Theme.SetEnabled(b, have >= amount)
				b.Activated:Connect(function()
					if b:GetAttribute("Disabled") then
						return
					end
					local ok, gold = request("Sell", id, amount)
					if ok then
						ctx.Notify(`Sold {amount} {def.Name} for {Format.Number(gold)} gold.`, "Success")
					end
				end)
			end
			local all = Theme.Button(
				row,
				`Sell all · {Format.Number(have * def.SellPrice)} gold`,
				"Gold",
				{ Size = UDim2.fromOffset(220, 36), TextSize = 15 }
			)
			Theme.SetEnabled(all, have > 0)
			all.Activated:Connect(function()
				if all:GetAttribute("Disabled") then
					return
				end
				local ok, gold = request("Sell", id, "All")
				if ok then
					ctx.Notify(`Sold for {Format.Number(gold)} gold.`, "Success")
				end
			end)
		end
	end

	local function siloSection()
		local card = Window.Section(win.Body, "STORED MATERIALS", 2)
		local wallet = State.Get("Wallet")
		for id, capacity in wallet and wallet.Capacity or {} do
			local def = ResourceConfig[id]
			local have = wallet.Resources[id] or 0
			Theme.Text(card, `{def.Icon} {def.Name}: {Format.Number(have)} / {Format.Number(capacity)}`, 16)
			local _, set = Theme.Bar(card, def.Color, 8)
			set(have / math.max(capacity, 1))
		end
		Theme.Text(
			card,
			"Collected materials go here. When it's full, farms can't be emptied until you sell or upgrade.",
			13,
			{
				TextColor3 = Theme.Colors.Muted,
			}
		)
	end

	local function coreSection(info: any, def: any)
		local card = Window.Section(win.Body, "EMPIRE TIERS", 2)
		for level, data in def.Levels do
			local limits = {}
			for typeId, limit in data.BuildingLimits or {} do
				table.insert(limits, `{limit} {BuildingConfig[typeId].Name}s`)
			end
			local prefix = if level == info.Level then "▶ " elseif level < info.Level then "✔ " else "   "
			Theme.Text(
				card,
				`{prefix}<b>Tier {level}</b>: {table.concat(limits, ", ")} · +{Format.Percent(data.EmpireBonus or 0)} creature yield`,
				15,
				{
					TextColor3 = if level <= info.Level then Theme.Colors.Text else Theme.Colors.Muted,
				}
			)
		end
		Theme.Text(
			card,
			"Other buildings can be at most one level above your Empire Core's tier.",
			13,
			{ TextColor3 = Theme.Colors.Muted }
		)
	end

	local function expansionSection()
		local card = Window.Section(win.Body, "EXPAND YOUR LAND", 3)
		local empire = State.Get("Empire") or {}
		local owned = empire.Expansions or {}
		local core = State.Get("Buildings").List.core
		local wallet = State.Get("Wallet")
		for _, zone in PlotConfig.ExpansionZones do
			local row = Window.Row(card, 44)
			local label = `<b>{zone.Name}</b> · 4 more rows of land · {Format.Cost(zone.Cost, ResourceConfig)}`
			Theme.Text(row, label, 14, {
				Size = UDim2.new(1, -150, 1, 0),
				AutomaticSize = Enum.AutomaticSize.None,
				TextYAlignment = Enum.TextYAlignment.Center,
			})
			local button = Theme.Button(row, "Buy land", "Gold", { Size = UDim2.fromOffset(140, 34), TextSize = 15 })
			local reason: string? = nil
			if owned[zone.Id] then
				reason = "Owned"
				button.Text = "✔ Owned"
			elseif core.Level < zone.CoreTier then
				reason = `Needs Empire Core tier {zone.CoreTier}.`
				button.Text = `Tier {zone.CoreTier}`
			else
				for id, amount in zone.Cost do
					if (wallet.Currencies[id] or wallet.Resources[id] or 0) < amount then
						reason = "You need " .. Format.Cost(zone.Cost, ResourceConfig) .. "."
					end
				end
			end
			Theme.SetEnabled(button, reason == nil)
			button.Activated:Connect(function()
				if reason then
					if reason ~= "Owned" then
						ctx.Notify(reason, "Error")
					end
					return
				end
				local ok = request("BuyExpansion", zone.Id)
				if ok then
					ctx.Notify(`{zone.Name} is yours! The fence has moved out.`, "Reward")
				end
			end)
		end
	end

	local function hatcherySection()
		local card = Window.Section(win.Body, "EGGS", 2)
		local empire = State.Get("Empire") or {}
		local hatchery = State.Get("Hatchery") or { Pity = {} }
		local wallet = State.Get("Wallet")
		Theme.Text(
			card,
			`Your habitat holds {empire.CreatureCount or 0} / {empire.CreatureCapacity or 6} creatures. Hatched creatures can be traded later on.`,
			14,
			{
				TextColor3 = Theme.Colors.Muted,
			}
		)
		for order, eggId in EggConfig.Order do
			local egg = EggConfig.Eggs[eggId]
			local box = Theme.Make("Frame", {
				BackgroundColor3 = Theme.Colors.PanelSunken,
				BackgroundTransparency = 0.2,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = order,
			}, card)
			Theme.Corner(box, 10)
			Theme.Stroke(box, egg.Color, 0.5)
			Theme.Padding(box, 10)
			local art = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(90, 110) }, box)
			Viewport.Egg(art, egg.Color, egg.Spots)
			local text = Theme.Make("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(100, 0),
				Size = UDim2.new(1, -100, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, box)
			Theme.List(text, 4)
			Theme.Text(text, `<b>{egg.Name}</b> · {Format.Cost(egg.Cost, ResourceConfig)}`, 17)
			Theme.Text(text, egg.Description, 13, { TextColor3 = Theme.Colors.Muted })
			-- Exact odds, rarest first, with rarity glyph + word (never colour alone).
			for _, entry in Hatching.Odds(egg) do
				local species = CreatureConfig.Species[entry.Species]
				local rarity = RarityConfig.Get(entry.Rarity)
				local owned = (State.Get("Collection") or {})[entry.Species] ~= nil
				local chance = entry.Chance * 100
				local percent = if chance < 10 then string.format("%.1f%%", chance) else string.format("%.0f%%", chance)
				Theme.Text(
					text,
					`<font color="#{rarity.Color:ToHex()}">{rarity.Glyph} {rarity.Label}</font>  {if owned
						then species.Name
						else "??? (" .. species.Name .. ")"}  ·  <b>{percent}</b>`,
					13
				)
			end
			local pity = hatchery.Pity[eggId] or 0
			local guaranteed = Hatching.PityReady(egg, pity)
			Theme.Text(
				text,
				if guaranteed
					then `<b>Next hatch is guaranteed {RarityConfig.Label(egg.PityRarity)} or better!</b>`
					else `Pity: {pity} / {egg.PityLimit - 1}. A {RarityConfig.Label(egg.PityRarity)} or better is guaranteed within {egg.PityLimit} hatches; the counter resets when you hatch one.`,
				12,
				{ TextColor3 = if guaranteed then Theme.Colors.Gold else Theme.Colors.Muted }
			)
			local _, setPity = Theme.Bar(text, Theme.Colors.Gold, 6)
			setPity(pity / math.max(egg.PityLimit - 1, 1))
			local affordable = true
			for id, amount in egg.Cost do
				if (wallet.Currencies[id] or wallet.Resources[id] or 0) < amount then
					affordable = false
				end
			end
			local full = (empire.CreatureCount or 0) >= (empire.CreatureCapacity or 6)
			local button = Theme.Button(
				text,
				if full then "Habitat full" else "Hatch",
				"Primary",
				{ Size = UDim2.fromOffset(180, 38) }
			)
			Theme.SetEnabled(button, affordable and not full)
			button.Activated:Connect(function()
				if button:GetAttribute("Disabled") then
					ctx.Notify(
						if full
							then "Your habitat is full. Upgrade it to make room."
							else "You need " .. Format.Cost(egg.Cost, ResourceConfig) .. ".",
						"Error"
					)
					return
				end
				request("HatchEgg", eggId)
			end)
		end
	end

	local function chamberSection()
		local card = Window.Section(win.Body, "READY TO EVOLVE?", 2)
		local creatures = State.Get("Creatures")
		local wallet = State.Get("Wallet") or { Currencies = {}, Resources = {} }
		local any = false
		for id, c in creatures and creatures.List or {} do
			local check = Evolution.Check(
				wallet,
				{
					Species = c.Species,
					Stage = c.Stage,
					Level = c.Level,
					JobCycles = c.JobCycles or {},
					WorkCycles = c.WorkCycles,
				} :: any
			)
			if check.NextStage then
				any = true
				local met = 0
				for _, r in check.Requirements do
					if r.Met then
						met += 1
					end
				end
				local row = Window.Row(card, 40)
				Theme.Text(
					row,
					`<b>{c.Name}</b> → {check.NextStage.Name} · {met}/{#check.Requirements} requirements`,
					14,
					{
						Size = UDim2.new(1, -150, 1, 0),
						AutomaticSize = Enum.AutomaticSize.None,
						TextYAlignment = Enum.TextYAlignment.Center,
					}
				)
				local open = Theme.Button(
					row,
					if check.Ready then "Evolve!" else "Details",
					if check.Ready then "Gold" else "Secondary",
					{
						Size = UDim2.fromOffset(140, 34),
						TextSize = 15,
					}
				)
				open.Activated:Connect(function()
					ctx.Open("Creatures", id)
				end)
			end
		end
		if not any then
			Theme.Text(card, "Every creature is fully evolved. Impressive!", 15, { TextColor3 = Theme.Colors.Muted })
		end
	end

	local function habitatSection()
		local empire = State.Get("Empire") or {}
		local card = Window.Section(
			win.Body,
			`RESTING CREATURES · {empire.CreatureCount or 0} / {empire.CreatureCapacity or 6} housed`,
			2
		)
		local creatures = State.Get("Creatures")
		local any = false
		for id, c in creatures and creatures.List or {} do
			if not c.Assignment then
				any = true
				local row = Window.Row(card, 40)
				Theme.Text(row, `<b>{c.Name}</b> Lv {c.Level}`, 15, {
					Size = UDim2.new(1, -130, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					TextYAlignment = Enum.TextYAlignment.Center,
				})
				local open =
					Theme.Button(row, "Details", "Secondary", { Size = UDim2.fromOffset(120, 34), TextSize = 15 })
				open.Activated:Connect(function()
					ctx.Open("Creatures", id)
				end)
			end
		end
		if not any then
			Theme.Text(card, "Everyone is at work. Busy little empire!", 15, { TextColor3 = Theme.Colors.Muted })
		end
	end

	render = function()
		Window.Clear(win.Body)
		liveStorage = nil
		local buildings = State.Get("Buildings")
		local info = buildingId and buildings and buildings.List[buildingId]
		if not info then
			Theme.Text(win.Body, "This building is gone.", 16)
			return
		end
		local def = BuildingConfig[info.Type]
		win.SetTitle(`{def.Name} · Level {info.Level}`)
		local head = Window.Section(win.Body, nil, 1)
		Theme.Text(head, def.Description, 15)
		if def.Locked then
			Theme.Text(head, "🔒 " .. def.Locked, 15, { TextColor3 = Theme.Colors.Warning })
		end

		if info.Type == "TradingPost" then
			tradingSection()
		elseif info.Type == "ResourceSilo" then
			siloSection()
		elseif info.Type == "EmpireCore" then
			coreSection(info, def)
			expansionSection()
		elseif info.Type == "Hatchery" then
			hatcherySection()
		elseif info.Type == "EvolutionChamber" then
			chamberSection()
		elseif info.Type == "Habitat" then
			habitatSection()
		elseif def.Recipe then
			productionSection(info, def)
		end
		upgradeSection(info, def)
		if def.Placeable then
			local move = Theme.Button(win.Body, "⇄ Move this building", "Secondary", {
				Size = UDim2.fromOffset(220, 38),
				LayoutOrder = 20,
			})
			move.Activated:Connect(function()
				ctx.Close()
				ctx.Controllers.Placement.Begin(info.Type, { MoveId = info.Id, Rot = info.Rot })
			end)
		end
	end

	-- Keep the storage line live between server updates.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if liveStorage and buildingId and ctx.IsOpen("Building") then
				local stored, capacity, output = Buildings.PredictedStored(buildingId)
				local def = output and ResourceConfig[output]
				liveStorage.Label.Text =
					`{def and def.Icon or ""} {Format.Number(math.floor(stored))} / {Format.Number(capacity)} stored`
				liveStorage.Set(if capacity > 0 then stored / capacity else 0)
			end
		end
	end)

	local function refreshIfOpen()
		if ctx.IsOpen("Building") then
			local scroll = win.Body.CanvasPosition
			render()
			win.Body.CanvasPosition = scroll
		end
	end
	-- Coalesce refreshes: Buildings updates arrive every few seconds while producing.
	local pending = false
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.delay(0.3, function()
			pending = false
			refreshIfOpen()
		end)
	end
	local lastSignature = ""
	State.OnChanged("Buildings", function(b)
		local info = buildingId and b.List[buildingId]
		-- Ignore pure storage ticks; the live label handles those.
		local signature = if info
			then `{info.Level}:{#info.Assigned}:{#info.Buffs}:{info.PerSecond}:{info.UpgradeBlocker}:{info.Starved}`
			else "gone"
		if signature ~= lastSignature then
			lastSignature = signature
			schedule()
		end
	end)
	State.OnChanged("Wallet", schedule)
	State.OnChanged("Empire", schedule)
	State.OnChanged("Hatchery", schedule)

	return {
		Root = win.Root,
		Open = function(id: any)
			buildingId = id
			picking = false
			render()
		end,
	}
end

return BuildingPanel
