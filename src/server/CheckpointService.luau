--!strict
-- CheckpointService.luau
-- Owns player progression: leaderstats, checkpoint tracking, respawn-at-checkpoint,
-- lava resets, and finish handling. Uses Roblox's standard `leaderstats` pattern so
-- the Stage value shows up on the in-game leaderboard automatically.

local Players = game:GetService("Players")

local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))

local CheckpointService = {}

-- Per-player highest reached stage, keyed by UserId. Stage 0 == spawn.
local playerStage: { [number]: number } = {}
local course: CourseBuilder.Course? = nil

-- Debounce so a single Touched isn't processed dozens of times per contact.
local finishDebounce: { [number]: boolean } = {}

local function getHumanoid(part: Instance): (Humanoid?, Player?)
	local character = part.Parent
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	return humanoid, player
end

local function setStage(player: Player, stage: number)
	if stage <= (playerStage[player.UserId] or 0) then
		return
	end
	playerStage[player.UserId] = stage

	local leaderstats = player:FindFirstChild("leaderstats")
	local stageValue = leaderstats and leaderstats:FindFirstChild("Stage")
	if stageValue and stageValue:IsA("IntValue") then
		stageValue.Value = stage
	end
end

-- Teleport a freshly spawned character to the player's current checkpoint.
local function teleportToCheckpoint(player: Player, character: Model)
	if not course then
		return
	end
	local stage = playerStage[player.UserId] or 0

	local target: BasePart?
	if stage <= 0 then
		target = course.spawn
	else
		target = course.checkpoints[stage]
	end
	if not target then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- +4 studs so we drop onto the pad rather than clipping into it.
		root.CFrame = CFrame.new(target.Position + Vector3.new(0, 4, 0))
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- Wait for the root part before teleporting.
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if root then
		teleportToCheckpoint(player, character)
	end
end

local function onPlayerAdded(player: Player)
	playerStage[player.UserId] = 0

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local stageValue = Instance.new("IntValue")
	stageValue.Name = "Stage"
	stageValue.Value = 0
	stageValue.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = leaderstats

	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	playerStage[player.UserId] = nil
	finishDebounce[player.UserId] = nil
end

-- Wire the world's Touched events to progression logic.
function CheckpointService.start(builtCourse: CourseBuilder.Course)
	course = builtCourse

	for stage, checkpoint in builtCourse.checkpoints do
		checkpoint.Touched:Connect(function(hit)
			local _, player = getHumanoid(hit)
			if player then
				setStage(player, stage)
			end
		end)
	end

	for _, lavaPart in builtCourse.lava do
		lavaPart.Touched:Connect(function(hit)
			local humanoid = getHumanoid(hit)
			if humanoid then
				humanoid.Health = 0
			end
		end)
	end

	builtCourse.finish.Touched:Connect(function(hit)
		local _, player = getHumanoid(hit)
		if not player then
			return
		end
		if finishDebounce[player.UserId] then
			return
		end
		finishDebounce[player.UserId] = true

		local leaderstats = player:FindFirstChild("leaderstats")
		local wins = leaderstats and leaderstats:FindFirstChild("Wins")
		if wins and wins:IsA("IntValue") then
			wins.Value += 1
		end

		-- Reset the player to the start for another lap.
		playerStage[player.UserId] = 0
		local stageValue = leaderstats and leaderstats:FindFirstChild("Stage")
		if stageValue and stageValue:IsA("IntValue") then
			stageValue.Value = 0
		end
		if player.Character then
			teleportToCheckpoint(player, player.Character)
		end

		task.delay(2, function()
			finishDebounce[player.UserId] = nil
		end)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CheckpointService
