--!strict
-- init.client.luau
-- HUD: current Stage, a live run timer, best time, coin counter, and buttons to
-- reset to checkpoint, skip a stage (gamepass), or open the trail shop. Rojo maps
-- src/client -> StarterPlayerScripts.Client (a LocalScript that runs once and persists).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShopItems = require(Shared:WaitForChild("ShopItems"))

-- Controller buttons for the HUD actions. On a PlayStation pad Roblox maps
-- ButtonY -> Triangle and ButtonX -> Square; neither collides with ButtonA (jump).
-- The shop toggles on DPadUp so it can't be hit mid-jump by accident.
local RESET_KEYS = { Enum.KeyCode.ButtonY, Enum.KeyCode.R }
local SKIP_KEYS = { Enum.KeyCode.ButtonX }
local SHOP_KEYS = { Enum.KeyCode.DPadUp, Enum.KeyCode.B }

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local formatTime = Config.formatTime

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

-- Coin counter (top-left).
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.AnchorPoint = Vector2.new(0, 0)
coinsLabel.Position = UDim2.new(0, 16, 0, 12)
coinsLabel.Size = UDim2.new(0, 150, 0, 40)
coinsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
coinsLabel.BackgroundTransparency = 0.25
coinsLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.TextScaled = true
coinsLabel.Text = "🪙 0"
coinsLabel.Parent = gui
corner(coinsLabel, 8)

-- Shop toggle (top-left, under the coin counter).
local shopButton = Instance.new("TextButton")
shopButton.Name = "ShopButton"
shopButton.AnchorPoint = Vector2.new(0, 0)
shopButton.Position = UDim2.new(0, 16, 0, 58)
shopButton.Size = UDim2.new(0, 150, 0, 36)
shopButton.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shopButton.Font = Enum.Font.GothamMedium
shopButton.TextScaled = true
shopButton.Text = "🛒 Shop"
shopButton.Parent = gui
corner(shopButton, 8)

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

-- Coin counter (leaderstats.Coins, added by CoinService shortly after join).
task.spawn(function()
	local coinsValue = leaderstats:WaitForChild("Coins", 15)
	if not coinsValue or not coinsValue:IsA("IntValue") then
		return
	end
	local function refreshCoins()
		coinsLabel.Text = "🪙 " .. tostring(coinsValue.Value)
	end
	coinsValue:GetPropertyChangedSignal("Value"):Connect(refreshCoins)
	refreshCoins()
end)

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

local skipEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkipStage")

-- The two actions, shared by touch/click (Activated) and controller (ContextActionService).
local function doReset()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end

local function doSkip()
	skipEvent:FireServer()
end

-- Touch / mouse.
resetButton.Activated:Connect(doReset)
skipButton.Activated:Connect(doSkip)

-- Keyboard / gamepad. createTouchButton = false: we already show our own buttons,
-- so no extra on-screen control is spawned on touch devices. Pass the input through
-- so nothing else is blocked.
local function bindAction(name: string, fn: () -> (), keys: { Enum.KeyCode })
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
end

bindAction("RainbowRushReset", doReset, RESET_KEYS)
bindAction("RainbowRushSkip", doSkip, SKIP_KEYS)

-- These are triggered by dedicated buttons (above), not by gamepad UI focus, so
-- keep them out of gamepad selection — that avoids ButtonA (jump) accidentally
-- activating a focused button.
resetButton.Selectable = false
skipButton.Selectable = false

-- Show the matching controller glyph on the buttons while a gamepad is in use,
-- and the plain labels for touch/mouse.
local function keyHint(keyCode: Enum.KeyCode, fallback: string): string
	local ok, str = pcall(function()
		return UserInputService:GetStringForKeyCode(keyCode)
	end)
	if ok and typeof(str) == "string" and str ~= "" then
		return str
	end
	return fallback
end

local function gamepadActive(): boolean
	return string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
end

local function updateHints()
	if gamepadActive() then
		resetButton.Text = "Reset  (" .. keyHint(Enum.KeyCode.ButtonY, "Y") .. ")"
		skipButton.Text = "Skip Stage  (" .. keyHint(Enum.KeyCode.ButtonX, "X") .. ")"
		shopButton.Text = "Shop  (" .. keyHint(Enum.KeyCode.DPadUp, "DPad↑") .. ")"
	else
		resetButton.Text = "Reset to checkpoint"
		skipButton.Text = "⏭ Skip Stage"
		shopButton.Text = "🛒 Shop"
	end
end

UserInputService.LastInputTypeChanged:Connect(updateHints)
updateHints()

-- ---------------------------------------------------------------------------
-- Trail shop panel

local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteFunction

