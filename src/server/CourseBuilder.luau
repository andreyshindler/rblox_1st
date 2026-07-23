--!strict
-- CourseBuilder.luau
-- Procedurally builds the Rainbow Rush obby into Workspace at server startup.
-- Building in code (rather than by hand in Studio) means the game is playable
-- the moment Rojo syncs and you press Play.
--
-- The course is split into themed zones (Config.ZONES); each stage's platform
-- kind, palette, material and friction come from its zone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CourseBuilder = {}

-- A moving platform carries its checkpoint marker so HazardService can keep the
-- two together as the platform slides.
export type MovingEntry = { platform: BasePart, checkpoint: BasePart }

-- A spinner is a kill-bar rotating about its platform's centre.
export type SpinnerEntry = { bar: BasePart, center: Vector3 }

-- Result of build(): everything the other services need to wire up.
export type Course = {
	spawn: SpawnLocation,
	checkpoints: { BasePart }, -- index 1 == checkpoint for stage 1, etc.
	lava: { BasePart }, -- everything here kills on touch (lava strips + spinner bars)
	finish: BasePart,
	movingPlatforms: { MovingEntry },
	disappearingPlatforms: { BasePart },
	spinners: { SpinnerEntry },
	conveyors: { BasePart },
	jumpPads: { BasePart },
	platforms: { BasePart }, -- stage index -> platform (for coin placement etc.)
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

-- Floating billboard naming each zone, hovering over its first platform.
local function makeZoneSign(zoneName: string, position: Vector3, color: Color3, parent: Instance)
	local anchor = Instance.new("Part")
	anchor.Name = "ZoneSign_" .. zoneName
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Position = position
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 300, 0, 60)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = zoneName
	label.Parent = billboard
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
	local movingPlatforms: { MovingEntry } = {}
	local disappearingPlatforms: { BasePart } = {}
	local spinners: { SpinnerEntry } = {}
	local conveyors: { BasePart } = {}
	local jumpPads: { BasePart } = {}
	local platforms: { BasePart } = {}

	local previousPlatform: BasePart = spawnPlatform

	-- Stages 1..STAGE_COUNT: platform + a lava strip in the gap + a checkpoint pad.
	for stage = 1, Config.STAGE_COUNT do
		local zone, posInZone = Config.zoneFor(stage)
		local kind = Config.platformKind(stage)

		-- Jump-pad stages sit across an extra-wide gap; everything else uses the
		-- standard hop distance.
		local gap = Config.GAP * (kind == "jumppad" and Config.JUMPPAD_GAP_MULT or 1)
		local step = Config.PLATFORM_SIZE.X + gap
		x += step

		local platform = makePart(
			"Platform_" .. stage,
			Config.PLATFORM_SIZE,
			Config.stageColor(stage),
			folder
		)
		platform.Position = Vector3.new(x, y, 0)
		platform.Material = zone.material
		platform:SetAttribute("Kind", kind)
		platform:SetAttribute("Zone", zone.name)
		if zone.friction then
			platform.CustomPhysicalProperties = PhysicalProperties.new(0.7, zone.friction, 0, 100, 1)
		end
		platforms[stage] = platform

		if posInZone == 1 then
			makeZoneSign(zone.name, platform.Position + Vector3.new(0, 12, 0), Config.stageColor(stage), folder)
		end

		-- Kind-specific dressing.
		if kind == "moving" then
			platform.Material = Enum.Material.Metal
		elseif kind == "disappearing" then
			platform.Material = Enum.Material.Ice
			platform.Transparency = 0.15
		elseif kind == "spinner" then
			-- A kill-bar sweeping over the platform; HazardService rotates it and
			-- it joins the lava list so the standard kill wiring applies.
			local bar = makePart(
				"SpinnerBar_" .. stage,
				Vector3.new(Config.PLATFORM_SIZE.X * 1.1, 1, 1.5),
				Config.LAVA_COLOR,
				folder
			)
			bar.Material = Enum.Material.Neon
			bar.CanCollide = false
			bar.Position = platform.Position + Vector3.new(0, Config.SPINNER_HEIGHT, 0)
			table.insert(spinners, { bar = bar, center = bar.Position })
			table.insert(lava, bar)
		elseif kind == "conveyor" then
			platform.Material = Enum.Material.DiamondPlate
			platform.Color = Color3.fromRGB(70, 70, 80)
			table.insert(conveyors, platform)
		elseif kind == "jumppad" then
			-- The launcher sits on the far edge of the PREVIOUS platform, aimed
			-- across the wide gap at this stage.
			local pad = makePart("JumpPad_" .. stage, Vector3.new(6, 0.6, 6), Color3.fromRGB(80, 255, 120), folder)
			pad.Material = Enum.Material.Neon
			pad.Position = previousPlatform.Position
				+ Vector3.new(Config.PLATFORM_SIZE.X / 2 - 3, 0.8, 0)
			-- Tagged so the CLIENT can wire the launch (the character is
			-- client-owned; a server-side velocity write would be overridden).
			CollectionService:AddTag(pad, "JumpPad")
			table.insert(jumpPads, pad)
		end

		-- Lava strip sitting in the open gap just before this platform (wider for
		-- jump-pad gaps so the whole crossing is lethal to fall into).
		local lavaSize = Config.LAVA_SIZE
		if kind == "jumppad" then
			lavaSize = Vector3.new(gap * 0.8, 1, Config.LAVA_SIZE.Z)
		end
		local lavaPart = makePart("Lava_" .. stage, lavaSize, Config.LAVA_COLOR, folder)
		lavaPart.Material = Enum.Material.Neon
		-- Centre of the gap: half a platform plus half the gap behind this platform's centre.
		lavaPart.Position = Vector3.new(x - (Config.PLATFORM_SIZE.X + gap) / 2, y, 0)
		table.insert(lava, lavaPart)

		-- Checkpoint pad at the start of this stage's platform. It is a
		-- non-colliding trigger: players pass through it (it still fires Touched)
		-- rather than standing on it, so disappearing platforms stay fair.
		local checkpoint = makePart(
			"Checkpoint_" .. stage,
			Config.CHECKPOINT_SIZE,
			Config.CHECKPOINT_COLOR,
			folder
		)
		checkpoint.Material = Enum.Material.Neon
		checkpoint.CanCollide = false
		checkpoint.Position = Vector3.new(x, y + 1, 0)

		local stageValue = Instance.new("IntValue")
		stageValue.Name = "Stage"
		stageValue.Value = stage
		stageValue.Parent = checkpoint

		checkpoints[stage] = checkpoint

		-- Register animated kinds now that both platform and checkpoint exist.
		if kind == "moving" then
			table.insert(movingPlatforms, { platform = platform, checkpoint = checkpoint })
		elseif kind == "disappearing" then
			table.insert(disappearingPlatforms, platform)
		end

		previousPlatform = platform
	end

	-- Finish pad after the final stage.
	x += Config.PLATFORM_SIZE.X + Config.GAP
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
		movingPlatforms = movingPlatforms,
		disappearingPlatforms = disappearingPlatforms,
		spinners = spinners,
		conveyors = conveyors,
		jumpPads = jumpPads,
		platforms = platforms,
	}
end

return CourseBuilder
