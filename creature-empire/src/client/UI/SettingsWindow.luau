--!strict
-- Settings (saved to your profile) and, for developers, test commands.

local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local SettingsWindow = {}

function SettingsWindow.new(ctx: any)
	local State = ctx.Controllers.State
	local win = Window.new(ctx.Gui, "Settings", "⚙", Vector2.new(560, 560), ctx.Close)
	Theme.List(win.Body, 10)

	local function set(key: string, value: any)
		local ok, result = ctx.Request("SetSetting", key, value)
		if not ok then
			ctx.Notify(result, "Error")
		end
	end

	local render: () -> ()

	local function volumeRow(parent: Instance, label: string, key: string, value: number)
		local row = Window.Row(parent, 40)
		Theme.Text(row, `{label}: <b>{math.floor(value * 100 + 0.5)}%</b>`, 16, {
			Size = UDim2.new(1, -230, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		local steps: { { any } } = { { "−", -0.1 }, { "+", 0.1 } }
		for _, step in steps do
			local b = Theme.Button(row, step[1], "Secondary", { Size = UDim2.fromOffset(48, 34) })
			b.Activated:Connect(function()
				set(key, math.clamp(math.floor((value + step[2]) * 10 + 0.5) / 10, 0, 1))
			end)
		end
		local mute = Theme.Button(
			row,
			if value > 0 then "Mute" else "Unmute",
			"Ghost",
			{ Size = UDim2.fromOffset(110, 34), TextSize = 15 }
		)
		mute.Activated:Connect(function()
			set(key, if value > 0 then 0 else 0.6)
		end)
	end

	local function toggleRow(parent: Instance, label: string, description: string, key: string, value: boolean)
		local row = Window.Row(parent, 44)
		local text = Theme.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -130, 1, 0) }, row)
		Theme.Text(text, `<b>{label}</b>`, 16)
		Theme.Text(text, description, 13, { TextColor3 = Theme.Colors.Muted, Position = UDim2.fromOffset(0, 20) })
		local b = Theme.Button(
			row,
			if value then "On" else "Off",
			if value then "Primary" else "Secondary",
			{ Size = UDim2.fromOffset(110, 34) }
		)
		b.Activated:Connect(function()
			set(key, not value)
		end)
	end

	render = function()
		Window.Clear(win.Body)
		local s = State.Get("Settings")
		if not s then
			Theme.Text(win.Body, "Loading…", 16)
			return
		end
		local audio = Window.Section(win.Body, "AUDIO", 1)
		volumeRow(audio, "Music", "Music", s.Music)
		volumeRow(audio, "Sound effects", "Sfx", s.Sfx)

		local visual = Window.Section(win.Body, "VISUALS & ACCESSIBILITY", 2)
		local row = Window.Row(visual, 40)
		Theme.Text(row, "<b>Visual effects</b>", 16, {
			Size = UDim2.new(1, -350, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		for _, option in { "Full", "Reduced", "Off" } do
			local b = Theme.Button(
				row,
				option,
				if s.Vfx == option then "Primary" else "Secondary",
				{ Size = UDim2.fromOffset(104, 34), TextSize = 15 }
			)
			b.Activated:Connect(function()
				set("Vfx", option)
			end)
		end
		toggleRow(
			visual,
			"Reduced motion",
			"Calmer interface animation, no bobbing or spinning scenery.",
			"ReducedMotion",
			s.ReducedMotion
		)
		toggleRow(visual, "Camera shake", "Shake on big moments (bosses, later updates).", "CameraShake", s.CameraShake)
		toggleRow(visual, "Fast reveals", "Skip the build-up when you get a new creature.", "FastOpen", s.FastOpen)

		local meta = State.Get("Meta")
		if meta then
			Theme.Text(
				win.Body,
				`Creature Empire v{meta.Version} · Update {meta.Phase}`
					.. (if meta.CanSave then "" else " · progress is not saved in this test session"),
				13,
				{
					TextColor3 = Theme.Colors.Muted,
					LayoutOrder = 3,
				}
			)
		end

		local dev = State.Get("Dev")
		if dev and dev.Allowed then
			local tools = Window.Section(win.Body, "DEVELOPER (Studio / allow-listed only)", 4)
			local commands: { { any } } = {
				{ "+1,000 gold", "gold", 1000 },
				{ "+100 petals", "petals", 100 },
				{ "+100 essence", "essence", 100 },
				{ "+50 crystals", "crystals", 50 },
				{ "+5 levels", "levelup" },
				{ "Finish expeditions", "finishexpeditions" },
				{ "+20 shards", "shards", 20 },
				{ "Core tier 5", "coremax" },
				{ "Event: Golden Hour", "event", "GoldenHour" },
				{ "Event: Bloom", "event", "Bloom" },
				{ "Event: Ember Rift", "event", "EmberRift" },
				{ "Fill storage", "fillstorage" },
				{ "Ready abilities", "resetcooldowns" },
				{ "Skip quest", "skipquest" },
				{ "Away 60 min", "offline", 60 },
				{ "Grant Prismaw", "grant", "Prismaw" },
				{ "Unlock all pets", "unlockall" },
				{ "Verbose logs", "verbose" },
				{ "Save now", "save" },
				{ "Reset profile", "reset" },
			}
			local grid = Theme.Make(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y },
				tools
			)
			Theme.Make(
				"UIGridLayout",
				{ CellSize = UDim2.fromOffset(150, 34), CellPadding = UDim2.fromOffset(6, 6) },
				grid
			)
			for _, command in commands do
				local b = Theme.Button(grid, command[1], "Ghost", { TextSize = 14 })
				b.Activated:Connect(function()
					local ok, message = ctx.Request("Dev", command[2], command[3])
					ctx.Notify(tostring(message), if ok then "Success" else "Error")
				end)
			end
		end
	end

	State.OnChanged("Settings", function()
		if ctx.IsOpen("Settings") then
			render()
		end
	end)

	return {
		Root = win.Root,
		Open = function()
			render()
		end,
	}
end

return SettingsWindow
