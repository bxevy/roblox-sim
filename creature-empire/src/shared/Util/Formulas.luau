--!strict
-- Pure economy and production math. No Roblox services, so the server, the client (for
-- previews) and the test suite all compute exactly the same numbers.

local Types = require(script.Parent.Parent.Types)

local Formulas = {}

-- Cost(level) = Base * Growth^(level - 1), rounded to a tidy number.
function Formulas.CostAt(base: number, growth: number, level: number): number
	local raw = base * growth ^ (level - 1)
	return Formulas.RoundNice(raw)
end

-- Rounds to 2 significant figures above 100 so prices read well (1,278 -> 1,300).
function Formulas.RoundNice(value: number): number
	if value < 100 then
		return math.floor(value + 0.5)
	end
	local magnitude = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / magnitude + 0.5) * magnitude
end

export type Bonus = { Category: string, Value: number }
export type BonusRules = {
	Categories: { [string]: { Cap: number } },
	MaxMultiplier: number,
}

-- Combines bonuses: same category adds (capped), categories multiply, total capped.
-- Unknown categories are ignored rather than trusted.
function Formulas.CombineBonuses(bonuses: { Bonus }, rules: BonusRules): number
	local sums: { [string]: number } = {}
	for _, bonus in bonuses do
		local rule = rules.Categories[bonus.Category]
		if rule and bonus.Value == bonus.Value then -- skip NaN
			sums[bonus.Category] = math.min((sums[bonus.Category] or 0) + bonus.Value, rule.Cap)
		end
	end
	local multiplier = 1
	for _, sum in sums do
		multiplier *= 1 + math.max(sum, -0.9)
	end
	return math.clamp(multiplier, 0, rules.MaxMultiplier)
end

export type WorkerInput = {
	Species: Types.SpeciesDef,
	Level: number,
	Job: string,
	ExtraBonuses: { { Stat: string, Category: string, Value: number } }?, -- empire, abilities, ...
	LevelBonus: number,
}

export type WorkerOutput = {
	Affinity: number,
	CycleTime: number, -- seconds per cycle for this worker
	PerCycle: number, -- units produced per cycle
	PerSecond: number,
	SpeedMultiplier: number,
	YieldMultiplier: number,
}

-- How fast one creature produces at a production building.
function Formulas.WorkerRate(worker: WorkerInput, level: Types.BuildingLevel, rules: BonusRules): WorkerOutput
	local species = worker.Species
	local affinity = species.JobAffinity[worker.Job] or 0
	local cycleTime = level.CycleTime or 0
	local perCycleBase = level.YieldPerCycle or 0
	if affinity <= 0 or cycleTime <= 0 then
		return {
			Affinity = 0,
			CycleTime = math.huge,
			PerCycle = 0,
			PerSecond = 0,
			SpeedMultiplier = 0,
			YieldMultiplier = 0,
		}
	end

	local speedBonuses: { Bonus } = {}
	local yieldBonuses: { Bonus } = {}
	local levelBonus = worker.LevelBonus * (worker.Level - 1)
	table.insert(speedBonuses, { Category = "Level", Value = levelBonus })
	table.insert(yieldBonuses, { Category = "Level", Value = levelBonus })

	local function add(modifier: any)
		if modifier.Job ~= nil and modifier.Job ~= worker.Job then
			return
		end
		if modifier.Stat == "WorkSpeed" then
			table.insert(speedBonuses, { Category = modifier.Category, Value = modifier.Value })
		elseif modifier.Stat == "Yield" then
			table.insert(yieldBonuses, { Category = modifier.Category, Value = modifier.Value })
		end
	end
	for _, modifier in species.Passive.Modifiers do
		add(modifier)
	end
	local extra: { any } = worker.ExtraBonuses or {}
	for _, modifier in extra do
		add(modifier)
	end

	local speedStat = (species.BaseStats.WorkSpeed or 10) / 10
	local yieldStat = (species.BaseStats.Yield or 10) / 10
	local speedMultiplier = speedStat * Formulas.CombineBonuses(speedBonuses, rules)
	local yieldMultiplier = yieldStat * affinity * Formulas.CombineBonuses(yieldBonuses, rules)

	local workerCycle = cycleTime / math.max(speedMultiplier, 0.01)
	local perCycle = perCycleBase * yieldMultiplier
	return {
		Affinity = affinity,
		CycleTime = workerCycle,
		PerCycle = perCycle,
		PerSecond = perCycle / workerCycle,
		SpeedMultiplier = speedMultiplier,
		YieldMultiplier = yieldMultiplier,
	}
end

-- Advances a stored amount by rate * dt, never past capacity. Returns new amount and how
-- much was actually produced.
function Formulas.Accumulate(stored: number, ratePerSecond: number, dt: number, capacity: number): (number, number)
	if dt <= 0 or ratePerSecond <= 0 then
		return stored, 0
	end
	local room = math.max(capacity - stored, 0)
	local produced = math.min(ratePerSecond * dt, room)
	return stored + produced, produced
end

-- Seconds of offline time that count, and at what efficiency.
function Formulas.OfflineSeconds(lastOnline: number, now: number, maxSeconds: number): number
	if lastOnline <= 0 or now <= lastOnline then
		return 0
	end
	return math.min(now - lastOnline, maxSeconds)
end

-- Placement price for the next copy of a building: PlaceCost * Growth^(owned - free).
function Formulas.PlaceCost(def: Types.BuildingDef, owned: number): { [string]: number }
	local cost = {}
	local free = def.FreeCount or 0
	local exponent = math.max(owned - free, 0)
	local placeCost: { [string]: number } = def.PlaceCost or {}
	for currency, base in placeCost do
		cost[currency] = Formulas.RoundNice(base * (def.PlaceGrowth or 1) ^ exponent)
	end
	return cost
end

return Formulas
