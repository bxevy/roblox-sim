-- Robux developer products. Roblox allows only one ProcessReceipt callback per game, so
-- every service registers its products here.
--
-- Each purchase is granted exactly once: the receipt id is saved in the player's data
-- (and the data saved right away) before Roblox is told it was granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Receipts = {}

type Handler = { GetProductId: () -> number, Grant: (Player) -> () }

local handlers: { Handler } = {}
local getData: (Player) -> any = function()
	return nil
end
local save: (Player) -> () = function() end

-- `getProductId` is read on every purchase, so ids set in Config later still work.
function Receipts.Register(getProductId: () -> number, grant: (Player) -> ())
	table.insert(handlers, { GetProductId = getProductId, Grant = grant })
end

local function processReceipt(receipt)
	local handler = nil
	for _, h in handlers do
		local id = h.GetProductId()
		if id ~= 0 and id == receipt.ProductId then
			handler = h
		end
	end
	if not handler then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and getData(player)
	if not player or not data then
		-- They left before it was processed; Roblox will retry next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not data.Receipts[receipt.PurchaseId] then
		data.Receipts[receipt.PurchaseId] = true
		handler.Grant(player)
		save(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Receipts.Start(dataGetter: (Player) -> any, saver: (Player) -> ())
	getData = dataGetter
	save = saver
	MarketplaceService.ProcessReceipt = processReceipt
end

return Receipts
