--!strict
-- Two-player trading in the same server.
--
--   1. A sends an invite (TradeRequest); B accepts within InviteSeconds (TradeRespond).
--   2. Both edit their offers (TradeOffer). Any change clears both "ready" ticks.
--   3. When both are ready, a short countdown runs; any change cancels it.
--   4. At the end everything is re-checked (ownership, tradability, room) and the swap is
--      applied to both profiles in one step with no yields (Shared/Util/Trade), then both
--      profiles are saved straight away.
-- Leaving the server, or either player cancelling, ends the session with nothing moved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local SocialConfig = require(Shared.Config.SocialConfig)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Trade = require(Shared.Util.Trade)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local EconomyService = require(script.Parent.EconomyService)
local ProductionService = require(script.Parent.ProductionService)
local BuildingService = require(script.Parent.BuildingService)
local CreatureService = require(script.Parent.CreatureService)

local TradingService = {}

type Session = {
	Players: { Player },
	Offers: { [Player]: Trade.Offer },
	Ready: { [Player]: boolean },
	Version: number,
	Committing: boolean,
	CountdownEnds: number?,
}

local sessions: { [Player]: Session } = {}
local invites: { [Player]: { [number]: number } } = {} -- target -> from userId -> expires (os.clock)

local function other(session: Session, player: Player): Player
	return if session.Players[1] == player then session.Players[2] else session.Players[1]
end

local function limitsFor(player: Player): Trade.Limits
	local data = PlayerDataService.GetData(player) :: Types.PlayerData
	return {
		CreatureCapacity = BuildingService.CreatureCapacity(data),
		Capacity = function(resource: string): number
			return EconomyService.Capacity(player, resource)
		end,
	}
end

