local testlib = require "testlib"
local luacov = require "luacov.runner"

testlib.f1()

local function get_lua()
   local index = -1
   local res = "lua"

   while arg[index] do
      res = arg[index]
      index = index - 1
   end

   return res
end

local lua = get_lua()
local dir_sep = package.config:sub(1, 1)

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
