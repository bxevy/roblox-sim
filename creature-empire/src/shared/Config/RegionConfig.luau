--!strict
-- Explorable regions outside the empire plots. Positions are offsets (studs) from the
-- region's Center, so the server (gameplay checks), the world builder and the client
-- (lighting, map, prompts) all agree on where everything is.
--
-- Emberfall Basin's mechanic is Heat: it builds while you're in the basin, faster during
-- eruptions and much faster on lava or next to an erupting vent. Cooling pools bring it
-- down, and a fire-resistant companion slows it. At 100 you're carried back to the gate.

export type Node = { Id: string, Kind: string, Offset: Vector3 }
export type Landmark = {
	Id: string,
	Name: string,
	Offset: Vector3,
	Radius: number,
	Hidden: boolean?,
	MinHeight: number?, -- must be at least this high above the region's floor (summits)
	Reward: { [string]: number },
}
export type Region = {
	Id: string,
	Name: string,
	Biome: string,
	Center: Vector3,
	HalfSize: Vector3, -- bounds of the region (players inside count as "in" it)
	CoreTier: number, -- Empire Core tier needed to travel there
	Phase: number,
	-- false: switched off for now (not built, no gate, travel, boss, wild or nodes; its
	-- tutorial steps are skipped). The content stays here, ready to switch back on.
	Enabled: boolean?,
	ArrivalOffset: Vector3,
	PlazaGate: Vector3, -- world position of the gate in the plaza
	Heat: {
		BaseRate: number, -- per second
		EruptionMultiplier: number,
		LavaRate: number,
		VentBurst: number,
		PoolRate: number, -- negative: cooling per second inside a pool
		PoolRadius: number,
		ResistFamilies: { [string]: number }, -- companion family -> heat gain multiplier
		Max: number,
		AfterRescue: number,
	},
	Pools: { Vector3 },
	Lava: { { From: Vector3, To: Vector3, Width: number } },
	Bridges: { { Offset: Vector3, Length: number, Rotation: number } },
	Vents: { Vector3 },
	VentCycle: { Period: number, Warning: number, Active: number, Radius: number },
	Nodes: { Node },
	NodeKinds: {
		[string]: { Name: string, Resource: string, Min: number, Max: number, Respawn: number, HoldTime: number },
	},
	Landmarks: { Landmark },
	Footprints: { Vector3 }, -- glowing trail to the hidden grotto
	WildSpawns: { Vector3 },
	WildTable: { { Species: string, Weight: number } },
	MaxWild: number,
	WildLifetime: number,
	Eruption: { Period: number, Duration: number, SpawnSpecies: string, SpawnOffset: Vector3 },
	Guardian: { Id: string, Offset: Vector3, ArenaRadius: number },
}

local RegionConfig = {}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

