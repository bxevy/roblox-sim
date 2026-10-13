--!strict
-- Minimal synchronous signal for server-internal events between services
-- (e.g. ProductionService tells QuestService a player collected moonpetals).

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local callbacks: { (T...) -> () } = {}
	local self = {}

	function self.Connect(_, callback: (T...) -> ()): Connection
		table.insert(callbacks, callback)
		local connection = {}
		function connection.Disconnect()
			local index = table.find(callbacks, callback)
			if index then
				table.remove(callbacks, index)
			end
		end
		return connection :: any
	end

	function self.Fire(_, ...: T...)
		for _, callback in table.clone(callbacks) do
			-- One failing listener must not stop the others (or the caller).
			local ok, err = pcall(function(...)
				callback(...)
				return true
			end, ...)
			if not ok then
				warn("[CE][Signal] listener failed:", err)
			end
		end
	end

	return self :: any
end

return Signal
