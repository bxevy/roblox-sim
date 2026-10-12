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

-- Armor comes in sets of 4 pieces. Each piece is its own item; wearing all 4 pieces of
-- one set gives that set's bonus and an extra aura.
export type ArmorDef = {
	Id: string,
	Kind: "Armor",
	DisplayName: string,
	Set: string,
	Slot: string, -- "Helmet" | "Chest" | "Legs" | "Boots"
	Tier: number,
	Rarity: string,
	Health: number,
	Defense: number,
}

export type SetBonus = {
	Health: number?,
	Defense: number?,
	Damage: number?,
	Speed: number?,
	Description: string,
}

export type ArmorSetDef = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Tier: number,
	Source: string, -- "Loot" (dungeon drops by tier) | "Crate"
	Health: number, -- full-set totals, split across the pieces
	Defense: number,
	SetBonus: SetBonus,
	Pieces: { [string]: string }, -- slot -> piece id
	Style: { [string]: any }, -- looks + effects, read by ArmorVisuals on the server
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

-- Armor sets ------------------------------------------------------------------------
-- Health/Defense are full-set totals; each piece gets a share (SLOT_SHARE).
-- Style keys (see ArmorVisuals): Primary, Secondary, Accent (glow), Cloth, Material,
-- TrimMaterial, Helmet, Pauldron, Emblem, Tabard, Cape, Fur, Wings, Skirt, Boots, Vfx.

Items.ArmorSlots = { "Helmet", "Chest", "Legs", "Boots" }
local SLOT_SHARE = { Helmet = 0.2, Chest = 0.4, Legs = 0.25, Boots = 0.15 }

