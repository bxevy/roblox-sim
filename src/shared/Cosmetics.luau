-- Player card cosmetics (backgrounds, titles, frames) and prestige emblems.
--
-- Unlock rules (checked on both server and client with Cosmetics.IsUnlocked):
--   nil                                  always unlocked
--   { Stat = "Clears_Crypt", Value = 1 } lifetime stat at least Value
--   { Level = 25 }                        reached this level (or have prestiged)
--   { Prestige = 3 }                      reached this prestige
--   { Item = "VoidlightGreatsword" }      own this weapon or armor piece
--   { AnyOfSet = "BlackDragon" }          own any piece of this armor set
--   { FullSet = "BlackDragon" }           own all 4 pieces of this armor set
--   { Rarity = "Mythic" }                 own any item of this rarity

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)

local Cosmetics = {}

local rgb = Color3.fromRGB

export type Unlock = { [string]: any }?

-- Prestige emblems -----------------------------------------------------------------
-- Shapes are drawn from UI frames (see CardUI.Emblem).
--   Shape: "Circle" | "Diamond" | "Star" | "Hex" | "Burst"
Cosmetics.Emblems = {
	{ Name = "Bronze", Shape = "Circle", Outer = rgb(205, 127, 50), Inner = rgb(110, 62, 28), Accent = rgb(255, 205, 150) },
	{ Name = "Silver", Shape = "Diamond", Outer = rgb(215, 220, 232), Inner = rgb(110, 115, 130), Accent = rgb(255, 255, 255) },
	{ Name = "Gold", Shape = "Star", Outer = rgb(255, 210, 70), Inner = rgb(170, 115, 20), Accent = rgb(255, 245, 190) },
	{ Name = "Emerald", Shape = "Hex", Outer = rgb(60, 210, 120), Inner = rgb(15, 90, 50), Accent = rgb(190, 255, 210) },
	{ Name = "Sapphire", Shape = "Diamond", Outer = rgb(70, 130, 255), Inner = rgb(20, 40, 120), Accent = rgb(190, 215, 255), Wings = true },
	{ Name = "Ruby", Shape = "Star", Outer = rgb(235, 50, 70), Inner = rgb(100, 10, 25), Accent = rgb(255, 190, 200), Wings = true },
	{ Name = "Amethyst", Shape = "Hex", Outer = rgb(175, 90, 255), Inner = rgb(60, 20, 110), Accent = rgb(230, 200, 255), Wings = true, Crown = true },
	{ Name = "Obsidian", Shape = "Burst", Outer = rgb(40, 35, 45), Inner = rgb(10, 8, 12), Accent = rgb(255, 60, 40), Crown = true },
	{ Name = "Celestial", Shape = "Burst", Outer = rgb(180, 240, 255), Inner = rgb(40, 90, 160), Accent = rgb(255, 255, 255), Wings = true, Crown = true },
	{ Name = "Godslayer", Shape = "Burst", Outer = rgb(255, 60, 120), Inner = rgb(60, 0, 30), Accent = rgb(255, 220, 90), Wings = true, Crown = true, Spin = true },
	-- Past the last prestige (the owner's Creator Rank): always this one.
	{ Name = "Creator", Shape = "Star", Outer = rgb(255, 255, 255), Inner = rgb(20, 0, 40), Accent = rgb(255, 120, 230), Wings = true, Crown = true, Spin = true },
}
Cosmetics.MaxPrestigeEmblem = 10 -- emblems past this index are special (Creator Rank)

-- Which emblem a prestige shows.
function Cosmetics.EmblemFor(prestige: number)
	if prestige <= 0 then
		return nil
	elseif prestige > Cosmetics.MaxPrestigeEmblem then
		return Cosmetics.Emblems[#Cosmetics.Emblems]
	end
	return Cosmetics.Emblems[prestige]
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
function Cosmetics.Roman(n: number): string
	return ROMAN[n] or tostring(n)
end

-- Backgrounds ----------------------------------------------------------------------
--   Colors: gradient stops; Rotation: gradient angle; Pattern: "Stripes" | "Dots" | "Rays" | "Stars" | nil
Cosmetics.Backgrounds = {
	{ Id = "Parchment", Name = "Parchment", Colors = { rgb(225, 205, 160), rgb(180, 150, 100) }, Rotation = 90, TextDark = true },
	{ Id = "Midnight", Name = "Midnight", Colors = { rgb(25, 30, 60), rgb(10, 10, 25) }, Rotation = 90, Pattern = "Stars", PatternColor = rgb(255, 255, 255) },
	{ Id = "Forest", Name = "Forest", Colors = { rgb(50, 110, 60), rgb(20, 50, 30) }, Rotation = 90, Pattern = "Dots", PatternColor = rgb(150, 220, 120) },
	{ Id = "CryptMist", Name = "Crypt Mist", Colors = { rgb(70, 95, 80), rgb(20, 28, 25) }, Rotation = 90, Pattern = "Dots", PatternColor = rgb(140, 255, 160), Unlock = { Stat = "Clears_Crypt", Value = 1 } },
	{ Id = "DesertSun", Name = "Desert Sun", Colors = { rgb(255, 200, 100), rgb(200, 110, 40) }, Rotation = 90, Pattern = "Rays", PatternColor = rgb(255, 240, 180), Unlock = { Stat = "Clears_Temple", Value = 1 } },
	{ Id = "Witchlight", Name = "Witchlight", Colors = { rgb(90, 50, 140), rgb(30, 60, 30), rgb(10, 15, 10) }, Rotation = 90, Pattern = "Dots", PatternColor = rgb(200, 120, 255), Unlock = { Stat = "Clears_Witchwood", Value = 1 } },
	{ Id = "MoltenCore", Name = "Molten Core", Colors = { rgb(255, 150, 40), rgb(170, 30, 10), rgb(30, 10, 10) }, Rotation = 90, Pattern = "Stripes", PatternColor = rgb(255, 210, 90), Unlock = { Stat = "Clears_Forge", Value = 1 } },
	{ Id = "AbyssalVoid", Name = "Abyssal Void", Colors = { rgb(120, 60, 200), rgb(30, 10, 60), rgb(0, 0, 0) }, Rotation = 70, Pattern = "Stars", PatternColor = rgb(220, 160, 255), Unlock = { Stat = "Clears_Abyss", Value = 1 } },
	{ Id = "FrozenAurora", Name = "Frozen Aurora", Colors = { rgb(90, 220, 200), rgb(60, 70, 180), rgb(20, 20, 60) }, Rotation = 70, Pattern = "Stars", PatternColor = rgb(200, 255, 255), Unlock = { Stat = "Clears_Keep", Value = 1 } },
	{ Id = "Slaughter", Name = "Crimson Tide", Colors = { rgb(150, 20, 25), rgb(40, 5, 8) }, Rotation = 120, Pattern = "Stripes", PatternColor = rgb(255, 80, 80), Unlock = { Stat = "EnemiesKilled", Value = 1000 } },
	{ Id = "BloodMoon", Name = "Blood Moon", Colors = { rgb(90, 0, 20), rgb(20, 0, 5) }, Rotation = 90, Pattern = "Rays", PatternColor = rgb(255, 40, 60), Unlock = { Stat = "Clears_Nightmare", Value = 5 } },
	{ Id = "RoyalVelvet", Name = "Royal Velvet", Colors = { rgb(110, 30, 130), rgb(40, 10, 60) }, Rotation = 90, Pattern = "Stripes", PatternColor = rgb(255, 210, 90), Unlock = { Level = 25 } },
	{ Id = "Dragonfire", Name = "Dragonfire", Colors = { rgb(255, 120, 30), rgb(150, 20, 10), rgb(20, 10, 10) }, Rotation = 90, Pattern = "Rays", PatternColor = rgb(255, 200, 80), Unlock = { AnyOfSet = "BlackDragon" } },
	{ Id = "Sakura", Name = "Sakura", Colors = { rgb(255, 200, 220), rgb(200, 90, 130) }, Rotation = 45, Pattern = "Dots", PatternColor = rgb(255, 240, 245), Unlock = { AnyOfSet = "ShogunsOath" } },
	{ Id = "Voidlight", Name = "Voidlight", Colors = { rgb(40, 50, 140), rgb(10, 10, 40) }, Rotation = 135, Pattern = "Stripes", PatternColor = rgb(120, 150, 255), Unlock = { Item = "VoidlightGreatsword" } },
	{ Id = "GoldenGlory", Name = "Golden Glory", Colors = { rgb(255, 230, 130), rgb(210, 150, 30) }, Rotation = 90, Pattern = "Rays", PatternColor = rgb(255, 255, 220), TextDark = true, Unlock = { Prestige = 1 } },
	{ Id = "Starfield", Name = "Starfield", Colors = { rgb(60, 20, 120), rgb(10, 10, 40), rgb(0, 0, 0) }, Rotation = 90, Pattern = "Stars", PatternColor = rgb(255, 230, 255), Unlock = { Prestige = 5 } },
	{ Id = "Godslayer", Name = "Godslayer", Colors = { rgb(255, 60, 120), rgb(120, 20, 160), rgb(255, 200, 60) }, Rotation = 45, Pattern = "Rays", PatternColor = rgb(255, 255, 255), Unlock = { Prestige = 10 } },
	{ Id = "CreatorRealm", Name = "Creator's Realm", Colors = { rgb(255, 120, 230), rgb(90, 40, 200), rgb(10, 0, 30) }, Rotation = 60, Pattern = "Stars", PatternColor = rgb(255, 255, 255), Unlock = { Prestige = 999 } },
}

-- Titles ---------------------------------------------------------------------------
Cosmetics.Titles = {
	{ Id = "Adventurer", Name = "Adventurer", Color = rgb(220, 220, 220) },
	{ Id = "Novice", Name = "Novice Delver", Color = rgb(200, 180, 140) },
	{ Id = "Bonebreaker", Name = "Bonebreaker", Color = rgb(235, 230, 210), Unlock = { Stat = "Kills_Skeleton", Value = 100 } },
	{ Id = "TombRaider", Name = "Tomb Raider", Color = rgb(255, 200, 100), Unlock = { Stat = "Clears_Temple", Value = 10 } },
	{ Id = "Forgeborn", Name = "Forgeborn", Color = rgb(255, 130, 40), Unlock = { Stat = "Clears_Forge", Value = 10 } },
	{ Id = "Voidwalker", Name = "Voidwalker", Color = rgb(190, 120, 255), Unlock = { Stat = "Clears_Abyss", Value = 10 } },
	{ Id = "Seraphic", Name = "Seraphic", Color = rgb(255, 240, 170), Unlock = { Stat = "SeraphRolled", Value = 1 } },
	{ Id = "Frostwalker", Name = "Frostwalker", Color = rgb(150, 220, 255), Unlock = { Stat = "Clears_Keep", Value = 10 } },
	{ Id = "Kingslayer", Name = "Kingslayer", Color = rgb(255, 120, 90), Unlock = { Stat = "BossesKilled", Value = 100 } },
	{ Id = "NightmareSlayer", Name = "Nightmare Slayer", Color = rgb(220, 40, 60), Unlock = { Stat = "Clears_Nightmare", Value = 10 } },
	{ Id = "TreasureHunter", Name = "Treasure Hunter", Color = rgb(255, 215, 80), Unlock = { Stat = "CratesOpened", Value = 25 } },
	{ Id = "Mythbearer", Name = "Mythbearer", Color = rgb(130, 150, 255), Unlock = { Rarity = "Mythic" } },
	{ Id = "WielderOfTheVoid", Name = "Wielder of the Void", Color = rgb(110, 130, 255), Unlock = { Item = "VoidlightGreatsword" } },
	{ Id = "DragonLord", Name = "Dragon Lord", Color = rgb(255, 70, 40), Unlock = { FullSet = "BlackDragon" } },
	{ Id = "Shogun", Name = "Shogun", Color = rgb(255, 170, 205), Unlock = { FullSet = "ShogunsOath" } },
	{ Id = "Ascendant", Name = "Ascendant", Color = rgb(255, 230, 140), Unlock = { Prestige = 1 } },
	{ Id = "Paragon", Name = "Paragon", Color = rgb(190, 140, 255), Unlock = { Prestige = 5 } },
	{ Id = "Godslayer", Name = "Godslayer", Color = rgb(255, 60, 120), Unlock = { Prestige = 10 } },
	{ Id = "Creator", Name = "The Creator", Color = rgb(255, 120, 230), Unlock = { Prestige = 999 } },
}

-- Frames (card border) ---------------------------------------------------------------
Cosmetics.Frames = {
	{ Id = "Wood", Name = "Wood", Colors = { rgb(120, 80, 45), rgb(70, 45, 25) } },
	{ Id = "Iron", Name = "Iron", Colors = { rgb(170, 175, 185), rgb(80, 85, 95) }, Unlock = { Level = 15 } },
	{ Id = "Gold", Name = "Gold", Colors = { rgb(255, 220, 90), rgb(180, 120, 20) }, Unlock = { Level = 30 } },
	{ Id = "Mythic", Name = "Mythic", Colors = { rgb(150, 170, 255), rgb(70, 50, 200) }, Unlock = { Rarity = "Mythic" } },
	{ Id = "Godly", Name = "Godly", Colors = { rgb(255, 70, 130), rgb(255, 200, 60) }, Unlock = { Rarity = "Godly" } },
	{ Id = "Ascended", Name = "Ascended", Colors = { rgb(255, 255, 255), rgb(255, 210, 90), rgb(255, 80, 160) }, Unlock = { Prestige = 3 }, Spin = true },
	{ Id = "Creator", Name = "Creator", Colors = { rgb(255, 255, 255), rgb(255, 120, 230), rgb(120, 60, 255) }, Unlock = { Prestige = 999 }, Spin = true },
}

local function index(list)
	local map = {}
	for _, entry in list do
		map[entry.Id] = entry
	end
	return map
end
Cosmetics.BackgroundsById = index(Cosmetics.Backgrounds)
Cosmetics.TitlesById = index(Cosmetics.Titles)
Cosmetics.FramesById = index(Cosmetics.Frames)

-- Unlocks ------------------------------------------------------------------------------

export type Profile = {
	Level: number,
	Prestige: number,
	Stats: { [string]: number },
	Weapons: { [string]: boolean },
	Armors: { [string]: boolean },
}

local function owns(profile: Profile, itemId: string): boolean
	return profile.Weapons[itemId] == true or profile.Armors[itemId] == true
end

function Cosmetics.IsUnlocked(profile: Profile, unlock: Unlock): boolean
	if not unlock then
		return true
	end
	if unlock.Stat then
		return (profile.Stats[unlock.Stat] or 0) >= unlock.Value
	elseif unlock.Level then
		return profile.Level >= unlock.Level or profile.Prestige > 0
	elseif unlock.Prestige then
		return profile.Prestige >= unlock.Prestige
	elseif unlock.Item then
		return owns(profile, unlock.Item)
	elseif unlock.AnyOfSet or unlock.FullSet then
		local set = Items.ArmorSets[unlock.AnyOfSet or unlock.FullSet]
		local count = 0
		for _, pieceId in set.Pieces do
			if profile.Armors[pieceId] then
				count += 1
			end
		end
		return if unlock.FullSet then count == 4 else count > 0
	elseif unlock.Rarity then
		for id in profile.Weapons do
			if Items.Weapons[id] and Items.Weapons[id].Rarity == unlock.Rarity then
				return true
			end
		end
		for id in profile.Armors do
			if Items.Armors[id] and Items.Armors[id].Rarity == unlock.Rarity then
				return true
			end
		end
		return false
	end
	return false
end

-- Human-readable unlock requirement for locked items in the UI.
function Cosmetics.Describe(unlock: Unlock): string
	if not unlock then
		return "Unlocked"
	elseif unlock.Stat then
		local pretty = unlock.Stat:gsub("Clears_", "Clear "):gsub("Kills_", "Defeat "):gsub("(%l)(%u)", "%1 %2")
		return `{pretty}: {unlock.Value}`
	elseif unlock.Level then
		return `Reach level {unlock.Level}`
	elseif unlock.Prestige then
		return `Reach Prestige {Cosmetics.Roman(unlock.Prestige)}`
	elseif unlock.Item then
		local item = Items.Weapons[unlock.Item] or Items.Armors[unlock.Item]
		return `Own {if item then item.DisplayName else unlock.Item}`
	elseif unlock.AnyOfSet then
		return `Own any {Items.ArmorSets[unlock.AnyOfSet].DisplayName} piece`
	elseif unlock.FullSet then
		return `Own the full {Items.ArmorSets[unlock.FullSet].DisplayName} set`
	elseif unlock.Rarity then
		return `Own any {unlock.Rarity} item`
	end
	return "Locked"
end

return Cosmetics
