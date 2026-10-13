--!strict
-- Regions of the world. In Phase 1 every plot sits in Verdant Reach; the other regions are
-- designed here so exploration (Phase 3+) only needs world building and content.

export type Biome = {
	Id: string,
	Name: string,
	Order: number,
	Description: string,
	NewMechanic: string,
	Palette: { Ground: Color3, Accent: Color3, Sky: Color3 },
	Unlock: string,
	Guardian: string?,
	Phase: number,
}

local BiomeConfig: { [string]: Biome } = {
	VerdantReach = {
		Id = "VerdantReach",
		Name = "Verdant Reach",
		Order = 1,
		Description = "Gentle grassland where every empire begins.",
		NewMechanic = "Day and night: moonpetals glow at night and some creatures only appear after dark.",
		Palette = {
			Ground = Color3.fromRGB(96, 160, 72),
			Accent = Color3.fromRGB(150, 200, 255),
			Sky = Color3.fromRGB(150, 200, 240),
		},
		Unlock = "Starting region.",
		Guardian = "Elderbark",
		Phase = 1,
	},
	EmberfallBasin = {
		Id = "EmberfallBasin",
		Name = "Emberfall Basin",
		Order = 2,
		Description = "Volcanic terrain with rare ores and heat-resistant creatures.",
		NewMechanic = "Heat: it builds while you explore and spikes on lava and erupting vents. Cool off in blue pools; a fire-resistant companion slows it. Eruptions every few minutes make everything hotter.",
		Palette = {
			Ground = Color3.fromRGB(60, 40, 35),
			Accent = Color3.fromRGB(255, 110, 40),
			Sky = Color3.fromRGB(120, 60, 50),
		},
		Unlock = "Empire Core tier 2. Travel through the gate in the plaza.",
		Guardian = "Magmaul",
		Phase = 3,
	},
	CrystalHollows = {
		Id = "CrystalHollows",
		Name = "Crystal Hollows",
		Order = 3,
		Description = "Branching crystal caverns full of mining opportunities.",
		NewMechanic = "Darkness: light-carrying creatures reveal paths and hidden veins.",
		Palette = {
			Ground = Color3.fromRGB(50, 50, 70),
			Accent = Color3.fromRGB(130, 210, 255),
			Sky = Color3.fromRGB(20, 20, 35),
		},
		Unlock = "Defeat the Emberfall guardian.",
		Guardian = "Prismaw",
		Phase = 3,
	},
	TempestIsles = {
		Id = "TempestIsles",
		Name = "Tempest Isles",
		Order = 4,
		Description = "Floating islands lashed by storms.",
		NewMechanic = "Storm cycles: lightning powers machines and opens wind routes between islands.",
		Palette = {
			Ground = Color3.fromRGB(120, 140, 120),
			Accent = Color3.fromRGB(255, 230, 80),
			Sky = Color3.fromRGB(80, 90, 120),
		},
		Unlock = "Empire Core tier 4.",
		Guardian = "Thundermaw",
		Phase = 4,
	},
	SunkenArchive = {
		Id = "SunkenArchive",
		Name = "The Sunken Archive",
		Order = 5,
		Description = "Flooded ancient ruins full of relics.",
		NewMechanic = "Water levels: draining and flooding rooms changes which areas are reachable.",
		Palette = {
			Ground = Color3.fromRGB(70, 90, 100),
			Accent = Color3.fromRGB(80, 220, 210),
			Sky = Color3.fromRGB(40, 70, 90),
		},
		Unlock = "Research: Diving Bells.",
		Guardian = "Abyssquid",
		Phase = 4,
	},
	UmbralFrontier = {
		Id = "UmbralFrontier",
		Name = "The Umbral Frontier",
		Order = 6,
		Description = "A dangerous shadow region with rare creatures and strange mutations.",
		NewMechanic = "Corruption: staying too long mutates resources, for better or worse.",
		Palette = {
			Ground = Color3.fromRGB(35, 30, 50),
			Accent = Color3.fromRGB(170, 110, 255),
			Sky = Color3.fromRGB(20, 15, 30),
		},
		Unlock = "First Ascension.",
		Guardian = "Nocturnox",
		Phase = 4,
	},
}

return BiomeConfig