RegionConfig.Regions = {
	Emberfall = {
		Id = "Emberfall",
		Name = "Emberfall Basin",
		Biome = "EmberfallBasin",
		Center = v(0, 0, -1600),
		HalfSize = v(270, 120, 270),
		CoreTier = 2,
		Phase = 3,
		Enabled = false, -- off for now: coming back later with the other biomes and their bosses
		ArrivalOffset = v(0, 3, 215),
		PlazaGate = v(20, 0.5, -30),
		Heat = {
			BaseRate = 0.6,
			EruptionMultiplier = 1.6,
			LavaRate = 12,
			VentBurst = 30,
			PoolRate = -9,
			PoolRadius = 14,
			ResistFamilies = { Emberkin = 0.5, Tideborn = 0.7 },
			Max = 100,
			AfterRescue = 30,
		},
		Pools = { v(0, 0, 150), v(-130, 0, 10), v(120, 0, -20), v(-60, 0, -170), v(190, 0, 120) },
		Lava = {
			{ From = v(-260, 0, 60), To = v(260, 0, 40), Width = 18 },
			{ From = v(160, 0, -260), To = v(60, 0, -60), Width = 14 },
		},
		Bridges = {
			{ Offset = v(-60, 0, 56), Length = 30, Rotation = 0 },
			{ Offset = v(90, 0, 47), Length = 30, Rotation = 0 },
			{ Offset = v(100, 0, -140), Length = 26, Rotation = 63 },
		},
		Vents = { v(-90, 0, 110), v(60, 0, 120), v(-170, 0, -60), v(40, 0, -40), v(-30, 0, -60), v(150, 0, 10) },
		VentCycle = { Period = 12, Warning = 2.5, Active = 3, Radius = 9 },
		NodeKinds = {
			Emberstone = {
				Name = "Emberstone deposit",
				Resource = "Emberstone",
				Min = 2,
				Max = 4,
				Respawn = 90,
				HoldTime = 1.5,
			},
			Crystal = { Name = "Crystal vein", Resource = "RawCrystal", Min = 4, Max = 8, Respawn = 120, HoldTime = 2 },
		},
		Nodes = {
			{ Id = "e1", Kind = "Emberstone", Offset = v(-40, 0, 180) },
			{ Id = "e2", Kind = "Emberstone", Offset = v(50, 0, 175) },
			{ Id = "e3", Kind = "Emberstone", Offset = v(-150, 0, 140) },
			{ Id = "e4", Kind = "Emberstone", Offset = v(140, 0, 150) },
			{ Id = "e5", Kind = "Emberstone", Offset = v(-200, 0, 20) },
			{ Id = "e6", Kind = "Emberstone", Offset = v(-110, 0, -90) },
			{ Id = "e7", Kind = "Emberstone", Offset = v(80, 0, -60) },
			{ Id = "e8", Kind = "Emberstone", Offset = v(200, 0, -10) },
			{ Id = "e9", Kind = "Emberstone", Offset = v(-160, 0, -180) },
			{ Id = "e10", Kind = "Emberstone", Offset = v(20, 0, -200) },
			{ Id = "c1", Kind = "Crystal", Offset = v(-205, 0, -110) },
			{ Id = "c2", Kind = "Crystal", Offset = v(185, 0, 185) },
			{ Id = "c3", Kind = "Crystal", Offset = v(172, 0, -183) }, -- inside the hidden grotto
		},
		Landmarks = {
			{ Id = "Gate", Name = "Emberfall Gate", Offset = v(0, 0, 215), Radius = 25, Reward = { Gold = 100 } },
			{
				Id = "Overlook",
				Name = "Ashen Overlook",
				Offset = v(-175, 0, 120),
				Radius = 22,
				MinHeight = 38, -- the top of the spire (46 studs up)
				Reward = { Gold = 300 },
			},
			{ Id = "Falls", Name = "Magma Falls", Offset = v(170, 0, -110), Radius = 30, Reward = { Gold = 300 } },
			{
				Id = "Caldera",
				Name = "Guardian's Caldera",
				Offset = v(0, 0, -110),
				Radius = 45,
				Reward = { Gold = 300 },
			},
			{
				Id = "Grotto",
				Name = "Hidden Ember Grotto",
				Offset = v(175, 0, -180),
				Radius = 16,
				Hidden = true,
				Reward = { Gold = 800, Essence = 30 },
			},
		},
		Footprints = {
			v(140, 0, -40),
			v(172, 0, -66),
			v(200, 0, -92),
			v(214, 0, -128),
			v(206, 0, -158),
			v(192, 0, -176),
		},
		WildSpawns = {
			v(-80, 0, 160),
			v(90, 0, 100),
			v(-190, 0, 80),
			v(-80, 0, -20),
			v(130, 0, -10),
			v(-120, 0, -140),
			v(60, 0, -170),
		},
		WildTable = {
			{ Species = "Cindercub", Weight = 32 },
			{ Species = "Ashwhisk", Weight = 28 },
			{ Species = "Gloomkit", Weight = 14 },
			{ Species = "Puddlefin", Weight = 10 },
			{ Species = "Magmaul", Weight = 12 },
			{ Species = "Coilhorn", Weight = 4 },
		},
		MaxWild = 5,
		WildLifetime = 180,
		Eruption = { Period = 480, Duration = 90, SpawnSpecies = "Pyrewing", SpawnOffset = v(-175, 46, 120) },
		Guardian = { Id = "Matriarch", Offset = v(0, 0, -110), ArenaRadius = 40 },
	},
} :: { [string]: Region }

-- Every region, in order; RegionConfig.Order holds only the ones switched on.
RegionConfig.All = { "Emberfall" }
RegionConfig.Order = {} :: { string }
for _, id in RegionConfig.All do
	if RegionConfig.Regions[id].Enabled ~= false then
		table.insert(RegionConfig.Order, id)
	end
end

-- Whether a region exists and is switched on.
function RegionConfig.IsOpen(id: string): boolean
	local region = RegionConfig.Regions[id]
	return region ~= nil and region.Enabled ~= false
end

function RegionConfig.Contains(region: Region, position: Vector3): boolean
	local d = position - region.Center
	return math.abs(d.X) <= region.HalfSize.X
		and math.abs(d.Z) <= region.HalfSize.Z
		and d.Y > -40
		and d.Y < region.HalfSize.Y
end

-- Which region a world position is in (nil = the empire area).
function RegionConfig.At(position: Vector3): Region?
	for _, id in RegionConfig.Order do
		local region = RegionConfig.Regions[id]
		if RegionConfig.Contains(region, position) then
			return region
		end
	end
	return nil
end

-- Vents and eruptions run on the shared server clock (workspace:GetServerTimeNow()), so
-- every client shows exactly what the server is checking.
function RegionConfig.VentPhase(region: Region, index: number, t: number): "Idle" | "Warning" | "Active"
	local cycle = region.VentCycle
	local phase = (t + index * 1.7) % cycle.Period
	if phase < cycle.Warning then
		return "Warning"
	elseif phase < cycle.Warning + cycle.Active then
		return "Active"
	end
	return "Idle"
end

function RegionConfig.EruptionActive(region: Region, t: number): boolean
	return t % region.Eruption.Period < region.Eruption.Duration
end

-- Seconds until the next eruption starts (0 while one is going on).
function RegionConfig.NextEruptionIn(region: Region, t: number): number
	if RegionConfig.EruptionActive(region, t) then
		return 0
	end
	return region.Eruption.Period - t % region.Eruption.Period
end

-- Distance from a point to a lava segment (flat, ignoring height).
function RegionConfig.DistanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local lengthSquared = ab:Dot(ab)
	local t = if lengthSquared > 0 then math.clamp(ap:Dot(ab) / lengthSquared, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

return RegionConfig
