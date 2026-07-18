--!strict
-- EffectsService.luau
-- Sound and visual feedback: checkpoint chime, coin ding, death sizzle, finish
-- fanfare + confetti, fireworks on a new personal best, and an optional ambient
-- music loop. Purely cosmetic — it only listens to hooks exposed by the game
-- services and never affects progression.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))
local CheckpointService = require(script.Parent:WaitForChild("CheckpointService"))
local TimerService = require(script.Parent:WaitForChild("TimerService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))

local EffectsService = {}

-- Play a one-shot positional sound at a part; the clone cleans itself up.
local function playAt(soundId: string, parent: Instance, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 4)
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Short confetti burst from an emitter parented to the given part.
local function burst(part: BasePart, colors: { Color3 }, count: number)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, part.Size.Y / 2 + 1, 0)
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(1, colors[#colors]),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(15, 30)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new(0.5)
	emitter.Rate = 0 -- burst-only
	emitter.Parent = attachment

	emitter:Emit(count)
	Debris:AddItem(attachment, 3)
end

function EffectsService.start(course: CourseBuilder.Course)
	-- Checkpoint chime, at the pad the player just cleared.
	CheckpointService.addCheckpointListener(function(_player, stage)
		local pad = course.checkpoints[stage]
		if pad then
			playAt(Config.SOUNDS.checkpoint, pad, 0.5)
		end
	end)

	-- Finish fanfare + confetti from the finish pad.
	CheckpointService.addFinishListener(function(_player, _elapsed)
		playAt(Config.SOUNDS.finish, course.finish, 0.8)
		burst(course.finish, {
			Color3.fromRGB(255, 215, 0),
			Color3.fromRGB(255, 120, 200),
		}, 60)
	end)

	-- Fireworks (bigger, brighter burst) at the player on a new personal best.
	TimerService.addBestListener(function(player, _seconds)
		local root = characterRoot(player)
		if root then
			burst(root, {
				Color3.fromRGB(120, 230, 255),
				Color3.fromRGB(255, 215, 0),
			}, 120)
		end
	end)

	-- Coin ding at the coin that was picked up.
	CoinService.setPickupListener(function(_player, coin)
		playAt(Config.SOUNDS.coin, coin, 0.4)
	end)

	-- Death sizzle at the character that just died.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						playAt(Config.SOUNDS.death, root, 0.5)
					end
				end)
			end
		end)
	end)

	-- Ambient music loop (opt-in via Config.MUSIC_ID).
	if Config.MUSIC_ID > 0 then
		local music = Instance.new("Sound")
		music.Name = "AmbientMusic"
		music.SoundId = "rbxassetid://" .. Config.MUSIC_ID
		music.Volume = Config.MUSIC_VOLUME
		music.Looped = true
		music.Parent = workspace
		music:Play()
	end
end

return EffectsService
