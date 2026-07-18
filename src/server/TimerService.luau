--!strict
-- TimerService.luau
-- Times each run (first checkpoint -> finish) and records the player's best time.
--
-- The live clock is driven entirely through replicated player Attributes rather
-- than a RemoteEvent: the server stamps `RunStartTime` (a server-synced timestamp)
-- and `RunActive`, and the client counts up locally against `workspace:GetServerTimeNow()`.
-- This survives respawns and late joins with no handshake.
--
-- Best times are loaded from / saved to DataService (DataStore + OrderedDataStore)
-- so they persist across sessions and feed the global board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent:WaitForChild("DataService"))

local TimerService = {}

-- Per-player best completion time in seconds, keyed by UserId (in-memory cache
-- backed by DataService).
local bestTimes: { [number]: number } = {}

-- Listeners notified when a player sets a new personal best (global board
-- refresh, fireworks, ...). Register via addBestListener.
local bestListeners: { (player: Player, seconds: number) -> () } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function setBestLeaderstat(player: Player, seconds: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local bestValue = leaderstats and leaderstats:FindFirstChild("Best")
	if bestValue and bestValue:IsA("NumberValue") then
		-- Round to 2 decimals for a tidy leaderboard value.
		bestValue.Value = math.floor(seconds * 100 + 0.5) / 100
	end
end

-- Registers a callback fired (in its own thread) whenever a new personal best is set.
function TimerService.addBestListener(fn: (player: Player, seconds: number) -> ())
	table.insert(bestListeners, fn)
end

-- Loads the player's persisted best (async) and reflects it on the leaderboard.
-- Safe to call right after the player's leaderstats are created.
function TimerService.loadPlayer(player: Player)
	task.spawn(function()
		local best = DataService.loadBest(player.UserId)
		if typeof(best) == "number" and best > 0 then
			bestTimes[player.UserId] = best
			setBestLeaderstat(player, best)
		end
	end)
end

-- Begin (or restart) a run for the player.
function TimerService.startRun(player: Player)
	player:SetAttribute("RunStartTime", serverNow())
	player:SetAttribute("RunActive", true)
end

-- End the run, record the elapsed time, update / persist the best if it beats the
-- record, and return the elapsed seconds.
function TimerService.finishRun(player: Player): number
	local start = player:GetAttribute("RunStartTime")
	local elapsed = 0
	if typeof(start) == "number" then
		elapsed = serverNow() - start
	end

	player:SetAttribute("RunActive", false)
	player:SetAttribute("LastRunTime", elapsed)

	local best = bestTimes[player.UserId]
	if elapsed > 0 and (not best or elapsed < best) then
		bestTimes[player.UserId] = elapsed
		setBestLeaderstat(player, elapsed)

		local userId = player.UserId
		task.spawn(function()
			DataService.saveBest(userId, elapsed)
		end)

		for _, listener in bestListeners do
			task.spawn(listener, player, elapsed)
		end
	end

	return elapsed
end

function TimerService.clear(player: Player)
	bestTimes[player.UserId] = nil
end

return TimerService
