--!strict
-- Game-wide settings.

local GameConfig = {}

GameConfig.Name = "Creature Empire"
GameConfig.Version = "0.3.0"

-- Development phase this build implements. Content with a higher `Phase` in the configs is
-- designed but not obtainable or buildable yet.
GameConfig.Phase = 3

-- A building (other than the Empire Core) can be at most this many levels above the
-- Empire Core's tier, so the core gates progression.
GameConfig.MaxLevelAboveCore = 1

-- Developer commands (DevService) work in Studio, and in live servers only for these
-- user ids. Keep this empty unless you need live debugging.
GameConfig.DeveloperUserIds = {} :: { number }

return GameConfig
