--!strict
-- Session-locked profile storage, independent of Roblox services so it can be tested
-- with a fake DataStore (tests/ProfileCore.spec.luau).
--
-- Each key stores a record: { Data = <profile>, Meta = { Lock = { JobId, Time }?, ... } }
--
-- Rules:
--  * Load takes the lock with UpdateAsync. If another live server holds it (refreshed in
--    the last LockTimeout seconds), Load waits and retries, and finally reports "Locked".
--    It never hands out a fresh profile in place of data it could not read.
--  * Save only writes while this server still holds the lock. If another server has
--    taken it, Save reports "LockLost" and writes nothing.
--  * Every DataStore call is wrapped in pcall and retried with bounded backoff.

export type Store = {
	UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any,
}

export type Options = {
	Store: Store,
	JobId: string,
	Now: () -> number, -- os.time in production
	Wait: (seconds: number) -> (),
	LockTimeout: number?, -- seconds before an unrefreshed lock counts as abandoned
	Attempts: number?, -- retries for DataStore errors
	LockedAttempts: number?, -- retries while another server holds the lock
	LockedRetryDelay: number?,
	Log: ((level: string, message: string, fields: { [string]: any }?) -> ())?,
}

export type LoadStatus = "Ok" | "Locked" | "Error"
export type SaveStatus = "Ok" | "LockLost" | "Error"

export type ProfileCore = {
	Load: (self: ProfileCore, key: string) -> (LoadStatus, any, boolean),
	Save: (self: ProfileCore, key: string, data: any, release: boolean) -> (SaveStatus, string?),
	Release: (self: ProfileCore, key: string) -> SaveStatus,
}

local ProfileCore = {}

function ProfileCore.new(options: Options): ProfileCore
	local store = options.Store
	local jobId = options.JobId
	local now = options.Now
	local wait = options.Wait
	local lockTimeout = options.LockTimeout or 240
	local attempts = options.Attempts or 5
	local lockedAttempts = options.LockedAttempts or 6
	local lockedRetryDelay = options.LockedRetryDelay or 5
	local log: (string, string, { [string]: any }?) -> () = options.Log or function(_level, _message, _fields) end

	-- Calls fn with retries; returns ok and result or the last error.
	local function protected(label: string, key: string, fn: () -> any): (boolean, any)
		local lastError
		for attempt = 1, attempts do
			local ok, result = pcall(fn)
			if ok then
				return true, result
			end
			lastError = result
			log("Warn", `{label} failed`, { key = key, attempt = attempt, error = tostring(result) })
			if attempt < attempts then
				wait(math.min(2 ^ (attempt - 1), 8))
			end
		end
		return false, lastError
	end

	local self = {}

	-- Returns status, data (nil for a brand new player), and whether the key was new.
	function self.Load(_, key: string): (LoadStatus, any, boolean)
		for lockedTry = 1, lockedAttempts do
			local outcome: "Taken" | "Locked" = "Taken"
			local loadedData: any = nil
			local isNew = false

			local ok, err = protected("Load", key, function()
				-- UpdateAsync may run the transform more than once; reset outputs each time.
				return store:UpdateAsync(key, function(record: any)
					outcome = "Taken"
					loadedData = nil
					isNew = false
					local t = now()
					if type(record) ~= "table" then
						if record ~= nil then
							-- Unknown format: refuse to touch it rather than overwrite it.
							error("unrecognised record format")
						end
						isNew = true
						record = { Data = nil, Meta = { Created = t, SaveCount = 0 } }
					end
					record.Meta = if type(record.Meta) == "table" then record.Meta else { Created = t, SaveCount = 0 }
					local lock = record.Meta.Lock
					if
						type(lock) == "table"
						and lock.JobId ~= jobId
						and type(lock.Time) == "number"
						and t - lock.Time < lockTimeout
					then
						outcome = "Locked"
						return nil -- cancel the write; another server is active
					end
					if type(lock) == "table" and lock.JobId ~= jobId then
						log("Warn", "Taking abandoned lock", { key = key, previous = tostring(lock.JobId) })
					end
					record.Meta.Lock = { JobId = jobId, Time = t }
					loadedData = record.Data
					return record
				end)
			end)

			if not ok then
				return "Error", err, false
			end
			if outcome == "Taken" then
				log("Info", "Loaded", { key = key, new = isNew })
				return "Ok", loadedData, isNew
			end
			log("Info", "Profile locked by another server, waiting", { key = key, try = lockedTry })
			if lockedTry < lockedAttempts then
				wait(lockedRetryDelay)
			end
		end
		return "Locked", "profile is in use by another server", false
	end

	-- Writes data while we hold the lock. `release` clears the lock (player leaving).
	function self.Save(_, key: string, data: any, release: boolean): (SaveStatus, string?)
		local lost = false
		local ok, err = protected("Save", key, function()
			return store:UpdateAsync(key, function(record: any)
				lost = false
				if type(record) ~= "table" or type(record.Meta) ~= "table" then
					lost = true
					return nil
				end
				local lock = record.Meta.Lock
				if type(lock) ~= "table" or lock.JobId ~= jobId then
					lost = true
					return nil -- someone else owns this profile now; do not overwrite
				end
				record.Data = data
				record.Meta.SaveCount = (tonumber(record.Meta.SaveCount) or 0) + 1
				record.Meta.LastSave = now()
				record.Meta.Lock = if release then nil else { JobId = jobId, Time = now() }
				return record
			end)
		end)
		if not ok then
			return "Error", tostring(err)
		end
		if lost then
			log("Warn", "Save refused: lock lost", { key = key })
			return "LockLost", "another server owns this profile"
		end
		return "Ok", nil
	end

	-- Gives up our lock without touching the stored data (used when we refuse to load a
	-- profile, so other servers aren't blocked until the lock times out).
	function self.Release(_, key: string): SaveStatus
		local ok = protected("Release", key, function()
			return store:UpdateAsync(key, function(record: any)
				if type(record) ~= "table" or type(record.Meta) ~= "table" then
					return nil
				end
				local lock = record.Meta.Lock
				if type(lock) ~= "table" or lock.JobId ~= jobId then
					return nil
				end
				record.Meta.Lock = nil
				return record
			end)
		end)
		return if ok then "Ok" else "Error"
	end

	return self :: any
end

return ProfileCore
