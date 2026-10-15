--!strict
-- Who may work at a building, and how well. One rule, used by the server (assigning,
-- save repair), production and the windows:
--   OnlySpecies  the building is that creature's own (each starter's building): no other
--                creature can work there, and it always can.
--   AnyCreature  every creature can work there, at least at AnyAffinity; creatures with
--                the job skill do better.
--   otherwise    creatures with the job skill (JobAffinity > 0).

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local CreatureConfig = require(Shared.Config.CreatureConfig)
local JobConfig = require(Shared.Config.JobConfig)

local WorkRules = {}

WorkRules.AnyAffinity = 0.5

function WorkRules.Affinity(def: Types.BuildingDef, speciesId: string, stage: number?): number
	if not def.Job then
		return 0
	end
	local species = CreatureConfig.Species[speciesId]
	if not species then
		return 0
	end
	if def.OnlySpecies and not table.find(def.OnlySpecies, speciesId) then
		return 0
	end
	local affinity = CreatureConfig.Affinity(species, stage or 1, def.Job)
	if def.AnyCreature then
		affinity = math.max(affinity, WorkRules.AnyAffinity)
	end
	if def.OnlySpecies and affinity <= 0 then
		affinity = 1 -- its own building
	end
	return affinity
end

function WorkRules.CanWork(def: Types.BuildingDef, speciesId: string, stage: number?): boolean
	return WorkRules.Affinity(def, speciesId, stage) > 0
end

-- Why a creature can't work here (for messages and disabled buttons).
function WorkRules.WhyNot(def: Types.BuildingDef, speciesId: string, creatureName: string): string
	if def.OnlySpecies and not table.find(def.OnlySpecies, speciesId) then
		local names = {}
		for _, id in def.OnlySpecies do
			local species = CreatureConfig.Species[id]
			table.insert(names, if species then species.Name else id)
		end
		return `Only {table.concat(names, " or ")} can work at the {def.Name}.`
	end
	local job = def.Job and JobConfig[def.Job]
	return `{creatureName} can't work as a {job and job.Name or def.Job or "worker"}.`
end

-- Short label for buttons.
function WorkRules.ShortWhyNot(def: Types.BuildingDef, speciesId: string): string
	if def.OnlySpecies and not table.find(def.OnlySpecies, speciesId) then
		local species = CreatureConfig.Species[def.OnlySpecies[1]]
		return `{if species then species.Name else "?"} only`
	end
	return "Can't do this job"
end

return WorkRules
