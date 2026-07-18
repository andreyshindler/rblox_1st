--!strict
-- init.server.luau
-- Entry point. Rojo maps src/server -> ServerScriptService.Server, and an `init`
-- script becomes the Script instance for that container. Builds the course, arms
-- the hazards, wires progression/timing, and sets up the skip-stage gamepass.

local CourseBuilder = require(script:WaitForChild("CourseBuilder"))
local HazardService = require(script:WaitForChild("HazardService"))
local CheckpointService = require(script:WaitForChild("CheckpointService"))
local GamepassService = require(script:WaitForChild("GamepassService"))
local GlobalBoard = require(script:WaitForChild("GlobalBoard"))
local CoinService = require(script:WaitForChild("CoinService"))
local ShopService = require(script:WaitForChild("ShopService"))
local EffectsService = require(script:WaitForChild("EffectsService"))
local RebirthService = require(script:WaitForChild("RebirthService"))
local DailyRewardService = require(script:WaitForChild("DailyRewardService"))
local BadgeAwards = require(script:WaitForChild("BadgeAwards"))
local GhostService = require(script:WaitForChild("GhostService"))

-- Enforce lighting/exposure at boot. The place file (default.project.json)
-- pins Lighting.Technology = ShadowMap (not scriptable), but the scriptable
-- exposure values are re-applied here so a live place published from a stale
-- sync can never ship overexposed, washed-out colors — especially on mobile
-- clients, whose fallback lighting pipeline blows bright scenes out to white.
local Lighting = game:GetService("Lighting")
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(80, 80, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
Lighting.ExposureCompensation = 0
Lighting.ClockTime = 14

local course = CourseBuilder.build()
HazardService.start(course)
CoinService.start(course)
CheckpointService.start(course)
GamepassService.start()
ShopService.start()
RebirthService.start()
DailyRewardService.start()
BadgeAwards.start()
GhostService.start()
GlobalBoard.start(course)
EffectsService.start(course)

print("[Rainbow Rush] Course built, hazards armed, checkpoints online.")
