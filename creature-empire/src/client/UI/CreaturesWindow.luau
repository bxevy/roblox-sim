--!strict
-- Creatures window: your creatures (details, job assignment, ability) and the collection
-- journal (every species, discovered or not).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared.Config.BuildingConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local JobConfig = require(Shared.Config.JobConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Production = require(Shared.Util.Production)
local Evolution = require(Shared.Util.Evolution)
local Format = require(Shared.Util.Format)
local MutationConfig = require(Shared.Config.MutationConfig)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)
local Viewport = require(script.Parent.Viewport)

local CreaturesWindow = {}

local STAT_NAMES = {}
for _, stat in CreatureConfig.Stats do
	STAT_NAMES[stat.Id] = stat.Name
end

function CreaturesWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Creatures", "❦", Vector2.new(900, 600), ctx.Close)
	Theme.List(win.Body, 10)

	local selected: string? = nil
	local tab = "Mine"

	-- Tabs
	local tabs = Window.Row(win.Body, 40, 0)
	local mineTab = Theme.Button(tabs, "My creatures", "Primary", { Size = UDim2.fromOffset(160, 36) })
	local journalTab = Theme.Button(tabs, "Collection journal", "Secondary", { Size = UDim2.fromOffset(190, 36) })

	local content = Theme.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	}, win.Body)

	local render: () -> ()

	mineTab.Activated:Connect(function()
		tab = "Mine"
		render()
	end)
	journalTab.Activated:Connect(function()
		tab = "Journal"
		render()
	end)

	-- Preview: production per minute if this creature worked at a building.
	local function previewRate(info: any, building: any): number
		local buildings = State.Get("Buildings")
		local coreLevel = buildings and buildings.List.core and buildings.List.core.Level or 1
		local fakeData: any = { Buildings = { core = { Level = coreLevel } } }
		local worker = Production.WorkerAt(
			fakeData,
			{ Id = info.Id, Species = info.Species, Level = info.Level, Stage = info.Stage } :: any,
			{ Type = building.Type, Level = building.Level } :: any,
			nil
		)
		return worker and worker.PerSecond * 60 or 0
	end

	local function detail(parent: Instance, info: any)
		local species = CreatureConfig.Species[info.Species]
		local family = CreatureConfig.Families[species.Family]
		local rarity = RarityConfig.Get(species.Rarity)
		local buildings = State.Get("Buildings")

		local column = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -250, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
		}, parent)
		Theme.List(column, 10)

		-- Header: portrait + identity
		local header = Window.Section(column, nil, 1)
		local top = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150) }, header)
		local portrait = Theme.Make("Frame", {
			BackgroundColor3 = Theme.Colors.PanelSunken,
			Size = UDim2.fromOffset(150, 150),
		}, top)
		Theme.Corner(portrait, 12)
		Theme.Stroke(portrait, rarity.Color, 0.4, 2)
		Viewport.Creature(portrait, info.Species, nil, { Spin = true, Stage = info.Stage, Mutation = info.Mutation })
		local identity = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(164, 0),
			Size = UDim2.new(1, -164, 1, 0),
		}, top)
		Theme.List(identity, 6)
		Theme.Text(identity, info.Name, 26, { FontFace = Theme.Heavy })
		local chips = Window.Row(identity, 24)
		Theme.Chip(chips, RarityConfig.Label(species.Rarity), rarity.Color)
		Theme.Chip(chips, family.Glyph .. " " .. family.Name, family.Color)
		Theme.Chip(chips, CreatureConfig.StageNames[info.Stage] or "Juvenile", Theme.Colors.Border)
		local mutation = info.Mutation and MutationConfig.Mutations[info.Mutation]
		if mutation then
			Theme.Chip(chips, `{mutation.Glyph} {mutation.Name}`, mutation.Color)
			Theme.Text(identity, mutation.Description, 13, { TextColor3 = mutation.Color })
		end
		Theme.Text(
			identity,
			`Level {info.Level}  ·  {Format.Number(info.Xp)} / {Format.Number(info.XpToNext)} XP`,
			15,
			{ FontFace = Theme.Bold }
		)
		local _, setXp = Theme.Bar(identity, Theme.Colors.Primary, 8)
		setXp(info.Xp / math.max(info.XpToNext, 1))
		Theme.Text(
			identity,
			`<i>{species.Idle.Personality}.</i> {species.Description}`,
			14,
			{ TextColor3 = Theme.Colors.Muted }
		)

		-- Job
		local jobCard = Window.Section(column, "JOB", 2)
		local status = info.Task
		if info.Assignment and info.PerSecond > 0 then
			status ..= `  ·  {Format.Rate(info.PerSecond * 60)} {ResourceConfig.Moonpetal.Icon}/min`
		end
		Theme.Text(jobCard, status, 17, { FontFace = Theme.Bold })
		local resting = math.max((info.RestUntilServer or 0) - Workspace:GetServerTimeNow(), 0)
		if resting > 0 and not info.Expedition then
			Theme.Text(
				jobCard,
				`Resting after an expedition: ready to explore again in {Format.Duration(resting)}.`,
				13,
				{
					TextColor3 = Theme.Colors.Muted,
				}
			)
		end
		-- Companion: follows you into the wild, helps befriend and gather, and resists heat.
		if not info.Expedition then
			local follow = Theme.Button(
				jobCard,
				if info.Companion then "Stop following" else "★ Take with me",
				if info.Companion then "Secondary" else "Gold",
				{ Size = UDim2.fromOffset(200, 36), TextSize = 15 }
			)
			follow.Activated:Connect(function()
				local ok, result = ctx.Request("SetCompanion", if info.Companion then nil else info.Id)
				if not ok then
					ctx.Notify(result, "Error")
				elseif not info.Companion then
					ctx.Notify(
						`{info.Name} will follow you. Companions help you befriend wild creatures and gather.`,
						"Success"
					)
				end
			end)
		end
		if info.SpeedMultiplier then
			Theme.Text(
				jobCard,
				`Work speed {Format.Percent(info.SpeedMultiplier)} · Yield {Format.Percent(info.YieldMultiplier)} (includes level, passive and empire bonuses)`,
				13,
				{ TextColor3 = Theme.Colors.Muted }
			)
		end
		if buildings and not info.Expedition then
			local ids = {}
			for id, b in buildings.List do
				local def = BuildingConfig[b.Type]
				if def and def.Job then
					table.insert(ids, id)
				end
			end
			table.sort(ids)
			for _, id in ids do
				local b = buildings.List[id]
				local def = BuildingConfig[b.Type]
				local affinity = CreatureConfig.Affinity(species, info.Stage, def.Job :: string)
				local row = Window.Row(jobCard, 40)
				local here = info.Assignment == id
				local used = #b.Assigned
				local label = `{def.Name} (Lv {b.Level}) · {used}/{b.Slots} workers`
				if affinity > 0 and not def.Locked then
					label ..= `  ·  ≈ {Format.Rate(previewRate(info, b))}/min`
				end
				Theme.Text(row, label, 14, {
					Size = UDim2.new(1, -150, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					TextYAlignment = Enum.TextYAlignment.Center,
				})
				local button
				if here then
					button =
						Theme.Button(row, "Unassign", "Secondary", { Size = UDim2.fromOffset(140, 34), TextSize = 15 })
					button.Activated:Connect(function()
						local ok, result = ctx.Request("AssignCreature", info.Id, nil)
						if not ok then
							ctx.Notify(result, "Error")
						end
					end)
				else
					button = Theme.Button(row, "Assign", "Primary", { Size = UDim2.fromOffset(140, 34), TextSize = 15 })
					if def.Locked then
						button.Text = "Locked"
						Theme.SetEnabled(button, false)
					elseif affinity <= 0 then
						button.Text = "Can't do this job"
						Theme.SetEnabled(button, false)
					elseif used >= b.Slots then
						button.Text = "Full"
						Theme.SetEnabled(button, false)
					end
					button.Activated:Connect(function()
						if button:GetAttribute("Disabled") then
							return
						end
						local ok, result = ctx.Request("AssignCreature", info.Id, id)
						if ok then
							ctx.Notify(`{info.Name} is heading to work!`, "Success")
						else
							ctx.Notify(result, "Error")
						end
					end)
				end
			end
		end

		-- Abilities
		local abilities = Window.Section(column, "ABILITIES", 3)
		local active = species.Active
		Theme.Text(
			abilities,
			`<b>⚡ {active.Name}</b>  <font color="#9aa6c4">(active · {Format.Duration(active.Cooldown)} cooldown)</font>`,
			16
		)
		Theme.Text(abilities, active.Description, 14, { TextColor3 = Theme.Colors.Muted })
		local use = Theme.Button(
			abilities,
			if info.AbilityReadyIn > 0 then `Ready in {Format.Duration(info.AbilityReadyIn)}` else "Use " .. active.Name,
			"Primary",
			{
				Size = UDim2.fromOffset(220, 36),
			}
		)
		-- Count down locally from the server's "ready in" value.
		local readyAt = os.clock() + info.AbilityReadyIn - State.Age("Creatures")
		local function tickButton()
			local remaining = readyAt - os.clock()
			use.Text = if remaining > 0 then `Ready in {Format.Duration(remaining)}` else "Use " .. active.Name
			Theme.SetEnabled(use, remaining <= 0)
		end
		tickButton()
		task.spawn(function()
			while use.Parent and readyAt > os.clock() do
				task.wait(0.5)
				tickButton()
			end
		end)
		use.Activated:Connect(function()
			if use:GetAttribute("Disabled") then
				return
			end
			local ok, result = ctx.Request("UseAbility", info.Id)
			if not ok then
				ctx.Notify(result, "Error")
			end
		end)
		Theme.Text(abilities, `<b>✦ {species.Passive.Name}</b>  <font color="#9aa6c4">(passive)</font>`, 16)
		Theme.Text(abilities, species.Passive.Description, 14, { TextColor3 = Theme.Colors.Muted })

		-- Jobs and stats
		local jobs = Window.Section(column, "JOB AFFINITY", 4)
		local jobRow = Theme.Make(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
			jobs
		)
		Theme.Make("UIGridLayout", {
			CellSize = UDim2.fromOffset(190, 24),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, jobRow)
		local jobIds = {}
		for jobId in species.JobAffinity do
			table.insert(jobIds, jobId)
		end
		local function skill(jobId: string): number
			return CreatureConfig.Affinity(species, info.Stage, jobId)
		end
		table.sort(jobIds, function(a, b)
			return skill(a) > skill(b)
		end)
		for _, jobId in jobIds do
			local job = JobConfig[jobId]
			local later = job and job.Phase > GameConfig.Phase
			Theme.Chip(
				jobRow,
				`{job and job.Name or jobId} {Format.Percent(skill(jobId))}` .. (if later then " · soon" else ""),
				if later then Theme.Colors.Muted else Theme.Colors.Primary
			)
		end

		local stats = Window.Section(column, "STATS", 5)
		local grid = Theme.Make(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
			stats
		)
		Theme.Make("UIGridLayout", {
			CellSize = UDim2.fromOffset(190, 22),
			CellPadding = UDim2.fromOffset(6, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		local relevant = {}
		local currentJob = nil
		if info.Assignment and buildings and buildings.List[info.Assignment] then
			local def = BuildingConfig[buildings.List[info.Assignment].Type]
			currentJob = def and def.Job and JobConfig[def.Job]
		end
		local relevantStats: { string } = if currentJob then currentJob.Stats else {}
		for _, stat in relevantStats do
			relevant[stat] = true
		end
		for i, stat in CreatureConfig.Stats do
			local value = species.BaseStats[stat.Id] or 10
			local text = `{stat.Name}: {value}`
			Theme.Text(grid, if relevant[stat.Id] then `<b>{text}  ◂</b>` else text, 14, {
				LayoutOrder = i,
				TextColor3 = if relevant[stat.Id] then Theme.Colors.Text else Theme.Colors.Muted,
			})
		end
		if currentJob then
			Theme.Text(
				stats,
				`◂ matters for its current job ({currentJob.Name}).`,
				12,
				{ TextColor3 = Theme.Colors.Muted }
			)
		end

		-- Evolution preview
		local evo = Window.Section(column, "EVOLUTION", 6)
		local wallet = State.Get("Wallet") or { Currencies = {}, Resources = {} }
		local check = Evolution.Check(
			wallet,
			{
				Species = info.Species,
				Stage = info.Stage,
				Level = info.Level,
				JobCycles = info.JobCycles or {},
				WorkCycles = info.WorkCycles,
			} :: any
		)
		local nextStage = check.NextStage
		if nextStage then
			Theme.Text(evo, `Next form: <b>{nextStage.Name}</b> ({CreatureConfig.StageNames[nextStage.Stage]})`, 15)
			for _, req in check.Requirements do
				local progress = if req.Kind == "Level"
						or req.Kind == "WorkCycles"
						or req.Cost
					then `  ({Format.Number(math.min(req.Have, req.Amount))} / {Format.Number(req.Amount)})`
					else ""
				Theme.Text(
					evo,
					(if req.Met then "✔ " else "○ ")
						.. req.Label
						.. progress
						.. (if req.Cost then " · used up" else ""),
					14,
					{ TextColor3 = if req.Met then Theme.Colors.Success else Theme.Colors.Muted }
				)
			end
			local unlocks: { string } = nextStage.Unlocks or {}
			for _, unlock in unlocks do
				Theme.Text(evo, "✦ " .. unlock, 14, { TextColor3 = Theme.Colors.Primary })
			end
			local allBuildings = State.Get("Buildings")
			local hasChamber = false
			for _, b in allBuildings and allBuildings.List or {} do
				if b.Type == "EvolutionChamber" then
					hasChamber = true
				end
			end
			local evolve =
				Theme.Button(evo, "Evolve into " .. nextStage.Name, "Gold", { Size = UDim2.fromOffset(280, 40) })
			Theme.SetEnabled(evolve, check.Ready and hasChamber)
			if not hasChamber then
				Theme.Text(evo, "Build an Evolution Chamber (Empire Core tier 2) to evolve creatures.", 12, {
					TextColor3 = Theme.Colors.Warning,
				})
			end
			evolve.Activated:Connect(function()
				if evolve:GetAttribute("Disabled") then
					ctx.Notify(
						if hasChamber then "Not all requirements are met yet." else "Build an Evolution Chamber first.",
						"Error"
					)
					return
				end
				local ok, result = ctx.Request("Evolve", info.Id)
				if not ok then
					ctx.Notify(result, "Error")
				end
			end)
		else
			Theme.Text(
				evo,
				"Fully evolved: " .. species.Evolution[info.Stage].Name .. ".",
				15,
				{ TextColor3 = Theme.Colors.Success }
			)
		end
		Theme.Text(
			column,
			`Origin: {info.Source}  ·  {if info.Tradable then "Tradable" else "Not tradable"}  ·  {Format.Number(
				info.WorkCycles
			)} work cycles`,
			12,
			{
				TextColor3 = Theme.Colors.Muted,
				LayoutOrder = 7,
			}
		)
	end

	local function renderMine()
		local creatures = State.Get("Creatures")
		local list = creatures and creatures.List or {}
		local ids = {}
		for id in list do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return (list[a].ObtainedAt or 0) < (list[b].ObtainedAt or 0)
		end)
		if #ids == 0 then
			Theme.Text(content, "You don't have any creatures yet.", 18)
			return
		end
		if not selected or not list[selected] then
			selected = ids[1]
		end

		local layout = Theme.Make(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
			content
		)
		Theme.List(layout, 12, Enum.FillDirection.Horizontal)

		local side = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(238, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
		}, layout)
		Theme.List(side, 8)
		for _, id in ids do
			local info = list[id]
			local species = CreatureConfig.Species[info.Species]
			local rarity = RarityConfig.Get(species.Rarity)
			local card = Theme.Button(
				side,
				"",
				if id == selected then "Primary" else "Ghost",
				{ Size = UDim2.new(1, 0, 0, 64), TextXAlignment = Enum.TextXAlignment.Left }
			)
			local holder = Theme.Make(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(4, 4) },
				card
			)
			Viewport.Creature(holder, info.Species, nil, { Stage = info.Stage, Mutation = info.Mutation })
			local glyph = info.Mutation and MutationConfig.Mutations[info.Mutation]
			Theme.Text(card, `<b>{info.Name}</b>  Lv {info.Level}{if glyph then "  " .. glyph.Glyph else ""}`, 16, {
				Position = UDim2.fromOffset(66, 8),
				Size = UDim2.new(1, -72, 0, 20),
				AutomaticSize = Enum.AutomaticSize.None,
			})
			Theme.Text(
				card,
				`<font color="#{rarity.Color:ToHex()}">{rarity.Glyph}</font> {rarity.Label} · {if info.Assignment
					then "Working"
					else "Idle"}`,
				13,
				{
					Position = UDim2.fromOffset(66, 32),
					Size = UDim2.new(1, -72, 0, 18),
					AutomaticSize = Enum.AutomaticSize.None,
					TextColor3 = Theme.Colors.Muted,
				}
			)
			card.Activated:Connect(function()
				selected = id
				render()
			end)
		end
		detail(layout, list[selected :: string])
	end

	local function renderJournal()
		local collection = State.Get("Collection") or {}
		local discovered = 0
		for _ in collection do
			discovered += 1
		end
		Theme.Text(
			content,
			`Discovered {discovered} of {#CreatureConfig.Order} species. Some appear only in certain places, weather or times of day.`,
			15,
			{
				TextColor3 = Theme.Colors.Muted,
			}
		)
		local list = Theme.Make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(0, 30),
		}, content)
		Theme.List(list, 10)
		for familyIndex, familyId in CreatureConfig.FamilyOrder do
			local family = CreatureConfig.Families[familyId]
			local section = Window.Section(list, nil, familyIndex)
			Theme.Text(
				section,
				`<font color="#{family.Color:ToHex()}">{family.Glyph}</font> <b>{family.Name}</b> · {family.Description}`,
				15
			)
			local grid = Theme.Make(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
				section
			)
			Theme.Make("UIGridLayout", {
				CellSize = UDim2.fromOffset(190, 172),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, grid)
			local order = 0
			for _, speciesId in CreatureConfig.Order do
				local species = CreatureConfig.Species[speciesId]
				if species.Family == familyId then
					order += 1
					local entry = collection[speciesId]
					local rarity = RarityConfig.Get(species.Rarity)
					local cell =
						Theme.Make("Frame", { BackgroundColor3 = Theme.Colors.PanelSunken, LayoutOrder = order }, grid)
					Theme.Corner(cell, 10)
					Theme.Stroke(cell, rarity.Color, if entry then 0.4 else 0.85)
					local art = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96) }, cell)
					Viewport.Creature(art, speciesId, nil, { Silhouette = entry == nil })
					Theme.Text(cell, if entry then `<b>{species.Name}</b>` else "<b>???</b>", 15, {
						Position = UDim2.fromOffset(8, 96),
						Size = UDim2.new(1, -16, 0, 18),
						AutomaticSize = Enum.AutomaticSize.None,
					})
					Theme.Text(
						cell,
						`<font color="#{rarity.Color:ToHex()}">{rarity.Glyph}</font> {rarity.Label}`
							.. (if entry then ` · owned {entry.Count}` else ""),
						12,
						{
							Position = UDim2.fromOffset(8, 114),
							Size = UDim2.new(1, -16, 0, 16),
							AutomaticSize = Enum.AutomaticSize.None,
							TextColor3 = Theme.Colors.Muted,
						}
					)
					Theme.Text(cell, species.Discovery, 11, {
						Position = UDim2.fromOffset(8, 132),
						Size = UDim2.new(1, -16, 0, 36),
						AutomaticSize = Enum.AutomaticSize.None,
						TextColor3 = Theme.Colors.Muted,
						TextYAlignment = Enum.TextYAlignment.Top,
					})
				end
			end
		end
	end

	render = function()
		Window.Clear(content)
		Theme.SetStyle(mineTab, if tab == "Mine" then "Primary" else "Secondary")
		Theme.SetStyle(journalTab, if tab == "Journal" then "Primary" else "Secondary")
		if tab == "Mine" then
			renderMine()
		else
			renderJournal()
		end
	end

	-- Live refresh while open, but only when something visible changed (assignment,
	-- level, ability readiness, worker slots), so portraits don't flicker on every XP tick.
	local dirty = false
	local lastSignature = ""
	local function signature(): string
		local parts = {}
		local creatures = State.Get("Creatures")
		local wallet = State.Get("Wallet")
		for id, info in creatures and creatures.List or {} do
			local ready = wallet ~= nil
				and Evolution.Check(
					wallet,
					{
						Species = info.Species,
						Stage = info.Stage,
						Level = info.Level,
						JobCycles = info.JobCycles or {},
						WorkCycles = info.WorkCycles,
					} :: any
				).Ready
			table.insert(
				parts,
				`{id}:{info.Assignment}:{info.Level}:{info.Stage}:{info.AbilityReadyIn > 0}:{info.Task}:{ready}:{info.RestIn > 0}:{info.Companion}`
			)
		end
		local buildings = State.Get("Buildings")
		for id, b in buildings and buildings.List or {} do
			table.insert(parts, `{id}:{b.Level}:{#b.Assigned}`)
		end
		table.sort(parts)
		return table.concat(parts, "|")
	end
	local function markDirty()
		if ctx.IsOpen("Creatures") and tab == "Mine" then
			local current = signature()
			if current ~= lastSignature then
				lastSignature = current
				dirty = true
			end
		end
	end
	State.OnChanged("Creatures", markDirty)
	State.OnChanged("Buildings", markDirty)
	State.OnChanged("Wallet", markDirty)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if dirty and ctx.IsOpen("Creatures") then
				dirty = false
				local scroll = win.Body.CanvasPosition
				render()
				win.Body.CanvasPosition = scroll
			end
		end
	end)

	return {
		Root = win.Root,
		Open = function(arg: any?)
			if arg == "Journal" then
				tab = "Journal"
			elseif type(arg) == "string" then
				selected = arg
				tab = "Mine"
			end
			render()
		end,
	}
end

return CreaturesWindow
