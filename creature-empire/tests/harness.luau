--!nocheck
-- Test harness for running the game's pure modules outside Roblox with Lune
-- (https://lune-org.github.io). It fakes just enough of Roblox for those modules:
--   * an instance-like tree mapped onto the source folders, so `script.Parent.X`,
--     `game:GetService("ReplicatedStorage").Shared` and `:WaitForChild` resolve to files
--   * `require` on those fake instances
--   * Roblox datatypes (Vector3, CFrame, Color3, ...) from Lune's roblox library
--
-- Only modules without engine side effects can be loaded this way (configs, Util,
-- server/Core). Services and UI need Roblox itself; see docs/TESTING.md.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

local ROOTS = {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
}

local cache = {}
local makeNode

-- Lune's fs calls can yield, which isn't allowed inside metamethods, so the source tree
-- is scanned once up front.
local files: { [string]: boolean } = {}
local dirs: { [string]: boolean } = {}
local function scan(dir: string)
	dirs[dir] = true
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path)
		else
			files[path] = true
		end
	end
end
scan("src")

local function fileFor(dir: string, name: string): string?
	for _, suffix in { ".luau", ".server.luau", ".client.luau" } do
		local path = dir .. "/" .. name .. suffix
		if files[path] then
			return path
		end
	end
	return nil
end

-- A fake Instance. `path` is a directory (folder) or a file (module).
makeNode = function(name: string, path: string?, parent: any, children: { [string]: string }?)
	local node = { Name = name, __path = path, __parent = parent, __children = children }
	local function child(_, childName)
		local mounts = rawget(node, "__children")
		if mounts and mounts[childName] then
			return makeNode(childName, mounts[childName], node)
		end
		local dir = rawget(node, "__path")
		if not dir then
			return nil
		end
		-- Modules can have children too (init-less folders sit next to them in Rojo).
		local base = string.gsub(dir, "%.luau$", "")
		if dirs[base .. "/" .. childName] then
			return makeNode(childName, base .. "/" .. childName, node)
		end
		local file = fileFor(base, childName)
		if file then
			return makeNode(childName, file, node)
		end
		return nil
	end
	return setmetatable(node, {
		__index = function(self, key)
			if key == "Parent" then
				return rawget(self, "__parent")
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return child
			elseif key == "GetService" then
				return function(_, serviceName)
					return child(self, serviceName)
				end
			elseif key == "IsA" then
				return function()
					return false
				end
			end
			local found = child(self, key)
			if found == nil then
				error(`{key} is not a valid member of {rawget(self, "Name")}`, 2)
			end
			return found
		end,
		__tostring = function(self)
			return rawget(self, "Name")
		end,
	})
end

local game = makeNode("game", nil, nil, {})
local services = {}
for serviceName, mounts in ROOTS do
	services[serviceName] = makeNode(serviceName, nil, game, mounts)
end
rawset(game, "__children", nil)
setmetatable(services, {})
getmetatable(game).__index = function(_, key)
	if key == "GetService" then
		return function(_, serviceName)
			return services[serviceName] or makeNode(serviceName, nil, game, {})
		end
	end
	return services[key]
end

local function load(node)
	local path = rawget(node, "__path")
	assert(path and string.match(path, "%.luau$"), `cannot require {tostring(node)}`)
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = fs.readFile(path)
	local env = {
		script = node,
		game = game,
		require = function(target)
			if type(target) == "string" then
				return require(target)
			end
			return load(target)
		end,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		NumberRange = roblox.NumberRange,
		Rect = roblox.Rect,
		warn = function(...)
			print("[warn]", ...)
		end,
	}
	local chunk = luau.load(source, { debugName = path, environment = env })
	local result = chunk()
	cache[path] = if result == nil then false else result
	return result
end

-- Loads a module by its Roblox path, e.g. Harness.require("ReplicatedStorage", "Shared", "Util", "Formulas").
function Harness.require(...: string)
	local node = services[(...)]
	for i = 2, select("#", ...) do
		node = node[select(i, ...)]
	end
	return load(node)
end

-- Tiny assertion library ----------------------------------------------------------------

local results = { Passed = 0, Failed = 0, Failures = {} }
Harness.Results = results

function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		results.Passed += 1
		print("  ✔ " .. name)
	else
		results.Failed += 1
		table.insert(results.Failures, name .. ": " .. tostring(err))
		print("  ✖ " .. name .. "\n      " .. tostring(err))
	end
end

function Harness.describe(name: string, fn: () -> ())
	print("\n" .. name)
	fn()
end

function Harness.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "values differ"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Harness.near(actual: number, expected: number, tolerance: number?, message: string?)
	if math.abs(actual - expected) > (tolerance or 1e-6) then
		error(`{message or "numbers differ"}: expected ~{expected}, got {actual}`, 2)
	end
end

function Harness.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function Harness.falsy(value: any, message: string?)
	if value then
		error((message or "expected a falsy value") .. ` (got {tostring(value)})`, 2)
	end
end

-- New plots no longer come with a Moonpetal Farm (the tutorial has you build your
-- starter's own building). Tests about farming add the old starting farm back.
function Harness.WithFarm(data: any): any
	data.Buildings.farm1 = {
		Id = "farm1",
		Type = "MoonpetalFarm",
		Level = 1,
		X = 4,
		Z = 10,
		Rot = 0,
		Stored = {},
	}
	return data
end

function Harness.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = Harness.deepCopy(v)
	end
	return copy
end

return Harness
