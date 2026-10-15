--!strict
-- The onboarding questline. QuestService checks each step with the evaluator named by
-- `Kind`, so new steps only need a config entry:
--   ChooseStarter                       a starter has been picked
--   StarterBuild / StarterAssign / StarterCollect / StarterSell (Target "1".."3", Amount)
--                                       the Nth starter's own building: built, staffed by
--                                       it, its harvest collected / sold (Util/Tutorial)
--   AssignSpecies (Target, Species)     that species working in that building type
--   Assign      (Amount)                creatures currently assigned to jobs
--   Collect     (Target, Amount)        units collected from buildings during this step
--   Sell        (Target, Amount)        units sold during this step
--   BuildingLevel (Target, Amount)      highest level of a building type
--   BuildingCount (Target, Amount)      how many of a building type are placed
--   UseAbility  (Amount)                active abilities used during this step
--   EarnGold    (Amount)                gold earned during this step
--   Hatch       (Amount)                eggs hatched during this step
--   Evolve      (Amount)                creatures evolved during this step
--   Visit       (Target, Amount)        times you entered a region during this step
--   Gather      (Target, Amount)        units gathered from resource nodes during this step
--   Discover    (Amount)                landmarks discovered in total
--   Craft       (Target, Amount)        items crafted during this step
--   Befriend    (Amount)                wild creatures befriended during this step
--   Expedition  (Amount)                expeditions completed during this step
--   Guardian    (Target, Amount)        guardian defeats during this step
--   Research    (Amount)                research completed in total (this run)
--   Synergy     (Amount)                buildings with at least one active synergy
--   Ascend      (Amount)                Ascensions in total
--   WorldEvent  (Amount)                world events taken part in during this step
--
-- `Pointer` is the building type the tutorial arrow points at.

local Types = require(script.Parent.Parent.Types)

local QuestConfig = {}

