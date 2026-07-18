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

local course = CourseBuilder.build()
HazardService.start(course)
CoinService.start(course)
CheckpointService.start(course)
GamepassService.start()
ShopService.start()
GlobalBoard.start(course)

print("[Rainbow Rush] Course built, hazards armed, checkpoints online.")
