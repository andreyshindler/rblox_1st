--!strict
-- init.server.luau
-- Entry point. Rojo maps src/server -> ServerScriptService, and an `init` script
-- becomes the Script instance for that container. Builds the course, then hands the
-- resulting parts to the CheckpointService to wire up progression.

local CourseBuilder = require(script:WaitForChild("CourseBuilder"))
local CheckpointService = require(script:WaitForChild("CheckpointService"))

local course = CourseBuilder.build()
CheckpointService.start(course)

print("[Rainbow Rush] Course built and checkpoints online.")
