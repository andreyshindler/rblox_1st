--!strict
-- GhostService.luau
-- Server side of ghost replays. The client records its own runs; when the
-- player sets a new personal best (TimerService.addBestListener), a short
-- submit window opens during which this service accepts the recording,
-- validates it, and persists it via DataService. "get" returns the stored
-- ghost so the client can race it.
--
-- Validation is strict — the payload is player-supplied: parallel numeric
-- arrays of equal length, bounded sample count, and a claimed time that
-- matches the best time that opened the window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local TimerService = require(script.Parent:WaitForChild("TimerService"))

local GhostService = {}

-- userId -> { openedAt: number, bestTime: number } while a submit window is open.
local pendingBest: { [number]: { openedAt: number, bestTime: number } } = {}

-- Returns a validated Ghost, or nil if the payload is malformed.
local function sanitize(data: unknown, expectedTime: number): DataService.Ghost?
	if typeof(data) ~= "table" then
		return nil
	end
	local t = (data :: any).samples
	if typeof(t) ~= "table" then
		return nil
	end

	local arrays: { [string]: { number } } = {}
	local length: number? = nil
	for _, field in { "t", "x", "y", "z", "ry" } do
		local arr = t[field]
		if typeof(arr) ~= "table" then
			return nil
		end
		local n = #arr
		if n == 0 or n > Config.GHOST_MAX_SAMPLES then
			return nil
		end
		if length == nil then
			length = n
		elseif n ~= length then
			return nil
		end
		for i = 1, n do
			local v = arr[i]
			if typeof(v) ~= "number" or v ~= v or math.abs(v) > 1e6 then
				return nil
			end
		end
		arrays[field] = table.create(n)
		table.move(arr, 1, n, 1, arrays[field])
	end

	return {
		time = expectedTime,
		samples = {
			t = arrays.t,
			x = arrays.x,
			y = arrays.y,
			z = arrays.z,
			ry = arrays.ry,
		},
	}
end

local function handleAction(player: Player, action: unknown, data: unknown)
	if action == "get" then
		return DataService.loadGhost(player.UserId)
	end

	if action == "submit" then
		local window = pendingBest[player.UserId]
		if not window or os.clock() - window.openedAt > Config.GHOST_SUBMIT_WINDOW then
			return false
		end

		local ghost = sanitize(data, window.bestTime)
		if not ghost then
			return false
		end

		pendingBest[player.UserId] = nil
		local userId = player.UserId
		task.spawn(function()
			DataService.saveGhost(userId, ghost)
		end)
		return true
	end

	return nil
end

function GhostService.start()
	-- A new personal best opens the submit window for that exact time.
	TimerService.addBestListener(function(player, seconds)
		pendingBest[player.UserId] = { openedAt = os.clock(), bestTime = seconds }
	end)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local ghostAction = Instance.new("RemoteFunction")
	ghostAction.Name = "GhostAction"
	ghostAction.Parent = remotes
	ghostAction.OnServerInvoke = handleAction

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		pendingBest[player.UserId] = nil
	end)
end

return GhostService
