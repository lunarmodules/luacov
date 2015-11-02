--- Loads <code>luacov.runner</code> and immediately starts it.
-- Useful for launching scripts from the command-line. Returns the <code>luacov.runner</code> module.
-- @class module
-- @name luacov
-- @usage lua -lluacov sometest.lua
local runner = require("luacov.runner")
runner.init()
return runner
