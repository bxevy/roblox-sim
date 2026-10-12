-- Pets: little companions that float beside you and give small bonuses while equipped.
-- They come from event crates (see Config.Events). Models are built from parts by
-- PetService on the server.
--
-- Bonus keys (added together, 0.1 = +10%): Gold, XP, Damage, Candy

export type PetDef = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Event: string?,
	Bonus: { [string]: number },
	Look: string, -- model builder in PetService
	Colors: { Color3 },
	Glow: Color3,
}

local rgb = Color3.fromRGB

local Pets = {}

Pets.Defs = {
	BlackCat = {
		DisplayName = "Black Cat", Rarity = "Common", Event = "Halloween", Look = "Cat",
		Bonus = { Gold = 0.05 }, Colors = { rgb(25, 22, 28), rgb(45, 40, 50) }, Glow = rgb(120, 255, 120),
	},
	MiniBat = {
		DisplayName = "Mini Bat", Rarity = "Common", Event = "Halloween", Look = "Bat",
		Bonus = { XP = 0.05 }, Colors = { rgb(40, 30, 50), rgb(90, 40, 110) }, Glow = rgb(255, 60, 60),
	},
	CandyCornSlime = {
		DisplayName = "Candy Corn Slime", Rarity = "Rare", Event = "Halloween", Look = "Slime",
		Bonus = { Candy = 0.1 }, Colors = { rgb(255, 210, 60), rgb(255, 130, 30), rgb(250, 245, 235) }, Glow = rgb(255, 200, 80),
	},
	Ghostie = {
		DisplayName = "Ghostie", Rarity = "Rare", Event = "Halloween", Look = "Ghost",
		Bonus = { Damage = 0.08 }, Colors = { rgb(240, 245, 255), rgb(200, 220, 255) }, Glow = rgb(170, 220, 255),
	},
	SkeletonPup = {
		DisplayName = "Skeleton Pup", Rarity = "Epic", Event = "Halloween", Look = "Pup",
		Bonus = { Gold = 0.1, XP = 0.1 }, Colors = { rgb(235, 230, 215), rgb(60, 55, 55) }, Glow = rgb(120, 200, 255),
	},
	PumpkinSpirit = {
		DisplayName = "Pumpkin Spirit", Rarity = "Legendary", Event = "Halloween", Look = "Pumpkin",
		Bonus = { Damage = 0.15, Candy = 0.25 }, Colors = { rgb(240, 120, 20), rgb(60, 110, 40) }, Glow = rgb(255, 200, 60),
	},
} :: { [string]: PetDef }

Pets.Order = { "BlackCat", "MiniBat", "CandyCornSlime", "Ghostie", "SkeletonPup", "PumpkinSpirit" }

for id, def in Pets.Defs do
	def.Id = id
end

local BONUS_NAMES = { Gold = "coins", XP = "XP", Damage = "damage", Candy = "candies" }

function Pets.Describe(def: PetDef): string
	local parts = {}
	for _, key in { "Damage", "Gold", "XP", "Candy" } do
		local value = def.Bonus[key]
		if value then
			table.insert(parts, `+{math.floor(value * 100 + 0.5)}% {BONUS_NAMES[key]}`)
		end
	end
	return table.concat(parts, ", ")
end

return Pets
