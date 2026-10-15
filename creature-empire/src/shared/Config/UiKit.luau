--!strict
-- The creator's UI kit: pictures cut from their kit sheet (art/ui/*.png, cleaned of the
-- painted labels). Upload each PNG to Roblox and put its id here; until an id is set
-- (0), the interface draws that piece in code (wood colours, gold trim).
--
-- Size is the PNG size in pixels; SliceCenter (x0, y0, x1, y1) is the stretchable middle
-- for 9-slice pieces, so the vine corners keep their shape at any size.

export type Piece = {
	Name: string,
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
	CloseButton = 128625618241564, -- from the starter sheet (was 103510426027879)
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
	-- Starter screen sheet (art/ui-starter): whole pieces shown at their real shape.
	WindowFrame = 76221640150895,
	HeaderPlaque = 115207371374649,
	CardFrameGreen = 121857964643675,
	CardFrameOrange = 115797231894650,
	CardFrameBlue = 93158039524170,
	ButtonSproutling = 70569526491371,
	ButtonCindercub = 91835279381396,
	ButtonPebblit = 111784220916581,
	BadgeVerdants = 105403983646900,
	BadgeEmberkin = 130584159331939,
	BadgeCrystalkin = 138718121493642,
	BadgeCommon = 85663110618123,
	PortraitSproutling = 81048497216059,
	PortraitCindercub = 72919480696239,
	PortraitPebblit = 81826648297332,
	-- Plain wooden card frames (art/ui-frames)
	WoodFrameGreen = 80630794751715,
	WoodFrameOrange = 137924713261382,
	WoodFrameBlue = 125385689515967,
	-- Spin Wheel sheet (art/ui-spin)
	SpinPanel = 102847727495518,
	SpinHeader = 88177704359846,
	SpinClose = 130229593738844,
	WheelFace = 106388577070766,
	WheelHub = 103077080816198,
	WheelPointer = 131718537231235,
	SpinFreeButton = 92228782280509,
	SpinRobuxButton = 128803419383597,
	OddsBox = 109226136282444,
	IconGold500 = 97222724994602,
	IconGold1000 = 93932138140162,
	IconGold2500 = 102837292709393,
	IconGold5000 = 122363477537619,
	IconCoins2x = 73757438204472,
	IconEssence = 75244608322405,
	IconLuck = 124772987573261,
	IconDragon = 133349929132347,
	-- Building panel sheet (art/ui-panel)
	PanelSide = 105108873507099,
	PanelHeader = 81941320325427,
	PanelClose = 123540482511615,
	BarGreen = 117989978229421,
	BarBrown = 89520539345305,
	SlotRow = 115879090501040,
	EmptySlotRow = 137658337972192,
	DetailsButton = 137568513865493,
	MoveButton = 100157935666816,
	TabLeaf = 93178907368636,
	TabPaw = 135643665098380,
	TabMove = 102435690354797,
}

