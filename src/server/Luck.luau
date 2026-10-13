-- 2x Luck (Robux Store perk). A lucky player rolls twice and keeps the rarer result, so
-- every rare outcome becomes roughly twice as likely without touching the listed odds.

local Luck = {}

function Luck.Has(player: Player): boolean
	return player:GetAttribute("Perk_Luck") == true
end

-- Calls `roll` once (or twice for a lucky player) and keeps the result `isRarer` prefers.
function Luck.Roll<T>(player: Player, roll: () -> T, isRarer: (a: T, b: T) -> boolean): T
	local result = roll()
	if Luck.Has(player) then
		local second = roll()
		if isRarer(second, result) then
			result = second
		end
	end
	return result
end

-- Multiplier for flat chances (e.g. the Mythic drop).
function Luck.Multiplier(player: Player): number
	return if Luck.Has(player) then 2 else 1
end

return Luck
