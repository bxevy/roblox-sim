--!strict
-- Central place for all tunable game values. Tweak numbers here, not in scripts.

local Config = {}

Config.DataStoreName = "PlayerData_v1"
Config.AutosaveInterval = 120 -- seconds

-- Minimum time between accepted Train requests (anti auto-clicker spam).
Config.TrainCooldown = 0.15

Config.DefaultData = {
	Power = 0,
	Coins = 0,
	Upgrades = {
		Strength = 0, -- more Power per click
		Backpack = 0, -- more Power you can hold before selling
		Value = 0, -- more Coins per Power sold
	},
}

export type UpgradeDef = {
	DisplayName: string,
	Description: string,
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
}

Config.Upgrades = {
	Strength = {
		DisplayName = "Strength",
		Description = "+1 Power per click",
		BaseCost = 10,
		CostGrowth = 1.5,
		MaxLevel = 50,
	},
	Backpack = {
		DisplayName = "Backpack",
		Description = "+25 Power capacity",
		BaseCost = 25,
		CostGrowth = 1.6,
		MaxLevel = 50,
	},
	Value = {
		DisplayName = "Sell Value",
		Description = "+1 Coin per Power",
		BaseCost = 100,
		CostGrowth = 2,
		MaxLevel = 25,
	},
} :: { [string]: UpgradeDef }

-- Order the upgrades appear in the shop UI.
Config.UpgradeOrder = { "Strength", "Backpack", "Value" }

function Config.GetUpgradeCost(upgradeId: string, currentLevel: number): number
	local def = Config.Upgrades[upgradeId]
	return math.floor(def.BaseCost * def.CostGrowth ^ currentLevel)
end

function Config.GetPowerPerClick(strengthLevel: number): number
	return 1 + strengthLevel
end

function Config.GetCapacity(backpackLevel: number): number
	return 50 + backpackLevel * 25
end

function Config.GetCoinsPerPower(valueLevel: number): number
	return 1 + valueLevel
end

return Config
