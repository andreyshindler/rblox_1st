--!strict
-- CourseBuilder.luau
-- Procedurally builds the Rainbow Rush obby into Workspace at server startup.
-- Building in code (rather than by hand in Studio) means the game is playable
-- the moment Rojo syncs and you press Play.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CourseBuilder = {}

-- Result of build(): the objects the CheckpointService needs to wire up.
export type Course = {
	spawn: SpawnLocation,
	checkpoints: { BasePart }, -- index 1 == checkpoint for stage 1, etc.
	lava: { BasePart },
	finish: BasePart,
}

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- Builds the whole course and returns the wiring handles. Idempotent-ish: if an
-- "Obby" folder already exists (e.g. a hot re-sync in Studio) it is cleared first.
function CourseBuilder.build(): Course
	local existing = workspace:FindFirstChild("Obby")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Obby"
	folder.Parent = workspace

	local y = Config.SPAWN_HEIGHT
	local step = Config.PLATFORM_SIZE.X + Config.GAP
	local x = 0

	-- Stage 0: the spawn platform + SpawnLocation.
	local spawnPlatform = makePart("SpawnPlatform", Config.PLATFORM_SIZE, Config.SPAWN_COLOR, folder)
	spawnPlatform.Position = Vector3.new(x, y, 0)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Color = Config.SPAWN_COLOR
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield delay
	spawn.Position = Vector3.new(x, y + 1, 0)
	spawn.Parent = folder

	local checkpoints: { BasePart } = {}
	local lava: { BasePart } = {}

	-- Stages 1..STAGE_COUNT: platform + a lava strip in the gap + a checkpoint pad.
	for stage = 1, Config.STAGE_COUNT do
		x += step

		local platform = makePart(
			"Platform_" .. stage,
			Config.PLATFORM_SIZE,
			Config.stageColor(stage),
			folder
		)
		platform.Position = Vector3.new(x, y, 0)

		-- Lava strip sitting in the gap just before this platform.
		local lavaPart = makePart(
			"Lava_" .. stage,
			Config.LAVA_SIZE,
			Config.LAVA_COLOR,
			folder
		)
		lavaPart.Material = Enum.Material.Neon
		lavaPart.Position = Vector3.new(x - step / 2, y, 0)
		table.insert(lava, lavaPart)

		-- Checkpoint pad at the start of this stage's platform.
		local checkpoint = makePart(
			"Checkpoint_" .. stage,
			Config.CHECKPOINT_SIZE,
			Config.CHECKPOINT_COLOR,
			folder
		)
		checkpoint.Material = Enum.Material.Neon
		checkpoint.Position = Vector3.new(x, y + 1, 0)

		local stageValue = Instance.new("IntValue")
		stageValue.Name = "Stage"
		stageValue.Value = stage
		stageValue.Parent = checkpoint

		checkpoints[stage] = checkpoint
	end

	-- Finish pad after the final stage.
	x += step
	local finishPlatform = makePart("FinishPlatform", Config.PLATFORM_SIZE, Config.FINISH_COLOR, folder)
	finishPlatform.Position = Vector3.new(x, y, 0)

	local finish = makePart("Finish", Vector3.new(8, 2, 8), Config.FINISH_COLOR, folder)
	finish.Material = Enum.Material.Neon
	finish.Position = Vector3.new(x, y + 1.5, 0)

	return {
		spawn = spawn,
		checkpoints = checkpoints,
		lava = lava,
		finish = finish,
	}
end

return CourseBuilder
