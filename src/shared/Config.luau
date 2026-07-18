--!strict
-- Config.luau
-- Shared tunables for Rainbow Rush. Lives in ReplicatedStorage so both the
-- server (course builder / checkpoints / hazards) and client (HUD) read the
-- same values.

local Config = {
	-- Number of playable stages (checkpoint 0 is the spawn, so there are
	-- STAGE_COUNT platforms after it, ending in the finish pad).
	STAGE_COUNT = 10,

	-- Geometry (in studs).
	PLATFORM_SIZE = Vector3.new(16, 1, 16),
	CHECKPOINT_SIZE = Vector3.new(6, 1, 6),
	LAVA_SIZE = Vector3.new(4, 1, 16), -- thin strip that sits in the open gap
	GAP = 8, -- open air between one platform's edge and the next (comfortably jumpable)
	SPAWN_HEIGHT = 20, -- Y position of the course floor

	-- Colours.
	LAVA_COLOR = Color3.fromRGB(200, 40, 20),
	CHECKPOINT_COLOR = Color3.fromRGB(255, 255, 255),
	SPAWN_COLOR = Color3.fromRGB(120, 200, 120),
	FINISH_COLOR = Color3.fromRGB(255, 215, 0),

	-- Moving platforms slide sideways (along Z) so the jump becomes a timing
	-- challenge. AMPLITUDE is the distance travelled to each side of centre.
	MOVE_AMPLITUDE = 8,
	MOVE_TIME = 2.5, -- seconds for one one-way sweep

	-- Disappearing platforms fade out shortly after a player steps on, then return.
	DISAPPEAR_DELAY = 0.6, -- grace period after first touch before it goes
	DISAPPEAR_DURATION = 2.0, -- how long it stays gone before returning

	-- Skip-stage gamepass. Create a gamepass on your game and put its id here.
	-- While it is 0 the button still works in Studio (see ALLOW_SKIP_IN_STUDIO)
	-- so you can test; in a live game a 0 id simply does nothing.
	SKIP_STAGE_GAMEPASS_ID = 0,
	ALLOW_SKIP_IN_STUDIO = true,
}

-- Rainbow gradient for stage platforms. `stageColor(i)` returns a hue-rotated
-- colour so consecutive platforms cycle through the spectrum.
function Config.stageColor(stageIndex: number): Color3
	local hue = (stageIndex / math.max(Config.STAGE_COUNT, 1)) % 1
	return Color3.fromHSV(hue, 0.65, 0.95)
end

-- Decides what kind of platform a stage gets. Returns "static", "moving" or
-- "disappearing". The mix is deterministic so the course is the same every build.
function Config.platformKind(stage: number): string
	if stage % 4 == 0 then
		return "disappearing"
	elseif stage % 3 == 0 then
		return "moving"
	end
	return "static"
end

return Config
