
-- This script expects the arguments "-c <luacov config file name>"

-- "Unload" the luacov.runner module which was included via "-lluacov" to be able to load a specific config file
package.loaded["luacov.runner"] = nil

-- Initialize the luacov.runner module with the luacov config file for the current test case
require("luacov.runner")(arg[2])

require "dirA.fileA"
require "dirB.fileB"
require "dirC.fileC"
require "dirC.nested.fileD"
