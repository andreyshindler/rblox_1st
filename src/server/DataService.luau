--!strict
-- DataService.luau
-- Thin, failure-tolerant wrapper around DataStoreService for best-time persistence.
--
-- * A regular DataStore holds each player's own best time (exact seconds).
-- * An OrderedDataStore holds best times as integer milliseconds so they can be
--   ranked for the global board (ascending = fastest first).
--
-- Every call is wrapped in pcall. If the DataStore API is unavailable (e.g. an
-- unpublished place, or Studio without API access) persistence turns itself off
-- and every method degrades to a safe no-op / empty result.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DataService = {}

export type Entry = { name: string, seconds: number }

local enabled = Config.USE_DATASTORE == true
local bestStore: DataStore? = nil
local globalStore: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}

if enabled then
	local ok = pcall(function()
		bestStore = DataStoreService:GetDataStore(Config.BEST_STORE_NAME)
		globalStore = DataStoreService:GetOrderedDataStore(Config.GLOBAL_STORE_NAME)
	end)
	if not ok then
		enabled = false
		warn("[Rainbow Rush] DataStore unavailable — best times will not persist this session.")
	end
end

local function key(userId: number): string
	return "u_" .. userId
end

function DataService.isEnabled(): boolean
	return enabled
end

-- Returns the player's saved best time in seconds, or nil if none / unavailable.
function DataService.loadBest(userId: number): number?
	if not enabled or not bestStore then
		return nil
	end
	local ok, result = pcall(function()
		return (bestStore :: DataStore):GetAsync(key(userId))
	end)
	if ok and typeof(result) == "number" then
		return result
	end
	return nil
end

-- Persists the player's best time to both the per-player store and the global
-- ranking store. Fire-and-forget; safe to call from a spawned thread.
function DataService.saveBest(userId: number, seconds: number)
	if not enabled then
		return
	end
	if bestStore then
		pcall(function()
			(bestStore :: DataStore):SetAsync(key(userId), seconds)
		end)
	end
	if globalStore then
		pcall(function()
			-- OrderedDataStore only stores integers; use milliseconds.
			(globalStore :: OrderedDataStore):SetAsync(key(userId), math.floor(seconds * 1000 + 0.5))
		end)
	end
end

-- Best-effort username lookup for board rows: online players first, then a
-- cached web lookup.
local function resolveName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.Name
		return online.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return "Player " .. userId
end

-- Returns up to `count` fastest times, ascending. Empty when unavailable.
function DataService.getTopTimes(count: number): { Entry }
	local entries: { Entry } = {}
	if not enabled or not globalStore then
		return entries
	end
	local ok, pages = pcall(function()
		return (globalStore :: OrderedDataStore):GetSortedAsync(true, count)
	end)
	if not ok or not pages then
		return entries
	end
	local page = pages:GetCurrentPage()
	for _, item in page do
		local userId = tonumber(string.match(item.key, "%d+"))
		local ms = item.value
		if userId and typeof(ms) == "number" then
			table.insert(entries, {
				name = resolveName(userId),
				seconds = ms / 1000,
			})
		end
	end
	return entries
end

return DataService
