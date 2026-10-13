--!strict
-- Top 10 for every leaderboard (refreshed by the server every couple of minutes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LeaderboardConfig = require(Shared.Config.LeaderboardConfig)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local LeaderboardWindow = {}

function LeaderboardWindow.new(ctx: any)
	local win = Window.new(ctx.Gui, "Leaderboards", "♛", Vector2.new(640, 640), ctx.Close)
	Theme.List(win.Body, 10)
	local latest: any = { Boards = {}, Status = "Loading leaderboards…" }

	local function render()
		Window.Clear(win.Body)
		for order, board in LeaderboardConfig.Boards do
			local card = Window.Section(win.Body, string.upper(board.Name), order)
			Theme.Text(card, board.Description, 13, { TextColor3 = Theme.Colors.Muted })
			local entries = latest.Boards[board.Id]
			if not entries or #entries == 0 then
				Theme.Text(card, latest.Status, 14, { TextColor3 = Theme.Colors.Muted })
			else
				for _, entry in entries do
					local me = entry.UserId == Players.LocalPlayer.UserId
					local score = if board.Format == "Number" then Format.Number(entry.Score) else tostring(entry.Score)
					local medal = if entry.Rank == 1
						then "🥇"
						elseif entry.Rank == 2 then "🥈"
						elseif entry.Rank == 3 then "🥉"
						else `{entry.Rank}.`
					Theme.Text(
						card,
						`{medal} {if me then "<b>" .. entry.Name .. " (you)</b>" else entry.Name}  ·  <font color="#ffd56a">{score}</font>`,
						15
					)
				end
			end
		end
		Theme.Text(win.Body, "Scores update every couple of minutes. Weekly boards reset on Monday (UTC).", 12, {
			TextColor3 = Theme.Colors.Muted,
			LayoutOrder = 99,
		})
	end

	Remotes.Events.GameEvent.OnClientEvent:Connect(function(name: string, payload: any)
		if name == "Leaderboards" then
			latest = payload
			if ctx.IsOpen("Leaderboards") then
				render()
			end
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			render()
		end,
	}
end

return LeaderboardWindow
