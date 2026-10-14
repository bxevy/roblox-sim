--!strict
-- Build menu: buildings you can place, with price, limit and what they do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared.Config.BuildingConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local ResearchConfig = require(Shared.Config.ResearchConfig)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local BuildMenu = {}

-- Categories shown in the menu, including ones arriving later (shown as "coming soon").
local CATEGORIES = {
	{
		Id = "Production",
		Name = "Production",
		Later = { "Alchemy Lab" },
	},
	{
		Id = "Creatures",
		Name = "Creature care",
		Later = { "Training Grounds", "Breeding Sanctuary", "Recovery Station" },
	},
	{
		Id = "Automation",
		Name = "Automation",
		Later = { "Conveyor", "Sorting Machine", "Power Relay" },
	},
	{
		Id = "Research",
		Name = "Research & exploration",
		Later = { "Relic Archive", "Biome Scanner", "Mutation Lab" },
	},
	{ Id = "Empire", Name = "Empire", Later = { "Defensive Tower", "Decorations", "Teleport Gate" } },
}

function BuildMenu.new(ctx: any)
	local State = ctx.Controllers.State
	local Placement = ctx.Controllers.Placement
	local win = Window.new(ctx.Gui, "Build", "⌂", Vector2.new(720, 560), ctx.Close)
	Theme.List(win.Body, 10)

	local function render()
		Window.Clear(win.Body)
		local buildings = State.Get("Buildings")
		local wallet = State.Get("Wallet")
		for order, category in CATEGORIES do
			local card = Window.Section(win.Body, string.upper(category.Name), order)
			local any = false
			for typeId, def in BuildingConfig do
				if def.Placeable and def.Category == category.Id then
					any = true
					local limits = buildings and buildings.Limits and buildings.Limits[typeId]
					local row = Theme.Make("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
					}, card)
					Theme.List(row, 4)
					Theme.Text(
						row,
						`<b>{def.Name}</b>  <font color="#dec496">{def.Footprint.X}×{def.Footprint.Z} cells</font>`,
						17
					)
					Theme.Text(row, def.Description, 14, { TextColor3 = Theme.Colors.Muted })
					local owned = limits and limits.Owned or 0
					local limit = limits and limits.Limit or 0
					local cost = limits and limits.NextCost or {}
					local affordable = true
					for currency, amount in cost do
						if (wallet and (wallet.Currencies[currency] or wallet.Resources[currency]) or 0) < amount then
							affordable = false
						end
					end
					Theme.Text(
						row,
						if limit > 0
							then `Built {owned} / {limit} (Empire Core tier sets the limit)`
							else `Unlocks at Empire Core tier {limits and limits.UnlockTier or "?"}`,
						13,
						{ TextColor3 = Theme.Colors.Muted }
					)
					local button = Theme.Button(
						row,
						"Place · " .. Format.Cost(cost, ResourceConfig),
						"Primary",
						{ Size = UDim2.fromOffset(240, 40) }
					)
					local reason: string? = nil
					if def.Phase > GameConfig.Phase then
						reason = "Coming soon."
					elseif owned >= limit then
						reason = if limit == 0
							then `Unlocks at Empire Core tier {limits and limits.UnlockTier or "?"}.`
							else "Upgrade the Empire Core to build more."
					elseif limits and limits.NeedsResearch then
						local node = ResearchConfig.Nodes[limits.NeedsResearch]
						reason = `Research {node and node.Name or limits.NeedsResearch} at the Research Station first.`
					elseif not affordable then
						reason = "Not enough resources yet."
					end
					if reason then
						Theme.SetEnabled(button, false)
						Theme.Text(row, reason, 13, { TextColor3 = Theme.Colors.Warning })
					end
					button.Activated:Connect(function()
						if reason then
							ctx.Notify(reason, "Error")
							return
						end
						ctx.Close()
						Placement.Begin(typeId)
					end)
				end
			end
			if category.Later and #category.Later > 0 then
				Theme.Text(card, "Coming in later updates: " .. table.concat(category.Later, " · "), 13, {
					TextColor3 = Theme.Colors.Muted,
				})
			end
			local _ = any
		end
	end

	State.OnChanged("Wallet", function()
		if ctx.IsOpen("Build") then
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

return BuildMenu
