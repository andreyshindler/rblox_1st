--!strict
-- HazardService.luau
-- Animates the course hazards: moving platforms slide side to side (TweenService),
-- disappearing platforms fade out shortly after a player steps on them, spinner
-- kill-bars sweep over their platforms, conveyors push players backward, and jump
-- pads launch players across wide gaps.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))

local HazardService = {}

-- Slide the platform from -amplitude to +amplitude along Z, reversing forever.
-- The checkpoint marker rides along by tracking the platform each frame.
local function setupMoving(entry: CourseBuilder.MovingEntry)
	local platform = entry.platform
	local checkpoint = entry.checkpoint

	local base = platform.Position
	local offset = checkpoint.Position - base
	local swing = Vector3.new(0, 0, Config.MOVE_AMPLITUDE)

	-- Start at one extreme, then tween to the other with an auto-reversing loop.
	platform.Position = base - swing
	checkpoint.Position = platform.Position + offset

	RunService.Heartbeat:Connect(function()
		checkpoint.Position = platform.Position + offset
	end)

	local info = TweenInfo.new(
		Config.MOVE_TIME,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- repeat forever
		true -- reverse each cycle
	)
	TweenService:Create(platform, info, { Position = base + swing }):Play()
end

-- Fade the platform out DISAPPEAR_DELAY seconds after a player first touches it,
-- keep it gone for DISAPPEAR_DURATION, then restore. A cooldown prevents overlap.
local function setupDisappearing(platform: BasePart)
	local originalTransparency = platform.Transparency
	local cooldown = false

	platform.Touched:Connect(function(hit)
		if cooldown then
			return
		end
		local character = hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		cooldown = true

		task.delay(Config.DISAPPEAR_DELAY, function()
			platform.CanCollide = false
			platform.Transparency = 0.8

			task.delay(Config.DISAPPEAR_DURATION, function()
				platform.CanCollide = true
				platform.Transparency = originalTransparency
				cooldown = false
			end)
		end)
	end)
end

-- Sweep the kill-bar around its platform's centre. The bar is already in the
-- course's lava list, so touching it kills via the standard wiring.
local function setupSpinner(entry: CourseBuilder.SpinnerEntry)
	local bar = entry.bar
	local pivot = CFrame.new(entry.center)
	local angle = 0

	RunService.Heartbeat:Connect(function(dt)
		angle += Config.SPINNER_SPEED * dt
		bar.CFrame = pivot * CFrame.Angles(0, angle, 0)
	end)
end

-- An anchored part with surface velocity acts as a conveyor belt: it pushes
-- whatever stands on it without moving itself. Pushing along -X works against
-- the direction of travel.
local function setupConveyor(platform: BasePart)
	platform.AssemblyLinearVelocity = Vector3.new(-Config.CONVEYOR_SPEED, 0, 0)
end

-- Launch characters up and forward across the wide gap. A short per-character
-- debounce stops one landing from re-triggering the pad repeatedly.
local function setupJumpPad(pad: BasePart)
	local recentlyLaunched: { [Model]: boolean } = {}

	pad.Touched:Connect(function(hit)
		local character = hit.Parent :: Model?
		if not character or recentlyLaunched[character] then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") then
			return
		end
		recentlyLaunched[character] = true

		root.AssemblyLinearVelocity = Config.JUMP_PAD_VELOCITY

		task.delay(1, function()
			recentlyLaunched[character] = nil
		end)
	end)
end

function HazardService.start(course: CourseBuilder.Course)
	for _, entry in course.movingPlatforms do
		setupMoving(entry)
	end
	for _, platform in course.disappearingPlatforms do
		setupDisappearing(platform)
	end
	for _, entry in course.spinners do
		setupSpinner(entry)
	end
	for _, platform in course.conveyors do
		setupConveyor(platform)
	end
	for _, pad in course.jumpPads do
		setupJumpPad(pad)
	end
end

return HazardService
