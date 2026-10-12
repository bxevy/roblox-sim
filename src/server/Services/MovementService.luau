-- Stamina, sprinting and dodging. The server owns stamina; the client asks to sprint or
-- dodge and plays the dash locally (it controls its own character's physics).
--
-- Player attributes (read by the client HUD):  Stamina, Sprinting
-- Character attribute (read by EnemyService):  InvulnerableUntil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local TICK = 0.1

local MovementService = {}

type State = {
	Stamina: number,
	WantsSprint: boolean,
	LastUse: number,
	LastDodge: number,
}

local states: { [Player]: State } = {}

local function setSprinting(player: Player, sprinting: boolean)
	if (player:GetAttribute("Sprinting") == true) ~= sprinting then
		player:SetAttribute("Sprinting", sprinting)
		PlayerService.RefreshStats(player)
	end
end

local function reset(player: Player)
	states[player] = {
		Stamina = Config.Movement.MaxStamina,
		WantsSprint = false,
		LastUse = 0,
		LastDodge = 0,
	}
	player:SetAttribute("Stamina", Config.Movement.MaxStamina)
	player:SetAttribute("Sprinting", false)
end

local function onDodge(player: Player)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local movement = Config.Movement
	if now - state.LastDodge < movement.DodgeCooldown * 0.8 or state.Stamina < movement.DodgeCost then
		return
	end
	state.LastDodge = now
	state.LastUse = now
	state.Stamina -= movement.DodgeCost
	player:SetAttribute("Stamina", math.floor(state.Stamina))
	character:SetAttribute("InvulnerableUntil", now + movement.InvulnerableTime)
end

local function update()
	local movement = Config.Movement
	local now = os.clock()
	for player, state in states do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local moving = humanoid ~= nil and humanoid.Health > 0 and humanoid.MoveDirection.Magnitude > 0.1
		local sprinting = state.WantsSprint and moving and state.Stamina > 0

		if sprinting then
			state.Stamina = math.max(0, state.Stamina - movement.SprintDrain * TICK)
			state.LastUse = now
			if state.Stamina <= 0 then
				state.WantsSprint = false -- out of breath: let go of Shift to try again
				sprinting = false
			end
		elseif now - state.LastUse >= movement.RegenDelay then
			state.Stamina = math.min(movement.MaxStamina, state.Stamina + movement.RegenRate * TICK)
		end

		setSprinting(player, sprinting)
		local rounded = math.floor(state.Stamina)
		if player:GetAttribute("Stamina") ~= rounded then
			player:SetAttribute("Stamina", rounded)
		end
	end
end

function MovementService.Start()
	Players.PlayerAdded:Connect(function(player)
		reset(player)
		player.CharacterAdded:Connect(function()
			reset(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		reset(player)
		player.CharacterAdded:Connect(function()
			reset(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	Remotes.SetSprint.OnServerEvent:Connect(function(player, sprinting)
		local state = states[player]
		if state then
			state.WantsSprint = sprinting == true and state.Stamina > 5
		end
	end)
	Remotes.Dodge.OnServerEvent:Connect(onDodge)

	task.spawn(function()
		while true do
			task.wait(TICK)
			update()
		end
	end)
end

return MovementService
