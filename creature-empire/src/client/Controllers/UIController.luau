--!strict
-- Owns the ScreenGui, the window manager (one window at a time, gamepad focus, close on
-- B/Escape-style back), toasts, and responsive scaling for phone to TV screens.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local StateController = require(script.Parent.StateController)
local AudioController = require(script.Parent.AudioController)

local localPlayer = Players.LocalPlayer

export type Context = {
	Gui: ScreenGui,
	Overlay: ScreenGui,
	Request: (string, ...any) -> (boolean, any),
	Notify: (string, string?) -> (),
	Open: (string, any?) -> (),
	Close: () -> (),
	IsOpen: (string) -> boolean,
	Controllers: { [string]: any },
}

export type WindowModule = {
	Root: GuiObject?,
	Open: (any?) -> (),
	OnClose: (() -> ())?,
	Modal: boolean?, -- cannot be closed by the player (starter choice)
}

local UIController = {}

local gui: ScreenGui
local overlay: ScreenGui
local windows: { [string]: WindowModule } = {}
local current: string? = nil
local toastHolder: Frame
local dim: TextButton
local context: Context

local KIND_COLORS = {
	Info = Theme.Colors.Border,
	Success = Theme.Colors.Success,
	Error = Theme.Colors.Danger,
	Reward = Theme.Colors.Gold,
}
local KIND_GLYPHS = { Info = "ⓘ", Success = "✔", Error = "✖", Reward = "★" }

function UIController.Notify(message: string, kind: string?)
	if type(message) ~= "string" or message == "" then
		return
	end
	local k = kind or "Info"
	local color = KIND_COLORS[k] or KIND_COLORS.Info
	local toast = Theme.Panel(toastHolder, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		LayoutOrder = -math.floor(os.clock() * 100),
	})
	local stroke = toast:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = color
	stroke.Transparency = 0.35
	Theme.Padding(toast, 10, 14)
	Theme.Text(toast, `<font color="#{color:ToHex()}">{KIND_GLYPHS[k] or ""}</font>  {message}`, 17, {
		FontFace = Theme.Bold,
	})
	Theme.PopIn(toast)
	if k == "Error" then
		AudioController.Play("UiError")
	else
		AudioController.Play("Notify")
	end
	-- Keep at most 3 toasts.
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder -- newest first (LayoutOrder is -time)
	end)
	for i = 4, #toasts do
		toasts[i]:Destroy()
	end
	task.delay(if k == "Error" then 4 else 3.2, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
			for _, d in toast:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, TweenInfo.new(0.25), { Transparency = 1 }):Play()
				end
			end
			task.wait(0.27)
			toast:Destroy()
		end
	end)
end

function UIController.Register(name: string, module: any)
	windows[name] = module
end

function UIController.Close()
	if not current then
		return
	end
	local module = windows[current]
	if module.Modal then
		return
	end
	current = nil
	if module.Root then
		module.Root.Visible = false
	end
	if module.OnClose then
		module.OnClose()
	end
	dim.Visible = false
	GuiService.SelectedObject = nil
	AudioController.Play("UiClose")
end

function UIController.Open(name: string, arg: any?)
	local module = windows[name]
	if not module then
		return
	end
	if current and current ~= name then
		local previous = windows[current]
		if previous.Modal then
			return -- a modal (starter choice) must be finished first
		end
		if previous.Root then
			previous.Root.Visible = false
		end
		if previous.OnClose then
			previous.OnClose()
		end
	end
	current = name
	module.Open(arg)
	if module.Root then
		module.Root.Visible = true
		Theme.PopIn(module.Root)
		dim.Visible = true
		task.defer(Theme.FocusFirst, module.Root)
	end
	AudioController.Play("UiOpen")
end

function UIController.Toggle(name: string, arg: any?)
	if current == name then
		UIController.Close()
	else
		UIController.Open(name, arg)
	end
end

function UIController.IsOpen(name: string): boolean
	return current == name
end

function UIController.Current(): string?
	return current
end

function UIController.Context(): Context
	return context
end

local function updateScale(scale: UIScale)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	-- 1.0 at 1600x900, so big monitors don't blow the interface up; phones go down to
	-- 0.62 so text stays readable; TVs a bit larger.
	local s = math.min(size.X / 1600, size.Y / 900)
	if GuiService:IsTenFootInterface() then
		s *= 1.15
	end
	scale.Scale = math.clamp(s, 0.62, 1.05)
end

function UIController.Start(controllers: { [string]: any })
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	gui = Theme.Make("ScreenGui", {
		Name = "CreatureEmpireUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		IgnoreGuiInset = false,
	}, playerGui)
	overlay = Theme.Make("ScreenGui", {
		Name = "CreatureEmpireOverlay",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	}, playerGui)
	for _, screen in { gui, overlay } do
		local scale = Theme.Make("UIScale", {}, screen)
		updateScale(scale)
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				updateScale(scale)
			end)
		end
	end

	dim = Theme.Make("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
		Selectable = false,
	}, gui)
	dim.Activated:Connect(UIController.Close)

	toastHolder = Theme.Make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, overlay)
	Theme.List(toastHolder, 6, nil, Enum.HorizontalAlignment.Center)

	Theme.OnClick = function()
		AudioController.Play("UiClick")
	end
	StateController.OnChanged("Settings", function(settings)
		Theme.ReducedMotion = settings.ReducedMotion
	end)

	Remotes.Events.Notify.OnClientEvent:Connect(UIController.Notify)

	context = {
		Gui = gui,
		Overlay = overlay,
		Request = StateController.Request,
		Notify = UIController.Notify,
		Open = UIController.Open,
		Close = UIController.Close,
		IsOpen = UIController.IsOpen,
		Controllers = controllers,
	}
end

return UIController
