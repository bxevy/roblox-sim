--!strict
-- World map: every region, whether it's open, travel buttons, and each region's journal
-- (landmarks, eruption timer, guardian record).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeConfig = require(Shared.Config.BiomeConfig)
local RegionConfig = require(Shared.Config.RegionConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local MapWindow = {}

function MapWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "World Map", "✈", Vector2.new(640, 600), ctx.Close)
	Theme.List(win.Body, 10)

	local function regionFor(biomeId: string): RegionConfig.Region?
		for _, region in RegionConfig.Regions do
			if region.Biome == biomeId then
				return region
			end
		end
		return nil
	end

	local function render()
		Window.Clear(win.Body)
		local buildings = State.Get("Buildings")
		local tier = buildings and buildings.List.core and buildings.List.core.Level or 1
		local exploration = State.Get("Exploration") or { Discoveries = {}, Guardians = {} }
		local biomes = {}
		for id, biome in BiomeConfig do
			table.insert(biomes, { Id = id, Def = biome })
		end
		table.sort(biomes, function(a, b)
			return a.Def.Order < b.Def.Order
		end)
		for order, entry in biomes do
			local biome = entry.Def
			local card = Window.Section(win.Body, nil, order)
			local palette = biome.Palette
			Theme.Stroke(card, palette.Accent, 0.5)
			Theme.Text(card, `<font color="#{palette.Accent:ToHex()}">◆</font> <b>{biome.Name}</b>`, 19)
			Theme.Text(card, biome.Description, 14, { TextColor3 = Theme.Colors.Muted })
			Theme.Text(card, "<b>Mechanic:</b> " .. biome.NewMechanic, 13)
			local region = regionFor(entry.Id)
			if entry.Id == "VerdantReach" then
				local home = Theme.Button(card, "⌂ Go home", "Secondary", { Size = UDim2.fromOffset(160, 36) })
				home.Activated:Connect(function()
					ctx.Close()
					ctx.Request("Travel", "Home")
				end)
			elseif region and region.Phase <= GameConfig.Phase then
				local unlocked = tier >= region.CoreTier
				local go = Theme.Button(
					card,
					if unlocked then "✈ Travel" else `🔒 Empire Core tier {region.CoreTier}`,
					"Primary",
					{
						Size = UDim2.fromOffset(220, 36),
					}
				)
				Theme.SetEnabled(go, unlocked)
				go.Activated:Connect(function()
					if not unlocked then
						return
					end
					ctx.Close()
					local ok, result = ctx.Request("Travel", region.Id)
					if not ok then
						ctx.Notify(result, "Error")
					end
				end)
				-- Journal
				local now = Workspace:GetServerTimeNow()
				Theme.Text(
					card,
					if RegionConfig.EruptionActive(region, now)
						then "<b>Erupting now!</b> Something rare visits the Ashen Overlook during eruptions."
						else `Next eruption in {Format.Duration(RegionConfig.NextEruptionIn(region, now))}.`,
					13,
					{ TextColor3 = Theme.Colors.Warning }
				)
				local found = 0
				for _, landmark in region.Landmarks do
					local when = exploration.Discoveries[landmark.Id]
					if when then
						found += 1
					end
					local name = if when or not landmark.Hidden then landmark.Name else "??? (a hidden place)"
					Theme.Text(card, (if when then "✔ " else "○ ") .. name, 13, {
						TextColor3 = if when then Theme.Colors.Success else Theme.Colors.Muted,
					})
				end
				Theme.Text(
					card,
					`Landmarks found: {found} / {#region.Landmarks}. Follow anything that glows…`,
					12,
					{ TextColor3 = Theme.Colors.Muted }
				)
				for guardianId, guardian in CombatConfig.Guardians do
					if guardian.Region == region.Id then
						local record = exploration.Guardians[guardianId]
						Theme.Text(
							card,
							`Guardian: <b>{guardian.Name}</b> · defeated {record and record.Defeats or 0} times`,
							13
						)
					end
				end
			else
				Theme.Text(
					card,
					"🔒 " .. biome.Unlock .. " (arrives in a later update)",
					13,
					{ TextColor3 = Theme.Colors.Muted }
				)
			end
		end
	end

	State.OnChanged("Exploration", function()
		if ctx.IsOpen("Map") then
			render()
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			render()
		end,
	}
end

return MapWindow
