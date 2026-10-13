--!strict
-- Every building type. Levels describe what each upgrade changes; the upgrade panel
-- shows those changes and BuildingModels (server/World) adds parts for each stage.
--
-- Prices follow Cost(level) = Base * Growth^(level - 1) (Formulas.CostAt), with a
-- different growth rate per building.

local Types = require(script.Parent.Parent.Types)
local Formulas = require(script.Parent.Parent.Util.Formulas)

local function gold(base: number, growth: number, level: number): { [string]: number }
	-- Level 2 is the first paid upgrade, so it costs exactly `base`.
	return { Gold = Formulas.CostAt(base, growth, level - 1) }
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
			{ BuildingLimits = { MoonpetalFarm = 2 }, EmpireBonus = 0 },
			{
				Cost = gold(600, 3.6, 2),
				Description = "Tier 2: build up to 3 farms, +5% to all creature yield, a crystal spire rises.",
				BuildingLimits = { MoonpetalFarm = 3 },
				EmpireBonus = 0.05,
			},
			{
				Cost = gold(600, 3.6, 3),
				Description = "Tier 3: up to 4 farms, +10% creature yield, floating rings.",
				BuildingLimits = { MoonpetalFarm = 4 },
				EmpireBonus = 0.1,
			},
			{
				Cost = gold(600, 3.6, 4),
				Description = "Tier 4: up to 5 farms, +15% creature yield, banners of your empire.",
				BuildingLimits = { MoonpetalFarm = 5 },
				EmpireBonus = 0.15,
			},
			{
				Cost = gold(600, 3.6, 5),
				Description = "Tier 5: up to 6 farms, +20% creature yield, a beacon of light.",
				BuildingLimits = { MoonpetalFarm = 6 },
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

	ResourceSilo = {
		Id = "ResourceSilo",
		Name = "Resource Silo",
		Category = "Automation",
		Description = "Holds the materials you collect. A bigger silo lets you collect more before selling.",
		Footprint = { X = 3, Z = 3 },
		Placeable = false,
		Fixed = true,
		Phase = 1,
		Levels = {
			{ Capacity = { Moonpetal = 150 } },
			{ Cost = gold(100, 2.4, 2), Description = "Holds 300 moonpetals.", Capacity = { Moonpetal = 300 } },
			{
				Cost = gold(100, 2.4, 3),
				Description = "Holds 650 moonpetals. Adds a second tank.",
				Capacity = { Moonpetal = 650 },
			},
			{ Cost = gold(100, 2.4, 4), Description = "Holds 1,400 moonpetals.", Capacity = { Moonpetal = 1400 } },
			{
				Cost = gold(100, 2.4, 5),
				Description = "Holds 3,000 moonpetals. Crowned with a glowing cap.",
				Capacity = { Moonpetal = 3000 },
			},
		},
	},

	TradingPost = {
		Id = "TradingPost",
		Name = "Trading Post",
		Category = "Empire",
		Description = "Sell materials for Gold.",
		Footprint = { X = 3, Z = 3 },
		Placeable = false,
		Fixed = true,
		Phase = 1,
		Levels = { {} },
	},

	Habitat = {
		Id = "Habitat",
		Name = "Creature Habitat",
		Category = "Creatures",
		Description = "Creatures without a job relax and play here.",
		Footprint = { X = 5, Z = 4 },
		Placeable = false,
		Fixed = true,
		Phase = 1,
		Levels = { {} },
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
		Locked = "Under construction. Research arrives in a later update.",
		Phase = 4,
		Levels = { {} },
	},
}

return BuildingConfig
