--!strict
-- Ghost.luau (client)
-- Records the local player's runs and races a translucent replay of their best.
--
-- Recording: while the server-replicated RunActive attribute is true, sample
-- the character's position + yaw at GHOST_SAMPLE_RATE Hz (times relative to
-- RunStartTime). Every completed run is offered to the server; the server only
-- accepts it inside the new-personal-best submit window, so no best-detection
-- logic is needed here.
--
-- Playback: a local-only rig (LocalScript-created parts replicate to no one)
-- follows the recorded samples, keyed to the same server clock the run timer
-- uses, so the ghost is exactly comparable to the live run.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Ghost = {}

local player = Players.LocalPlayer
local ghostAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GhostAction") :: RemoteFunction

type Samples = { t: { number }, x: { number }, y: { number }, z: { number }, ry: { number } }
type GhostData = { time: number, samples: Samples }

local enabled = true
local bestGhost: GhostData? = nil

-- Recording state.
local recording = false
local recorded: Samples? = nil
local sampleAccumulator = 0

-- Playback state.
local rig: BasePart? = nil
local rigLabel: TextLabel? = nil
local playCursor = 1

local function round2(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end

local function runElapsed(): number?
	local startTime = player:GetAttribute("RunStartTime")
	if player:GetAttribute("RunActive") == true and typeof(startTime) == "number" then
		return workspace:GetServerTimeNow() - startTime
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Rig

local function destroyRig()
	if rig then
		rig:Destroy()
		rig = nil
		rigLabel = nil
	end
end

local function ensureRig(): BasePart
	if rig then
		return rig
	end
	local part = Instance.new("Part")
	part.Name = "BestRunGhost"
	part.Size = Vector3.new(2.5, 4.5, 1.5)
	part.Color = Color3.fromRGB(120, 230, 255)
	part.Material = Enum.Material.ForceField
	part.Transparency = 0.35
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	-- Parented to the camera: unambiguous local-only, and cleaned up on respawn
	-- churn by us rather than by server replication.
	part.Parent = workspace.CurrentCamera

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 28)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(120, 230, 255)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.Text = "👻"
	label.Parent = billboard

	rig = part
	rigLabel = label
	return part
end

-- ---------------------------------------------------------------------------
-- Recording

local function startRecording()
	recording = true
	sampleAccumulator = 0
	recorded = { t = {}, x = {}, y = {}, z = {}, ry = {} }
end

local function captureSample()
	local samples = recorded
	local elapsed = runElapsed()
	if not samples or not elapsed then
		return
	end
	if #samples.t >= Config.GHOST_MAX_SAMPLES then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local position = root.Position
	local _, yaw, _ = root.CFrame:ToOrientation()
	table.insert(samples.t, round2(elapsed))
	table.insert(samples.x, round2(position.X))
	table.insert(samples.y, round2(position.Y))
	table.insert(samples.z, round2(position.Z))
	table.insert(samples.ry, round2(yaw))
end

local function stopRecordingAndSubmit()
	recording = false
	local samples = recorded
	recorded = nil
	if not samples or #samples.t < 2 then
		return
	end

	local lastRun = player:GetAttribute("LastRunTime")
	if typeof(lastRun) ~= "number" or lastRun <= 0 then
		return -- run was abandoned, not finished
	end

	-- Offer every completed run; the server only accepts new personal bests.
	task.spawn(function()
		local ok, accepted = pcall(function()
			return ghostAction:InvokeServer("submit", { samples = samples })
		end)
		if ok and accepted == true then
			bestGhost = { time = lastRun, samples = samples }
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Playback

local function stepPlayback()
	local ghost = bestGhost
	local elapsed = enabled and ghost and runElapsed() or nil
	if not ghost or not elapsed then
		destroyRig()
		playCursor = 1
		return
	end

	local t = ghost.samples.t
	local count = #t
	if elapsed > t[count] then
		destroyRig() -- the ghost has finished its run
		return
	end

	-- Advance the cursor to the segment containing `elapsed` (resets each run).
	if playCursor > 1 and t[playCursor] > elapsed then
		playCursor = 1
	end
	while playCursor < count and t[playCursor + 1] <= elapsed do
		playCursor += 1
	end
	local i = playCursor
	local j = math.min(i + 1, count)
	local span = t[j] - t[i]
	local alpha = span > 0 and math.clamp((elapsed - t[i]) / span, 0, 1) or 0

	local s = ghost.samples
	local from = Vector3.new(s.x[i], s.y[i], s.z[i])
	local to = Vector3.new(s.x[j], s.y[j], s.z[j])
	local yaw = s.ry[i] + (s.ry[j] - s.ry[i]) * alpha

	local part = ensureRig()
	part.CFrame = CFrame.new(from:Lerp(to, alpha)) * CFrame.Angles(0, yaw, 0)
	if rigLabel then
		rigLabel.Text = string.format("👻 %s", Config.formatTime(ghost.time))
	end
end

-- ---------------------------------------------------------------------------
-- Public API

function Ghost.setEnabled(on: boolean)
	enabled = on
	if not on then
		destroyRig()
	end
end

function Ghost.isEnabled(): boolean
	return enabled
end

function Ghost.hasGhost(): boolean
	return bestGhost ~= nil
end

function Ghost.start()
	-- Pull any stored ghost from a previous session.
	task.spawn(function()
		local ok, stored = pcall(function()
			return ghostAction:InvokeServer("get")
		end)
		if ok and typeof(stored) == "table" then
			bestGhost = stored :: GhostData
		end
	end)

	-- Record while a run is active; submit when it ends.
	player:GetAttributeChangedSignal("RunActive"):Connect(function()
		if player:GetAttribute("RunActive") == true then
			startRecording()
		elseif recording then
			stopRecordingAndSubmit()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if recording then
			sampleAccumulator += dt
			local interval = 1 / Config.GHOST_SAMPLE_RATE
			if sampleAccumulator >= interval then
				sampleAccumulator -= interval
				captureSample()
			end
		end
	end)

	RunService.RenderStepped:Connect(stepPlayback)
end

return Ghost
