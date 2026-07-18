--!strict
-- ShopService.luau
-- Server side of the trail shop. All validation happens here — the client only
-- ever asks. A RemoteFunction ("ShopAction") supports:
--   "get"          -> profile snapshot { coins, owned, equipped }
--   "buy", itemId  -> attempts purchase, returns { ok, error?, snapshot }
--   "equip", id    -> equips an owned trail ("" unequips), returns snapshot
-- The equipped trail is attached to the character's HumanoidRootPart on spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopItems = require(Shared:WaitForChild("ShopItems"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local ShopService = {}

local function snapshot(userId: number)
	local profile = DataService.getProfile(userId)
	if not profile then
		return { coins = 0, owned = {}, equipped = nil }
	end
	return { coins = profile.coins, owned = profile.owned, equipped = profile.equipped }
end

local function setCoinsLeaderstat(player: Player, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Coins")
	if stat and stat:IsA("IntValue") then
		stat.Value = value
	end
end

-- Removes any existing trail and attaches the equipped one (if any).
local function applyTrail(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local old = root:FindFirstChild("RainbowRushTrail")
	if old then
		old:Destroy()
	end

	local profile = DataService.getProfile(player.UserId)
	local itemId = profile and profile.equipped
	local item = itemId and ShopItems.byId[itemId]
	if not item then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root

	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = root

	-- Build the colour sequence from the item's colour list.
	local keypoints: { ColorSequenceKeypoint } = {}
	local n = #item.colors
	for i, color in item.colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(n - 1, 1), color))
	end
	if n == 1 then
		keypoints = { ColorSequenceKeypoint.new(0, item.colors[1]), ColorSequenceKeypoint.new(1, item.colors[1]) }
	end

	local trail = Instance.new("Trail")
	trail.Name = "RainbowRushTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = 0.6
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root
end

local function ownsItem(profile: DataService.Profile, itemId: string): boolean
	return table.find(profile.owned, itemId) ~= nil
end

local function handleAction(player: Player, action: unknown, itemId: unknown)
	local profile = DataService.getProfile(player.UserId)
	if not profile then
		return { ok = false, error = "Profile not loaded yet", snapshot = snapshot(player.UserId) }
	end

	if action == "get" then
		return { ok = true, snapshot = snapshot(player.UserId) }
	end

	if typeof(itemId) ~= "string" then
		return { ok = false, error = "Bad item", snapshot = snapshot(player.UserId) }
	end

	if action == "buy" then
		local item = ShopItems.byId[itemId]
		if not item then
			return { ok = false, error = "Unknown item", snapshot = snapshot(player.UserId) }
		end
		if ownsItem(profile, itemId) then
			return { ok = false, error = "Already owned", snapshot = snapshot(player.UserId) }
		end
		if profile.coins < item.price then
			return { ok = false, error = "Not enough coins", snapshot = snapshot(player.UserId) }
		end
		profile.coins -= item.price
		table.insert(profile.owned, itemId)
		profile.equipped = itemId
		DataService.markProfileDirty(player.UserId)
		setCoinsLeaderstat(player, profile.coins)
		if player.Character then
			applyTrail(player, player.Character)
		end
		return { ok = true, snapshot = snapshot(player.UserId) }
	end

	if action == "equip" then
		if itemId == "" then
			profile.equipped = nil
		else
			if not ownsItem(profile, itemId) then
				return { ok = false, error = "Not owned", snapshot = snapshot(player.UserId) }
			end
			profile.equipped = itemId
		end
		DataService.markProfileDirty(player.UserId)
		if player.Character then
			applyTrail(player, player.Character)
		end
		return { ok = true, snapshot = snapshot(player.UserId) }
	end

	return { ok = false, error = "Unknown action", snapshot = snapshot(player.UserId) }
end

function ShopService.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local shopAction = Instance.new("RemoteFunction")
	shopAction.Name = "ShopAction"
	shopAction.Parent = remotes

	shopAction.OnServerInvoke = handleAction

	local function onCharacter(player: Player, character: Model)
		-- Root may not exist yet on spawn.
		character:WaitForChild("HumanoidRootPart", 5)
		applyTrail(player, character)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)
end

return ShopService
