local runner = require "luacov.runner"

local function f(x)
   return coroutine.yield(x + 1) + 2
end

local function g(x)
   return coroutine.yield(x + 3) + 4
end

local wf = coroutine.wrap(f)
local wg = corowrap(runner.with_luacov(g))

assert(wf(3) == 4)
assert(wf(5) == 7)
assert(wg(8) == 11)
assert(wg(10) == 14)
