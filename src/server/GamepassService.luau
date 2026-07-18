--!strict
-- GamepassService.luau
-- Skip-stage gamepass. Players who own the gamepass can press the HUD's "Skip
-- Stage" button to jump forward one checkpoint. Players who don't own it get the
-- Roblox purchase prompt; a successful purchase performs the skip.
--
-- In Studio (with ALLOW_SKIP_IN_STUDIO) the button always works so you can test
-- without a real gamepass id configured.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))

local GamepassService = {}

-- Small per-player cooldown so a rapid double-click doesn't skip two stages.
local skipCooldown: { [number]: boolean } = {}

local function ownsSkip(player: Player): boolean
	local id = Config.SKIP_STAGE_GAMEPASS_ID
	if id <= 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and owns == true
end

local function trySkip(player: Player)
	if skipCooldown[player.UserId] then
		return
	end
	skipCooldown[player.UserId] = true
	task.delay(0.5, function()
		skipCooldown[player.UserId] = nil
	end)

	if ownsSkip(player) then
		CheckpointService.advanceStage(player)
	elseif Config.ALLOW_SKIP_IN_STUDIO and RunService:IsStudio() then
		CheckpointService.advanceStage(player)
	elseif Config.SKIP_STAGE_GAMEPASS_ID > 0 then
		-- Doesn't own it and we're live: offer the purchase.
		MarketplaceService:PromptGamePassPurchase(player, Config.SKIP_STAGE_GAMEPASS_ID)
	end
end

function GamepassService.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local skipEvent = remotes:FindFirstChild("SkipStage")
	if not skipEvent then
		skipEvent = Instance.new("RemoteEvent")
		skipEvent.Name = "SkipStage"
		skipEvent.Parent = remotes
	end

	;(skipEvent :: RemoteEvent).OnServerEvent:Connect(function(player)
		trySkip(player)
	end)

	-- Complete the skip right after a successful in-game purchase.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if purchased and gamePassId == Config.SKIP_STAGE_GAMEPASS_ID then
			CheckpointService.advanceStage(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		skipCooldown[player.UserId] = nil
	end)
end

return GamepassService
