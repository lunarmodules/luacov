local testlib = require "testlib"
local luacov = require "luacov.runner"

testlib.f1()

local dir_sep = package.config:sub(1, 1)
local lua = arg[-4] or "lua"
local slash = lua:find(dir_sep)

if slash and slash ~= 1 then
   lua = ".." .. dir_sep .. lua
end

local function test(tick_as_module)
   local config = tick_as_module and ".luacov" or "tick.luacov"
   local mod = tick_as_module and "luacov.tick" or "luacov"
   local cmd = ("%q"):format(lua) .. ' -e "package.path=[[../?.lua;../../../src/?.lua;]]..package.path"'
   cmd = cmd .. ' -e "osexit = os.exit"'
   cmd = cmd .. ' -e "require([[luacov.runner]]).load_config([[' .. config .. ']])"'
   cmd = cmd .. " -l " .. mod
   cmd = cmd .. ' -e "dofile([[script.lua]])"'
   cmd = cmd:gsub("/", dir_sep)

   local ok = os.execute("cd subdir && " .. cmd)
   assert(ok == 0 or ok == true)
end

test(true)
test(false)

testlib.f2()
