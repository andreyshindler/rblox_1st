--!strict
-- CoinService.luau
-- The coin economy: scatters spinning coin pickups over every stage platform,
-- awards their value on touch, keeps the Coins leaderstat in sync with the
-- persisted profile, and pays a bonus (base + speed) on finishing a run.
--
-- Coins are shared per-server: a collected coin vanishes for everyone and
-- respawns after Config.COIN_RESPAWN seconds.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local CoinService = {}

-- Optional listener fired on every pickup (used by effects for the coin ding).
local pickupListener: ((player: Player, coin: BasePart) -> ())? = nil

function CoinService.setPickupListener(fn: (player: Player, coin: BasePart) -> ())
	pickupListener = fn
end

-- Listeners fired after any award with the player's new balance (badges etc.).
local awardListeners: { (player: Player, newTotal: number) -> () } = {}

function CoinService.addAwardListener(fn: (player: Player, newTotal: number) -> ())
	table.insert(awardListeners, fn)
end

local function setCoinsLeaderstat(player: Player, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild("Coins")
	if stat and stat:IsA("IntValue") then
		stat.Value = value
	end
end

-- Award coins into the player's profile and leaderstat. Earnings are scaled by
-- the rebirth multiplier (+REBIRTH_MULT per rebirth); spending elsewhere is not.
function CoinService.award(player: Player, amount: number)
	local profile = DataService.getProfile(player.UserId)
	if not profile then
		return
	end
	local multiplier = 1 + profile.rebirths * Config.REBIRTH_MULT
	profile.coins += math.floor(amount * multiplier + 0.5)
	DataService.markProfileDirty(player.UserId)
	setCoinsLeaderstat(player, profile.coins)

	for _, listener in awardListeners do
		task.spawn(listener, player, profile.coins)
	end
end

-- Finish payout: a flat bonus plus a speed bonus that scales linearly from
-- SPEED_BONUS_MAX (instant run) down to 0 at SPEED_BONUS_PAR seconds.
function CoinService.awardFinishBonus(player: Player, elapsed: number)
	local speedFraction = math.clamp(1 - elapsed / Config.SPEED_BONUS_PAR, 0, 1)
	local bonus = Config.FINISH_BONUS + math.floor(Config.SPEED_BONUS_MAX * speedFraction)
	CoinService.award(player, bonus)
end

local function makeCoin(position: Vector3, value: number, parent: Instance): BasePart
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 3, 3)
	coin.Color = Color3.fromRGB(255, 210, 60)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	-- Cylinder axis is X; roll it so the coin stands like a wheel, then spin
	-- about the world Y axis with an endless tween.
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	coin:SetAttribute("Value", value)
	coin.Parent = parent

	local info = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
	TweenService:Create(coin, info, {
		CFrame = coin.CFrame * CFrame.Angles(0, math.rad(180), 0),
	}):Play()

	return coin
end

local function setupCoin(coin: BasePart)
	local taken = false

	coin.Touched:Connect(function(hit)
		if taken then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		taken = true

		local value = coin:GetAttribute("Value")
		CoinService.award(player, typeof(value) == "number" and value or 1)
		if pickupListener then
			task.spawn(pickupListener, player, coin)
		end

		coin.Transparency = 1

		task.delay(Config.COIN_RESPAWN, function()
			coin.Transparency = 0
			taken = false
		end)
	end)
end

local function onPlayerAdded(player: Player)
	-- CheckpointService creates leaderstats; wait for it, then attach Coins.
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end

	local stat = Instance.new("IntValue")
	stat.Name = "Coins"
	stat.Value = 0
	stat.Parent = leaderstats

	local profile = DataService.loadProfile(player.UserId)
	setCoinsLeaderstat(player, profile.coins)
end

function CoinService.start(course: CourseBuilder.Course)
	local folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = workspace:FindFirstChild("Obby") or workspace

	for stage, platform in course.platforms do
		local zone = select(1, Config.zoneFor(stage))
		local zoneIndex = table.find(Config.ZONES, zone) or 1
		local top = platform.Position + Vector3.new(0, Config.PLATFORM_SIZE.Y / 2 + 2.5, 0)

		for i = 1, Config.COINS_PER_STAGE do
			-- Spread coins across the platform's Z axis, away from the checkpoint.
			local offset = Vector3.new(
				(i - (Config.COINS_PER_STAGE + 1) / 2) * 4,
				0,
				(i % 2 == 0) and 5 or -5
			)
			local coin = makeCoin(top + offset, zoneIndex, folder)
			setupCoin(coin)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return CoinService
