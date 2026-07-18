--!strict
-- TimerService.luau
-- Times each run (spawn -> finish) and records the player's best time.
--
-- The live clock is driven entirely through replicated player Attributes rather
-- than a RemoteEvent: the server stamps `RunStartTime` (a server-synced timestamp)
-- and `RunActive`, and the client counts up locally against `workspace:GetServerTimeNow()`.
-- This survives respawns and late joins with no handshake.

local TimerService = {}

-- Per-player best completion time in seconds, keyed by UserId (session-only).
local bestTimes: { [number]: number } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Begin (or restart) a run for the player.
function TimerService.startRun(player: Player)
	player:SetAttribute("RunStartTime", serverNow())
	player:SetAttribute("RunActive", true)
end

-- End the run, record the elapsed time, update the best if it beats the record,
-- and return the elapsed seconds.
function TimerService.finishRun(player: Player): number
	local start = player:GetAttribute("RunStartTime")
	local elapsed = 0
	if typeof(start) == "number" then
		elapsed = serverNow() - start
	end

	player:SetAttribute("RunActive", false)
	player:SetAttribute("LastRunTime", elapsed)

	local best = bestTimes[player.UserId]
	if not best or elapsed < best then
		bestTimes[player.UserId] = elapsed

		local leaderstats = player:FindFirstChild("leaderstats")
		local bestValue = leaderstats and leaderstats:FindFirstChild("Best")
		if bestValue and bestValue:IsA("NumberValue") then
			-- Round to 2 decimals for a tidy leaderboard value.
			bestValue.Value = math.floor(elapsed * 100 + 0.5) / 100
		end
	end

	return elapsed
end

function TimerService.clear(player: Player)
	bestTimes[player.UserId] = nil
end

return TimerService
