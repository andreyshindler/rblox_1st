--!strict
-- BadgeAwards.luau
-- Awards Roblox badges off the game's listener hooks. Badge ids come from
-- Config.BADGE_IDS (0 = disabled) — create the badges on the Creator Dashboard
-- and paste their ids there. Every award is pcall-guarded and de-duplicated per
-- session, so unset ids or API hiccups can never affect gameplay.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local RebirthService = require(script.Parent:WaitForChild("RebirthService"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local BadgeAwards = {}

-- Per-session "already tried" marks so we don't spam AwardBadge (it is a web
-- call). AwardBadge itself is a no-op for badges the player already owns.
local attempted: { [number]: { [string]: boolean } } = {}

local function award(player: Player, badgeKey: string)
	local badgeId = Config.BADGE_IDS[badgeKey]
	if typeof(badgeId) ~= "number" or badgeId <= 0 then
		return
	end
	local marks = attempted[player.UserId]
	if not marks then
		marks = {}
		attempted[player.UserId] = marks
	end
	if marks[badgeKey] then
		return
	end
	marks[badgeKey] = true

	task.spawn(function()
		pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
	end)
end

function BadgeAwards.start()
	CheckpointService.addFinishListener(function(player, elapsed)
		local profile = DataService.getProfile(player.UserId)
		if profile then
			if profile.wins >= 1 then
				award(player, "FIRST_WIN")
			end
			if profile.wins >= 10 then
				award(player, "WINS_10")
			end
		end
		if elapsed > 0 and elapsed <= Config.SPEEDRUN_TIME then
			award(player, "SPEEDRUNNER")
		end
	end)

	CoinService.addAwardListener(function(player, newTotal)
		if newTotal >= Config.RICH_COINS then
			award(player, "RICH")
		end
	end)

	RebirthService.addRebirthListener(function(player, _rebirths)
		award(player, "REBORN")
	end)

	Players.PlayerRemoving:Connect(function(player)
		attempted[player.UserId] = nil
	end)
end

return BadgeAwards
