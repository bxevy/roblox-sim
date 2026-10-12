-- Every weapon and armor in the game.
--
-- Items have a Tier (1-8, plus 9 for ultra-rare Mythic drops). Tier sets rarity and base power; dungeons drop items by tier
-- (see Dungeons.luau). Each class uses one weapon type; armor works for every class.

export type Effect = {
	Type: string, -- "Burn" | "Frost" | "Lifesteal"
	Amount: number, -- Burn: fraction of hit dealt per second, Frost: slow fraction, Lifesteal: fraction healed
	Duration: number?, -- seconds (Burn, Frost)
}

export type WeaponDef = {
	Id: string,
	Kind: "Weapon",
	DisplayName: string,
	Type: string, -- "Sword" | "Staff" | "Bow"
	Tier: number,
	Rarity: string,
	Damage: number,
	Cooldown: number,
	Range: number,
	Splash: number?, -- staffs: area damage radius around the target
	Effect: Effect?,
	Color: Color3, -- blade / shaft / limbs
	Accent: Color3, -- guard / gem / string
	Material: Enum.Material,
	Model: string?, -- custom model builder in CombatService (otherwise built from Type)
}

export type ArmorDef = {
	Id: string,
	Kind: "Armor",
	DisplayName: string,
	Tier: number,
	Rarity: string,
	Health: number,
	Defense: number,
	Color: Color3,
	Accent: Color3,
	Material: Enum.Material,
}

local Items = {}

local TIER_RARITY = { "Common", "Uncommon", "Uncommon", "Rare", "Rare", "Epic", "Epic", "Legendary", "Mythic" }
local TIER_DAMAGE = { 10, 16, 24, 36, 52, 75, 105, 150, 230 }

local WEAPON_TYPES = {
	Sword = { DamageMultiplier = 1, Cooldown = 0.5, Range = 7 },
	Staff = { DamageMultiplier = 1.3, Cooldown = 0.8, Range = 45, Splash = 5 },
	Bow = { DamageMultiplier = 0.8, Cooldown = 0.45, Range = 60 },
}

local rgb = Color3.fromRGB
local M = Enum.Material

-- { Id, DisplayName, Type, Tier, Color, Accent, Material, Effect?, Model? }
local WEAPON_LIST = {
	-- Swords (Warrior)
	{ "WoodenSword", "Wooden Sword", "Sword", 1, rgb(150, 105, 60), rgb(90, 60, 35), M.Wood },
	{ "IronSword", "Iron Sword", "Sword", 2, rgb(165, 165, 175), rgb(90, 70, 40), M.Metal },
	{ "SteelBlade", "Steel Blade", "Sword", 3, rgb(210, 215, 225), rgb(60, 60, 70), M.Metal },
	{ "KnightsLongsword", "Knight's Longsword", "Sword", 4, rgb(235, 235, 245), rgb(200, 170, 60), M.Metal },
	{ "BoneCleaver", "Bone Cleaver", "Sword", 5, rgb(230, 225, 205), rgb(140, 40, 40), M.Marble, { Type = "Lifesteal", Amount = 0.06 } },
	{ "SandReaver", "Sand Reaver", "Sword", 6, rgb(235, 195, 90), rgb(40, 60, 140), M.Metal, { Type = "Burn", Amount = 0.15, Duration = 3 } },
	{ "Frostbrand", "Frostbrand", "Sword", 7, rgb(150, 220, 255), rgb(230, 245, 255), M.Ice, { Type = "Frost", Amount = 0.4, Duration = 2 } },
	{ "Dragonfang", "Dragonfang", "Sword", 8, rgb(255, 110, 40), rgb(60, 20, 20), M.Neon, { Type = "Burn", Amount = 0.25, Duration = 3 } },
	-- Mythic: never in normal loot tables, only from the ultra-rare drop (Config.MythicDrop)
	{ "VoidlightGreatsword", "Voidlight Greatsword", "Sword", 9, rgb(236, 240, 252), rgb(28, 34, 92), M.Metal, { Type = "Frost", Amount = 0.5, Duration = 2.5 }, "Voidlight" },

	-- Staffs (Mage)
	{ "ApprenticeStaff", "Apprentice Staff", "Staff", 1, rgb(120, 85, 50), rgb(120, 180, 255), M.Wood },
	{ "WillowStaff", "Willow Staff", "Staff", 2, rgb(140, 120, 80), rgb(120, 255, 140), M.Wood },
	{ "CrystalStaff", "Crystal Staff", "Staff", 3, rgb(200, 200, 220), rgb(200, 120, 255), M.Metal },
	{ "NecroStaff", "Necro Staff", "Staff", 4, rgb(50, 45, 55), rgb(120, 255, 120), M.Slate, { Type = "Lifesteal", Amount = 0.05 } },
	{ "StaffOfCinders", "Staff of Cinders", "Staff", 5, rgb(70, 40, 30), rgb(255, 120, 40), M.Wood, { Type = "Burn", Amount = 0.15, Duration = 3 } },
	{ "SunspireScepter", "Sunspire Scepter", "Staff", 6, rgb(230, 190, 70), rgb(255, 240, 150), M.Metal, { Type = "Burn", Amount = 0.2, Duration = 3 } },
	{ "RimefrostStaff", "Rimefrost Staff", "Staff", 7, rgb(170, 210, 240), rgb(120, 220, 255), M.Ice, { Type = "Frost", Amount = 0.4, Duration = 2 } },
	{ "ArchmagesInferno", "Archmage's Inferno", "Staff", 8, rgb(40, 20, 30), rgb(255, 80, 20), M.Basalt, { Type = "Burn", Amount = 0.3, Duration = 3 } },

	-- Bows (Ranger)
	{ "HuntingBow", "Hunting Bow", "Bow", 1, rgb(140, 95, 55), rgb(230, 230, 230), M.Wood },
	{ "RecurveBow", "Recurve Bow", "Bow", 2, rgb(110, 70, 40), rgb(230, 230, 230), M.Wood },
	{ "Longbow", "Longbow", "Bow", 3, rgb(160, 120, 70), rgb(255, 255, 255), M.Wood },
	{ "BoneBow", "Bone Bow", "Bow", 4, rgb(225, 220, 200), rgb(160, 40, 40), M.Marble, { Type = "Lifesteal", Amount = 0.05 } },
	{ "DesertWind", "Desert Wind", "Bow", 5, rgb(220, 185, 110), rgb(60, 200, 200), M.Sandstone, { Type = "Frost", Amount = 0.3, Duration = 2 } },
	{ "ViperSting", "Viper's Sting", "Bow", 6, rgb(40, 110, 50), rgb(140, 255, 80), M.Metal, { Type = "Burn", Amount = 0.2, Duration = 3 } },
	{ "FrostbiteBow", "Frostbite Bow", "Bow", 7, rgb(160, 210, 245), rgb(230, 250, 255), M.Ice, { Type = "Frost", Amount = 0.45, Duration = 2 } },
	{ "PhoenixBow", "Phoenix Bow", "Bow", 8, rgb(255, 120, 30), rgb(255, 230, 120), M.Neon, { Type = "Burn", Amount = 0.25, Duration = 3 } },
}

