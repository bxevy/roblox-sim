--!strict
-- All RemoteEvents and RemoteFunctions. The server creates them; clients wait for them.
-- Every client -> server request is validated by the server (see server/Core/Net).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "CreatureEmpireRemotes"

-- Server -> client
local EVENTS = {
	"State", -- (section: string, payload) a section of the player's own state changed
	"Notify", -- (message: string, kind: "Info" | "Success" | "Error" | "Reward")
	"GameEvent", -- (name: string, payload) one-off moments: creature obtained, ability used, ...
	"DataStatus", -- (status: "Loading" | "Ready" | "Unsaved" | "Failed", message: string?)
}

-- Client -> server. Each returns (ok: boolean, messageOrResult: any).
local FUNCTIONS = {
	"GetSnapshot", -- () -> snapshot | nil while loading
	"ChooseStarter", -- (speciesId)
	"AssignCreature", -- (creatureId, buildingId?) nil building = unassign
	"Collect", -- (buildingId)
	"Sell", -- (resourceId, amount: number | "All")
	"PlaceBuilding", -- (type, x, z, rot)
	"UpgradeBuilding", -- (buildingId)
	"MoveBuilding", -- (buildingId, x, z, rot)
	"BuyExpansion", -- (zoneId)
	"HatchEgg", -- (eggId) -> (ok, { CreatureId, Species, Pity })
	"Evolve", -- (creatureId)
	"UseAbility", -- (creatureId)
	"ClaimQuest", -- ()
	"SetSetting", -- (key, value)
	"InspectPlot", -- (ownerUserId) -> read-only summary of another player's empire
	"Dev", -- (command, ...) developer commands, refused for everyone not authorised
}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing :: Folder
	else
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
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local Remotes = {
	Events = {} :: { [string]: RemoteEvent },
	Functions = {} :: { [string]: RemoteFunction },
}

for _, name in EVENTS do
	Remotes.Events[name] = folder:WaitForChild(name) :: RemoteEvent
end
for _, name in FUNCTIONS do
	Remotes.Functions[name] = folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
