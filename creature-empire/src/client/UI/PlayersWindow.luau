--!strict
-- Everyone in the server: visit their plot, inspect, trade, and choose who may collaborate
-- on yours. Cheering happens at their Empire Core (walk up and press the prompt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SocialConfig = require(Shared.Config.SocialConfig)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local PlayersWindow = {}

function PlayersWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Players", "☺", Vector2.new(620, 600), ctx.Close)
	Theme.List(win.Body, 10)
	local localPlayer = Players.LocalPlayer

	local function render()
		Window.Clear(win.Body)
		local social = State.Get("Social") or { Collaborators = {}, Helping = {}, Max = SocialConfig.MaxCollaborators }
		local intro = Window.Section(win.Body, nil, 1)
		Theme.Text(
			intro,
			`<b>Collaborators</b> can collect your harvests into your silo (and nothing else). You have {#social.Collaborators} / {social.Max}.`
				.. "\n<b>Cheer</b> someone's empire at their Empire Core: their creatures work 10% faster for 10 minutes, and you get a small thank-you gift.",
			14
		)
		if #social.Helping > 0 then
			local names = {}
			for _, userId in social.Helping do
				local p = Players:GetPlayerByUserId(userId)
				table.insert(names, p and p.DisplayName or tostring(userId))
			end
			Theme.Text(intro, "You're a collaborator for: " .. table.concat(names, ", "), 14, {
				TextColor3 = Theme.Colors.Success,
			})
		end
		local others = {}
		for _, p in Players:GetPlayers() do
			if p ~= localPlayer then
				table.insert(others, p)
			end
		end
		table.sort(others, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
		if #others == 0 then
			Theme.Text(win.Body, "Nobody else is here yet. Invite friends to visit, trade and cheer!", 15, {
				TextColor3 = Theme.Colors.Muted,
				LayoutOrder = 2,
			})
		end
		for order, p in others do
			local card = Window.Section(win.Body, nil, 1 + order)
			local isCollaborator = table.find(social.Collaborators, p.UserId) ~= nil
			Theme.Text(
				card,
				`<b>{p.DisplayName}</b> <font color="#9aa6c4">@{p.Name}</font>`
					.. (if isCollaborator then "  · collaborator on your plot" else ""),
				16
			)
			local row = Window.Row(card, 40)
			local function button(label: string, style: any, onClick: () -> ())
				local b = Theme.Button(row, label, style, { Size = UDim2.fromOffset(130, 36), TextSize = 14 })
				b.Activated:Connect(onClick)
				return b
			end
			button("Visit", "Primary", function()
				ctx.Close()
				local ok, result = ctx.Request("VisitPlot", p.UserId)
				if not ok then
					ctx.Notify(result, "Error")
				end
			end)
			button("Inspect", "Secondary", function()
				ctx.Open("Inspect", p.UserId)
			end)
			button("Trade", "Gold", function()
				local ok, result = ctx.Request("TradeRequest", p.UserId)
				ctx.Notify(
					if ok then `Trade invite sent to {p.DisplayName}.` else result,
					if ok then "Success" else "Error"
				)
			end)
			button(if isCollaborator then "Remove helper" else "Make helper", "Ghost", function()
				local ok, result = ctx.Request("SetCollaborator", p.UserId, not isCollaborator)
				if not ok then
					ctx.Notify(result, "Error")
				end
			end)
		end
	end

	State.OnChanged("Social", function()
		if ctx.IsOpen("Players") then
			render()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if ctx.IsOpen("Players") then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if ctx.IsOpen("Players") then
			task.defer(render)
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			render()
		end,
	}
end

return PlayersWindow
