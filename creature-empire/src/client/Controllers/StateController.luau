--!strict
-- The client's read-only copy of its own state. The server pushes sections (Wallet,
-- Buildings, Creatures, Quests, Settings, ...); UI code listens with OnChanged.
-- Nothing here is authoritative: the client only displays it and sends requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local StateController = {}

local state: { [string]: any } = {}
local received: { [string]: number } = {} -- os.clock when each section arrived
local listeners: { [string]: { (any) -> () } } = {}
local status = "Loading"
local statusListeners: { (string, string?) -> () } = {}

local function emit(section: string)
	local forSection: { (any) -> () } = listeners[section] or {}
	for _, callback in forSection do
		task.spawn(callback, state[section])
	end
	local forAll: { (any) -> () } = listeners["*"] or {}
	for _, callback in forAll do
		task.spawn(callback, section)
	end
end

local function set(section: string, payload: any)
	state[section] = payload
	received[section] = os.clock()
	emit(section)
end

function StateController.Get(section: string): any
	return state[section]
end

-- Seconds since a section last arrived (for extrapolating production and cooldowns).
function StateController.Age(section: string): number
	return os.clock() - (received[section] or os.clock())
end

-- Calls back now (if the section exists) and on every change.
function StateController.OnChanged(section: string, callback: (any) -> ())
	listeners[section] = listeners[section] or {}
	table.insert(listeners[section], callback)
	if section ~= "*" and state[section] ~= nil then
		task.spawn(callback, state[section])
	end
end

function StateController.Status(): string
	return status
end

function StateController.OnStatus(callback: (string, string?) -> ())
	table.insert(statusListeners, callback)
	task.spawn(callback, status)
end

-- Sends a request and returns (ok, result). Network errors become a friendly failure.
function StateController.Request(name: string, ...: any): (boolean, any)
	local remote = Remotes.Functions[name]
	local ok, success, result = pcall(remote.InvokeServer, remote, ...)
	if not ok then
		return false, "Connection problem. Try again."
	end
	return success, result
end

function StateController.Start()
	Remotes.Events.State.OnClientEvent:Connect(set)
	Remotes.Events.DataStatus.OnClientEvent:Connect(function(newStatus: string, message: string?)
		status = newStatus
		for _, callback in statusListeners do
			task.spawn(callback, newStatus, message)
		end
	end)
	-- The first pushes can race the client starting up, so also ask for a snapshot.
	task.spawn(function()
		for _ = 1, 30 do
			local ok, snapshot = StateController.Request("GetSnapshot")
			if ok and type(snapshot) == "table" then
				for section, payload in snapshot do
					if state[section] == nil then
						set(section, payload)
					end
				end
				if snapshot.Meta then
					status = if snapshot.Meta.CanSave then "Ready" else "Unsaved"
					for _, callback in statusListeners do
						task.spawn(callback, status)
					end
				end
				return
			end
			task.wait(1)
		end
	end)
end

return StateController
