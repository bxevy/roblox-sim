--!strict
-- Server-internal events. Services announce what happened; other services (quests,
-- achievements later on, analytics) listen without the announcer knowing about them.

local Signal = require(script.Parent.Signal)

return {
	-- (player, resourceId, amount)
	Collected = Signal.new() :: Signal.Signal<Player, string, number>,
	-- (player, resourceId, amount, goldReceived)
	Sold = Signal.new() :: Signal.Signal<Player, string, number, number>,
	-- (player, currencyId, amount, reason)
	CurrencyEarned = Signal.new() :: Signal.Signal<Player, string, number, string>,
	-- (player, creatureId, abilityId)
	AbilityUsed = Signal.new() :: Signal.Signal<Player, string, string>,
	-- (player) a creature was assigned or unassigned
	AssignmentsChanged = Signal.new() :: Signal.Signal<Player>,
	-- (player, buildingId, what: "Placed" | "Upgraded")
	BuildingChanged = Signal.new() :: Signal.Signal<Player, string, string>,
	-- (player, creatureId, source)
	CreatureObtained = Signal.new() :: Signal.Signal<Player, string, string>,
	-- (player, creatureId, newLevel)
	CreatureLeveled = Signal.new() :: Signal.Signal<Player, string, number>,
	-- (player, eggId, speciesId)
	Hatched = Signal.new() :: Signal.Signal<Player, string, string>,
	-- (player, creatureId, newStage)
	Evolved = Signal.new() :: Signal.Signal<Player, string, number>,
	-- (player, regionId)
	RegionEntered = Signal.new() :: Signal.Signal<Player, string>,
	-- (player, resourceId, amount)
	Gathered = Signal.new() :: Signal.Signal<Player, string, number>,
	-- (player, landmarkId)
	Discovered = Signal.new() :: Signal.Signal<Player, string>,
	-- (player, itemId, amount)
	Crafted = Signal.new() :: Signal.Signal<Player, string, number>,
	-- (player, speciesId)
	Befriended = Signal.new() :: Signal.Signal<Player, string>,
	-- (player, destinationId, success)
	ExpeditionCompleted = Signal.new() :: Signal.Signal<Player, string, boolean>,
	-- (player, guardianId)
	GuardianDefeated = Signal.new() :: Signal.Signal<Player, string>,
	-- (player, speciesId)
	StarterChosen = Signal.new() :: Signal.Signal<Player, string>,
	-- (player, nodeId)
	Researched = Signal.new() :: Signal.Signal<Player, string>,
	-- (player, ascension count)
	Ascended = Signal.new() :: Signal.Signal<Player, number>,
	-- (player, ownerUserId)
	Cheered = Signal.new() :: Signal.Signal<Player, number>,
	-- (player, eventId) a world event the player took part in has ended (Rift joined, Bloom helped)
	WorldEventJoined = Signal.new() :: Signal.Signal<Player, string>,
	-- (playerA, playerB)
	Traded = Signal.new() :: Signal.Signal<Player, Player>,
}