-- { Id, DisplayName, Tier, Health, Defense, Color, Accent, Material }
local ARMOR_LIST = {
	{ "LeatherTunic", "Leather Tunic", 1, 20, 0.03, rgb(120, 80, 50), rgb(80, 55, 35), M.Leather },
	{ "StuddedLeather", "Studded Leather", 2, 40, 0.05, rgb(100, 70, 45), rgb(180, 180, 190), M.Leather },
	{ "Chainmail", "Chainmail", 3, 70, 0.08, rgb(150, 150, 160), rgb(110, 110, 120), M.DiamondPlate },
	{ "IronPlate", "Iron Plate", 4, 110, 0.11, rgb(130, 130, 140), rgb(90, 90, 100), M.Metal },
	{ "KnightsPlate", "Knight's Plate", 5, 160, 0.14, rgb(200, 200, 210), rgb(200, 170, 60), M.Metal },
	{ "ScarabCarapace", "Scarab Carapace", 6, 230, 0.17, rgb(30, 80, 100), rgb(240, 200, 70), M.Glass },
	{ "GlacialAegis", "Glacial Aegis", 7, 320, 0.2, rgb(170, 215, 245), rgb(120, 220, 255), M.Ice },
	{ "DragonscaleArmor", "Dragonscale Armor", 8, 450, 0.25, rgb(150, 30, 25), rgb(255, 150, 40), M.Slate },
}

Items.Weapons = {} :: { [string]: WeaponDef }
Items.Armors = {} :: { [string]: ArmorDef }
Items.WeaponOrder = {} :: { string }
Items.ArmorOrder = {} :: { string }

for _, entry in WEAPON_LIST do
	local id, name, weaponType, tier = entry[1], entry[2], entry[3], entry[4]
	local base = WEAPON_TYPES[weaponType]
	Items.Weapons[id] = {
		Id = id,
		Kind = "Weapon",
		DisplayName = name,
		Type = weaponType,
		Tier = tier,
		Rarity = TIER_RARITY[tier],
		Damage = math.floor(TIER_DAMAGE[tier] * base.DamageMultiplier),
		Cooldown = base.Cooldown,
		Range = base.Range,
		Splash = base.Splash,
		Effect = entry[8],
		Model = entry[9],
		Color = entry[5],
		Accent = entry[6],
		Material = entry[7],
	}
	table.insert(Items.WeaponOrder, id)
end

for _, entry in ARMOR_LIST do
	local id, tier = entry[1], entry[3]
	Items.Armors[id] = {
		Id = id,
		Kind = "Armor",
		DisplayName = entry[2],
		Tier = tier,
		Rarity = TIER_RARITY[tier],
		Health = entry[4],
		Defense = entry[5],
		Color = entry[6],
		Accent = entry[7],
		Material = entry[8],
	}
	table.insert(Items.ArmorOrder, id)
end

function Items.WeaponsOfType(weaponType: string, tier: number): { WeaponDef }
	local found = {}
	for _, id in Items.WeaponOrder do
		local weapon = Items.Weapons[id]
		if weapon.Type == weaponType and weapon.Tier == tier then
			table.insert(found, weapon)
		end
	end
	return found
end

function Items.ArmorsOfTier(tier: number): { ArmorDef }
	local found = {}
	for _, id in Items.ArmorOrder do
		if Items.Armors[id].Tier == tier then
			table.insert(found, Items.Armors[id])
		end
	end
	return found
end

-- Short description of an item's special effect, for UI.
function Items.DescribeEffect(effect: Effect?): string?
	if not effect then
		return nil
	end
	if effect.Type == "Burn" then
		return `Burn {math.floor(effect.Amount * 100)}%/s`
	elseif effect.Type == "Frost" then
		return `Frost: slows {math.floor(effect.Amount * 100)}%`
	elseif effect.Type == "Lifesteal" then
		return `Lifesteal {math.floor(effect.Amount * 100)}%`
	end
	return nil
end

return Items
