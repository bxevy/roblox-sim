--!strict
-- Loads the hand-made models listed in AssetConfig.ModelAssets from Roblox (InsertService)
-- into ReplicatedStorage/Assets/<Category>/<Name>, where the game looks for custom models.
-- Runs once at server start, before the world is built. Scripts inside loaded models are
-- removed (models are art only). A model already placed there by hand is kept.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetConfig = require(ReplicatedStorage.Shared.Config.AssetConfig)
local Log = require(script.Parent.Parent.Core.Log)

local AssetLoader = {}

local function folderFor(category: string): Folder
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		local made = Instance.new("Folder")
		made.Name = "Assets"
		made.Parent = ReplicatedStorage
		assets = made
	end
	local folder = (assets :: Instance):FindFirstChild(category)
	if not folder then
		local made = Instance.new("Folder")
		made.Name = category
		made.Parent = assets
		folder = made
	end
	return folder :: Folder
end

local function loadOne(category: string, name: string, assetId: number)
	local folder = folderFor(category)
	if folder:FindFirstChild(name) then
		return -- placed by hand (or from a file): that one wins
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not container then
		Log.Warn("Assets", "Could not load model", { name = name, id = assetId, error = tostring(container) })
		return
	end
	-- LoadAsset wraps the asset in a Model; unwrap a single Model inside it.
	local children = (container :: Instance):GetChildren()
	local model: Model
	if #children == 1 and children[1]:IsA("Model") then
		model = children[1] :: Model
	else
		model = container :: Model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	model.Name = name
	model.Parent = folder
	if model ~= container then
		(container :: Instance):Destroy()
	end
	Log.Info("Assets", "Loaded model", { category = category, name = name, id = assetId })
end

function AssetLoader.Load()
	local jobs = 0
	for category, list in AssetConfig.ModelAssets do
		for name, assetId in list do
			if type(assetId) == "number" and assetId > 0 then
				jobs += 1
				task.spawn(function()
					loadOne(category, name, assetId)
					jobs -= 1
				end)
			end
		end
	end
	-- Wait (briefly) so the world and first plots are built with the models in place.
	local deadline = os.clock() + 15
	while jobs > 0 and os.clock() < deadline do
		task.wait()
	end
end

return AssetLoader