local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
shopPanel.Size = UDim2.new(0, 360, 0, 440)
shopPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
shopPanel.BackgroundTransparency = 0.05
shopPanel.Visible = false
shopPanel.Parent = gui
corner(shopPanel, 12)

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, -60, 0, 44)
shopTitle.Position = UDim2.new(0, 16, 0, 8)
shopTitle.BackgroundTransparency = 1
shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextScaled = true
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Text = "Trail Shop"
shopTitle.Parent = shopPanel

local shopClose = Instance.new("TextButton")
shopClose.Name = "CloseButton"
shopClose.AnchorPoint = Vector2.new(1, 0)
shopClose.Position = UDim2.new(1, -10, 0, 10)
shopClose.Size = UDim2.new(0, 40, 0, 40)
shopClose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
shopClose.TextColor3 = Color3.fromRGB(255, 255, 255)
shopClose.Font = Enum.Font.GothamBold
shopClose.TextScaled = true
shopClose.Text = "✕"
shopClose.Parent = shopPanel
corner(shopClose, 8)

local shopList = Instance.new("ScrollingFrame")
shopList.Name = "Items"
shopList.Position = UDim2.new(0, 12, 0, 60)
shopList.Size = UDim2.new(1, -24, 1, -72)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.Parent = shopPanel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = shopList

-- One row per item; the action button is captured for refreshes.
local actionButtons: { [string]: TextButton } = {}

for order, item in ShopItems.list do
	local row = Instance.new("Frame")
	row.Name = "Item_" .. item.id
	row.Size = UDim2.new(1, -8, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	row.LayoutOrder = order
	row.Parent = shopList
	corner(row, 8)

	-- Swatch showing the trail's first colour.
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(0, 10, 1, -12)
	swatch.Position = UDim2.new(0, 6, 0, 6)
	swatch.BackgroundColor3 = item.colors[1]
	swatch.Parent = row
	corner(swatch, 4)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -140, 1, 0)
	nameLabel.Position = UDim2.new(0, 24, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = item.name
	nameLabel.Parent = row

	local action = Instance.new("TextButton")
	action.Name = "Action"
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -8, 0.5, 0)
	action.Size = UDim2.new(0, 100, 0, 40)
	action.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
	action.TextColor3 = Color3.fromRGB(255, 255, 255)
	action.Font = Enum.Font.GothamMedium
	action.TextScaled = true
	action.Text = "🪙 " .. item.price
	action.Parent = row
	corner(action, 8)

	actionButtons[item.id] = action
end

-- Redraw every row from a profile snapshot returned by the server.
local function refreshShop(snap: any)
	local ownedSet: { [string]: boolean } = {}
	if typeof(snap.owned) == "table" then
		for _, id in snap.owned :: { string } do
			ownedSet[id] = true
		end
	end
	for _, item in ShopItems.list do
		local button = actionButtons[item.id]
		if snap.equipped == item.id then
			button.Text = "Equipped"
			button.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
		elseif ownedSet[item.id] then
			button.Text = "Equip"
			button.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
		else
			button.Text = "🪙 " .. item.price
			button.BackgroundColor3 = (snap.coins or 0) >= item.price and Color3.fromRGB(90, 140, 220)
				or Color3.fromRGB(90, 90, 110)
		end
	end
end

-- Buy if unowned, equip if owned, unequip if equipped.
local function activateItem(item: ShopItems.Item)
	task.spawn(function()
		local button = actionButtons[item.id]
		local verb: string
		if button.Text == "Equipped" then
			verb = "equip" -- with "" below: unequip
		elseif button.Text == "Equip" then
			verb = "equip"
		else
			verb = "buy"
		end
		local id = (button.Text == "Equipped") and "" or item.id
		local ok, result = pcall(function()
			return shopAction:InvokeServer(verb, id)
		end)
		if ok and typeof(result) == "table" and result.snapshot then
			refreshShop(result.snapshot)
		end
	end)
end

for _, item in ShopItems.list do
	actionButtons[item.id].Activated:Connect(function()
		activateItem(item)
	end)
end

local function setShopOpen(open: boolean)
	shopPanel.Visible = open
	if open then
		task.spawn(function()
			local ok, result = pcall(function()
				return shopAction:InvokeServer("get")
			end)
			if ok and typeof(result) == "table" and result.snapshot then
				refreshShop(result.snapshot)
			end
		end)
		-- Hand gamepad focus to the panel so console players can navigate it.
		if gamepadActive() then
			local firstItem = ShopItems.list[1]
			GuiService.SelectedObject = firstItem and actionButtons[firstItem.id] or shopClose
		end
	else
		GuiService.SelectedObject = nil
	end
end

local function toggleShop()
	setShopOpen(not shopPanel.Visible)
end

shopButton.Activated:Connect(toggleShop)
shopClose.Activated:Connect(function()
	setShopOpen(false)
end)
bindAction("RainbowRushShop", toggleShop, SHOP_KEYS)

-- The launcher button itself stays out of gamepad focus (same reasoning as
-- reset/skip); the panel's own buttons are selectable for console navigation.
shopButton.Selectable = false
