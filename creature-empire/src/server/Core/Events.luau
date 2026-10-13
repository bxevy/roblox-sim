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
	-- (player, speciesId)
	StarterChosen = Signal.new() :: Signal.Signal<Player, string>,
}
