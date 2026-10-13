--!strict
-- Saves player settings. Only known keys with valid values are accepted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Parent.Core.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)
local _Types = require(ReplicatedStorage.Shared.Types)

local VALIDATORS: { [string]: (any) -> boolean } = {
	Music = function(v)
		return Net.Check.Number(v) and v >= 0 and v <= 1
	end,
	Sfx = function(v)
		return Net.Check.Number(v) and v >= 0 and v <= 1
	end,
	Vfx = function(v)
		return v == "Full" or v == "Reduced" or v == "Off"
	end,
	ReducedMotion = function(v)
		return type(v) == "boolean"
	end,
	CameraShake = function(v)
		return type(v) == "boolean"
	end,
	FastOpen = function(v)
		return type(v) == "boolean"
	end,
}

local SettingsService = {}

function SettingsService.Start()
	StateService.Register("Settings", function(_player, profile)
		return table.clone(profile.Data.Settings)
	end)

	Net.Handle(
		"SetSetting",
		{ Rate = { 20, 5 }, Args = { Net.Check.String, Net.Check.Any } },
		function(player, key, value)
			local validate = VALIDATORS[key]
			if not validate or not validate(value) then
				return false, "Invalid setting."
			end
			local data = PlayerDataService.GetData(player)
			if not data then
				return false, "Not loaded."
			end
			(data.Settings :: any)[key] = value
			PlayerDataService.MarkDirty(player)
			StateService.Push(player, "Settings")
			return true, nil
		end
	)
end

return SettingsService