local function piece(size: Vector2, slice: { number }?, inner: { number }?): Piece
	return {
		Name = "", -- filled below
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
	CloseButton = piece(Vector2.new(152, 143)),
	-- Wallet badges (coin / flower on the left, the number is drawn by the game)
	BadgeGold = piece(Vector2.new(280, 108), { 116, 28, 208, 80 }),
	BadgeEssence = piece(Vector2.new(270, 116), { 120, 30, 212, 86 }),
	-- Menu icons (Inner: the symbol on its dark disc, without the vine ring)
	IconBuild = piece(Vector2.new(160, 146), nil, { 38, 33, 122, 117 }),
	IconCreatures = piece(Vector2.new(152, 146), nil, { 34, 33, 118, 117 }),
	IconMap = piece(Vector2.new(158, 146), nil, { 37, 33, 121, 117 }),
	IconShop = piece(Vector2.new(166, 146), nil, { 41, 33, 125, 117 }),
	IconMore = piece(Vector2.new(166, 146), nil, { 41, 33, 125, 117 }),
	-- Starter screen sheet. The card frames stretch only along their vine sides.
	WindowFrame = piece(Vector2.new(662, 451)),
	HeaderPlaque = piece(Vector2.new(573, 108)),
	CardFrameGreen = piece(Vector2.new(259, 283), { 60, 60, 199, 223 }),
	CardFrameOrange = piece(Vector2.new(254, 278), { 60, 60, 194, 218 }),
	CardFrameBlue = piece(Vector2.new(258, 278), { 60, 60, 198, 218 }),
	ButtonSproutling = piece(Vector2.new(236, 101)),
	ButtonCindercub = piece(Vector2.new(247, 102)),
	ButtonPebblit = piece(Vector2.new(249, 101)),
	BadgeVerdants = piece(Vector2.new(170, 58)),
	BadgeEmberkin = piece(Vector2.new(175, 60)),
	BadgeCrystalkin = piece(Vector2.new(182, 59)),
	BadgeCommon = piece(Vector2.new(165, 58)),
	PortraitSproutling = piece(Vector2.new(228, 208)),
	PortraitCindercub = piece(Vector2.new(250, 210)),
	PortraitPebblit = piece(Vector2.new(250, 210)),
	-- Plain wooden card frames: the border is ~27 px, so only the straight sides stretch.
	WoodFrameGreen = piece(Vector2.new(227, 226), { 40, 40, 187, 186 }),
	WoodFrameOrange = piece(Vector2.new(225, 226), { 40, 40, 185, 186 }),
	WoodFrameBlue = piece(Vector2.new(226, 225), { 40, 40, 186, 185 }),
	-- Spin Wheel sheet, sizes as uploaded.
	SpinPanel = piece(Vector2.new(281, 216)),
	SpinHeader = piece(Vector2.new(310, 82)),
	SpinClose = piece(Vector2.new(64, 48)),
	WheelFace = piece(Vector2.new(212, 213)),
	WheelHub = piece(Vector2.new(68, 68)),
	WheelPointer = piece(Vector2.new(68, 54)),
	SpinFreeButton = piece(Vector2.new(179, 56)),
	SpinRobuxButton = piece(Vector2.new(182, 56)),
	OddsBox = piece(Vector2.new(293, 206)),
	IconGold500 = piece(Vector2.new(46, 34)),
	IconGold1000 = piece(Vector2.new(48, 39)),
	IconGold2500 = piece(Vector2.new(56, 42)),
	IconGold5000 = piece(Vector2.new(68, 48)),
	IconCoins2x = piece(Vector2.new(55, 42)),
	IconEssence = piece(Vector2.new(54, 59)),
	IconLuck = piece(Vector2.new(49, 55)),
	IconDragon = piece(Vector2.new(67, 65)),
	-- Building panel sheet. The side panel and bars stretch between their riveted corners;
	-- the header plaque has words painted on, so only its ends and a clean strip are used.
	PanelSide = piece(Vector2.new(280, 462), { 44, 44, 236, 418 }),
	PanelHeader = piece(Vector2.new(350, 83)),
	PanelClose = piece(Vector2.new(83, 85)),
	BarGreen = piece(Vector2.new(430, 79), { 30, 24, 400, 55 }),
	BarBrown = piece(Vector2.new(429, 63), { 30, 20, 399, 43 }),
	SlotRow = piece(Vector2.new(429, 89)),
	EmptySlotRow = piece(Vector2.new(429, 86)),
	DetailsButton = piece(Vector2.new(133, 43)),
	MoveButton = piece(Vector2.new(365, 70)),
	TabLeaf = piece(Vector2.new(81, 80)),
	TabPaw = piece(Vector2.new(81, 80)),
	TabMove = piece(Vector2.new(82, 79)),
} :: { [string]: Piece }

for name, entry in UiKit do
	entry.Name = name
end
for name, id in IDS do
	if UiKit[name] then
		UiKit[name].Id = id
	end
end

return UiKit
