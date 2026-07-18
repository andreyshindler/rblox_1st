--!strict
-- DailyRewardService.luau
-- Daily login rewards with a streak: consecutive days climb the DAILY_REWARDS
-- table; missing a day resets the streak. Reaching DAILY_TRAIL_DAY also grants
-- the DAILY_STREAK_TRAIL cosmetic. A RemoteFunction ("DailyAction") serves:
--   "check" -> { claimable, streakIfClaimed, reward }
--   "claim" -> { ok, reward?, streak?, coins? }
-- All timing uses whole UTC days so timezone changes can't double-claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopItems = require(Shared:WaitForChild("ShopItems"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))

local DailyRewardService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- The streak the player would be on if they claimed right now, or 0 if today's
-- reward is already claimed.
local function pendingStreak(profile: DataService.Profile): number
	local day = today()
	if profile.lastDailyClaim >= day then
		return 0 -- already claimed today
	elseif profile.lastDailyClaim == day - 1 then
		return profile.dailyStreak + 1 -- consecutive day
	end
	return 1 -- first ever, or streak broken
end

local function rewardFor(streak: number): number
	return Config.DAILY_REWARDS[math.min(streak, #Config.DAILY_REWARDS)]
end

local function handleAction(player: Player, action: unknown)
	local profile = DataService.getProfile(player.UserId)
	if not profile then
		return { ok = false, claimable = false }
	end

	if action == "check" then
		local streak = pendingStreak(profile)
		return {
			ok = true,
			claimable = streak > 0,
			streakIfClaimed = streak,
			reward = streak > 0 and rewardFor(streak) or 0,
		}
	end

	if action == "claim" then
		local streak = pendingStreak(profile)
		if streak <= 0 then
			return { ok = false, claimable = false }
		end

		profile.dailyStreak = streak
		profile.lastDailyClaim = today()

		-- Day-DAILY_TRAIL_DAY bonus: the streak trail, if it exists and is unowned.
		if
			streak >= Config.DAILY_TRAIL_DAY
			and ShopItems.byId[Config.DAILY_STREAK_TRAIL]
			and not table.find(profile.owned, Config.DAILY_STREAK_TRAIL)
		then
			table.insert(profile.owned, Config.DAILY_STREAK_TRAIL)
		end

		DataService.markProfileDirty(player.UserId)
		-- award() applies the rebirth multiplier and fires badge listeners.
		CoinService.award(player, rewardFor(streak))

		local after = DataService.getProfile(player.UserId)
		return {
			ok = true,
			reward = rewardFor(streak),
			streak = streak,
			coins = after and after.coins or 0,
		}
	end

	return { ok = false }
end

function DailyRewardService.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local dailyAction = Instance.new("RemoteFunction")
	dailyAction.Name = "DailyAction"
	dailyAction.Parent = remotes

	dailyAction.OnServerInvoke = handleAction
end

return DailyRewardService
