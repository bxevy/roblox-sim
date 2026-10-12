-- Player cards: customization (background, title, frame, showcased stats), viewing other
-- players' cards, and the nameplate over each player's head (title, level, prestige emblem).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardUI = require(ReplicatedStorage.Shared.CardUI)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local NAMEPLATE = "Nameplate"

local CardService = {}

local statLabels: { [string]: string } = {}
for _, entry in Config.StatNames do
	statLabels[entry[1]] = entry[2]
end

local function profile(data): Cosmetics.Profile
	return { Level = data.Level, Prestige = data.Prestige, Stats = data.Stats, Weapons = data.Weapons, Armors = data.Armors }
end

local function cardData(player: Player)
	local data = PlayerService.GetData(player)
	if not data then
		return nil
	end
	local showcase = {}
	for _, statId in data.Card.Showcase do
		table.insert(showcase, { Label = statLabels[statId] or statId, Value = data.Stats[statId] or 0 })
	end
	return {
		UserId = player.UserId,
		Name = player.DisplayName,
		Level = data.Level,
		Prestige = data.Prestige,
		Class = data.Class,
		Background = data.Card.Background,
		Title = data.Card.Title,
		Frame = data.Card.Frame,
		Showcase = showcase,
	}
end

local function onSetCard(player: Player, field: unknown, value: unknown): (boolean, string?)
	local data = PlayerService.GetData(player)
	if not data then
		return false, "Still loading"
	end
	local lists = { Background = Cosmetics.BackgroundsById, Title = Cosmetics.TitlesById, Frame = Cosmetics.FramesById }
	if type(field) == "string" and lists[field] then
		local def = type(value) == "string" and lists[field][value]
		if not def then
			return false, "Unknown option"
		end
		if not Cosmetics.IsUnlocked(profile(data), def.Unlock) then
			return false, `Locked: {Cosmetics.Describe(def.Unlock)}`
		end
		data.Card[field] = value
	elseif field == "Showcase" then
		-- value = { slot, statId }
		local pick: any = value
		if type(pick) ~= "table" or type(pick[1]) ~= "number" or type(pick[2]) ~= "string" or not statLabels[pick[2]] then
			return false, "Unknown stat"
		end
		local slot = math.clamp(math.floor(pick[1]), 1, 3)
		data.Card.Showcase[slot] = pick[2]
	else
		return false, "Unknown field"
	end
	PlayerService.Push(player)
	return true
end

-- Nameplates ---------------------------------------------------------------------

local function updateNameplate(player: Player)
	local data = PlayerService.GetData(player)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not data or not head then
		return
	end
	local old = head:FindFirstChild(NAMEPLATE)
	if old then
		old:Destroy()
	end
	local title = Cosmetics.TitlesById[data.Card.Title] or Cosmetics.Titles[1]
	local class = data.Class and Config.Classes[data.Class]

	local gui = Instance.new("BillboardGui")
	gui.Name = NAMEPLATE
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0

	local hasEmblem = data.Prestige > 0
	local textOffset = if hasEmblem then 46 else 0
	if hasEmblem then
		CardUI.Emblem(gui, data.Prestige, 42, UDim2.fromOffset(0, 2))
	end
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.fromOffset(textOffset, 0)
	titleLabel.Size = UDim2.new(1, -textOffset, 0, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = title.Color
	titleLabel.TextStrokeTransparency = 0.3
	titleLabel.TextXAlignment = if hasEmblem then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	titleLabel.Text = title.Name
	titleLabel.Parent = gui
	local levelLabel = titleLabel:Clone()
	levelLabel.Position = UDim2.fromOffset(textOffset, 22)
	levelLabel.Size = UDim2.new(1, -textOffset, 0, 20)
	levelLabel.TextColor3 = if class then class.Color else Color3.new(1, 1, 1)
	levelLabel.Text = `Lv {data.Level}{if class then " " .. class.DisplayName else ""}`
	levelLabel.Parent = gui

	gui.Parent = head
end

-- Only rebuild the nameplate when something it shows changed.
local shown: { [Player]: string } = {}
local function maybeUpdate(player: Player)
	local data = PlayerService.GetData(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local key = `{data.Level}|{data.Prestige}|{data.Card.Title}|{data.Class}`
	if shown[player] ~= key or not head:FindFirstChild(NAMEPLATE) then
		shown[player] = key
		updateNameplate(player)
	end
end

function CardService.Start()
	Remotes.SetCard.OnServerInvoke = onSetCard
	Remotes.GetCard.OnServerInvoke = function(_, userId)
		local target = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		return target and cardData(target)
	end
	PlayerService.OnPush(maybeUpdate)
	PlayerService.OnCharacterReady(function(player)
		shown[player] = nil
		maybeUpdate(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		shown[player] = nil
	end)
end

return CardService
