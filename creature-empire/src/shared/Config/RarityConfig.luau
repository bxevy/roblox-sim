--!strict
-- Rarity tiers. Every place that shows rarity uses the Label and Glyph as well as the
-- colour, so rarity never relies on colour alone.

export type Rarity = {
	Id: string,
	Order: number,
	Label: string,
	Glyph: string,
	Color: Color3,
}

local RarityConfig = {}

RarityConfig.Tiers = {
	Common = { Id = "Common", Order = 1, Label = "Common", Glyph = "●", Color = Color3.fromRGB(190, 196, 206) },
	Uncommon = { Id = "Uncommon", Order = 2, Label = "Uncommon", Glyph = "▲", Color = Color3.fromRGB(110, 210, 120) },
	Rare = { Id = "Rare", Order = 3, Label = "Rare", Glyph = "◆", Color = Color3.fromRGB(80, 160, 255) },
	Epic = { Id = "Epic", Order = 4, Label = "Epic", Glyph = "★", Color = Color3.fromRGB(190, 110, 255) },
	Legendary = {
		Id = "Legendary",
		Order = 5,
		Label = "Legendary",
		Glyph = "✦",
		Color = Color3.fromRGB(255, 190, 60),
	},
	Mythic = { Id = "Mythic", Order = 6, Label = "Mythic", Glyph = "❖", Color = Color3.fromRGB(255, 90, 140) },
} :: { [string]: Rarity }

function RarityConfig.Get(id: string): Rarity
	return RarityConfig.Tiers[id] or RarityConfig.Tiers.Common
end

-- "◆ Rare" style label.
function RarityConfig.Label(id: string): string
	local tier = RarityConfig.Get(id)
	return tier.Glyph .. " " .. tier.Label
end

return RarityConfig
