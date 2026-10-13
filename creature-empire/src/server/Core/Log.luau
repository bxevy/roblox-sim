--!strict
-- Structured diagnostic logs for economy and data operations:
--   [CE][Data] save ok  user=123 bytes=2048
-- Keep messages short and put the details in fields so they can be searched.

local Log = {}

Log.Verbose = false -- set true (e.g. from DevService) to log every economy change

local function render(tag: string, message: string, fields: { [string]: any }?): string
	local parts = { `[CE][{tag}] {message}` }
	if fields then
		local keys = {}
		for key in fields do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			table.insert(parts, `{key}={tostring(fields[key])}`)
		end
	end
	return table.concat(parts, " ")
end

function Log.Info(tag: string, message: string, fields: { [string]: any }?)
	print(render(tag, message, fields))
end

function Log.Debug(tag: string, message: string, fields: { [string]: any }?)
	if Log.Verbose then
		print(render(tag, message, fields))
	end
end

function Log.Warn(tag: string, message: string, fields: { [string]: any }?)
	warn(render(tag, message, fields))
end

return Log
