--!strict
-- Regional guardian fights (the Magmaul Matriarch in the Guardian's Caldera).
--
-- The server runs the whole fight: health (scaled by how many players are in the arena),
-- phases, telegraphed slams aimed at players (announced ahead of impact so they can be
-- dodged; a hit adds heat and knocks you back), damage from each player's companion
-- (Shared/Util/Combat, with element multipliers and a team bonus) and rewards. Clients
-- only draw it, from the attributes on Workspace.Guardians.<id> and GameEvents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local RegionConfig = require(Shared.Config.RegionConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local Combat = require(Shared.Util.Combat)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local BuildingService = require(script.Parent.BuildingService)
local RegionService = require(script.Parent.RegionService)

local TICK = 0.25
local ATTACK_RANGE_EXTRA = 15
local RESET_AFTER = 30 -- seconds with nobody in the arena before health resets

type Pending = { Position: Vector3, Radius: number, ImpactAt: number }
type Fight = {
	Def: any,
	Center: Vector3,
	Radius: number,
	Anchor: Configuration,
	Alive: boolean,
	Health: number,
	MaxHealth: number,
	Fighters: number, -- players the health was scaled for
	Damage: { [number]: number }, -- userId -> damage dealt this fight
	NextSlam: number,
	Pending: { Pending },
	RespawnAt: number,
	EmptySince: number?,
}

local GuardianService = {}

local fights: { [string]: Fight } = {}
local cooldowns: { [Player]: { Attack: number, Special: number } } = {}
local rng = Random.new()

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function playersInArena(fight: Fight, extra: number?): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local part = root(player)
		if
			part
			and flatDistance(part.Position, fight.Center) <= fight.Radius + (extra or 0)
			and math.abs(part.Position.Y - fight.Center.Y) < 30
		then
			table.insert(list, player)
		end
	end
	return list
end

local function publish(fight: Fight)
	local anchor = fight.Anchor
	anchor:SetAttribute("Alive", fight.Alive)
	anchor:SetAttribute("Health", math.max(math.floor(fight.Health), 0))
	anchor:SetAttribute("MaxHealth", math.floor(fight.MaxHealth))
	local phase = Combat.Phase(fight.Def, if fight.MaxHealth > 0 then fight.Health / fight.MaxHealth else 1)
	anchor:SetAttribute("Phase", phase)
	anchor:SetAttribute("RespawnAt", fight.RespawnAt)
end

local function reset(fight: Fight)
	fight.Alive = true
	fight.Fighters = 1
	fight.MaxHealth = Combat.MaxHealth(fight.Def, 1)
	fight.Health = fight.MaxHealth
	fight.Damage = {}
	fight.Pending = {}
	fight.NextSlam = 0
	fight.EmptySince = nil
	publish(fight)
end

local function reward(fight: Fight)
	local def = fight.Def
	local total = 0
	for _, amount in fight.Damage do
		total += amount
	end
	local now = os.time()
	for userId, amount in fight.Damage do
		local player = Players:GetPlayerByUserId(userId)
		local data = player and PlayerDataService.GetData(player)
		if player and data and total > 0 and amount / total >= def.MinShare then
			local record = data.Guardians[def.Id] or { Defeats = 0, LastRewardAt = 0 }
			data.Guardians[def.Id] = record
			local first = record.Defeats == 0
			record.Defeats += 1
			data.Stats.GuardianWins = (data.Stats.GuardianWins or 0) + 1
			if now - record.LastRewardAt >= def.RewardCooldown then
				record.LastRewardAt = now
				local parts = {}
				for id, value in def.Reward do
					EconomyService.Add(player, id, value, "Guardian")
					local resource = ResourceConfig[id]
					table.insert(parts, `{Format.Number(value)} {resource and resource.Name or id}`)
				end
				Remotes.Events.Notify:FireClient(player, `{def.Name} defeated! +{table.concat(parts, ", ")}`, "Reward")
			else
				Remotes.Events.Notify:FireClient(
					player,
					`{def.Name} defeated! (Rewards recharge {Format.Duration(
						def.RewardCooldown - (now - record.LastRewardAt)
					)})`,
					"Success"
				)
			end
			if first and def.FirstWinCreature then
				local count = 0
				for _ in data.Creatures do
					count += 1
				end
				if count < BuildingService.CreatureCapacity(data) then
					CreatureService.Grant(player, def.FirstWinCreature, "Guardian", false, { Guardian = def.Id })
				else
					Remotes.Events.Notify:FireClient(
						player,
						"A young Magmaul wanted to join you, but your habitat is full. Defeat the Matriarch again with room to spare.",
						"Error"
					)
					record.Defeats = 0 -- try again next time
				end
			end
			PlayerDataService.MarkDirty(player)
			StateService.Push(player, "Exploration")
			Events.GuardianDefeated:Fire(player, def.Id)
		end
	end
	Log.Info("Guardian", "Defeated", { guardian = def.Id, fighters = fight.Fighters })
end

local function slam(fight: Fight, now: number)
	local def = fight.Def
	local _, phase = Combat.Phase(def, fight.Health / fight.MaxHealth)
	local targets = playersInArena(fight)
	if #targets == 0 then
		return
	end
	for _ = 1, phase.Slams do
		local target = targets[rng:NextInteger(1, #targets)]
		local part = root(target)
		if part then
			-- Aim near the player, not exactly at them.
			local position = Vector3.new(
				part.Position.X + rng:NextNumber(-3, 3),
				fight.Center.Y,
				part.Position.Z + rng:NextNumber(-3, 3)
			)
			local impactAt = now + def.Warning
			table.insert(fight.Pending, { Position = position, Radius = phase.Radius, ImpactAt = impactAt })
			Remotes.Events.GameEvent:FireAllClients("GuardianTelegraph", {
				Guardian = def.Id,
				Position = position,
				Radius = phase.Radius,
				ImpactAt = impactAt,
			})
		end
	end
	fight.NextSlam = now + phase.SlamEvery
end

local function resolveImpacts(fight: Fight, now: number)
	for i = #fight.Pending, 1, -1 do
		local pending = fight.Pending[i]
		if pending.ImpactAt <= now then
			table.remove(fight.Pending, i)
			Remotes.Events.GameEvent:FireAllClients(
				"GuardianSlam",
				{ Guardian = fight.Def.Id, Position = pending.Position, Radius = pending.Radius }
			)
			for _, player in playersInArena(fight, 10) do
				local part = root(player)
				if part and flatDistance(part.Position, pending.Position) <= pending.Radius then
					RegionService.AddHeat(player, fight.Def.SlamHeat)
					local away =
						Vector3.new(part.Position.X - pending.Position.X, 0, part.Position.Z - pending.Position.Z)
					local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
					local character = player.Character
					if character then
						character:PivotTo(CFrame.new(part.Position + direction * 12 + Vector3.new(0, 2, 0)))
					end
					Remotes.Events.GameEvent:FireClient(
						player,
						"Scorched",
						{ Amount = fight.Def.SlamHeat, Slam = true }
					)
				end
			end
		end
	end
end

local function tickFight(fight: Fight, now: number)
	if not fight.Alive then
		if now >= fight.RespawnAt then
			reset(fight)
		end
		return
	end
	local inside = playersInArena(fight)
	if #inside == 0 then
		fight.EmptySince = fight.EmptySince or now
		if fight.Health < fight.MaxHealth and now - (fight.EmptySince :: number) > RESET_AFTER then
			reset(fight)
		end
		return
	end
	fight.EmptySince = nil
	-- More players joined mid-fight: the guardian toughens up (never weakens).
	if #inside > fight.Fighters then
		local extra = (#inside - fight.Fighters) * fight.Def.HealthPerExtraPlayer
		fight.Fighters = #inside
		fight.MaxHealth += extra
		fight.Health += extra
		publish(fight)
	end
	-- The guardian only fights back once someone has attacked.
	if next(fight.Damage) then
		if now >= fight.NextSlam then
			slam(fight, now)
		end
		resolveImpacts(fight, now)
	end
end

local function attack(player: Player, kind: string): (boolean, any)
	if kind ~= "Attack" and kind ~= "Special" then
		return false, "Invalid request."
	end
	local data = PlayerDataService.GetData(player)
	local companion = data and data.Companion and data.Creatures[data.Companion]
	if not data or not companion then
		return false, "Choose a companion creature first (Creatures window → Take with me)."
	end
	local fight: Fight? = nil
	local part = root(player)
	for _, candidate in fights do
		if part and flatDistance(part.Position, candidate.Center) <= candidate.Radius + ATTACK_RANGE_EXTRA then
			fight = candidate
		end
	end
	if not fight or not fight.Alive then
		return false, "There's nothing to fight here."
	end
	local f = fight :: Fight
	local now = os.clock()
	local mine = cooldowns[player]
	local def = if kind == "Special" then CombatConfig.Special else CombatConfig.Attack
	if now < mine[kind :: any] then
		return false, `Ready in {math.ceil(mine[kind :: any] - now)}s.`
	end
	mine[kind :: any] = now + def.Cooldown

	local others = math.max(#playersInArena(f, ATTACK_RANGE_EXTRA) - 1, 0)
	local special = kind == "Special"
	local support = special and Combat.IsSupport(companion.Species)
	local damage = Combat.Damage(
		companion.Species,
		companion.Level,
		companion.Stage,
		f.Def.Family,
		special and not support,
		others
	)
	if support then
		-- Support companions cool everyone nearby instead of a big hit.
		for _, ally in playersInArena(f, ATTACK_RANGE_EXTRA) do
			local allyPart = root(ally)
			if
				allyPart
				and part
				and (allyPart.Position - part.Position).Magnitude <= CombatConfig.Special.CoolRadius
			then
				RegionService.AddHeat(ally, -CombatConfig.Special.CoolAllies)
			end
		end
	end
	f.Health -= damage
	f.Damage[player.UserId] = (f.Damage[player.UserId] or 0) + damage
	Remotes.Events.GameEvent:FireAllClients("GuardianHit", {
		Guardian = f.Def.Id,
		Damage = damage,
		UserId = player.UserId,
		CreatureId = companion.Id,
		Family = (CreatureConfig.Species[companion.Species] :: any).Family,
		Special = special,
		Support = support,
	})
	if f.Health <= 0 then
		f.Health = 0
		f.Alive = false
		f.Pending = {}
		f.RespawnAt = Workspace:GetServerTimeNow() + f.Def.Respawn
		publish(f)
		reward(f)
		Remotes.Events.GameEvent:FireAllClients("GuardianDefeated", { Guardian = f.Def.Id })
	else
		publish(f)
	end
	return true, damage
end

function GuardianService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = Workspace
	for id, def in CombatConfig.Guardians do
		local region = RegionConfig.Regions[def.Region]
		if region then
			local anchor = Instance.new("Configuration")
			anchor.Name = id
			anchor:SetAttribute("Name", def.Name)
			anchor:SetAttribute("Species", def.Species)
			anchor:SetAttribute("Position", region.Center + region.Guardian.Offset)
			anchor:SetAttribute("ArenaRadius", region.Guardian.ArenaRadius)
			anchor.Parent = folder
			local fight: Fight = {
				Def = def,
				Center = region.Center + region.Guardian.Offset,
				Radius = region.Guardian.ArenaRadius,
				Anchor = anchor,
				Alive = true,
				Health = 0,
				MaxHealth = 0,
				Fighters = 1,
				Damage = {},
				NextSlam = 0,
				Pending = {},
				RespawnAt = 0,
				EmptySince = nil,
			}
			reset(fight)
			fights[id] = fight
		end
	end

	PlayerDataService.Loaded:Connect(function(player)
		cooldowns[player] = { Attack = 0, Special = 0 }
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
	Net.Handle("GuardianAttack", { Rate = { 4, 2 }, Args = { Net.Check.Id } }, attack)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = Workspace:GetServerTimeNow()
			for _, fight in fights do
				local ok, err = pcall(function()
					tickFight(fight, now)
					return true
				end)
				if not ok then
					Log.Warn("Guardian", "tick failed", { error = tostring(err) })
				end
			end
		end
	end)
end

return GuardianService
