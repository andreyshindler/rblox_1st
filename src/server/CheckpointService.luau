--!strict
-- CheckpointService.luau
-- Owns player progression: leaderstats, checkpoint tracking, respawn-at-checkpoint,
-- lava resets, and finish handling. Uses Roblox's standard `leaderstats` pattern so
-- Stage / Wins / Best show up on the in-game leaderboard automatically. Delegates
-- run timing to TimerService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))
local TimerService = require(script.Parent:WaitForChild("TimerService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local DataService = require(script.Parent:WaitForChild("DataService"))

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

local function setLeaderstat(player: Player, name: string, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then
		stat.Value = value
	end
end

local function setStage(player: Player, stage: number)
	if stage <= (playerStage[player.UserId] or 0) then
		return
	end
	playerStage[player.UserId] = stage
	setLeaderstat(player, "Stage", stage)

	-- A run is timed from clearing the first checkpoint to the finish. Starting
	-- here (rather than at spawn) means the clock only runs once the player is
	-- actually on the course, and each new lap re-arms cleanly.
	if stage == 1 and not player:GetAttribute("RunActive") then
		TimerService.startRun(player)
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

	-- Best completion time in seconds (0 == no time set yet).
	local best = Instance.new("NumberValue")
	best.Name = "Best"
	best.Value = 0
	best.Parent = leaderstats

	leaderstats.Parent = player

	-- Pull the player's persisted best time onto the leaderboard.
	TimerService.loadPlayer(player)

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
	TimerService.clear(player)
	DataService.releaseProfile(player.UserId)
end

-- Public: the player's current stage.
function CheckpointService.getStage(player: Player): number
	return playerStage[player.UserId] or 0
end

-- Public: bump the player forward one stage and teleport them there. Used by the
-- skip-stage gamepass. No-op once they are already at the final stage.
function CheckpointService.advanceStage(player: Player)
	local current = playerStage[player.UserId] or 0
	local target = math.min(current + 1, Config.STAGE_COUNT)
	if target == current then
		return
	end
	playerStage[player.UserId] = target
	setLeaderstat(player, "Stage", target)
	if player.Character then
		teleportToCheckpoint(player, player.Character)
	end
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

		-- Stop the clock, record the time / best, and pay the finish bonus.
		local elapsed = TimerService.finishRun(player)
		CoinService.awardFinishBonus(player, elapsed)

		local leaderstats = player:FindFirstChild("leaderstats")
		local wins = leaderstats and leaderstats:FindFirstChild("Wins")
		if wins and wins:IsA("IntValue") then
			wins.Value += 1
		end

		-- Reset the player to the start for another lap. The finish time stays on
		-- the HUD until they clear the first checkpoint again, which re-arms the clock.
		playerStage[player.UserId] = 0
		setLeaderstat(player, "Stage", 0)
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
