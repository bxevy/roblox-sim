--!strict
-- Grid pathfinding on a plot (A*, 8 directions, no corner cutting), then string-pulled so
-- creatures walk in natural straight lines between turns. Pure, so it is unit-tested; the
-- client uses it to walk creatures around buildings instead of through them.
--
-- Cells are integer pairs. `blocked(cx, cz)` says whether a cell can't be walked through;
-- the start and goal cells are always allowed (creatures live in the habitat and work
-- right next to buildings).

export type Cell = { X: number, Z: number }

local Path = {}

local SQRT2 = math.sqrt(2)
local NEIGHBOURS = {
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	{ 0, 1, 1 },
	{ 0, -1, 1 },
	{ 1, 1, SQRT2 },
	{ 1, -1, SQRT2 },
	{ -1, 1, SQRT2 },
	{ -1, -1, SQRT2 },
}

local function key(x: number, z: number): number
	return (x + 512) * 1024 + (z + 512)
end

-- Returns the cells from start to goal (inclusive), or nil if there's no way through
-- within `maxNodes` expansions.
function Path.Find(start: Cell, goal: Cell, blocked: (number, number) -> boolean, maxNodes: number?): { Cell }?
	local limit = maxNodes or 2000
	local function walkable(x: number, z: number): boolean
		return (x == goal.X and z == goal.Z) or (x == start.X and z == start.Z) or not blocked(x, z)
	end
	local function h(x: number, z: number): number
		local dx, dz = math.abs(x - goal.X), math.abs(z - goal.Z)
		return math.max(dx, dz) + (SQRT2 - 1) * math.min(dx, dz)
	end
	local open: { { X: number, Z: number, F: number } } = { { X = start.X, Z = start.Z, F = h(start.X, start.Z) } }
	local g: { [number]: number } = { [key(start.X, start.Z)] = 0 }
	local from: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local expanded = 0
	while #open > 0 do
		-- Small grids: a linear scan for the best node is fast enough and keeps this simple.
		local bestIndex = 1
		for i = 2, #open do
			if open[i].F < open[bestIndex].F then
				bestIndex = i
			end
		end
		local node = table.remove(open, bestIndex) :: { X: number, Z: number, F: number }
		local nodeKey = key(node.X, node.Z)
		if not closed[nodeKey] then
			closed[nodeKey] = true
			if node.X == goal.X and node.Z == goal.Z then
				local cells = { { X = node.X, Z = node.Z } }
				local current = nodeKey
				while from[current] do
					current = from[current]
					local x = current // 1024 - 512
					local z = current % 1024 - 512
					table.insert(cells, 1, { X = x, Z = z })
				end
				return cells
			end
			expanded += 1
			if expanded > limit then
				return nil
			end
			for _, n in NEIGHBOURS do
				local nx, nz = node.X + n[1], node.Z + n[2]
				local diagonalOk = n[3] == 1 or (walkable(node.X + n[1], node.Z) and walkable(node.X, node.Z + n[2]))
				if walkable(nx, nz) and diagonalOk then
					local nk = key(nx, nz)
					local cost = (g[nodeKey] :: number) + n[3]
					if not closed[nk] and (g[nk] == nil or cost < g[nk]) then
						g[nk] = cost
						from[nk] = nodeKey
						table.insert(open, { X = nx, Z = nz, F = cost + h(nx, nz) })
					end
				end
			end
		end
	end
	return nil
end

-- Whether a straight line between two cell centres only crosses walkable cells.
function Path.Clear(a: Cell, b: Cell, blocked: (number, number) -> boolean, endpoints: { Cell }): boolean
	local dx, dz = b.X - a.X, b.Z - a.Z
	local length = math.sqrt(dx * dx + dz * dz)
	-- Unit normal to the line: samples on both sides check the creature's width fits.
	local nx, nz = if length > 0 then -dz / length else 0, if length > 0 then dx / length else 0
	local steps = math.max(math.ceil(math.max(math.abs(dx), math.abs(dz)) * 4), 1)
	for i = 0, steps do
		local t = i / steps
		for _, offset in { -0.3, 0, 0.3 } do
			local x = math.floor(a.X + 0.5 + dx * t + nx * offset)
			local z = math.floor(a.Z + 0.5 + dz * t + nz * offset)
			local isEnd = false
			for _, e in endpoints do
				isEnd = isEnd or (e.X == x and e.Z == z)
			end
			if not isEnd and blocked(x, z) then
				return false
			end
		end
	end
	return true
end

-- Drops in-between cells wherever the line of sight is clear.
function Path.Simplify(cells: { Cell }, blocked: (number, number) -> boolean): { Cell }
	if #cells <= 2 then
		return cells
	end
	local endpoints = { cells[1], cells[#cells] }
	local out = { cells[1] }
	local anchor = 1
	local i = 2
	while i < #cells do
		if not Path.Clear(cells[anchor], cells[i + 1], blocked, endpoints) then
			table.insert(out, cells[i])
			anchor = i
		end
		i += 1
	end
	table.insert(out, cells[#cells])
	return out
end

return Path
