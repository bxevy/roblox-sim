-- Makes your pet bob gently up and down. Your client simulates your pet's physics, so
-- moving its anchor here shows up smoothly for everyone.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ANCHOR_NAME = "PetAnchor"

local Pets = {}

function Pets.Start()
	local player = Players.LocalPlayer
	local base: Vector3? = nil
	local anchor: Attachment? = nil
	RunService.RenderStepped:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local found = root and root:FindFirstChild(ANCHOR_NAME)
		if found ~= anchor then
			anchor = found :: Attachment?
			base = if anchor then anchor.Position else nil
		end
		if anchor and base then
			local t = os.clock()
			anchor.Position = base + Vector3.new(0, math.sin(t * 2.2) * 0.35, math.sin(t * 1.1) * 0.15)
		end
	end)
end

return Pets
