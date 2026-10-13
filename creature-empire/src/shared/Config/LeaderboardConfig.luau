--!strict
-- Leaderboards (OrderedDataStores). Scores are whole numbers worked out from saved data by
-- Shared/Util/Leaderboard. "Weekly" boards use a key per week, so they reset every Monday
-- 00:00 UTC.

export type Board = {
	Id: string,
	Name: string,
	Description: string,
	Weekly: boolean?,
	Format: "Number" | "Plain",
}

local LeaderboardConfig = {}

LeaderboardConfig.StoreVersion = 1
LeaderboardConfig.UpdateInterval = 120 -- seconds between score writes per player
LeaderboardConfig.RefreshInterval = 120 -- seconds between top-10 reads
LeaderboardConfig.Size = 10

LeaderboardConfig.Boards = {
	{
		Id = "Empire",
		Name = "Greatest Empires",
		Description = "Empire score: core tier, building levels, creatures and Ascensions.",
		Format = "Number",
	},
	{
		Id = "Collection",
		Name = "Collectors",
		Description = "Species discovered.",
		Format = "Plain",
	},
	{
		Id = "Explorers",
		Name = "Explorers",
		Description = "Expeditions completed, landmarks found and guardians defeated.",
		Format = "Plain",
	},
	{
		Id = "WeeklyGold",
		Name = "This Week's Earners",
		Description = "Gold earned this week (resets every Monday).",
		Weekly = true,
		Format = "Number",
	},
} :: { Board }

return LeaderboardConfig
