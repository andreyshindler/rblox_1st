--!strict
-- Music.luau (client)
-- Zone-aware background music. Watches the player's Stage leaderstat, maps it
-- to a zone (Config.zoneFor), and crossfades between that zone's track and the
-- previous one. Track ids live in Config.MUSIC — zones without a track fall
-- back to MUSIC.DEFAULT; if that is 0 too, this module simply stays silent, so
-- the game is safe to ship before any audio ids are chosen.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Music = {}

local player = Players.LocalPlayer

local currentSound: Sound? = nil
local currentId = 0

local function trackForStage(stage: number): number
	local zone = select(1, Config.zoneFor(math.max(stage, 1)))
	local zoneId = Config.MUSIC[zone.name]
	if typeof(zoneId) == "number" and zoneId > 0 then
		return zoneId
	end
	local fallback = Config.MUSIC.DEFAULT
	return typeof(fallback) == "number" and fallback or 0
end

local function fadeOutAndStop(sound: Sound)
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(Config.MUSIC_CROSSFADE, Enum.EasingStyle.Linear),
		{ Volume = 0 }
	)
	tween.Completed:Once(function()
		sound:Stop()
		sound:Destroy()
	end)
	tween:Play()
end

local function switchTo(trackId: number)
	if trackId == currentId then
		return
	end
	currentId = trackId

	local old = currentSound
	currentSound = nil
	if old then
		fadeOutAndStop(old)
	end

	if trackId <= 0 then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "ZoneMusic_" .. trackId
	sound.SoundId = "rbxassetid://" .. trackId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	currentSound = sound

	TweenService:Create(
		sound,
		TweenInfo.new(Config.MUSIC_CROSSFADE, Enum.EasingStyle.Linear),
		{ Volume = Config.MUSIC_VOLUME }
	):Play()
end

function Music.start()
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 30)
		local stageValue = leaderstats and leaderstats:WaitForChild("Stage", 10)
		if not stageValue or not stageValue:IsA("IntValue") then
			-- No stage stat (shouldn't happen): fall back to the default track.
			switchTo(typeof(Config.MUSIC.DEFAULT) == "number" and Config.MUSIC.DEFAULT or 0)
			return
		end

		stageValue:GetPropertyChangedSignal("Value"):Connect(function()
			switchTo(trackForStage(stageValue.Value))
		end)
		switchTo(trackForStage(stageValue.Value))
	end)
end

return Music
