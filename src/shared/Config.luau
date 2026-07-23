--!strict
-- Config.luau
-- Shared tunables for Rainbow Rush. Lives in ReplicatedStorage so both the
-- server (course builder / checkpoints / hazards) and client (HUD) read the
-- same values.

export type Zone = {
	name: string,
	hueMin: number, -- platform colour range (HSV hue, 0..1)
	hueMax: number,
	saturation: number,
	value: number,
	material: Enum.Material,
	friction: number?, -- nil = default physics; Ice sets a low value
	-- Eight platform kinds, one per stage in the zone, in order. Kinds:
	-- "static" | "moving" | "disappearing" | "spinner" | "conveyor" | "jumppad"
	pattern: { string },
}

local Config = {
	-- Stages are grouped into themed zones of ZONE_SIZE; STAGE_COUNT must equal
	-- ZONE_SIZE * #ZONES (checkpoint 0 is the spawn platform before stage 1).
	STAGE_COUNT = 24,
	ZONE_SIZE = 8,

	-- Geometry (in studs).
	PLATFORM_SIZE = Vector3.new(16, 1, 16),
	CHECKPOINT_SIZE = Vector3.new(6, 1, 6),
	LAVA_SIZE = Vector3.new(4, 1, 16), -- thin strip that sits in the open gap
	GAP = 8, -- open air between one platform's edge and the next (comfortably jumpable)
	SPAWN_HEIGHT = 20, -- Y position of the course floor

	-- Colours.
	LAVA_COLOR = Color3.fromRGB(200, 40, 20),
	CHECKPOINT_COLOR = Color3.fromRGB(255, 255, 255),
	SPAWN_COLOR = Color3.fromRGB(90, 185, 105),
	FINISH_COLOR = Color3.fromRGB(255, 215, 0),

	-- Moving platforms slide sideways (along Z) so the jump becomes a timing
	-- challenge. AMPLITUDE is the distance travelled to each side of centre.
	MOVE_AMPLITUDE = 8,
	MOVE_TIME = 2.5, -- seconds for one one-way sweep

	-- Disappearing platforms fade out shortly after a player steps on, then return.
	DISAPPEAR_DELAY = 0.6, -- grace period after first touch before it goes
	DISAPPEAR_DURATION = 2.0, -- how long it stays gone before returning

	-- Spinner: a kill-bar sweeping over the platform.
	SPINNER_SPEED = math.rad(90), -- radians per second
	SPINNER_HEIGHT = 2.5, -- bar centre height above the platform top

	-- Conveyor: anchored platform with surface velocity pushing against travel.
	CONVEYOR_SPEED = 12, -- studs/second, pushing back toward the start

	-- Jump pad: launches the player over an extra-wide gap. At gravity 196.2 the
	-- flight time is 2*65/196.2 ≈ 0.66s, so 48 forward ≈ 32 studs — landing in
	-- the middle of the far platform (which spans ~23–39 studs from the pad).
	JUMP_PAD_VELOCITY = Vector3.new(48, 65, 0), -- forward (+X) and up impulse
	JUMPPAD_GAP_MULT = 2.5, -- the gap before a jumppad stage is this many GAPs wide

	-- Skip-stage gamepass. In Studio the button also works without ownership
	-- (see ALLOW_SKIP_IN_STUDIO) so it stays easy to test.
	SKIP_STAGE_GAMEPASS_ID = 1918256892,
	ALLOW_SKIP_IN_STUDIO = true,

	-- Best-time persistence. When enabled, each player's best time is saved to a
	-- DataStore (loaded on join) and submitted to an OrderedDataStore that powers
	-- the global best-time board. Requires a published game, or Studio with
	-- "Enable Studio Access to API Services" ticked — if the API is unavailable,
	-- persistence quietly turns itself off and the game still runs.
	USE_DATASTORE = true,
	BEST_STORE_NAME = "RainbowRushBest_v1",
	GLOBAL_STORE_NAME = "RainbowRushGlobal_v1",
	PROFILE_STORE_NAME = "RainbowRushProfile_v1", -- coins, owned trails, equipped trail

	-- Coin economy. Each stage scatters COINS_PER_STAGE pickups; a coin's value
	-- is its zone number (Meadow 1, Ice 2, Volcano 3). Collected coins respawn
	-- after COIN_RESPAWN seconds. Finishing pays FINISH_BONUS plus a speed bonus
	-- of up to SPEED_BONUS_MAX for runs faster than SPEED_BONUS_PAR seconds.
	COINS_PER_STAGE = 2,
	COIN_RESPAWN = 45,
	FINISH_BONUS = 25,
	SPEED_BONUS_MAX = 50,
	SPEED_BONUS_PAR = 180,
	PROFILE_SAVE_DEBOUNCE = 15, -- seconds between debounced profile writes

	-- Global best-time board (physical sign near spawn).
	GLOBAL_BOARD_SIZE = 10, -- how many top times to show
	BOARD_REFRESH = 45, -- seconds between automatic board refreshes

	-- Sound effects. The defaults are Roblox built-ins (rbxasset://) that are
	-- guaranteed to exist; swap any of them for catalogue ids
	-- ("rbxassetid://<number>") for a richer soundscape.
	SOUNDS = {
		checkpoint = "rbxasset://sounds/electronicpingshort.wav",
		coin = "rbxasset://sounds/snap.mp3",
		death = "rbxasset://sounds/splat.mp3",
		finish = "rbxasset://sounds/victory.wav",
	},
	-- Background music: per-zone tracks with a client-side crossfade as the
	-- player progresses. Paste free-to-use audio ids from the Creator Store
	-- (Toolbox → Marketplace → Audio → Music, filter Free — Monstercat/NCS
	-- tracks are licensed for Roblox use). 0 = silent; DEFAULT plays wherever a
	-- zone has no track of its own.
	MUSIC = {
		DEFAULT = 0,
		Meadow = 0,
		Ice = 0,
		Volcano = 0,
	},
	MUSIC_VOLUME = 0.3,
	MUSIC_CROSSFADE = 1.5, -- seconds to fade between zone tracks

	-- Rebirth: after finishing at least one run since the last rebirth, players
	-- can rebirth — progress resets, they gain a rank and a permanent coin
	-- multiplier of REBIRTH_MULT per rebirth (0.25 = +25% each).
	REBIRTH_MULT = 0.25,

	-- Daily rewards: coins for consecutive daily logins; the streak caps at the
	-- table's last entry. Reaching day DAILY_TRAIL_DAY also grants the
	-- DAILY_STREAK_TRAIL cosmetic if not already owned.
	DAILY_REWARDS = { 20, 30, 45, 60, 80, 100, 150 },
	DAILY_TRAIL_DAY = 7,
	DAILY_STREAK_TRAIL = "rainbow",

	-- Roblox badges. Create badges for the experience on the Creator Dashboard
	-- and paste their ids here; 0 disables a badge. Awarding is pcall-guarded so
	-- unset/invalid ids can never break gameplay.
	BADGE_IDS = {
		FIRST_WIN = 0, -- finish the course once
		WINS_10 = 0, -- finish the course 10 times
		SPEEDRUNNER = 0, -- finish faster than SPEEDRUN_TIME
		RICH = 0, -- hold RICH_COINS coins at once
		REBORN = 0, -- rebirth for the first time
	},
	SPEEDRUN_TIME = 60, -- seconds; finishing faster earns SPEEDRUNNER
	RICH_COINS = 1000,

	-- Ghost replays: the client records its own best run (position + yaw) and
	-- races a translucent replay of it. Samples are recorded at GHOST_SAMPLE_RATE
	-- per second, capped at GHOST_MAX_SAMPLES (~6.6 minutes at 10 Hz). A new
	-- personal best opens a GHOST_SUBMIT_WINDOW-second window during which the
	-- server accepts the client's recording.
	GHOST_STORE_NAME = "RainbowRushGhost_v1",
	GHOST_SAMPLE_RATE = 10,
	GHOST_MAX_SAMPLES = 4000,
	GHOST_SUBMIT_WINDOW = 30,
}

-- Themed zones, ZONE_SIZE stages each, in course order. Difficulty ramps:
-- Meadow teaches the mechanics, Ice is slippery with vanishing footing, and
-- Volcano combines everything.
Config.ZONES = {
	{
		name = "Meadow",
		hueMin = 0.24,
		hueMax = 0.38,
		saturation = 0.75,
		value = 0.78,
		material = Enum.Material.Grass,
		friction = nil,
		pattern = { "static", "static", "moving", "static", "conveyor", "static", "jumppad", "moving" },
	},
	{
		name = "Ice",
		hueMin = 0.52,
		hueMax = 0.6,
		saturation = 0.5,
		value = 0.88,
		material = Enum.Material.Ice,
		friction = 0.05,
		pattern = { "static", "disappearing", "moving", "disappearing", "conveyor", "jumppad", "disappearing", "spinner" },
	},
	{
		name = "Volcano",
		hueMin = 0.0,
		hueMax = 0.07,
		saturation = 0.85,
		value = 0.55,
		material = Enum.Material.Slate,
		friction = nil,
		pattern = { "spinner", "conveyor", "moving", "spinner", "disappearing", "jumppad", "spinner", "disappearing" },
	},
} :: { Zone }

-- Zone lookup for a 1-based stage number: returns the zone and the 1-based
-- position of the stage within it.
function Config.zoneFor(stage: number): (Zone, number)
	local zoneIndex = math.clamp(math.ceil(stage / Config.ZONE_SIZE), 1, #Config.ZONES)
	local posInZone = stage - (zoneIndex - 1) * Config.ZONE_SIZE
	return Config.ZONES[zoneIndex], posInZone
end

-- Platform colour: a hue swept across the zone's own range, so each zone reads
-- as one palette while platforms within it still vary.
function Config.stageColor(stage: number): Color3
	local zone, pos = Config.zoneFor(stage)
	local t = (pos - 1) / math.max(Config.ZONE_SIZE - 1, 1)
	local hue = zone.hueMin + (zone.hueMax - zone.hueMin) * t
	return Color3.fromHSV(hue, zone.saturation, zone.value)
end

-- What kind of platform a stage gets, from its zone's fixed pattern — fully
-- deterministic so the course is identical every build.
function Config.platformKind(stage: number): string
	local zone, pos = Config.zoneFor(stage)
	return zone.pattern[pos] or "static"
end

-- Format seconds as "12.34s" or "1:05.20". Shared by the client HUD and the
-- server-built global board so both read identically.
function Config.formatTime(t: number): string
	if t <= 0 then
		return "0.00s"
	end
	local minutes = math.floor(t / 60)
	local seconds = t - minutes * 60
	if minutes > 0 then
		return string.format("%d:%05.2f", minutes, seconds)
	end
	return string.format("%.2fs", seconds)
end

return Config
