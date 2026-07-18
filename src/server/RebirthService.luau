--!strict
-- RebirthService.luau
-- Rebirth: after finishing the course at least once since the last rebirth, a
-- player may rebirth — their stage resets to the start and they gain a
-- permanent rank (Rebirths leaderstat) and coin multiplier (see
-- CoinService.award), plus a coloured aura that marks their tier in-world.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))

local RebirthService = {}

-- Aura colours by rebirth count (capped at the last tier).
local AURA_TIERS: { Color3 } = {
	Color3.fromRGB(205, 127, 50), -- bronze
	Color3.fromRGB(210, 210, 210), -- silver
	Color3.fromRGB(255, 215, 0), -- gold
	Color3.fromRGB(120, 230, 255), -- diamond
	Color3.fromRGB(170, 60, 255), -- mythic
}

-- Listeners fired after a successful rebirth (badges, effects, ...).
local rebirthListeners: { (player: Player, rebirths: number) -> () } = {}

function RebirthService.addRebirthListener(fn: (player: Player, rebirths: number) -> ())
	table.insert(rebirthListeners, fn)
end

local function setRebirthsLeaderstat(player: Player, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Rebirths")
	if stat and stat:IsA("IntValue") then
		stat.Value = value
	end
end

-- Attach (or refresh) the aura on the character to match the rebirth tier.
local function applyAura(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local old = root:FindFirstChild("RebirthAura")
	if old then
		old:Destroy()
	end

	local profile = DataService.getProfile(player.UserId)
	local rebirths = profile and profile.rebirths or 0
	if rebirths <= 0 then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "RebirthAura"
	attachment.Position = Vector3.new(0, -2.5, 0)
	attachment.Parent = root

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(AURA_TIERS[math.min(rebirths, #AURA_TIERS)])
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Rate = 12
	emitter.Parent = attachment
end

local function tryRebirth(player: Player)
	local profile = DataService.getProfile(player.UserId)
	if not profile or profile.winsSinceRebirth <= 0 then
		return
	end

	profile.rebirths += 1
	profile.winsSinceRebirth = 0
	DataService.markProfileDirty(player.UserId)

	setRebirthsLeaderstat(player, profile.rebirths)
	player:SetAttribute("CanRebirth", false)
	CheckpointService.resetToStart(player)
	if player.Character then
		applyAura(player, player.Character)
	end

	for _, listener in rebirthListeners do
		task.spawn(listener, player, profile.rebirths)
	end
end

local function onPlayerAdded(player: Player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local stat = Instance.new("IntValue")
		stat.Name = "Rebirths"
		stat.Value = 0
		stat.Parent = leaderstats
	end

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 5)
		applyAura(player, character)
	end)

	local profile = DataService.loadProfile(player.UserId)
	setRebirthsLeaderstat(player, profile.rebirths)
	if player.Character then
		applyAura(player, player.Character)
	end
end

function RebirthService.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local rebirthEvent = Instance.new("RemoteEvent")
	rebirthEvent.Name = "Rebirth"
	rebirthEvent.Parent = remotes

	rebirthEvent.OnServerEvent:Connect(tryRebirth)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return RebirthService
