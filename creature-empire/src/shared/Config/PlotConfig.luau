--!strict
-- Plot layout. Each plot is a grid of cells. Cell (0, 0) is a front corner (the edge that
-- faces the plaza); +Z goes away from the plaza. Buildings snap to cells.

local PlotConfig = {}

PlotConfig.CellSize = 4 -- studs
PlotConfig.GridX = 24
PlotConfig.GridZ = 24
PlotConfig.PlotCount = 6 -- set the place's Max Players to this (see README)
PlotConfig.RingRadius = 150 -- studs from the world centre to each plot's front edge
PlotConfig.FloorHeight = 0.5 -- top surface of the plot floor (Y)

-- Every plot starts with these. Fixed ones can never move; the rest are starter copies
-- of placeable buildings. Ids are stable so saved data can refer to them.
PlotConfig.FixedLayout = {
	{ Id = "core", Type = "EmpireCore", X = 10, Z = 10, Rot = 0 },
	{ Id = "silo", Type = "ResourceSilo", X = 15, Z = 11, Rot = 0 },
	{ Id = "trading", Type = "TradingPost", X = 6, Z = 3, Rot = 0 },
	{ Id = "habitat", Type = "Habitat", X = 2, Z = 18, Rot = 0 },
	{ Id = "research", Type = "ResearchStation", X = 18, Z = 18, Rot = 0 },
}

PlotConfig.StarterBuildings = {
	{ Id = "farm1", Type = "MoonpetalFarm", X = 4, Z = 10, Rot = 0 },
}

-- Cells kept free for the entrance path from the plaza to the Empire Core.
PlotConfig.ReservedCells = {
	{ X1 = 11, Z1 = 0, X2 = 12, Z2 = 9 },
}

-- Expansion zones (Phase 2) are drawn beyond these edges as overgrown, roped-off land.
PlotConfig.ExpansionZones = {
	{ Name = "West Meadow", Side = "Left", Depth = 4 },
	{ Name = "East Grove", Side = "Right", Depth = 4 },
	{ Name = "North Ridge", Side = "Back", Depth = 4 },
}

-- How close (studs) a player must be to collect from or interact with a building.
PlotConfig.InteractRange = 28

return PlotConfig
