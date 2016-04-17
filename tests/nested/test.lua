local testlib = require "testlib"
local luacov = require "luacov.runner"

testlib.f1()

luacov.pause()

local cmd = arg[-5] or "lua"
local slash = cmd:find("/")

if slash and slash ~= 1 then
   cmd = "../" .. cmd
end

cmd = cmd .. " -e 'package.path=[[../?.lua;../../../src/?.lua;]]'"
cmd = cmd .. " -e 'osexit = os.exit'"
cmd = cmd .. " -e 'require([[luacov.runner]]).load_config({statsfile = [[../luacov.stats.out]], savestepsize = 1})'"
cmd = cmd .. " -l luacov.tick"
cmd = cmd .. " -e 'dofile([[script.lua]])'"

local ok = os.execute("cd subdir && " .. cmd)
assert(ok == 0 or ok == true)

luacov.resume()

testlib.f2()
