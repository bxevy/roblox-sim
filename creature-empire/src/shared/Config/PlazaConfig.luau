--!strict
-- The plaza at the centre of Verdant Reach is the shared shop area: the Trading Post
-- (sell and craft), the Hatchery nest and the Spin Wheel stand around the Founders'
-- Crystal, between the paths to the plots. The server builds them here and checks
-- players are close by before selling, crafting, hatching or spinning.
--
-- Moving them in Studio: Workspace › PlazaLayout holds one marker part per station
-- (TradingPost, Hatchery, SpinWheel). Move or turn a marker and the station is built
-- there, standing on the marker's bottom, its front facing the marker's Front face.
-- Without a marker, the Angle/Radius below are used.

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

-- The Studio marker for a station, if the place has one.
local function marker(id: string): BasePart?
	local ok, found = pcall(function()
		local folder = game:GetService("Workspace"):FindFirstChild("PlazaLayout")
		return folder and folder:FindFirstChild(id)
	end)
	if ok and found and found:IsA("BasePart") then
		return found
	end
	return nil
end

-- Centre of the station on the floor, its front (-Z) facing the crystal (or wherever its
-- marker's Front face points).
function PlazaConfig.CFrame(id: string): CFrame
	local part = marker(id)
	if part then
		local bottom = part.Position - part.CFrame.UpVector * part.Size.Y / 2
		local look = part.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		end
		return CFrame.lookAt(bottom, bottom + flat.Unit)
	end
	local station = PlazaConfig.Stations[id]
	local angle = math.rad(station.Angle)
	local position = Vector3.new(math.sin(angle) * station.Radius, PlazaConfig.FloorY, math.cos(angle) * station.Radius)
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

function PlazaConfig.Position(id: string): Vector3
	return PlazaConfig.CFrame(id).Position
end

return PlazaConfig
