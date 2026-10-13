--!strict
-- Number and time formatting for the interface.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }

-- 1234 -> "1,234"; 1234567 -> "1.23M".
function Format.Number(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	value = math.abs(value)
	local text
	if value < 100000 then
		local whole = math.floor(value)
		text = tostring(whole):reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if text:sub(1, 1) == "," then
			text = text:sub(2)
		end
	else
		local index = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
		local scaled = value / 10 ^ (index * 3)
		text = string.format(if scaled >= 100 then "%.0f" elseif scaled >= 10 then "%.1f" else "%.2f", scaled)
			.. SUFFIXES[index + 1]
	end
	return if negative then "-" .. text else text
end

-- Rate with one decimal when small: 0.25 -> "0.3", 15 -> "15".
function Format.Rate(value: number): string
	if value < 10 then
		return string.format("%.1f", value)
	end
	return Format.Number(value)
end

-- 75 -> "1m 15s", 3700 -> "1h 1m".
function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		local s = seconds % 60
		return math.floor(seconds / 60) .. "m" .. (if s > 0 then " " .. s .. "s" else "")
	end
	local m = math.floor(seconds / 60) % 60
	return math.floor(seconds / 3600) .. "h" .. (if m > 0 then " " .. m .. "m" else "")
end

function Format.Percent(multiplier: number): string
	return math.floor(multiplier * 100 + 0.5) .. "%"
end

-- { Gold = 120 } -> "120 Gold"
function Format.Cost(cost: { [string]: number }, names: { [string]: any }): string
	local parts = {}
	for id, amount in cost do
		local def = names[id]
		table.insert(parts, Format.Number(amount) .. " " .. (if def then def.Name else id))
	end
	table.sort(parts)
	return table.concat(parts, " + ")
end

return Format
