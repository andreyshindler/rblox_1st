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

-- A player's persistent record. `owned` is a list of ShopItems ids;
-- `lastDailyClaim` is a unix day number (os.time() // 86400), 0 = never claimed.
export type Profile = {
	coins: number,
	owned: { string },
	equipped: string?,
	wins: number,
	rebirths: number,
	winsSinceRebirth: number,
	dailyStreak: number,
	lastDailyClaim: number,
}

-- A recorded best run: parallel sample arrays (time, position, yaw), kept flat
-- and rounded client-side for compact JSON.
export type Ghost = {
	time: number,
	samples: { t: { number }, x: { number }, y: { number }, z: { number }, ry: { number } },
}

local enabled = Config.USE_DATASTORE == true
local bestStore: DataStore? = nil
local globalStore: OrderedDataStore? = nil
local profileStore: DataStore? = nil
local ghostStore: DataStore? = nil
local nameCache: { [number]: string } = {}

if enabled then
	local ok = pcall(function()
		bestStore = DataStoreService:GetDataStore(Config.BEST_STORE_NAME)
		globalStore = DataStoreService:GetOrderedDataStore(Config.GLOBAL_STORE_NAME)
		profileStore = DataStoreService:GetDataStore(Config.PROFILE_STORE_NAME)
		ghostStore = DataStoreService:GetDataStore(Config.GHOST_STORE_NAME)
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

-- ---------------------------------------------------------------------------
-- Profiles (coins / owned trails / equipped trail)
--
-- The in-memory cache is authoritative while the player is online; writes are
-- debounced, and flushed on leave and on server shutdown. UpdateAsync is used
-- for the write so a stale in-flight value from another server never clobbers
-- a richer record (highest coins + union of owned wins).

local profiles: { [number]: Profile } = {}
local dirty: { [number]: boolean } = {}
local lastSave: { [number]: number } = {}

local function defaultProfile(): Profile
	return {
		coins = 0,
		owned = {},
		equipped = nil,
		wins = 0,
		rebirths = 0,
		winsSinceRebirth = 0,
		dailyStreak = 0,
		lastDailyClaim = 0,
	}
end

-- Best-of-both merge for cross-server races: counters take the max, owned is the
-- union, and current-session state (equipped, streak, winsSinceRebirth) trusts
-- the newer record. lastDailyClaim takes the max so a reward is never claimable
-- twice on the same day.
local function mergeProfiles(old: Profile?, new: Profile): Profile
	if not old then
		return new
	end
	local ownedSet: { [string]: boolean } = {}
	local owned: { string } = {}
	for _, list in { old.owned, new.owned } do
		for _, id in list do
			if not ownedSet[id] then
				ownedSet[id] = true
				table.insert(owned, id)
			end
		end
	end
	return {
		coins = math.max(old.coins, new.coins),
		owned = owned,
		equipped = new.equipped,
		wins = math.max(old.wins or 0, new.wins),
		rebirths = math.max(old.rebirths or 0, new.rebirths),
		winsSinceRebirth = new.winsSinceRebirth,
		dailyStreak = new.dailyStreak,
		lastDailyClaim = math.max(old.lastDailyClaim or 0, new.lastDailyClaim),
	}
end

local function writeProfile(userId: number)
	local profile = profiles[userId]
	if not enabled or not profileStore or not profile then
		return
	end
	lastSave[userId] = os.clock()
	dirty[userId] = nil
	pcall(function()
		(profileStore :: DataStore):UpdateAsync(key(userId), function(old)
			return mergeProfiles(old :: Profile?, profile)
		end)
	end)
end

-- In-flight guard so concurrent loadProfile calls (several services load on
-- join) result in exactly one GetAsync and share the same cached table.
local loadingProfiles: { [number]: boolean } = {}

-- Loads (or initialises) the player's profile into the cache. Yields; call from
-- a spawned thread on join. Returns the cached profile.
function DataService.loadProfile(userId: number): Profile
	while loadingProfiles[userId] do
		task.wait()
	end
	if profiles[userId] then
		return profiles[userId]
	end
	loadingProfiles[userId] = true

	local loaded: Profile? = nil
	if enabled and profileStore then
		local ok, result = pcall(function()
			return (profileStore :: DataStore):GetAsync(key(userId))
		end)
		if ok and typeof(result) == "table" then
			local t = result :: any
			loaded = {
				coins = typeof(t.coins) == "number" and t.coins or 0,
				owned = typeof(t.owned) == "table" and t.owned or {},
				equipped = typeof(t.equipped) == "string" and t.equipped or nil,
				wins = typeof(t.wins) == "number" and t.wins or 0,
				rebirths = typeof(t.rebirths) == "number" and t.rebirths or 0,
				winsSinceRebirth = typeof(t.winsSinceRebirth) == "number" and t.winsSinceRebirth or 0,
				dailyStreak = typeof(t.dailyStreak) == "number" and t.dailyStreak or 0,
				lastDailyClaim = typeof(t.lastDailyClaim) == "number" and t.lastDailyClaim or 0,
			}
		end
	end
	profiles[userId] = loaded or defaultProfile()
	loadingProfiles[userId] = nil
	return profiles[userId]
end

-- The cached profile, or nil if not loaded yet.
function DataService.getProfile(userId: number): Profile?
	return profiles[userId]
end

-- Mark the profile changed; it is written after a debounce window (or on leave).
function DataService.markProfileDirty(userId: number)
	if not profiles[userId] then
		return
	end
	dirty[userId] = true
	local since = os.clock() - (lastSave[userId] or 0)
	local wait = math.max(Config.PROFILE_SAVE_DEBOUNCE - since, 0)
	task.delay(wait, function()
		if dirty[userId] then
			writeProfile(userId)
		end
	end)
end

-- Flush and drop the profile when the player leaves.
function DataService.releaseProfile(userId: number)
	if dirty[userId] then
		writeProfile(userId)
	end
	profiles[userId] = nil
	dirty[userId] = nil
	lastSave[userId] = nil
end

game:BindToClose(function()
	for userId in profiles do
		writeProfile(userId)
	end
end)

-- ---------------------------------------------------------------------------
-- Ghost replays (best-run recordings)

-- Session cache; false marks "checked the store, nothing there" so repeated
-- requests from the client don't re-hit the DataStore.
local ghosts: { [number]: Ghost | false } = {}

-- Returns the player's stored best-run recording, or nil. Yields on first call.
function DataService.loadGhost(userId: number): Ghost?
	local cached = ghosts[userId]
	if cached ~= nil then
		return cached or nil
	end
	local loaded: Ghost? = nil
	if enabled and ghostStore then
		local ok, result = pcall(function()
			return (ghostStore :: DataStore):GetAsync(key(userId))
		end)
		if ok and typeof(result) == "table" then
			local t = result :: any
			if typeof(t.time) == "number" and typeof(t.samples) == "table" then
				loaded = t :: Ghost
			end
		end
	end
	ghosts[userId] = loaded or false
	return loaded
end

-- Persists a new best-run recording (already validated by GhostService) and
-- updates the session cache. Fire-and-forget; safe from a spawned thread.
function DataService.saveGhost(userId: number, ghost: Ghost)
	ghosts[userId] = ghost
	if not enabled or not ghostStore then
		return
	end
	pcall(function()
		(ghostStore :: DataStore):SetAsync(key(userId), ghost)
	end)
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
