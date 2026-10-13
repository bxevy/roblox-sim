--!strict
-- Plot grid maths shared by the placement preview (client) and placement validation
-- (server), so the preview turns red for exactly the cases the server would reject.

local PlotConfig = require(script.Parent.Parent.Config.PlotConfig)

local Grid = {}

export type Footprint = { X: number, Z: number }
export type Placement = { Type: string, X: number, Z: number, Rot: number }

-- Footprint after rotation (odd quarter turns swap the sides).
function Grid.Rotated(footprint: Footprint, rot: number): (number, number)
	if rot % 2 == 1 then
		return footprint.Z, footprint.X
	end
	return footprint.X, footprint.Z
end

local function isInteger(n: any): boolean
	return type(n) == "number" and n == n and n == math.floor(n) and math.abs(n) < 1e6
end

function Grid.ValidPlacementInput(x: any, z: any, rot: any): boolean
	return isInteger(x) and isInteger(z) and isInteger(rot) and rot >= 0 and rot <= 3
end

-- Cells as "x,z" keys.
function Grid.Cells(footprint: Footprint, x: number, z: number, rot: number): { string }
	local sx, sz = Grid.Rotated(footprint, rot)
	local cells = table.create(sx * sz)
	for cx = x, x + sx - 1 do
		for cz = z, z + sz - 1 do
			table.insert(cells, cx .. "," .. cz)
		end
	end
	return cells
end

-- Whether one cell is buildable: inside the base plot or an owned expansion zone.
function Grid.CellAllowed(cx: number, cz: number, expansions: { [string]: boolean }?): boolean
	if cx >= 0 and cz >= 0 and cx < PlotConfig.GridX and cz < PlotConfig.GridZ then
		return true
	end
	if expansions then
		for _, zone in PlotConfig.ExpansionZones do
			local r = zone.Rect
			if expansions[zone.Id] and cx >= r.X1 and cx <= r.X2 and cz >= r.Z1 and cz <= r.Z2 then
				return true
			end
		end
	end
	return false
end

function Grid.InBounds(
	footprint: Footprint,
	x: number,
	z: number,
	rot: number,
	expansions: { [string]: boolean }?
): boolean
	local sx, sz = Grid.Rotated(footprint, rot)
	for cx = x, x + sx - 1 do
		for cz = z, z + sz - 1 do
			if not Grid.CellAllowed(cx, cz, expansions) then
				return false
			end
		end
	end
	return true
end

-- Every occupied cell, from existing buildings and reserved paths.
-- `footprints` maps building type -> footprint; `ignoreId` skips one building (moving).
function Grid.Occupancy(
	buildings: { [string]: any }, -- records with Type, X, Z, Rot
	footprints: { [string]: Footprint },
	ignoreId: string?
): { [string]: string }
	local occupied: { [string]: string } = {}
	for id, b in buildings do
		local fp = footprints[b.Type]
		if fp and id ~= ignoreId then
			for _, cell in Grid.Cells(fp, b.X, b.Z, b.Rot) do
				occupied[cell] = id
			end
		end
	end
	for _, area in PlotConfig.ReservedCells do
		for cx = area.X1, area.X2 do
			for cz = area.Z1, area.Z2 do
				occupied[cx .. "," .. cz] = occupied[cx .. "," .. cz] or "path"
			end
		end
	end
	return occupied
end

-- Checks bounds and overlap. Returns ok and a player-facing reason.
function Grid.CanPlace(
	occupancy: { [string]: string },
	footprint: Footprint,
	x: number,
	z: number,
	rot: number,
	expansions: { [string]: boolean }?
): (boolean, string?)
	if not Grid.ValidPlacementInput(x, z, rot) then
		return false, "Invalid position."
	end
	if not Grid.InBounds(footprint, x, z, rot, expansions) then
		return false, "That doesn't fit on your plot."
	end
	for _, cell in Grid.Cells(footprint, x, z, rot) do
		local owner = occupancy[cell]
		if owner == "path" then
			return false, "Keep the entrance path clear."
		elseif owner then
			return false, "Something is already there."
		end
	end
	return true, nil
end

-- Local offset (studs, relative to the plot's front-left corner on the floor) of the
-- centre of a footprint. The plot's CFrame turns it into world space.
function Grid.LocalCenter(footprint: Footprint, x: number, z: number, rot: number): Vector3
	local sx, sz = Grid.Rotated(footprint, rot)
	local size = PlotConfig.CellSize
	return Vector3.new((x + sx / 2) * size, 0, (z + sz / 2) * size)
end

-- Cell under a local position (studs from the front-left corner).
function Grid.CellAt(localX: number, localZ: number): (number, number)
	local size = PlotConfig.CellSize
	return math.floor(localX / size), math.floor(localZ / size)
end

return Grid