local ARMOR_SETS = {
	{
		Id = "SquireLeathers",
		DisplayName = "Squire's Leathers",
		Rarity = "Common",
		Tier = 1,
		Health = 30,
		Defense = 0.04,
		SetBonus = { Health = 10, Description = "+10 health" },
		Names = { "Squire's Coif", "Squire's Jerkin", "Squire's Breeches", "Squire's Boots" },
		Style = {
			Primary = rgb(130, 90, 55), Secondary = rgb(85, 58, 38), Accent = rgb(200, 175, 120), Cloth = rgb(120, 45, 40),
			Material = M.Leather, TrimMaterial = M.Leather,
			Helmet = "Coif", Pauldron = "Leather", Skirt = "Loincloth", Boots = "Leather",
			Vfx = { Kind = "Dust", Color = rgb(200, 180, 140), Rate = 2 },
		},
	},
	{
		Id = "MilitiaChainmail",
		DisplayName = "Militia Chainmail",
		Rarity = "Common",
		Tier = 2,
		Health = 50,
		Defense = 0.06,
		SetBonus = { Defense = 0.02, Description = "+2% defense" },
		Names = { "Militia Kettle Hat", "Militia Hauberk", "Militia Chausses", "Militia Boots" },
		Style = {
			Primary = rgb(150, 150, 160), Secondary = rgb(105, 105, 115), Accent = rgb(230, 230, 240), Cloth = rgb(40, 70, 150),
			Material = M.DiamondPlate, TrimMaterial = M.Metal,
			Helmet = "Kettle", Pauldron = "Round", Tabard = true, Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Glint", Color = rgb(255, 255, 255), Rate = 2 },
		},
	},
	{
		Id = "KnightsPlate",
		DisplayName = "Knight's Plate",
		Rarity = "Rare",
		Tier = 3,
		Health = 90,
		Defense = 0.09,
		SetBonus = { Health = 20, Defense = 0.03, Description = "+20 health, +3% defense" },
		Names = { "Knight's Great Helm", "Knight's Cuirass", "Knight's Cuisses", "Knight's Sabatons" },
		Style = {
			Primary = rgb(195, 198, 208), Secondary = rgb(125, 125, 135), Accent = rgb(255, 255, 255), Cloth = rgb(160, 30, 35),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "GreatHelm", Plume = rgb(170, 30, 35), Pauldron = "Layered", Tabard = true, Skirt = "Tassets", Boots = "Plate",
			Vfx = { Kind = "Glint", Color = rgb(255, 255, 255), Rate = 5 },
		},
	},
	{
		Id = "CrusaderPlate",
		DisplayName = "Crusader's Plate",
		Rarity = "Rare",
		Tier = 4,
		Health = 130,
		Defense = 0.12,
		SetBonus = { Health = 30, Damage = 0.05, Description = "+30 health, +5% damage" },
		Names = { "Crusader's Helm", "Crusader's Hauberk", "Crusader's Greaves", "Crusader's Boots" },
		Style = {
			Primary = rgb(235, 232, 225), Secondary = rgb(215, 175, 60), Accent = rgb(200, 30, 30), Cloth = rgb(240, 238, 230),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Crusader", Pauldron = "Round", Emblem = "Cross", Tabard = true, Cape = true, Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Motes", Color = rgb(255, 215, 120), Rate = 5 },
		},
	},
	{
		Id = "RoyalGuard",
		DisplayName = "Royal Guard Regalia",
		Rarity = "Legendary",
		Tier = 5,
		Health = 190,
		Defense = 0.15,
		SetBonus = { Health = 40, Defense = 0.03, Description = "+40 health, +3% defense" },
		Names = { "Royal Guard Crown Helm", "Royal Guard Breastplate", "Royal Guard Tassets", "Royal Guard Sabatons" },
		Style = {
			Primary = rgb(45, 65, 145), Secondary = rgb(225, 180, 60), Accent = rgb(90, 180, 255), Cloth = rgb(110, 30, 120),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Crowned", Pauldron = "Winged", Emblem = "Crest", Cape = true, Skirt = "Tassets", Boots = "Plate",
			Vfx = { Kind = "Sparkles", Color = rgb(255, 215, 100), Rate = 8, Light = true },
		},
	},
	{
		Id = "WarlordsBastion",
		DisplayName = "Warlord's Bastion",
		Rarity = "Legendary",
		Tier = 6,
		Health = 260,
		Defense = 0.18,
		SetBonus = { Health = 30, Damage = 0.08, Description = "+30 health, +8% damage" },
		Names = { "Warlord's Horned Helm", "Warlord's Bastion", "Warlord's Legplates", "Warlord's Stompers" },
		Style = {
			Primary = rgb(55, 52, 56), Secondary = rgb(115, 35, 28), Accent = rgb(255, 90, 30),
			Material = M.Metal, TrimMaterial = M.CorrodedMetal,
			Helmet = "Horned", Pauldron = "Spiked", Emblem = "Skull", Fur = rgb(115, 92, 70), Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Embers", Color = rgb(255, 110, 40), Rate = 10, Light = true },
		},
	},
	{
		Id = "PaladinsRadiance",
		DisplayName = "Paladin's Radiance",
		Rarity = "Mythic",
		Tier = 7,
		Health = 360,
		Defense = 0.21,
		SetBonus = { Health = 60, Defense = 0.04, Description = "+60 health, +4% defense, holy wings glow" },
		Names = { "Radiant Halo Helm", "Radiant Aegis", "Radiant Greaves", "Radiant Sabatons" },
		Style = {
			Primary = rgb(245, 240, 230), Secondary = rgb(235, 190, 70), Accent = rgb(255, 230, 130), Cloth = rgb(250, 245, 235),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Halo", Pauldron = "Winged", Emblem = "Sun", Wings = "Angel", Cape = true, Skirt = "Tassets", Boots = "Plate",
			Vfx = { Kind = "Holy", Color = rgb(255, 235, 150), Rate = 10, Light = true },
		},
	},
	{
		Id = "AbyssalKnight",
		DisplayName = "Abyssal Knight",
		Rarity = "Mythic",
		Tier = 8,
		Health = 480,
		Defense = 0.24,
		SetBonus = { Damage = 0.1, Defense = 0.03, Description = "+10% damage, +3% defense, void aura" },
		Names = { "Abyssal Visage", "Abyssal Carapace", "Abyssal Legguards", "Abyssal Treads" },
		Style = {
			Primary = rgb(25, 28, 62), Secondary = rgb(70, 72, 130), Accent = rgb(90, 125, 255), Cloth = rgb(18, 18, 40),
			Material = M.Metal, TrimMaterial = M.Metal,
			Helmet = "Abyssal", Pauldron = "Spiked", Emblem = "Core", Cape = true, Skirt = "Fauld", Boots = "Plate",
			Vfx = { Kind = "Void", Color = rgb(110, 130, 255), Rate = 12, Light = true },
		},
	},
	{
		Id = "BlackDragon",
		DisplayName = "Black Dragon",
		Rarity = "Godly",
		Tier = 10,
		Source = "Crate",
		Health = 650,
		Defense = 0.3,
		SetBonus = { Health = 100, Damage = 0.15, Description = "+100 health, +15% damage, dragon fire aura" },
		Names = { "Black Dragon Helm", "Black Dragon Scalemail", "Black Dragon Legguards", "Black Dragon Talons" },
		Style = {
			Primary = rgb(28, 24, 28), Secondary = rgb(62, 50, 56), Accent = rgb(255, 50, 20),
			Material = M.Slate, TrimMaterial = M.Basalt,
			Helmet = "Dragon", Pauldron = "Dragon", Emblem = "Cracks", Wings = "Dragon", Skirt = "Scales", Boots = "Claws",
			Vfx = { Kind = "Embers", Color = rgb(255, 70, 30), Rate = 14, Light = true, Smoke = true },
		},
	},
	{
		Id = "ShogunsOath",
		DisplayName = "Shogun's Oath",
		Rarity = "Godly",
		Tier = 10,
		Source = "Crate",
		Health = 600,
		Defense = 0.28,
		SetBonus = { Health = 80, Damage = 0.1, Speed = 0.1, Description = "+80 health, +10% damage, +10% speed, sakura aura" },
		Names = { "Shogun's Kabuto", "Shogun's Do", "Shogun's Haidate", "Shogun's Tabi" },
		Style = {
			Primary = rgb(175, 28, 32), Secondary = rgb(26, 22, 24), Accent = rgb(232, 185, 60), Cloth = rgb(30, 40, 95),
			Material = M.SmoothPlastic, TrimMaterial = M.Metal,
			Helmet = "Kabuto", Pauldron = "Sode", Emblem = "Lamellar", Skirt = "Kusazuri", Boots = "Tabi",
			Vfx = { Kind = "Petals", Color = rgb(255, 175, 205), Rate = 8 },
		},
	},
}

