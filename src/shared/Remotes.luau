-- Creates (on the server) or waits for (on the client) all RemoteEvents/Functions.
-- Both sides require this module and get the same named instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = { "Notify", "StateChanged", "DungeonStatus", "PortalUpdate", "OpenShop", "Attack", "SetSprint", "Dodge", "OpenCrates", "OpenSkills", "OpenQuests", "QuestsChanged", "ClassRolled", "PlayMove", "BossBar", "PartyInvite", "PartyChanged", "OpenEvent", "HalloweenCrateResult" }
local FUNCTIONS = { "GetState", "Equip", "RollClass", "UseAbility", "SetDifficulty", "BuyPotion", "UsePotion", "Admin", "OpenCrate", "GetLeaderboards", "Prestige", "UpgradeSkill", "ClaimQuest", "GetQuests", "SetCard", "GetCard", "UseWeaponSkill", "PartyAction", "GetParty", "OpenHalloweenCrate", "EquipLimitedClass", "EquipPet" }

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
	PartyInvite = get("PartyInvite") :: RemoteEvent, -- (inviterUserId, inviterName)
	PartyChanged = get("PartyChanged") :: RemoteEvent, -- (party info or nil)
	PartyAction = get("PartyAction") :: RemoteFunction, -- (action, arg) -> (ok, message?)
	GetParty = get("GetParty") :: RemoteFunction,
	OpenEvent = get("OpenEvent") :: RemoteEvent, -- open the event window (event plaza prompt)
	HalloweenCrateResult = get("HalloweenCrateResult") :: RemoteEvent, -- (result) after a Robux crate
	OpenHalloweenCrate = get("OpenHalloweenCrate") :: RemoteFunction, -- ("Candies" | "Robux") -> (ok, result | message)
	EquipLimitedClass = get("EquipLimitedClass") :: RemoteFunction,
	EquipPet = get("EquipPet") :: RemoteFunction, -- (petId?) -> (ok, message?)
	BossBar = get("BossBar") :: RemoteEvent, -- (info: { Name, Health, MaxHealth, Shielded, Enraged, Mini }?)
	PortalUpdate = get("PortalUpdate") :: RemoteEvent, -- (info?) while standing on a portal pad
	OpenShop = get("OpenShop") :: RemoteEvent, -- ()
	OpenCrates = get("OpenCrates") :: RemoteEvent, -- () opens the crate window
	OpenSkills = get("OpenSkills") :: RemoteEvent, -- () opens the skills window (Skill Sanctum)
	OpenQuests = get("OpenQuests") :: RemoteEvent, -- () opens the quest log (Quest Board)
	QuestsChanged = get("QuestsChanged") :: RemoteEvent, -- (quests) live quest progress

	-- Client -> server
	Attack = get("Attack") :: RemoteEvent, -- (aimDirection: Vector3) next combo step
	UseWeaponSkill = get("UseWeaponSkill") :: RemoteFunction, -- (aimDirection) -> (ok, cooldownRemaining)
	PlayMove = get("PlayMove") :: RemoteEvent, -- (character, animationName) play an attack animation
	SetSprint = get("SetSprint") :: RemoteEvent, -- (sprinting: boolean)
	Dodge = get("Dodge") :: RemoteEvent, -- ()
	GetState = get("GetState") :: RemoteFunction,
	Equip = get("Equip") :: RemoteFunction, -- (kind: "Weapon" | "Armor", id) -> (ok, err?)
	RollClass = get("RollClass") :: RemoteFunction, -- (currency: "Coins" | "Robux") -> (ok, err?)
	ClassRolled = get("ClassRolled") :: RemoteEvent, -- (classId) result of a roll, for the reveal
	UseAbility = get("UseAbility") :: RemoteFunction, -- (abilityId, aimDirection) -> (ok, cooldownRemaining)
	SetDifficulty = get("SetDifficulty") :: RemoteFunction, -- (difficultyId) -> (ok, err?)
	BuyPotion = get("BuyPotion") :: RemoteFunction, -- (potionId) -> (ok, err?)
	UsePotion = get("UsePotion") :: RemoteFunction, -- (potionId) -> (ok, err?)
	GetLeaderboards = get("GetLeaderboards") :: RemoteFunction,
	Prestige = get("Prestige") :: RemoteFunction, -- () -> (ok, err?)
	UpgradeSkill = get("UpgradeSkill") :: RemoteFunction, -- (skillId) -> (ok, err?)
	ClaimQuest = get("ClaimQuest") :: RemoteFunction, -- (kind: "Story" | "Daily", index) -> (ok, err?)
	GetQuests = get("GetQuests") :: RemoteFunction, -- () -> quests
	SetCard = get("SetCard") :: RemoteFunction, -- (field, value) -> (ok, err?)
	GetCard = get("GetCard") :: RemoteFunction, -- (userId) -> card data -- () -> { [boardId]: { { Name, Value } } }
	OpenCrate = get("OpenCrate") :: RemoteFunction, -- (crateId) -> (ok, result | err)
	Admin = get("Admin") :: RemoteFunction, -- (action, arg?) -> (ok, message?)  admins only
}
