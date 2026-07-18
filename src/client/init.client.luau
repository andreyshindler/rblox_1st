--!strict
-- init.client.luau
-- Minimal HUD: shows the player's current Stage (read from leaderstats.Stage) and a
-- "Reset to checkpoint" button that kills the character so they respawn at their last
-- checkpoint. Rojo maps src/client -> StarterPlayerScripts.Client (a LocalScript).

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function waitForStageValue(): IntValue
	local leaderstats = player:WaitForChild("leaderstats")
	local stageValue = leaderstats:WaitForChild("Stage")
	return stageValue :: IntValue
end

-- Build the GUI.
local gui = Instance.new("ScreenGui")
gui.Name = "RainbowRushHud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local stageLabel = Instance.new("TextLabel")
stageLabel.Name = "StageLabel"
stageLabel.AnchorPoint = Vector2.new(0.5, 0)
stageLabel.Position = UDim2.new(0.5, 0, 0, 12)
stageLabel.Size = UDim2.new(0, 260, 0, 48)
stageLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
stageLabel.BackgroundTransparency = 0.25
stageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stageLabel.Font = Enum.Font.GothamBold
stageLabel.TextScaled = true
stageLabel.Text = "Stage 0"
stageLabel.Parent = gui

local labelCorner = Instance.new("UICorner")
labelCorner.CornerRadius = UDim.new(0, 8)
labelCorner.Parent = stageLabel

local resetButton = Instance.new("TextButton")
resetButton.Name = "ResetButton"
resetButton.AnchorPoint = Vector2.new(0.5, 0)
resetButton.Position = UDim2.new(0.5, 0, 0, 68)
resetButton.Size = UDim2.new(0, 200, 0, 40)
resetButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.Font = Enum.Font.GothamMedium
resetButton.TextScaled = true
resetButton.Text = "Reset to checkpoint"
resetButton.Parent = gui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = resetButton

-- Keep the label in sync with the Stage value.
local stageValue = waitForStageValue()
local function refresh()
	stageLabel.Text = "Stage " .. tostring(stageValue.Value)
end
stageValue.Changed:Connect(refresh)
refresh()

-- Reset button: kill the current character. The server's CharacterAdded handler
-- respawns the player at their last checkpoint.
resetButton.Activated:Connect(function()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
end)
