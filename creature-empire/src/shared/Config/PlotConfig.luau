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
	{ Id = "research", Type = "ResearchStation", X = 18, Z = 18, Rot = 0 },
}

PlotConfig.StarterBuildings = {
	{ Id = "habitat", Type = "Habitat", X = 2, Z = 18, Rot = 0 },
	{ Id = "farm1", Type = "MoonpetalFarm", X = 4, Z = 10, Rot = 0 },
}

-- Cells kept free for the entrance path from the plaza to the Empire Core.
PlotConfig.ReservedCells = {
	{ X1 = 11, Z1 = 0, X2 = 12, Z2 = 9 },
}

-- Expansion zones: overgrown land beyond the plot edges. Buying one (from the Empire Core)
-- moves the fence out and makes its cells buildable. Rect = the zone's cells (inclusive),
-- in the same grid coordinates as the plot, so the west zone has negative X.
export type Zone = {
	Id: string,
	Name: string,
	Side: string,
	Rect: { X1: number, Z1: number, X2: number, Z2: number },
	CoreTier: number,
	Cost: { [string]: number },
}

PlotConfig.ExpansionZones = {
	{
		Id = "West",
		Name = "West Meadow",
		Side = "Left",
		Rect = { X1 = -4, Z1 = 0, X2 = -1, Z2 = 23 },
		CoreTier = 2,
		Cost = { Gold = 1500 },
	},
	{
		Id = "East",
		Name = "East Grove",
		Side = "Right",
		Rect = { X1 = 24, Z1 = 0, X2 = 27, Z2 = 23 },
		CoreTier = 3,
		Cost = { Gold = 6000, RefinedCrystal = 40 },
	},
	{
		Id = "North",
		Name = "North Ridge",
		Side = "Back",
		Rect = { X1 = 0, Z1 = 24, X2 = 23, Z2 = 27 },
		CoreTier = 4,
		Cost = { Gold = 20000, RefinedCrystal = 120 },
	},
} :: { Zone }

function PlotConfig.Zone(id: string): Zone?
	for _, zone in PlotConfig.ExpansionZones do
		if zone.Id == id then
			return zone
		end
	end
	return nil
end

-- How close (studs) a player must be to collect from or interact with a building.
PlotConfig.InteractRange = 28

return PlotConfig
