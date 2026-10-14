--!strict
-- The plaza at the centre of Verdant Reach is the shared shop area: the Trading Post
-- (sell and craft), the Hatchery nest and the Spin Wheel stand around the Founders'
-- Crystal, between the paths to the plots. The server builds them here and checks
-- players are close by before selling, crafting, hatching or spinning.

local PlazaConfig = {}

export type Station = {
	Id: string,
	Name: string,
	Action: string, -- proximity prompt text
	Angle: number, -- degrees around the crystal (0 = towards the spawn)
	Radius: number, -- studs from the crystal
}

PlazaConfig.FloorY = 0.55 -- top of the plaza paving

PlazaConfig.Stations = {
	-- The shop and the wheel flank the spawn; the nest is to the east. The travel gate
	-- (about 146 degrees) and the leaderboard board (270) keep their places.
	TradingPost = { Id = "TradingPost", Name = "Trading Post", Action = "Sell & craft", Angle = 36, Radius = 24 },
	Hatchery = { Id = "Hatchery", Name = "Hatchery", Action = "Hatch eggs", Angle = 90, Radius = 24 },
	SpinWheel = { Id = "SpinWheel", Name = "Spin Wheel", Action = "Spin", Angle = 324, Radius = 24 },
} :: { [string]: Station }

-- How close (studs from a station's centre) a player must be to use it.
PlazaConfig.Range = 24

-- Building types that live in the plaza and never on a plot.
PlazaConfig.BuildingTypes = { TradingPost = true, Hatchery = true } :: { [string]: boolean }

function PlazaConfig.Position(id: string): Vector3
	local station = PlazaConfig.Stations[id]
	local angle = math.rad(station.Angle)
	return Vector3.new(math.sin(angle) * station.Radius, PlazaConfig.FloorY, math.cos(angle) * station.Radius)
end

-- Centre of the station on the floor, its front (-Z) facing the crystal.
function PlazaConfig.CFrame(id: string): CFrame
	local position = PlazaConfig.Position(id)
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

return PlazaConfig
