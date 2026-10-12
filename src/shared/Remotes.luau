-- Creates (on the server) or waits for (on the client) all RemoteEvents/Functions.
-- Both sides require this module and get the same named instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = { "Notify", "StateChanged", "DungeonStatus", "PortalUpdate", "OpenShop", "Attack", "SetSprint", "Dodge", "OpenCrates" }
local FUNCTIONS = { "GetState", "Equip", "ChooseClass", "UseAbility", "SetDifficulty", "BuyPotion", "UsePotion", "Admin", "OpenCrate", "GetLeaderboards" }

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
	DungeonStatus = get("DungeonStatus") :: RemoteEvent, -- (text: string?, info: { Style: string, Boss: boolean }?)
	PortalUpdate = get("PortalUpdate") :: RemoteEvent, -- (info?) while standing on a portal pad
	OpenShop = get("OpenShop") :: RemoteEvent, -- ()
	OpenCrates = get("OpenCrates") :: RemoteEvent, -- () opens the crate window

	-- Client -> server
	Attack = get("Attack") :: RemoteEvent, -- (aimDirection: Vector3)
	SetSprint = get("SetSprint") :: RemoteEvent, -- (sprinting: boolean)
	Dodge = get("Dodge") :: RemoteEvent, -- ()
	GetState = get("GetState") :: RemoteFunction,
	Equip = get("Equip") :: RemoteFunction, -- (kind: "Weapon" | "Armor", id) -> (ok, err?)
	ChooseClass = get("ChooseClass") :: RemoteFunction, -- (classId) -> (ok, err?)
	UseAbility = get("UseAbility") :: RemoteFunction, -- (abilityId, aimDirection) -> (ok, cooldownRemaining)
	SetDifficulty = get("SetDifficulty") :: RemoteFunction, -- (difficultyId) -> (ok, err?)
	BuyPotion = get("BuyPotion") :: RemoteFunction, -- (potionId) -> (ok, err?)
	UsePotion = get("UsePotion") :: RemoteFunction, -- (potionId) -> (ok, err?)
	GetLeaderboards = get("GetLeaderboards") :: RemoteFunction, -- () -> { [boardId]: { { Name, Value } } }
	OpenCrate = get("OpenCrate") :: RemoteFunction, -- (crateId) -> (ok, result | err)
	Admin = get("Admin") :: RemoteFunction, -- (action, arg?) -> (ok, message?)  admins only
}
