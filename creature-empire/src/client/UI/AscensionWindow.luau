--!strict
-- Ascension: what you'd earn, exactly what resets and what stays, a two-step confirm, and
-- the permanent perk shop (Empire Shards).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AscensionConfig = require(Shared.Config.AscensionConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local AscensionWindow = {}

local RESETS = {
	"Gold, Essence and Insight (each run starts with 50 gold, plus Golden Start)",
	"Materials in your silo",
	"Every building, back to the starting layout",
	"Land expansions",
	"Research",
}
local KEEPS = {
	"Every creature: levels, evolutions and mutations",
	"Your collection journal, discoveries and guardian records",
	"Quests, egg pity, settings and Ember Lures",
	"Empire Shards and perks",
}

function AscensionWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Ascension", "⬢", Vector2.new(620, 640), ctx.Close)
	Theme.List(win.Body, 10)
	local confirming = false

	local function render()
		Window.Clear(win.Body)
		local ascension = State.Get("Ascension")
		local wallet = State.Get("Wallet")
		if not ascension then
			return
		end
		local shards = wallet and wallet.Currencies.EmpireShards or 0
		local icon = ResourceConfig.EmpireShards.Icon

		local summary = Window.Section(win.Body, nil, 1)
		Theme.Text(
			summary,
			`Ascensions: <b>{ascension.Count}</b> · {icon} Empire Shards: <b>{Format.Number(shards)}</b>`,
			18
		)
		Theme.Text(
			summary,
			`Gold earned this run: {Format.Number(ascension.RunGold)}. Ascending now pays <b>{ascension.Payout} shards</b> (more gold earned = more shards), and every Ascension adds +{math.floor(
				AscensionConfig.YieldPerAscension * 100
			)}% yield for all creatures.`
				.. (if ascension.Count == 0 then " Your first Ascension also brings Titanicore." else ""),
			14
		)

		local resets = Window.Section(win.Body, "RESETS", 2)
		for _, line in RESETS do
			Theme.Text(resets, "✖ " .. line, 14, { TextColor3 = Theme.Colors.Warning })
		end
		local keeps = Window.Section(win.Body, "STAYS", 3)
		for _, line in KEEPS do
			Theme.Text(keeps, "✔ " .. line, 14, { TextColor3 = Theme.Colors.Success })
		end

		local action = Window.Section(win.Body, nil, 4)
		if not ascension.CanAscend then
			Theme.Text(action, "🔒 " .. (ascension.Reason or "Not yet."), 15, { TextColor3 = Theme.Colors.Muted })
		elseif not confirming then
			local go = Theme.Button(action, "⬢ Ascend…", "Gold", { Size = UDim2.fromOffset(220, 42) })
			go.Activated:Connect(function()
				confirming = true
				render()
			end)
		else
			Theme.Text(
				action,
				`<b>Are you sure?</b> Your buildings and resources reset now. You receive {ascension.Payout} shards.`,
				15,
				{ TextColor3 = Theme.Colors.Warning }
			)
			local row = Window.Row(action, 44)
			local yes = Theme.Button(row, "Yes, Ascend", "Danger", { Size = UDim2.fromOffset(200, 40) })
			local no = Theme.Button(row, "Cancel", "Secondary", { Size = UDim2.fromOffset(140, 40) })
			no.Activated:Connect(function()
				confirming = false
				render()
			end)
			yes.Activated:Connect(function()
				Theme.SetEnabled(yes, false)
				confirming = false
				local ok, result = ctx.Request("Ascend")
				if not ok then
					ctx.Notify(result, "Error")
					render()
				end
			end)
		end

		local perks = Window.Section(win.Body, "PERKS (permanent)", 5)
		for _, perkId in AscensionConfig.PerkOrder do
			local perk = AscensionConfig.Perks[perkId]
			local rank = ascension.Perks[perkId] or 0
			local cost = if rank < perk.MaxRank then perk.Cost * (rank + 1) else nil
			local row = Window.Row(perks, 52)
			Theme.Text(
				row,
				`<b>{perk.Name}</b> {rank}/{perk.MaxRank}\n<font color="#9aa6c4">{perk.Description} (per rank)</font>`,
				14,
				{
					Size = UDim2.new(1, -170, 1, 0),
					AutomaticSize = Enum.AutomaticSize.None,
					TextYAlignment = Enum.TextYAlignment.Center,
				}
			)
			local b = Theme.Button(
				row,
				if cost then `{icon} {cost}` else "Maxed",
				"Primary",
				{ Size = UDim2.fromOffset(150, 36), TextSize = 15 }
			)
			Theme.SetEnabled(b, cost ~= nil and shards >= cost)
			b.Activated:Connect(function()
				if b:GetAttribute("Disabled") then
					if cost then
						ctx.Notify(`You need {cost} Empire Shards.`, "Error")
					end
					return
				end
				local ok, result = ctx.Request("BuyPerk", perkId)
				if ok then
					ctx.Notify(`{perk.Name} is now rank {result}!`, "Reward")
				else
					ctx.Notify(result, "Error")
				end
			end)
		end
	end

	local function refresh()
		if ctx.IsOpen("Ascension") then
			render()
		end
	end
	State.OnChanged("Ascension", refresh)
	State.OnChanged("Wallet", refresh)

	return {
		Root = win.Root,
		Open = function()
			confirming = false
			render()
		end,
	}
end

return AscensionWindow
