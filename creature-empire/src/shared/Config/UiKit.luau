--!strict
-- The creator's UI kit: pictures cut from their kit sheet (art/ui/*.png, cleaned of the
-- painted labels). Upload each PNG to Roblox and put its id here; until an id is set
-- (0), the interface draws that piece in code (wood colours, gold trim).
--
-- Size is the PNG size in pixels; SliceCenter (x0, y0, x1, y1) is the stretchable middle
-- for 9-slice pieces, so the vine corners keep their shape at any size.

export type Piece = {
	Id: number,
	Size: Vector2,
	SliceCenter: Rect?,
}

local function piece(size: Vector2, slice: { number }?): Piece
	return {
		Id = 0,
		Size = size,
		SliceCenter = if slice then Rect.new(slice[1], slice[2], slice[3], slice[4]) else nil,
	}
end

local UiKit = {
	-- Frames and panels
	LargeFrame = piece(Vector2.new(692, 316), { 100, 90, 592, 240 }), -- windows
	CardFrame = piece(Vector2.new(274, 304), { 64, 76, 210, 236 }), -- cards and HUD panels
	HeaderBanner = piece(Vector2.new(766, 96), { 180, 20, 586, 76 }), -- window titles
	ProgressBar = piece(Vector2.new(556, 110), { 80, 40, 472, 70 }), -- empty track
	-- Rarity tiles (collection grid)
	TileCommon = piece(Vector2.new(154, 154), { 44, 44, 110, 110 }),
	TileRare = piece(Vector2.new(154, 154), { 44, 44, 110, 110 }),
	TileEpic = piece(Vector2.new(154, 154), { 44, 44, 110, 110 }),
	TileMythic = piece(Vector2.new(160, 154), { 44, 44, 116, 110 }),
	-- Buttons and tabs (the icon on the left is part of the picture)
	ButtonGreen = piece(Vector2.new(296, 114), { 120, 30, 232, 84 }),
	ButtonOrange = piece(Vector2.new(286, 110), { 120, 30, 232, 80 }),
	TabActive = piece(Vector2.new(248, 102), { 108, 28, 200, 74 }),
	TabInactive = piece(Vector2.new(240, 96), { 102, 26, 194, 70 }),
	CloseButton = piece(Vector2.new(128, 116)),
	-- Wallet badges (coin / flower on the left, the number is drawn by the game)
	BadgeGold = piece(Vector2.new(280, 108), { 116, 28, 208, 80 }),
	BadgeEssence = piece(Vector2.new(270, 116), { 120, 30, 212, 86 }),
	-- Menu icons
	IconBuild = piece(Vector2.new(160, 146)),
	IconCreatures = piece(Vector2.new(152, 146)),
	IconMap = piece(Vector2.new(158, 146)),
	IconShop = piece(Vector2.new(166, 146)),
	IconMore = piece(Vector2.new(166, 146)),
} :: { [string]: Piece }

return UiKit
