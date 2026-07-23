--!strict
-- JumpPads.luau (client)
-- Launches the LOCAL character when it touches a jump pad. This must run on
-- the client: player characters are network-owned by their own client, so a
-- server-side velocity write is overridden by the client's simulation within a
-- frame (the launch "works in Studio solo-test" but fails live). Writing the
-- velocity here — after forcing a jump state so grounded friction can't eat
-- the horizontal component — applies instantly and sticks.
--
-- Pads are built and tagged "JumpPad" by the server's CourseBuilder.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local JumpPads = {}

local player = Players.LocalPlayer
local debounce = false

local function onPadTouched(hit: BasePart)
	if debounce then
		return
	end
	local character = player.Character
	if not character or not hit:IsDescendantOf(character) then
		return -- someone else's character, or a stray part
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	debounce = true

	-- Leave the grounded state first, or the humanoid's own movement control
	-- cancels the horizontal velocity on the very next physics step.
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity = Config.JUMP_PAD_VELOCITY

	task.delay(0.5, function()
		debounce = false
	end)
end

local function wirePad(pad: Instance)
	if pad:IsA("BasePart") then
		pad.Touched:Connect(onPadTouched)
	end
end

function JumpPads.start()
	for _, pad in CollectionService:GetTagged("JumpPad") do
		wirePad(pad)
	end
	CollectionService:GetInstanceAddedSignal("JumpPad"):Connect(wirePad)
end

return JumpPads
