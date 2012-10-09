--- Loads <code>luacov.runner</code> and immediately starts it.
-- Useful for launching scripts from the command-line.
-- @class module
-- @name luacov
-- @example  lua -lluacov sometest.lua 
local runner = require("luacov.runner")
runner.init()
