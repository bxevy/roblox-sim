--!strict
-- Every building type. Levels describe what each upgrade changes; the upgrade panel
-- shows those changes and BuildingModels (server/World) adds parts for each stage.
--
-- Prices follow Cost(level) = Base * Growth^(level - 1) (Formulas.CostAt), with a
-- different growth rate per building.

local Types = require(script.Parent.Parent.Types)
local Formulas = require(script.Parent.Parent.Util.Formulas)
local RegionConfig = require(script.Parent.RegionConfig)

local function gold(base: number, growth: number, level: number): { [string]: number }
	-- Level 2 is the first paid upgrade, so it costs exactly `base`.
	return { Gold = Formulas.CostAt(base, growth, level - 1) }
end

-- Gold plus a material, both on their own curves (major milestones need new resources).
local function goldAnd(
	base: number,
	growth: number,
	level: number,
	material: string,
	materialBase: number
): { [string]: number }
	local cost = gold(base, growth, level)
	cost[material] = Formulas.CostAt(materialBase, growth, level - 1)
	return cost
end

-- The standard 5-level production building: more slots, storage and speed per level.
local function productionLevels(
	base: number,
	growth: number,
	cycle: number,
	storage: number,
	notes: { string }
): { Types.BuildingLevel }
	return {
		{ CycleTime = cycle, YieldPerCycle = 1, Slots = 1, Storage = storage },
		{
			Cost = gold(base, growth, 2),
			Description = notes[1],
			CycleTime = cycle * 0.9,
			YieldPerCycle = 1,
			Slots = 2,
			Storage = math.floor(storage * 1.75),
		},
		{
			Cost = gold(base, growth, 3),
			Description = notes[2],
			CycleTime = cycle * 0.83,
			YieldPerCycle = 1.25,
			Slots = 2,
			Storage = storage * 3,
		},
		{
			Cost = gold(base, growth, 4),
			Description = notes[3],
			CycleTime = cycle * 0.75,
			YieldPerCycle = 1.25,
			Slots = 3,
			Storage = storage * 5,
		},
		{
			Cost = gold(base, growth, 5),
			Description = notes[4],
			CycleTime = cycle * 0.67,
			YieldPerCycle = 2,
			Slots = 3,
			Storage = storage * 8,
		},
	} :: any
end

