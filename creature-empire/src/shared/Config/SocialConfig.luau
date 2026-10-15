--!strict
-- Multiplayer rules: plot permissions, cheering and trading.
--
-- Permissions on a plot:
--   Owner         everything
--   Collaborator  chosen by the owner (saved, up to MaxCollaborators): can collect the
--                 owner's harvests into the OWNER's silo and cheer. Can't build, upgrade,
--                 sell, assign or spend anything.
--   Visitor       look around, inspect, cheer

local SocialConfig = {}

SocialConfig.MaxCollaborators = 5

-- Cheering another empire: its production buildings work faster for a while. Each visitor
-- can cheer a given empire once per Cooldown, and at most MaxStacks cheers count at once.
-- The cheering player gets a small thank-you gift (also on a cooldown).
SocialConfig.Cheer = {
	Cooldown = 10 * 60,
	Duration = 10 * 60,
	Value = 0.1, -- +10% work speed, bonus category "Boost"
	MaxStacks = 3,
	Reward = { Gold = 50 } :: { [string]: number },
	Range = 60, -- studs from the empire's core
}

-- Trading between two players in the same server.
SocialConfig.Trade = {
	InviteSeconds = 30,
	ConfirmSeconds = 3, -- countdown after both are ready; any change cancels it
	MaxCreatures = 4, -- per side
	-- Only these can be traded besides creatures. Currencies and silo materials can't be, so
	-- trades can't carry wealth past an Ascension (parked on a friend) or be used to sell
	-- gold. Ember Lures are kept through Ascension anyway.
	Resources = { "EmberLure" },
	MaxDistance = nil :: number?, -- trades work from anywhere in the server
}

-- Switched-off items (ResourceConfig Enabled = false) can't be traded for now.
do
	local ResourceConfig = require(script.Parent.ResourceConfig)
	local kept = {}
	for _, id in SocialConfig.Trade.Resources do
		local def = ResourceConfig[id]
		if def and def.Enabled ~= false then
			table.insert(kept, id)
		end
	end
	SocialConfig.Trade.Resources = kept
end

return SocialConfig
