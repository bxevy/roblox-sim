-- The Robux Store (Config.RobuxStore): 2x Luck and 2x Coins game passes, and exclusive
-- armor sets sold as Developer Products. Class slots are sold by ClassService.
--
-- Owned perks are mirrored onto the player as attributes ("Perk_Luck", "Perk_Coins") so
-- other services and the client can check them cheaply. Ownership comes from the game
-- pass, or from data.Perks (admin gifts / testing).
--
-- For the store's 3D previews, a mannequin wearing each exclusive set is built once and
-- put in ReplicatedStorage.StorePreviews; the client shows clones of them in the store.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local Receipts = require(script.Parent.Parent.Receipts)
local ArmorVisuals = require(script.Parent.Parent.ArmorVisuals)
local Sfx = require(script.Parent.Parent.Sfx)

local Store = Config.RobuxStore
local MANNEQUIN_SKIN = Color3.fromRGB(205, 160, 125)
local MANNEQUIN_CLOTH = Color3.fromRGB(45, 42, 52)

local StoreService = {}

local function ownsPass(player: Player, passId: number): boolean
	if passId == 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and owns == true
end

local function setPerk(player: Player, perkId: string, owned: boolean)
	player:SetAttribute(`Perk_{perkId}`, if owned then true else nil)
end

-- Re-checks every perk for a player (on join, and after admin changes).
function StoreService.RefreshPerks(player: Player)
	local data = DataService.Get(player)
	for _, perkId in Store.PerkOrder do
		local owned = (data ~= nil and data.Perks[perkId] == true) or ownsPass(player, Store.Perks[perkId].GamePassId)
		setPerk(player, perkId, owned)
	end
	PlayerService.Push(player)
end

local function celebrate(player: Player, text: string, color: Color3)
	PlayerService.Notify(player, text, color)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Sfx.play("LevelUp", root)
	end
end

local function ownsWholeSet(data, setId: string): boolean
	for _, pieceId in Items.ArmorSets[setId].Pieces do
		if not data.Armors[pieceId] then
			return false
		end
	end
	return true
end

-- Gives every piece of an exclusive set and equips it.
local function grantArmor(player: Player, setId: string)
	local set = Items.ArmorSets[setId]
	for _, pieceId in set.Pieces do
		PlayerService.GiveItem(player, "Armor", pieceId)
	end
	PlayerService.EquipArmorSet(player, setId)
	celebrate(player, `You got the exclusive {set.DisplayName} armor! Thanks for the support!`, Config.Rarities.Exclusive)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			PlayerService.Notify(other, `{player.DisplayName} is now wearing the {set.DisplayName} armor!`, Config.Rarities.Exclusive)
		end
	end
end

local function onStoreAction(player: Player, action: unknown, id: unknown): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Still loading"
	end
	if action == "Perk" then
		local perk = type(id) == "string" and Store.Perks[id]
		if not perk then
			return false, "Unknown perk"
		end
		if player:GetAttribute(`Perk_{id}`) then
			return false, `You already own {perk.DisplayName}`
		end
		if perk.GamePassId == 0 then
			return false, `{perk.DisplayName} isn't set up yet (Config.RobuxStore.Perks.{id}.GamePassId)`
		end
		MarketplaceService:PromptGamePassPurchase(player, perk.GamePassId)
		return true
	elseif action == "Armor" then
		local entry = type(id) == "string" and Store.Armor[id]
		if not entry or not Items.ArmorSets[id :: string] then
			return false, "Unknown armor"
		end
		if ownsWholeSet(data, id :: string) then
			return false, "You already own this armor"
		end
		if entry.ProductId == 0 then
			return false, `This armor isn't set up yet (Config.RobuxStore.Armor.{id}.ProductId)`
		end
		MarketplaceService:PromptProductPurchase(player, entry.ProductId)
		return true
	end
	return false, "Unknown action"
end

-- Admin/testing: toggle a perk without buying the pass.
function StoreService.TogglePerk(player: Player, perkId: string): boolean
	local data = DataService.Get(player)
	if not data or not Store.Perks[perkId] then
		return false
	end
	data.Perks[perkId] = if data.Perks[perkId] then nil else true
	StoreService.RefreshPerks(player)
	return player:GetAttribute(`Perk_{perkId}`) == true
end

-- An anchored R15 mannequin wearing the full set (no scripts, no physics).
local function buildPreview(setId: string): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = MANNEQUIN_SKIN
	description.LeftArmColor = MANNEQUIN_SKIN
	description.RightArmColor = MANNEQUIN_SKIN
	description.TorsoColor = MANNEQUIN_CLOTH
	description.LeftLegColor = MANNEQUIN_CLOTH
	description.RightLegColor = MANNEQUIN_CLOTH
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[StoreService] Couldn't build an armor preview:", model)
		return nil
	end
	model.Name = setId
	for _, child in model:GetDescendants() do
		if child:IsA("BaseScript") then
			child:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model:PivotTo(CFrame.new())
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	local set = Items.ArmorSets[setId]
	local pieces = {}
	for slot, pieceId in set.Pieces do
		pieces[slot] = Items.Armors[pieceId]
	end
	ArmorVisuals.apply(model, pieces, setId)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	return model
end

local function buildPreviews()
	local folder = Instance.new("Folder")
	folder.Name = "StorePreviews"
	for _, setId in Store.ArmorOrder do
		local model = buildPreview(setId)
		if model then
			model.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

function StoreService.Start()
	task.spawn(buildPreviews)
	Remotes.RobuxStore.OnServerInvoke = onStoreAction

	DataService.OnLoaded(function(player)
		StoreService.RefreshPerks(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, perkId in Store.PerkOrder do
			local perk = Store.Perks[perkId]
			if perk.GamePassId ~= 0 and perk.GamePassId == passId then
				setPerk(player, perkId, true)
				PlayerService.Push(player)
				celebrate(player, `{perk.DisplayName} unlocked forever! Thanks for the support!`, perk.Color)
			end
		end
	end)

	for _, setId in Store.ArmorOrder do
		Receipts.Register(function()
			return Store.Armor[setId].ProductId
		end, function(player)
			grantArmor(player, setId)
		end)
	end
end

return StoreService
