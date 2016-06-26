local testlib = require "testlib"
local luacov = require "luacov.runner"

testlib.f1()

local dir_sep = package.config:sub(1, 1)
local cmd = arg[-4] or "lua"
local slash = cmd:find(dir_sep)

if slash and slash ~= 1 then
   cmd = ".." .. dir_sep .. cmd
end

cmd = ("%q"):format(cmd) .. ' -e "package.path=[[../?.lua;../../../src/?.lua;]]..package.path"'
cmd = cmd .. ' -e "osexit = os.exit"'
cmd = cmd .. ' -e "require([[luacov.runner]]).load_config({statsfile = [[../luacov.stats.out]], savestepsize = 1})"'
cmd = cmd .. " -l luacov.tick"
cmd = cmd .. ' -e "dofile([[script.lua]])"'
cmd = cmd:gsub("/", dir_sep)

local ok = os.execute("cd subdir && " .. cmd)
assert(ok == 0 or ok == true)

testlib.f2()
