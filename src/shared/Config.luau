--!strict
-- Config.luau
-- Shared tunables for Rainbow Rush. Lives in ReplicatedStorage so both the
-- server (course builder / checkpoints) and client (HUD) read the same values.

export type StageColor = { number }

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
}

-- Rainbow gradient for stage platforms. `stageColor(i)` returns a hue-rotated
-- colour so consecutive platforms cycle through the spectrum.
function Config.stageColor(stageIndex: number): Color3
	local hue = (stageIndex / math.max(Config.STAGE_COUNT, 1)) % 1
	return Color3.fromHSV(hue, 0.65, 0.95)
end

return Config
