local runner = require "luacov.runner"
local my_hook = require "my_hook"
debug.sethook(my_hook, "line")
local a = 2
debug.sethook(runner.debug_hook, "line")
local b = 3
