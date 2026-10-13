--!strict
-- Wraps every client -> server RemoteFunction with the same protections:
--   * the player's profile must be loaded (unless AllowBeforeLoad)
--   * per-player rate limits (token bucket per remote)
--   * argument type checks (Check.*) before the handler runs
--   * errors inside a handler are caught, logged, and reported as a generic failure
-- Handlers return (ok: boolean, result: any). Clients never decide outcomes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local RateLimiter = require(script.Parent.RateLimiter)
local Log = require(script.Parent.Log)

export type HandlerOptions = {
	Rate: { number }?, -- { capacity, refillPerSecond }, default { 6, 3 }
	AllowBeforeLoad: boolean?,
	Args: { (any) -> boolean }?, -- one checker per argument
}

local Net = {}

local isReady: (Player) -> boolean = function()
	return false
end
local onViolation: (Player, string, string) -> () = function() end
local limiters: { [string]: RateLimiter.RateLimiter } = {}

function Net.Configure(options: { IsReady: (Player) -> boolean, OnViolation: (Player, string, string) -> () })
	isReady = options.IsReady
	onViolation = options.OnViolation
end

-- Argument checkers ----------------------------------------------------------------------

Net.Check = {}

function Net.Check.Id(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 64 and not string.find(value, "[^%w%-_{}]")
end

function Net.Check.OptionalId(value: any): boolean
	return value == nil or Net.Check.Id(value)
end

function Net.Check.Integer(value: any): boolean
	return type(value) == "number" and value == value and value == math.floor(value) and math.abs(value) < 1e9
end

function Net.Check.Number(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

function Net.Check.String(value: any): boolean
	return type(value) == "string" and #value <= 200
end

function Net.Check.Boolean(value: any): boolean
	return type(value) == "boolean"
end

function Net.Check.Any(_value: any): boolean
	return true
end

-- Registration ----------------------------------------------------------------------------

function Net.Handle(name: string, options: HandlerOptions, handler: (Player, ...any) -> (boolean, any))
	local remote = Remotes.Functions[name]
	assert(remote, `Unknown remote {name}`)
	local rate = options.Rate or { 6, 3 }
	local limiter = RateLimiter.new(rate[1], rate[2])
	limiters[name] = limiter
	local checks: { (any) -> boolean } = options.Args or {}

	remote.OnServerInvoke = function(player: Player, ...: any)
		if not options.AllowBeforeLoad and not isReady(player) then
			return false, "Your empire is still loading."
		end
		if not limiter:Allow(tostring(player.UserId)) then
			onViolation(player, name, "rate")
			return false, "Slow down a little!"
		end
		local args = table.pack(...)
		if args.n > math.max(#checks, 0) and #checks > 0 then
			onViolation(player, name, "extra arguments")
			return false, "Invalid request."
		end
		for index, check in checks do
			if not check(args[index]) then
				onViolation(player, name, `argument {index}`)
				return false, "Invalid request."
			end
		end
		local ok, success, result = pcall(handler, player, table.unpack(args, 1, args.n))
		if not ok then
			Log.Warn("Net", "handler error", { remote = name, user = player.UserId, error = tostring(success) })
			return false, "Something went wrong. Please try again."
		end
		return success, result
	end
end

Players.PlayerRemoving:Connect(function(player)
	for _, limiter in limiters do
		limiter:Forget(tostring(player.UserId))
	end
end)

return Net