Items.Weapons = {} :: { [string]: WeaponDef }
Items.Armors = {} :: { [string]: ArmorDef } -- every armor piece, by piece id
Items.ArmorSets = {} :: { [string]: ArmorSetDef }
Items.ArmorSetOrder = {} :: { string } -- weakest first
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

for _, set in ARMOR_SETS do
	local pieces = {}
	for i, slot in Items.ArmorSlots do
		local pieceId = `{set.Id}_{slot}`
		pieces[slot] = pieceId
		Items.Armors[pieceId] = {
			Id = pieceId,
			Kind = "Armor",
			DisplayName = set.Names[i],
			Set = set.Id,
			Slot = slot,
			Tier = set.Tier,
			Rarity = set.Rarity,
			Health = math.floor(set.Health * SLOT_SHARE[slot]),
			Defense = set.Defense * SLOT_SHARE[slot],
		}
		table.insert(Items.ArmorOrder, pieceId)
	end
	Items.ArmorSets[set.Id] = {
		Id = set.Id,
		DisplayName = set.DisplayName,
		Rarity = set.Rarity,
		Tier = set.Tier,
		Source = set.Source or "Loot",
		Health = set.Health,
		Defense = set.Defense,
		SetBonus = set.SetBonus,
		Pieces = pieces,
		Style = set.Style,
	}
	table.insert(Items.ArmorSetOrder, set.Id)
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

-- Armor pieces that drop from dungeons at this tier (crate-only sets are excluded).
function Items.ArmorsOfTier(tier: number): { ArmorDef }
	local found = {}
	for _, id in Items.ArmorOrder do
		local piece = Items.Armors[id]
		if piece.Tier == tier and Items.ArmorSets[piece.Set].Source == "Loot" then
			table.insert(found, piece)
		end
	end
	return found
end

-- Armor pieces of a rarity that can drop from dungeons (used for crate filler rolls).
function Items.LootArmorsOfRarity(rarity: string): { ArmorDef }
	local found = {}
	for _, id in Items.ArmorOrder do
		local piece = Items.Armors[id]
		if piece.Rarity == rarity and Items.ArmorSets[piece.Set].Source == "Loot" then
			table.insert(found, piece)
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
