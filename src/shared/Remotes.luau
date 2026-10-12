-- Creates (on the server) or waits for (on the client) all RemoteEvents/Functions.
-- Both sides require this module and get the same named instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = { "Notify", "StateChanged", "DungeonStatus", "PortalUpdate", "OpenShop", "Attack" }
local FUNCTIONS = { "GetState", "Equip", "ChooseClass", "UseAbility", "SetDifficulty", "BuyPotion", "UsePotion" }

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
	PortalUpdate = get("PortalUpdate") :: RemoteEvent, -- (info?) while standing on a portal pad
	OpenShop = get("OpenShop") :: RemoteEvent, -- ()

	-- Client -> server
	Attack = get("Attack") :: RemoteEvent, -- (aimDirection: Vector3)
	GetState = get("GetState") :: RemoteFunction,
	Equip = get("Equip") :: RemoteFunction, -- (kind: "Weapon" | "Armor", id) -> (ok, err?)
	ChooseClass = get("ChooseClass") :: RemoteFunction, -- (classId) -> (ok, err?)
	UseAbility = get("UseAbility") :: RemoteFunction, -- (abilityId, aimDirection) -> (ok, cooldownRemaining)
	SetDifficulty = get("SetDifficulty") :: RemoteFunction, -- (difficultyId) -> (ok, err?)
	BuyPotion = get("BuyPotion") :: RemoteFunction, -- (potionId) -> (ok, err?)
	UsePotion = get("UsePotion") :: RemoteFunction, -- (potionId) -> (ok, err?)
}
