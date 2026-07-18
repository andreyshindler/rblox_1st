--!strict
-- GlobalBoard.luau
-- Builds a physical "Fastest Times" sign near spawn and keeps it populated from
-- the OrderedDataStore (via DataService). Refreshes on a timer and shortly after
-- any player sets a new personal best.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local TimerService = require(script.Parent:WaitForChild("TimerService"))

local GlobalBoard = {}

local rowsContainer: Frame? = nil
local lastRefresh = 0 -- os.clock() of the last refresh, for debouncing
local REFRESH_DEBOUNCE = 15 -- min seconds between best-triggered refreshes

local function makeRow(rank: number, text: string, color: Color3): TextLabel
	local row = Instance.new("TextLabel")
	row.Name = "Row_" .. rank
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundTransparency = 1
	row.TextColor3 = color
	row.Font = Enum.Font.GothamMedium
	row.TextScaled = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = text
	row.LayoutOrder = rank
	return row
end

-- (Re)draws the board from the current top times.
function GlobalBoard.refresh()
	local container = rowsContainer
	if not container then
		return
	end
	lastRefresh = os.clock()

	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local entries = DataService.getTopTimes(Config.GLOBAL_BOARD_SIZE)
	if #entries == 0 then
		local message = DataService.isEnabled() and "No times yet — be the first!"
			or "Enable API Services to save times"
		makeRow(1, message, Color3.fromRGB(200, 200, 200)).Parent = container
		return
	end

	local medal = { Color3.fromRGB(255, 215, 0), Color3.fromRGB(210, 210, 210), Color3.fromRGB(205, 127, 50) }
	for rank, entry in entries do
		local color = medal[rank] or Color3.fromRGB(255, 255, 255)
		local text = string.format("%d.  %s  —  %s", rank, entry.name, Config.formatTime(entry.seconds))
		makeRow(rank, text, color).Parent = container
	end
end

-- Builds the sign next to the spawn platform.
local function buildSign(course: CourseBuilder.Course)
	local sign = Instance.new("Part")
	sign.Name = "GlobalBoard"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Size = Vector3.new(18, 12, 1)
	sign.Color = Color3.fromRGB(15, 15, 25)
	sign.Material = Enum.Material.SmoothPlastic
	-- Beside the spawn, turned to face back toward it.
	sign.CFrame = CFrame.new(course.spawn.Position + Vector3.new(0, 7, 14))
	sign.Parent = workspace:FindFirstChild("Obby") or workspace

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(720, 480)
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.Parent = sign

	local padding = Instance.new("Frame")
	padding.Size = UDim2.new(1, -40, 1, -30)
	padding.Position = UDim2.new(0, 20, 0, 15)
	padding.BackgroundTransparency = 1
	padding.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(120, 230, 255)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "🏆 Fastest Times"
	title.Parent = padding

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.Position = UDim2.new(0, 0, 0, 72)
	list.Size = UDim2.new(1, 0, 1, -72)
	list.BackgroundTransparency = 1
	list.Parent = padding

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	rowsContainer = list
end

function GlobalBoard.start(course: CourseBuilder.Course)
	buildSign(course)
	GlobalBoard.refresh()

	-- Nudge a refresh (debounced) whenever someone sets a new best.
	TimerService.setBestListener(function()
		if os.clock() - lastRefresh >= REFRESH_DEBOUNCE then
			GlobalBoard.refresh()
		end
	end)

	-- Periodic refresh so times from other servers show up.
	task.spawn(function()
		while true do
			task.wait(Config.BOARD_REFRESH)
			GlobalBoard.refresh()
		end
	end)
end

return GlobalBoard
