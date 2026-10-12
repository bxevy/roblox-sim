--!strict
-- Creates (on the server) or waits for (on the client) all RemoteEvents/Functions.
-- Both sides require this module and get the same named instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = { "Train", "DataChanged", "Notify" }
local FUNCTIONS = { "BuyUpgrade", "GetData" }

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function get(name: string): any
	return folder:WaitForChild(name)
end

return {
	Train = get("Train") :: RemoteEvent,
	DataChanged = get("DataChanged") :: RemoteEvent,
	Notify = get("Notify") :: RemoteEvent,
	BuyUpgrade = get("BuyUpgrade") :: RemoteFunction,
	GetData = get("GetData") :: RemoteFunction,
}
