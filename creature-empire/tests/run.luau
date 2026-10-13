--!nocheck
-- Runs every spec: `lune run tests/run` from the creature-empire folder.
-- Exits with code 1 if anything fails (for CI).

local process = require("@lune/process")
local H = require("./harness")

require("./specs/Config.spec")
require("./specs/Economy.spec")
require("./specs/Data.spec")
require("./specs/Phase2.spec")
require("./specs/Phase3.spec")
require("./specs/Phase4.spec")
require("./specs/Phase5.spec")

local results = H.Results
print(`\n{results.Passed} passed, {results.Failed} failed`)
if results.Failed > 0 then
	for _, failure in results.Failures do
		print("  - " .. failure)
	end
	process.exit(1)
end