QuestConfig.Tutorial = {
	{
		Id = "Starter",
		Title = "Choose a partner",
		Description = "Pick your first creature.",
		Kind = "ChooseStarter",
		Amount = 1,
		Reward = {},
	},
	-- Starter 1: build its own building, put it to work, collect the first harvest.
	{
		Id = "Build1",
		Title = "Build {Building}",
		Description = "Open Build and place the {Building}. It's {Starter}'s own: only {Starter} can work there.",
		Kind = "StarterBuild",
		Target = "1",
		Amount = 1,
		Reward = { Gold = 50 },
		Kit = true,
	},
	{
		Id = "Staff1",
		Title = "Put {Starter} to work",
		Description = "Open the {Building} and assign {Starter}.",
		Kind = "StarterAssign",
		Target = "1",
		Amount = 1,
		Reward = { Gold = 30 },
		Pointer = "{Building}",
	},
	{
		Id = "Harvest1",
		Title = "First harvest",
		Description = "Collect 10 {Resource} from the {Building}.",
		Kind = "StarterCollect",
		Target = "1",
		Amount = 10,
		Reward = { Gold = 40 },
		Pointer = "{Building}",
	},
	{
		Id = "Sell1",
		Title = "Open for business",
		Description = "Sell 10 {Resource} at the Trading Post in the plaza. A new friend is waiting!",
		Kind = "StarterSell",
		Target = "1",
		Amount = 10,
		Reward = { Gold = 50, Creature = "NextStarter" },
		Pointer = "TradingPost",
	},
	-- Starter 2: build its own building, put it to work, collect the first harvest.
	{
		Id = "Build2",
		Title = "Build {Building}",
		Description = "Open Build and place the {Building}. It's {Starter}'s own: only {Starter} can work there.",
		Kind = "StarterBuild",
		Target = "2",
		Amount = 1,
		Reward = { Gold = 50 },
		Kit = true,
	},
	{
		Id = "Staff2",
		Title = "Put {Starter} to work",
		Description = "Open the {Building} and assign {Starter}.",
		Kind = "StarterAssign",
		Target = "2",
		Amount = 1,
		Reward = { Gold = 30 },
		Pointer = "{Building}",
	},
	{
		Id = "Harvest2",
		Title = "Two partners",
		Description = "Collect 10 {Resource} from the {Building}. Your third partner arrives when you do!",
		Kind = "StarterCollect",
		Target = "2",
		Amount = 10,
		Reward = { Gold = 50, Creature = "NextStarter" },
		Pointer = "{Building}",
	},
	-- Starter 3: build its own building, put it to work, collect the first harvest.
	{
		Id = "Build3",
		Title = "Build {Building}",
		Description = "Open Build and place the {Building}. It's {Starter}'s own: only {Starter} can work there.",
		Kind = "StarterBuild",
		Target = "3",
		Amount = 1,
		Reward = { Gold = 60 },
		Kit = true,
	},
	{
		Id = "Staff3",
		Title = "Put {Starter} to work",
		Description = "Open the {Building} and assign {Starter}.",
		Kind = "StarterAssign",
		Target = "3",
		Amount = 1,
		Reward = { Gold = 30 },
		Pointer = "{Building}",
	},
	{
		Id = "Harvest3",
		Title = "The whole team",
		Description = "Collect 10 {Resource} from the {Building}.",
		Kind = "StarterCollect",
		Target = "3",
		Amount = 10,
		Reward = { Gold = 150 },
		Pointer = "{Building}",
	},
	{
		Id = "Workshop",
		Title = "A job for everyone",
		Description = "Build a Workshop: any creature can work there, crafting trinkets for Gold.",
		Kind = "BuildingCount",
		Target = "Workshop",
		Amount = 1,
		Reward = { Gold = 100 },
	},
	{
		Id = "Ability",
		Title = "Special talents",
		Description = "Use a creature's active ability (open Creatures, or tap a portrait in the creature bar).",
		Kind = "UseAbility",
		Amount = 1,
		Reward = { Gold = 50 },
	},
	{
		Id = "Silo",
		Title = "Room to grow",
		Description = "Upgrade the Resource Silo to level 2.",
		Kind = "BuildingLevel",
		Target = "ResourceSilo",
		Amount = 2,
		Reward = { Gold = 120 },
		Pointer = "ResourceSilo",
	},
	{
		Id = "Earn",
		Title = "Growing economy",
		Description = "Earn 500 gold.",
		Kind = "EarnGold",
		Amount = 500,
		Reward = { Gold = 100 },
	},
	{
		Id = "CoreTier2",
		Title = "An empire rises",
		Description = "Upgrade the Empire Core to tier 2.",
		Kind = "BuildingLevel",
		Target = "EmpireCore",
		Amount = 2,
		Reward = { Gold = 250, Essence = 25 },
		Pointer = "EmpireCore",
	},
	-- Update 2: hatching, crystals and evolution
	{
		Id = "Hatchery",
		Title = "A warm nest",
		Description = "Visit the Hatchery nest in the plaza and hatch an egg. Its odds are shown before you hatch.",
		Kind = "Hatch",
		Amount = 1,
		Reward = { Gold = 300 },
		Pointer = "Hatchery",
	},
	{
		Id = "FirstHatch",
		Title = "Something is moving",
		Description = "Hatch another egg at the plaza Hatchery.",
		Kind = "Hatch",
		Amount = 1,
		Reward = { Gold = 150 },
		Pointer = "Hatchery",
	},
	{
		Id = "Chamber",
		Title = "Standing stones",
		Description = "Build an Evolution Chamber.",
		Kind = "BuildingCount",
		Target = "EvolutionChamber",
		Amount = 1,
		Reward = { Essence = 20 },
	},
	{
		Id = "Evolve",
		Title = "Growing up",
		Description = "Evolve a creature. Check each creature's requirements in the Creatures window.",
		Kind = "Evolve",
		Amount = 1,
		Reward = { Gold = 1000, Shards = 1 },
		Pointer = "EvolutionChamber",
	},
	{
		Id = "CoreTier3",
		Title = "A crystal crown",
		Description = "Upgrade the Empire Core to tier 3 (needs Refined Crystal).",
		Kind = "BuildingLevel",
		Target = "EmpireCore",
		Amount = 3,
		Reward = { Gold = 1500, Essence = 40 },
		Pointer = "EmpireCore",
	},
	-- Update 3: Emberfall Basin
	{
		Id = "Basin",
		Region = "Emberfall", -- skipped while the basin is switched off
		Title = "Into the heat",
		Description = "Step through the Emberfall Gate in the plaza (press M for the map). Watch your heat meter!",
		Kind = "Visit",
		Target = "Emberfall",
		Amount = 1,
		Reward = { Gold = 500 },
	},
	{
		Id = "Gather",
		Region = "Emberfall", -- skipped while the basin is switched off
		Title = "Warm stones",
		Description = "Gather 10 Emberstone from deposits in the basin (hold the prompt).",
		Kind = "Gather",
		Target = "Emberstone",
		Amount = 10,
		Reward = { Gold = 400 },
	},
	{
		Id = "Landmarks",
		Region = "Emberfall", -- skipped while the basin is switched off
		Title = "Cartographer",
		Description = "Discover 3 landmarks in Emberfall Basin.",
		Kind = "Discover",
		Amount = 3,
		Reward = { Essence = 30 },
	},
	{
		Id = "Lure",
		Region = "Emberfall", -- skipped while the basin is switched off
		Title = "Something sweet",
		Description = "Craft an Ember Lure at the Trading Post in the plaza.",
		Kind = "Craft",
		Target = "EmberLure",
		Amount = 1,
		Reward = { Gold = 300 },
		Pointer = "TradingPost",
	},
	{
		Id = "Befriend",
		Region = "Emberfall", -- skipped while the basin is switched off
		Title = "New friends",
		Description = "Befriend a wild creature in the basin with a lure.",
		Kind = "Befriend",
		Amount = 1,
		Reward = { Gold = 800, Essence = 20 },
	},
	{
		Id = "Expedition",
		Title = "Beyond the walls",
		Description = "Build an Expedition Portal and bring a team home from an expedition.",
		Kind = "Expedition",
		Amount = 1,
		Reward = { Gold = 1500 },
		Pointer = "ExpeditionPortal",
	},
	{
		Id = "Guardian",
		Region = "Emberfall", -- skipped while the basin is switched off
		Title = "The Matriarch",
		Description = "Defeat the Magmaul Matriarch in the Guardian's Caldera (bring friends, or a Tideborn companion).",
		Kind = "Guardian",
		Target = "Matriarch",
		Amount = 1,
		Reward = { Gold = 3000, Shards = 2 },
	},
	{
		Id = "Study",
		Title = "The Research Station",
		Description = "Assign any creature to the Research Station (Wisplets are best) and collect 20 Essence there.",
		Kind = "Collect",
		Target = "Essence",
		Amount = 20,
		Reward = { Gold = 1500 },
		Pointer = "ResearchStation",
	},
	{
		Id = "Breakthrough",
		Title = "First breakthrough",
		Description = "Complete any research at the Research Station.",
		Kind = "Research",
		Amount = 1,
		Reward = { Essence = 30 },
		Pointer = "ResearchStation",
	},
	{
		Id = "Together",
		Title = "Better together",
		Description = "Trigger a synergy: try a Verdant and an Emberkin at the same Workshop. The building panel lists every synergy.",
		Kind = "Synergy",
		Amount = 1,
		Reward = { Gold = 2500 },
	},
	{
		Id = "Couriers",
		Title = "Couriers",
		Description = "Research Courier Routes, then build a Courier Post and give it a courier (Cogling works).",
		Kind = "BuildingCount",
		Target = "CourierPost",
		Amount = 1,
		Reward = { Gold = 4000 },
	},
	{
		Id = "Arcane",
		Title = "Runes in the shell",
		Description = "Hatch an egg. Arcane Eggs (Essence) hold scholars, couriers and reef dwellers.",
		Kind = "Hatch",
		Amount = 1,
		Reward = { Essence = 50 },
		Pointer = "Hatchery",
	},
	{
		Id = "Researcher",
		Title = "A wider mind",
		Description = "Complete 4 research projects.",
		Kind = "Research",
		Amount = 4,
		Reward = { Gold = 10000, Shards = 3 },
		Pointer = "ResearchStation",
	},
	{
		Id = "Ascend",
		Title = "Ascension",
		Description = "Reach Empire Core tier 5, then Ascend from the Empire Core: start over stronger, keep your creatures.",
		Kind = "Ascend",
		Amount = 1,
		Reward = { Shards = 5 },
		Pointer = "EmpireCore",
	},
	{
		Id = "WorldEvent",
		Title = "Stronger together",
		Description = "Take part in a world event: send a team into an Ember Rift, or collect 10+ moonpetals during a Grand Bloom. The banner at the top shows the next one.",
		Kind = "WorldEvent",
		Amount = 1,
		Reward = { Gold = 3000, Essence = 30 },
	},
} :: { Types.QuestStep }

return QuestConfig
