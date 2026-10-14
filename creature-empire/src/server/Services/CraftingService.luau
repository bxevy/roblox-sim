--!strict
-- Crafting at the plaza Trading Post (Ember Lures). Inputs are spent all-or-nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CraftConfig = require(Shared.Config.CraftConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local PlazaConfig = require(Shared.Config.PlazaConfig)

local Core = script.Parent.Parent.Core
local Net = require(Core.Net)
local Events = require(Core.Events)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local CraftingService = {}

local function craft(player: Player, recipeId: string): (boolean, any)
	local recipe = CraftConfig[recipeId]
	if not recipe or recipe.Phase > GameConfig.Phase then
		return false, "Unknown recipe."
	end
	if not PlotService.IsNear(player, PlazaConfig.Position("TradingPost"), PlazaConfig.Range) then
		return false, "Craft at the Trading Post in the plaza."
	end
	if
		EconomyService.Balance(player, recipe.Output) + recipe.Amount > EconomyService.Capacity(player, recipe.Output)
	then
		return false, "You can't carry any more of those."
	end
	if not EconomyService.Spend(player, recipe.Inputs, "Craft " .. recipeId) then
		return false, "You need " .. Format.Cost(recipe.Inputs, ResourceConfig) .. "."
	end
	EconomyService.Add(player, recipe.Output, recipe.Amount, "Craft")
	Events.Crafted:Fire(player, recipe.Output, recipe.Amount)
	return true, recipe.Amount
end

function CraftingService.Start()
	Net.Handle("Craft", { Rate = { 4, 1 }, Args = { Net.Check.Id } }, craft)
end

return CraftingService
