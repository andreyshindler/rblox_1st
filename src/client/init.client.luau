--!strict
-- init.client.luau
-- HUD: current Stage, a live run timer, the player's best time, and buttons to
-- reset to checkpoint or skip a stage (gamepass). Rojo maps src/client ->
-- StarterPlayerScripts.Client (a LocalScript that runs once and persists).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Format seconds as "12.34s" or "1:05.20" for longer runs.
local function formatTime(t: number): string
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

-- Small helper to keep the widget construction tidy.
local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name = "RainbowRushHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Stage readout (top).
local stageLabel = Instance.new("TextLabel")
stageLabel.Name = "StageLabel"
stageLabel.AnchorPoint = Vector2.new(0.5, 0)
stageLabel.Position = UDim2.new(0.5, 0, 0, 12)
stageLabel.Size = UDim2.new(0, 260, 0, 44)
stageLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
stageLabel.BackgroundTransparency = 0.25
stageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stageLabel.Font = Enum.Font.GothamBold
stageLabel.TextScaled = true
stageLabel.Text = "Stage 0"
stageLabel.Parent = gui
corner(stageLabel, 8)

-- Live run timer.
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.Position = UDim2.new(0.5, 0, 0, 62)
timerLabel.Size = UDim2.new(0, 200, 0, 36)
timerLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
timerLabel.BackgroundTransparency = 0.35
timerLabel.TextColor3 = Color3.fromRGB(120, 230, 255)
timerLabel.Font = Enum.Font.GothamMedium
timerLabel.TextScaled = true
timerLabel.Text = "0.00s"
timerLabel.Parent = gui
corner(timerLabel, 8)

-- Best time.
local bestLabel = Instance.new("TextLabel")
bestLabel.Name = "BestLabel"
bestLabel.AnchorPoint = Vector2.new(0.5, 0)
bestLabel.Position = UDim2.new(0.5, 0, 0, 102)
bestLabel.Size = UDim2.new(0, 200, 0, 28)
bestLabel.BackgroundTransparency = 1
bestLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
bestLabel.Font = Enum.Font.GothamMedium
bestLabel.TextScaled = true
bestLabel.Text = "Best --"
bestLabel.Parent = gui

-- Bottom buttons: reset (left of centre) and skip stage (right of centre).
local resetButton = Instance.new("TextButton")
resetButton.Name = "ResetButton"
resetButton.AnchorPoint = Vector2.new(1, 1)
resetButton.Position = UDim2.new(0.5, -8, 1, -16)
resetButton.Size = UDim2.new(0, 170, 0, 44)
resetButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.Font = Enum.Font.GothamMedium
resetButton.TextScaled = true
resetButton.Text = "Reset to checkpoint"
resetButton.Parent = gui
corner(resetButton, 8)

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.AnchorPoint = Vector2.new(0, 1)
skipButton.Position = UDim2.new(0.5, 8, 1, -16)
skipButton.Size = UDim2.new(0, 170, 0, 44)
skipButton.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
skipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
skipButton.Font = Enum.Font.GothamMedium
skipButton.TextScaled = true
skipButton.Text = "⏭ Skip Stage"
skipButton.Parent = gui
corner(skipButton, 8)

-- Keep the stage label in sync with leaderstats.Stage.
local leaderstats = player:WaitForChild("leaderstats")
local stageValue = leaderstats:WaitForChild("Stage")
local function refreshStage()
	stageLabel.Text = "Stage " .. tostring(stageValue.Value)
end
stageValue:GetPropertyChangedSignal("Value"):Connect(refreshStage)
refreshStage()

-- Best time (leaderstats.Best, in seconds; 0 == none yet).
local bestValue = leaderstats:WaitForChild("Best")
local function refreshBest()
	local v = bestValue.Value
	bestLabel.Text = (v > 0) and ("Best " .. formatTime(v)) or "Best --"
end
bestValue:GetPropertyChangedSignal("Value"):Connect(refreshBest)
refreshBest()

-- Live timer: read the server-set attributes and count up locally against the
-- synced server clock, so it stays accurate across respawns with no handshake.
RunService.RenderStepped:Connect(function()
	local active = player:GetAttribute("RunActive")
	local startTime = player:GetAttribute("RunStartTime")
	if active and typeof(startTime) == "number" then
		timerLabel.Text = formatTime(workspace:GetServerTimeNow() - startTime)
	else
		local last = player:GetAttribute("LastRunTime")
		timerLabel.Text = (typeof(last) == "number" and last > 0) and formatTime(last) or "0.00s"
	end
end)

-- Reset button: kill the character so the server respawns them at their checkpoint.
resetButton.Activated:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end)

-- Skip button: ask the server to skip a stage (gated by the gamepass server-side).
local skipEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkipStage")
skipButton.Activated:Connect(function()
	skipEvent:FireServer()
end)
