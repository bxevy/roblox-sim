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
	Inner: Rect?, -- menu icons: just the symbol inside the round frame (x0, y0, x1, y1)
}

-- Uploaded by the game's creator.
local IDS: { [string]: number } = {
	LargeFrame = 71011017731034,
	CardFrame = 128207985531955,
	HeaderBanner = 89723654360611,
	ProgressBar = 80471369628478,
	ButtonGreen = 85363763162354,
	ButtonOrange = 82100018667006,
	TabActive = 90193938463422,
	TabInactive = 101075524508759,
	CloseButton = 103510426027879,
	BadgeGold = 114436514393660,
	BadgeEssence = 114048679966500,
	TileCommon = 81007021942512,
	TileRare = 85227747704426,
	TileEpic = 76955082920070,
	TileMythic = 70573979301002,
	IconBuild = 94748300278139,
	IconCreatures = 101744924517905,
	IconMap = 77060885619894,
	IconShop = 78339137500390,
	IconMore = 71580186205315,
}

local function piece(size: Vector2, slice: { number }?, inner: { number }?): Piece
	return {
		Id = 0, -- filled from IDS below
		Size = size,
		SliceCenter = if slice then Rect.new(slice[1], slice[2], slice[3], slice[4]) else nil,
		Inner = if inner then Rect.new(inner[1], inner[2], inner[3], inner[4]) else nil,
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
	-- Menu icons (Inner: the symbol on its dark disc, without the vine ring)
	IconBuild = piece(Vector2.new(160, 146), nil, { 38, 33, 122, 117 }),
	IconCreatures = piece(Vector2.new(152, 146), nil, { 34, 33, 118, 117 }),
	IconMap = piece(Vector2.new(158, 146), nil, { 37, 33, 121, 117 }),
	IconShop = piece(Vector2.new(166, 146), nil, { 41, 33, 125, 117 }),
	IconMore = piece(Vector2.new(166, 146), nil, { 41, 33, 125, 117 }),
} :: { [string]: Piece }

for name, id in IDS do
	if UiKit[name] then
		UiKit[name].Id = id
	end
end

return UiKit