-- What the client shows for an offer (creature details come from the giver's data).
local function describe(player: Player, offer: Trade.Offer): any
	local data = PlayerDataService.GetData(player)
	local creatures = {}
	for _, id in offer.Creatures do
		local creature = data and data.Creatures[id]
		if creature then
			local species = CreatureConfig.Species[creature.Species]
			table.insert(creatures, {
				Id = id,
				Species = creature.Species,
				Name = creature.Nickname or (species and species.Name or creature.Species),
				Level = creature.Level,
				Stage = creature.Stage,
				Mutation = creature.Mutation,
			})
		end
	end
	return { Creatures = creatures, Resources = table.clone(offer.Resources) }
end

local function push(session: Session, message: string?)
	for _, player in session.Players do
		local them = other(session, player)
		Remotes.Events.GameEvent:FireClient(player, "TradeState", {
			Partner = them.DisplayName,
			PartnerUserId = them.UserId,
			Mine = describe(player, session.Offers[player]),
			Theirs = describe(them, session.Offers[them]),
			MyReady = session.Ready[player] == true,
			TheirReady = session.Ready[them] == true,
			CountdownEnds = session.CountdownEnds,
			Message = message,
		})
	end
end

local function close(session: Session, reason: string)
	for _, player in session.Players do
		if sessions[player] == session then
			sessions[player] = nil
		end
		if player.Parent then
			Remotes.Events.GameEvent:FireClient(player, "TradeClosed", { Reason = reason })
		end
	end
end

local function commit(session: Session)
	local a, b = session.Players[1], session.Players[2]
	local dataA = PlayerDataService.GetData(a)
	local dataB = PlayerDataService.GetData(b)
	if not dataA or not dataB or not a.Parent or not b.Parent then
		close(session, "The other player left. Nothing was traded.")
		return
	end
	ProductionService.Flush(a)
	ProductionService.Flush(b)
	local offerA, offerB = session.Offers[a], session.Offers[b]
	-- From here to Apply there are no yields: nothing can change in between.
	local ok, reason = Trade.Validate(dataA, offerA, limitsFor(a), dataB, offerB, limitsFor(b))
	if not ok then
		session.Ready = {}
		session.CountdownEnds = nil
		push(session, reason)
		return
	end
	Trade.Apply(dataA, offerA, dataB, offerB, os.time())
	session.Committing = true
	for _, player in { a, b } do
		PlayerDataService.MarkDirty(player)
		CreatureService.RefreshAll(player)
		ProductionService.Invalidate(player)
		StateService.Push(player, "Wallet", "Creatures", "Collection", "Empire", "Buildings")
	end
	Events.Traded:Fire(a, b)
	Log.Info("Trade", "Completed", {
		a = a.UserId,
		b = b.UserId,
		aCreatures = #offerA.Creatures,
		bCreatures = #offerB.Creatures,
	})
	close(session, "Trade complete!")
	-- Save both sides now so a crash can't undo one half.
	local results = {}
	for _, player in { a, b } do
		task.spawn(function()
			local ok = false
			for attempt = 1, 5 do
				ok = PlayerDataService.SaveNow(player)
				if ok or not player.Parent then
					break
				end
				task.wait(2 ^ attempt)
			end
			results[player] = ok
			if results[a] ~= nil and results[b] ~= nil and results[a] ~= results[b] then
				-- Only one side stored: the other keeps retrying through autosave and the
				-- release on leave, but flag it so it can be checked.
				Log.Warn("Trade", "Only one side saved right away", { a = a.UserId, b = b.UserId })
			end
		end)
	end
end

local function startCountdown(session: Session)
	session.Version += 1
	local version = session.Version
	session.CountdownEnds = Workspace:GetServerTimeNow() + SocialConfig.Trade.ConfirmSeconds
	push(session, nil)
	task.delay(SocialConfig.Trade.ConfirmSeconds, function()
		local a, b = session.Players[1], session.Players[2]
		if
			session.Version == version
			and sessions[a] == session
			and sessions[b] == session
			and session.Ready[a]
			and session.Ready[b]
			and not session.Committing
		then
			commit(session)
		end
	end)
end

local function request(player: Player, userId: number): (boolean, any)
	if not EconomyConfig.Trading.Enabled then
		return false, "Trading is turned off."
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player or not PlayerDataService.GetData(target) then
		return false, "They aren't available to trade."
	end
	if sessions[player] then
		return false, "Finish your current trade first."
	end
	if sessions[target] then
		return false, `{target.DisplayName} is already trading.`
	end
	local list = invites[target] or {}
	invites[target] = list
	list[player.UserId] = os.clock() + SocialConfig.Trade.InviteSeconds
	Remotes.Events.GameEvent:FireClient(target, "TradeInvite", {
		FromUserId = player.UserId,
		FromName = player.DisplayName,
		Seconds = SocialConfig.Trade.InviteSeconds,
	})
	return true, nil
end

local function respond(player: Player, fromUserId: number, accept: boolean): (boolean, any)
	local list = invites[player]
	local expires = list and list[fromUserId]
	if list then
		list[fromUserId] = nil
	end
	local from = Players:GetPlayerByUserId(fromUserId)
	if not expires or expires < os.clock() or not from then
		return false, "That invite has expired."
	end
	if not accept then
		Remotes.Events.Notify:FireClient(from, `{player.DisplayName} declined your trade.`, "Info")
		return true, nil
	end
	if sessions[player] or sessions[from] then
		return false, "One of you is already trading."
	end
	local session: Session = {
		Players = { from, player },
		Offers = { [from] = Trade.Empty(), [player] = Trade.Empty() },
		Ready = {},
		Version = 0,
		Committing = false,
		CountdownEnds = nil,
	}
	sessions[from] = session
	sessions[player] = session
	push(session, nil)
	return true, nil
end

local function setOffer(player: Player, raw: any): (boolean, any)
	local session = sessions[player]
	if not session or session.Committing then
		return false, "You aren't trading."
	end
	local offer = Trade.Clean(raw)
	if not offer then
		return false, "Invalid offer."
	end
	local ok, reason = Trade.CanGive(PlayerDataService.GetData(player) :: Types.PlayerData, offer)
	if not ok then
		return false, reason
	end
	session.Offers[player] = offer
	session.Ready = {} -- any change: both must confirm again
	session.CountdownEnds = nil
	session.Version += 1
	push(session, nil)
	return true, nil
end

local function setReady(player: Player, ready: boolean): (boolean, any)
	local session = sessions[player]
	if not session or session.Committing then
		return false, "You aren't trading."
	end
	session.Ready[player] = ready
	local a, b = session.Players[1], session.Players[2]
	if session.Ready[a] and session.Ready[b] then
		local dataA, dataB = PlayerDataService.GetData(a), PlayerDataService.GetData(b)
		if not dataA or not dataB then
			close(session, "The other player left. Nothing was traded.")
			return true, nil
		end
		local ok, reason =
			Trade.Validate(dataA, session.Offers[a], limitsFor(a), dataB, session.Offers[b], limitsFor(b))
		if not ok then
			session.Ready = {}
			push(session, reason)
			return true, nil
		end
		startCountdown(session)
	else
		session.Version += 1
		session.CountdownEnds = nil
		push(session, nil)
	end
	return true, nil
end

local function cancel(player: Player): (boolean, any)
	local session = sessions[player]
	if session and not session.Committing then
		close(session, `{player.DisplayName} cancelled the trade.`)
	end
	return true, nil
end

function TradingService.Start()
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		local session = sessions[player]
		if session and not session.Committing then
			close(session, "The other player left. Nothing was traded.")
		end
		sessions[player] = nil
	end)
	local Check = Net.Check
	Net.Handle("TradeRequest", { Rate = { 3, 0.2 }, Args = { Check.Integer } }, request)
	Net.Handle("TradeRespond", { Rate = { 4, 1 }, Args = { Check.Integer, Check.Boolean } }, respond)
	Net.Handle("TradeOffer", { Rate = { 8, 3 }, Args = { Check.Any } }, setOffer)
	Net.Handle("TradeReady", { Rate = { 6, 2 }, Args = { Check.Boolean } }, setReady)
	Net.Handle("TradeCancel", { Rate = { 4, 1 } }, cancel)
end

return TradingService