local BuildingConfig: { [string]: Types.BuildingDef } = {
	EmpireCore = {
		Id = "EmpireCore",
		Name = "Empire Core",
		Category = "Empire",
		Description = "The heart of your empire. Each tier lets you build more and makes every creature a little better.",
		Footprint = { X = 4, Z = 4 },
		Placeable = false,
		Fixed = true,
		Phase = 1,
		Levels = {
			{
				BuildingLimits = { MoonpetalFarm = 2, Habitat = 2 },
				EmpireBonus = 0,
			},
			{
				Cost = gold(600, 3.6, 2),
				Description = "Tier 2: 3 farms, the Crystal Mine, Smelter, Evolution Chamber, Expedition Portal and a Courier Post, +5% creature yield.",
				BuildingLimits = {
					MoonpetalFarm = 3,
					Habitat = 3,
					CrystalMine = 1,
					CrystalSmelter = 1,
					EvolutionChamber = 1,
					ExpeditionPortal = 1,
					CourierPost = 1,
				},
				EmpireBonus = 0.05,
			},
			{
				Cost = goldAnd(600, 3.6, 3, "RefinedCrystal", 10),
				Description = "Tier 3: 4 farms, 2 mines, the Essence Condenser, +10% creature yield, floating rings.",
				BuildingLimits = {
					MoonpetalFarm = 4,
					Habitat = 4,
					CrystalMine = 2,
					CrystalSmelter = 1,
					EssenceCondenser = 1,
					EvolutionChamber = 1,
					ExpeditionPortal = 1,
					CourierPost = 1,
				},
				EmpireBonus = 0.1,
			},
			{
				Cost = goldAnd(600, 3.6, 4, "RefinedCrystal", 10),
				Description = "Tier 4: 5 farms, 3 mines, 2 smelters, 2 Courier Posts, +15% creature yield, banners of your empire.",
				BuildingLimits = {
					MoonpetalFarm = 5,
					Habitat = 5,
					CrystalMine = 3,
					CrystalSmelter = 2,
					EssenceCondenser = 1,
					EvolutionChamber = 1,
					ExpeditionPortal = 1,
					CourierPost = 2,
				},
				EmpireBonus = 0.15,
			},
			{
				Cost = goldAnd(600, 3.6, 5, "RefinedCrystal", 10),
				Description = "Tier 5: 6 farms, 4 mines, 2 condensers, +20% creature yield, a beacon of light.",
				BuildingLimits = {
					MoonpetalFarm = 6,
					Habitat = 6,
					CrystalMine = 4,
					CrystalSmelter = 2,
					EssenceCondenser = 2,
					EvolutionChamber = 1,
					ExpeditionPortal = 1,
					CourierPost = 2,
				},
				EmpireBonus = 0.2,
			},
		},
	},

	MoonpetalFarm = {
		Id = "MoonpetalFarm",
		Name = "Moonpetal Farm",
		Category = "Production",
		Description = "Creatures grow glowing moonpetals here. Collect the harvest before storage fills up.",
		Footprint = { X = 4, Z = 4 },
		Placeable = true,
		Job = "Farmer",
		Recipe = "GrowMoonpetal",
		PlaceCost = { Gold = 150 },
		PlaceGrowth = 2.2,
		FreeCount = 1,
		Phase = 1,
		Levels = {
			{ CycleTime = 6, YieldPerCycle = 1, Slots = 1, Storage = 40 },
			{
				Cost = gold(120, 2.2, 2),
				Description = "A second crop bed: room for 2 workers, more storage, faster growth.",
				CycleTime = 5.5,
				YieldPerCycle = 1,
				Slots = 2,
				Storage = 70,
			},
			{
				Cost = gold(120, 2.2, 3),
				Description = "Sprinkler windmill: crops grow faster and each harvest is bigger.",
				CycleTime = 5,
				YieldPerCycle = 1.25,
				Slots = 2,
				Storage = 120,
			},
			{
				Cost = gold(120, 2.2, 4),
				Description = "Moon lanterns: a third worker plot and much more storage.",
				CycleTime = 4.5,
				YieldPerCycle = 1.25,
				Slots = 3,
				Storage = 200,
			},
			{
				Cost = gold(120, 2.2, 5),
				Description = "Crystal glasshouse: doubles each harvest.",
				CycleTime = 4,
				YieldPerCycle = 2,
				Slots = 3,
				Storage = 320,
			},
		},
	},

	CrystalMine = {
		Id = "CrystalMine",
		Name = "Crystal Mine",
		Category = "Production",
		Description = "Miners chip raw crystal out of a glittering outcrop.",
		Footprint = { X = 4, Z = 4 },
		Placeable = true,
		Job = "Miner",
		Recipe = "MineCrystal",
		PlaceCost = { Gold = 500 },
		PlaceGrowth = 2.5,
		Phase = 2,
		Levels = productionLevels(400, 2.3, 8, 30, {
			"A second tunnel: room for 2 miners, more storage.",
			"Mine cart rails: faster digging and bigger hauls.",
			"Crystal lamps: a third miner and much more storage.",
			"Deep vein: doubles each haul.",
		}),
	},

	CrystalSmelter = {
		Id = "CrystalSmelter",
		Name = "Crystal Smelter",
		Category = "Production",
		Description = "Smelters melt 3 Raw Crystal from your silo into 1 Refined Crystal.",
		Footprint = { X = 3, Z = 3 },
		Placeable = true,
		Job = "Smelter",
		Recipe = "SmeltCrystal",
		PlaceCost = { Gold = 1200 },
		PlaceGrowth = 3,
		Phase = 2,
		Levels = productionLevels(900, 2.4, 10, 15, {
			"Second crucible: room for 2 smelters.",
			"Bellows: hotter fires, faster smelting, bigger batches.",
			"Twin chimneys: a third smelter and more storage.",
			"Starfire core: doubles each batch.",
		}),
	},

	EssenceCondenser = {
		Id = "EssenceCondenser",
		Name = "Essence Condenser",
		Category = "Production",
		Description = "Alchemists condense 1 Refined Crystal and 8 Moonpetals from your silo into 3 Essence.",
		Footprint = { X = 3, Z = 3 },
		Placeable = true,
		Job = "Alchemist",
		Recipe = "CondenseEssence",
		PlaceCost = { Gold = 6000, RefinedCrystal = 20 },
		PlaceGrowth = 3,
		Phase = 2,
		Levels = productionLevels(3000, 2.5, 12, 30, {
			"Second coil: room for 2 alchemists.",
			"Focusing lens: faster condensing, more Essence per batch.",
			"Arcane rings: a third alchemist and more storage.",
			"Resonance chamber: doubles each batch.",
		}),
	},

	ExpeditionPortal = {
		Id = "ExpeditionPortal",
		Name = "Expedition Portal",
		Category = "Research",
		Description = "Sends teams of creatures on timed expeditions. Each level runs one more expedition at a time.",
		Footprint = { X = 4, Z = 4 },
		Placeable = true,
		-- Emberstone comes from Emberfall Basin; while the basin is off, only Gold (expeditions
		-- then bring Emberstone home for the upgrades).
		PlaceCost = if RegionConfig.IsOpen("Emberfall") then { Gold = 2000, Emberstone = 10 } else { Gold = 2000 },
		PlaceGrowth = 1,
		Phase = 3,
		Levels = {
			{ ExpeditionSlots = 1 },
			{
				Cost = goldAnd(4000, 2.5, 2, "Emberstone", 30),
				Description = "Run 2 expeditions at once.",
				ExpeditionSlots = 2,
			},
			{
				Cost = goldAnd(4000, 2.5, 3, "Emberstone", 30),
				Description = "Run 3 expeditions at once.",
				ExpeditionSlots = 3,
			},
		},
	},

	Hatchery = {
		Id = "Hatchery",
		Name = "Hatchery",
		Category = "Creatures",
		Description = "The warm nest in the plaza where everyone hatches eggs. Every egg shows its exact odds.",
		Footprint = { X = 3, Z = 3 },
		Placeable = false, -- in the plaza (PlazaConfig), not on plots
		PlaceCost = { Gold = 400 }, -- what plot Hatcheries cost before the move (refunded)
		PlaceGrowth = 1,
		Phase = 2,
		Levels = { {} },
	},

	EvolutionChamber = {
		Id = "EvolutionChamber",
		Name = "Evolution Chamber",
		Category = "Creatures",
		Description = "A ring of standing stones. Creatures that meet their requirements evolve here.",
		Footprint = { X = 4, Z = 4 },
		Placeable = true,
		PlaceCost = { Gold = 2500 },
		PlaceGrowth = 1,
		Phase = 2,
		Levels = { {} },
	},

	ResourceSilo = {
		Id = "ResourceSilo",
		Name = "Resource Silo",
		Category = "Automation",
		Description = "Holds the materials you collect, and feeds smelters and condensers. Bigger silos hold more.",
		Footprint = { X = 3, Z = 3 },
		Placeable = false,
		Fixed = true,
		Phase = 1,
		Levels = {
			{ Capacity = { Moonpetal = 150, RawCrystal = 120, RefinedCrystal = 40, Emberstone = 60 } },
			{
				Cost = gold(100, 2.4, 2),
				Description = "Bigger tank: about twice the room for everything.",
				Capacity = { Moonpetal = 300, RawCrystal = 250, RefinedCrystal = 80, Emberstone = 120 },
			},
			{
				Cost = gold(100, 2.4, 3),
				Description = "Adds a second tank.",
				Capacity = { Moonpetal = 650, RawCrystal = 550, RefinedCrystal = 180, Emberstone = 260 },
			},
			{
				Cost = goldAnd(100, 2.4, 4, "RefinedCrystal", 5),
				Description = "Reinforced tanks.",
				Capacity = { Moonpetal = 1400, RawCrystal = 1200, RefinedCrystal = 400, Emberstone = 550 },
			},
			{
				Cost = goldAnd(100, 2.4, 5, "RefinedCrystal", 5),
				Description = "Crowned with a glowing cap.",
				Capacity = { Moonpetal = 3000, RawCrystal = 2600, RefinedCrystal = 900, Emberstone = 1200 },
			},
		},
	},

	TradingPost = {
		Id = "TradingPost",
		Name = "Trading Post",
		Category = "Empire",
		Description = "The plaza shop: sell materials for Gold and craft lures.",
		Footprint = { X = 3, Z = 3 },
		Placeable = false, -- in the plaza (PlazaConfig), not on plots
		Phase = 1,
		Levels = { {} },
	},

	Habitat = {
		Id = "Habitat",
		Name = "Creature Habitat",
		Category = "Creatures",
		Description = "Home for 5 creatures. Build more to keep more on your plot; the rest wait in your backpack.",
		Footprint = { X = 5, Z = 4 },
		Placeable = true,
		PlaceCost = { Gold = 1500 },
		PlaceGrowth = 1.8,
		FreeCount = 1, -- the one every plot starts with
		Phase = 1,
		Levels = {
			{ CreatureCapacity = 5 },
		},
	},

	ResearchStation = {
		Id = "ResearchStation",
		Name = "Research Station",
		Category = "Research",
		Description = "Unlocks new recipes, buildings and creature techniques.",
		Footprint = { X = 4, Z = 4 },
		Placeable = false,
		Fixed = true,
		Job = "Researcher",
		Recipe = "StudyInsight",
		Phase = 4,
		Levels = productionLevels(800, 2.4, 10, 25, {
			"A second desk: room for 2 researchers.",
			"Star charts: faster studies, more Insight each time.",
			"An observatory dome: a third researcher and more storage.",
			"The great library: doubles each study.",
		}),
	},

	CourierPost = {
		Id = "CourierPost",
		Name = "Courier Post",
		Category = "Automation",
		Description = "Couriers carry harvests from your buildings to the silo (or wallet) by themselves, fullest building first. They stop when the silo is full.",
		Footprint = { X = 3, Z = 3 },
		Placeable = true,
		Job = "Courier",
		RequiresResearch = "Couriers",
		PlaceCost = { Gold = 3000, RefinedCrystal = 10 },
		PlaceGrowth = 2.5,
		Phase = 4,
		Levels = {
			{ CycleTime = 5, YieldPerCycle = 4, Slots = 1 },
			{
				Cost = gold(3000, 2.5, 2),
				Description = "A second cart: room for 2 couriers.",
				CycleTime = 4.5,
				YieldPerCycle = 4,
				Slots = 2,
			},
			{
				Cost = goldAnd(3000, 2.5, 3, "RefinedCrystal", 15),
				Description = "Bigger baskets: every trip carries more.",
				CycleTime = 4,
				YieldPerCycle = 6,
				Slots = 2,
			},
			{
				Cost = goldAnd(3000, 2.5, 4, "RefinedCrystal", 15),
				Description = "A rail line: room for 3 couriers, faster trips.",
				CycleTime = 3.5,
				YieldPerCycle = 6,
				Slots = 3,
			},
		},
	},
}

return BuildingConfig
