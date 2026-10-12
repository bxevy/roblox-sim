-- Testing commands, ONLY active in Roblox Studio (never in a live game).
-- Type these in chat:
--   /level 20          set your level
--   /gold 5000         add gold
--   /give Dragonfang   give an item by id (see Items.luau)
--   /giveall           give every weapon and armor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Items = require(ReplicatedStorage.Shared.Items)
local PlayerService = require(script.Parent.PlayerService)

local DevService = {}

local function run(player: Player, message: string)
	local command, arg = message:match("^/(%w+)%s*(%S*)")
	if not command then
		return
	end
	command = command:lower()

	if command == "level" and tonumber(arg) then
		PlayerService.SetLevel(player, tonumber(arg) :: number)
		PlayerService.Notify(player, `[Dev] Level set to {arg}`)
	elseif command == "gold" and tonumber(arg) then
		PlayerService.AddGold(player, tonumber(arg) :: number)
		PlayerService.Notify(player, `[Dev] +{arg} Gold`)
	elseif command == "give" then
		local kind = if Items.Weapons[arg] then "Weapon" elseif Items.Armors[arg] then "Armor" else nil
		if kind then
			PlayerService.GiveItem(player, kind, arg)
			PlayerService.Notify(player, `[Dev] Gave {arg}`)
		else
			PlayerService.Notify(player, `[Dev] No item called {arg}`)
		end
	elseif command == "giveall" then
		for id in Items.Weapons do
			PlayerService.GiveItem(player, "Weapon", id)
		end
		for id in Items.Armors do
			PlayerService.GiveItem(player, "Armor", id)
		end
		PlayerService.Notify(player, "[Dev] Gave every item")
	end
end

function DevService.Start()
	if not RunService:IsStudio() then
		return
	end

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		for _, name in { "level", "gold", "give", "giveall" } do
			local textCommand = Instance.new("TextChatCommand")
			textCommand.Name = `Dev_{name}`
			textCommand.PrimaryAlias = `/{name}`
			textCommand.Triggered:Connect(function(source, text)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					run(player, text)
				end
			end)
			textCommand.Parent = TextChatService
		end
	else
		local function hook(player: Player)
			player.Chatted:Connect(function(message)
				run(player, message)
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, player in Players:GetPlayers() do
			hook(player)
		end
	end
	print("[DevService] Studio test commands enabled: /level, /gold, /give, /giveall")
end

return DevService
