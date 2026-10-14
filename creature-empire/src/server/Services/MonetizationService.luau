--!strict
-- Optional purchases (MonetizationConfig). Product grants are idempotent: the purchase id
-- is recorded in PlayerData.Receipts and the profile saved before Roblox is told the
-- purchase was granted, so a crash or retry can never grant twice or lose a purchase.
-- Game passes are checked with MarketplaceService and cached per session.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Core = script.Parent.Parent.Core
local Log = require(Core.Log)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local ProductionService = require(script.Parent.ProductionService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local CreatureService = require(script.Parent.CreatureService)
local SpinConfig = require(Shared.Config.SpinConfig)

local MonetizationService = {}

local passes: { [Player]: { [string]: boolean } } = {}
-- Purchases granted in memory whose save hasn't succeeded yet (confirmed only once saved).
local unsaved: { [string]: boolean } = {}

local function productById(id: number): (string?, MonetizationConfig.Product?)
	for key, product in MonetizationConfig.Products do
		if product.Id ~= 0 and product.Id == id then
			return key, product
		end
	end
	return nil, nil
end

function MonetizationService.HasPass(player: Player, passKey: string): boolean
	local owned = passes[player]
	return owned ~= nil and owned[passKey] == true
end

local applyBoost: (Player, Types.PlayerData) -> ()

-- One-time rewards of owned passes (the Starter Bundle), granted once per profile.
local function grantPassRewards(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	for key, pass in MonetizationConfig.Passes do
		local flag = "PassGranted_" .. key
		if pass.Grants and MonetizationService.HasPass(player, key) and (data.Stats[flag] or 0) == 0 then
			data.Stats[flag] = 1
			local grants = pass.Grants
			if grants.Gold then
				EconomyService.Add(player, "Gold", grants.Gold, "Pass " .. key)
			end
			if grants.FarmBoostSeconds then
				local now = os.time()
				data.BoostUntil = math.max(data.BoostUntil, now) + grants.FarmBoostSeconds
				applyBoost(player, data)
			end
			if grants.Species then
				CreatureService.Grant(player, grants.Species, "Shop", false)
			end
			PlayerDataService.MarkDirty(player)
			PlayerDataService.SaveNow(player)
			Log.Info("Shop", "Pass rewards granted", { user = player.UserId, pass = key })
		end
	end
end

local function applyPasses(player: Player)
	player:SetAttribute("Supporter", MonetizationService.HasPass(player, "Supporter"))
	task.spawn(grantPassRewards, player)
	PlotService.RefreshSign(player)
	StateService.Push(player, "Shop")
end

local function checkPasses(player: Player)
	local owned = {}
	for key, pass in MonetizationConfig.Passes do
		if pass.Id ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			owned[key] = ok and result == true
		end
	end
	if not player.Parent then
		return -- left while checking
	end
	-- Merge: a pass bought while this check ran stays owned.
	local current = passes[player] or {}
	for key, value in owned do
		current[key] = current[key] == true or value
	end
	passes[player] = current
	applyPasses(player)
end

function applyBoost(player: Player, data: Types.PlayerData)
	local remaining = data.BoostUntil - os.time()
	ProductionService.SetPlayerBoost(
		player,
		MonetizationConfig.Boost.Stat,
		MonetizationConfig.Boost.Value,
		math.max(remaining, 0)
	)
end

local function grant(player: Player, data: Types.PlayerData, product: MonetizationConfig.Product)
	local now = os.time()
	if product.Kind == "FarmBoost" and product.Seconds then
		-- Always the full time paid for (the shop stops selling near the limit).
		data.BoostUntil = math.max(data.BoostUntil, now) + product.Seconds
		applyBoost(player, data)
	elseif product.Kind == "LuckBoost" and product.Seconds then
		-- The same 2x Luck as the Spin Wheel's (eggs: rare-or-better twice as likely).
		local current = data.Boosts.Luck or 0
		data.Boosts.Luck = math.min(math.max(current, now) + product.Seconds, now + SpinConfig.MaxBoostSeconds)
		StateService.Push(player, "Spin")
	elseif product.Kind == "Currency" and product.Currency and product.Amount then
		EconomyService.Add(player, product.Currency, product.Amount, "Shop")
	end
end

local function pruneReceipts(data: Types.PlayerData)
	local list = {}
	for id, at in data.Receipts do
		table.insert(list, { Id = id, At = at })
	end
	if #list <= MonetizationConfig.MaxReceipts then
		return
	end
	table.sort(list, function(a, b)
		return a.At < b.At
	end)
	for i = 1, #list - MonetizationConfig.MaxReceipts do
		data.Receipts[list[i].Id] = nil
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerDataService.GetData(player)
	if not player or not data then
		-- Not in this server (or still loading): Roblox retries later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if data.Receipts[purchaseId] then
		if unsaved[purchaseId] then
			-- Granted earlier but not stored yet: confirm only once it's saved.
			if not PlayerDataService.SaveNow(player) then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			unsaved[purchaseId] = nil
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (a retry)
	end
	local key, product = productById(receipt.ProductId)
	if not product then
		Log.Warn("Shop", "Unknown product", { user = receipt.PlayerId, product = receipt.ProductId })
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grant(player, data, product)
	data.Receipts[purchaseId] = os.time()
	pruneReceipts(data)
	PlayerDataService.MarkDirty(player)
	if not PlayerDataService.SaveNow(player) then
		-- The grant stays recorded in memory; the retry saves again before confirming.
		unsaved[purchaseId] = true
		Log.Warn("Shop", "Save after purchase failed; will confirm on retry", { user = player.UserId })
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	StateService.Push(player, "Shop")
	Remotes.Events.Notify:FireClient(player, `Thank you! {product.Name} is active.`, "Reward")
	Log.Info("Shop", "Granted", { user = player.UserId, product = key, purchase = purchaseId })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start()
	StateService.Register("Shop", function(player, profile)
		return {
			Passes = table.clone(passes[player] or {}),
			BoostUntil = profile.Data.BoostUntil,
		}
	end)
	PlayerDataService.Loaded:Connect(function(player)
		task.spawn(checkPasses, player)
		local data = PlayerDataService.GetData(player)
		if data and data.BoostUntil > os.time() then
			applyBoost(player, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for key, pass in MonetizationConfig.Passes do
				if pass.Id == passId then
					local owned = passes[player] or {}
					owned[key] = true
					passes[player] = owned
					applyPasses(player)
					Remotes.Events.Notify:FireClient(player, `Thank you for becoming a {pass.Name}!`, "Reward")
				end
			end
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
