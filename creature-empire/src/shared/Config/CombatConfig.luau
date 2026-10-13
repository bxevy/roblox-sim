--!strict
-- Guardian fights. Players fight through their companion creature: Attack (short
-- cooldown) and Special (long cooldown; Verdant and Tideborn companions cool nearby allies
-- instead of hitting harder). Telegraphed slams must be dodged; getting hit adds heat.

local CombatConfig = {}

-- Damage multiplier: attacker family -> defender family.
CombatConfig.Elements = {
	Tideborn = { Emberkin = 1.5 },
	Crystalkin = { Emberkin = 1.25 },
	Emberkin = { Emberkin = 0.5, Verdant = 1.5 },
	Verdant = { Emberkin = 0.75, Tideborn = 1.25 },
	Voltbeast = { Tideborn = 1.5 },
} :: { [string]: { [string]: number } }

CombatConfig.Attack = { Cooldown = 1.2, Power = 10 }
CombatConfig.Special = { Cooldown = 18, Power = 35, CoolAllies = 35, CoolRadius = 25 }
CombatConfig.SupportFamilies = { Verdant = true, Tideborn = true }
CombatConfig.TeamBonusPerPlayer = 0.1 -- extra damage per other player in the arena
CombatConfig.MaxTeamBonus = 0.3

export type Phase = { Above: number, SlamEvery: number, Slams: number, Radius: number }
export type Guardian = {
	Id: string,
	Name: string,
	Species: string,
	Family: string,
	Region: string,
	BaseHealth: number,
	HealthPerExtraPlayer: number,
	Phases: { Phase },
	Warning: number,
	SlamHeat: number,
	Respawn: number,
	Reward: { [string]: number },
	RewardCooldown: number,
	MinShare: number,
	FirstWinCreature: string?,
}

CombatConfig.Guardians = {
	Matriarch = {
		Id = "Matriarch",
		Name = "Magmaul Matriarch",
		Species = "Magmaul",
		Family = "Emberkin",
		Region = "Emberfall",
		BaseHealth = 2500,
		HealthPerExtraPlayer = 1400,
		Phases = {
			{ Above = 0.6, SlamEvery = 6, Slams = 1, Radius = 12 },
			{ Above = 0.25, SlamEvery = 5, Slams = 2, Radius = 13 },
			{ Above = 0, SlamEvery = 3.5, Slams = 2, Radius = 15 }, -- enraged
		} :: { Phase },
		Warning = 2, -- seconds between the telegraph and the slam
		SlamHeat = 40,
		Respawn = 180,
		Reward = { Gold = 2000, Emberstone = 20, Essence = 30 },
		RewardCooldown = 600, -- seconds between rewards for the same player
		MinShare = 0.03, -- share of damage needed to earn the reward
		FirstWinCreature = "Magmaul",
	},
} :: { [string]: Guardian }

function CombatConfig.ElementMultiplier(attacker: string, defender: string): number
	local row = CombatConfig.Elements[attacker]
	return row and row[defender] or 1
end

return CombatConfig
