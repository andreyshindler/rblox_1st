--!strict
-- HazardService.luau
-- Animates the course hazards: moving platforms slide side to side (TweenService)
-- and disappearing platforms fade out shortly after a player steps on them.

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

function HazardService.start(course: CourseBuilder.Course)
	for _, entry in course.movingPlatforms do
		setupMoving(entry)
	end
	for _, platform in course.disappearingPlatforms do
		setupDisappearing(platform)
	end
end

return HazardService
