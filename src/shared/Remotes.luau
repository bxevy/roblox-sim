-- Creates (on the server) or waits for (on the client) all RemoteEvents/Functions.
-- Both sides require this module and get the same named instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = { "Notify", "StateChanged", "DungeonStatus" }
local FUNCTIONS = { "GetState", "EquipWeapon", "UseAbility" }

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
	-- Server -> client
	Notify = get("Notify") :: RemoteEvent, -- (message: string, color: Color3?)
	StateChanged = get("StateChanged") :: RemoteEvent, -- (state)
	DungeonStatus = get("DungeonStatus") :: RemoteEvent, -- (text: string?)

	-- Client -> server
	GetState = get("GetState") :: RemoteFunction,
	EquipWeapon = get("EquipWeapon") :: RemoteFunction, -- (weaponId) -> (ok, err?)
	UseAbility = get("UseAbility") :: RemoteFunction, -- (abilityId) -> (ok, cooldownRemaining)
}
