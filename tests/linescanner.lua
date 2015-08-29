-- Allow testing without installing,
package.path = "src/?.lua;"..package.path

local LineScanner = require("luacov.reporter").LineScanner

local ntests = 0

-- source must contain "+", "?" or "-" at the end of each line,
-- marking expected output: "+" for always included lines, "?" for lines
-- included when hit, "-" for excluded lines.
local function test(source)
   ntests = ntests + 1

   local lines = {}
   local failed = false
   local scanner = LineScanner:new()

   for line in source:gmatch("[^\n]+") do
      local expected_symbol = line:sub(-1)
      line = line:sub(1, -2)

      local always_excluded, excluded_when_not_hit = scanner:consume(line)
      local actual_symbol = always_excluded and "-" or (excluded_when_not_hit and "?" or "+")

      if actual_symbol ~= expected_symbol then
         failed = true
      end

      table.insert(lines, line..expected_symbol.." "..actual_symbol)
   end

   if failed then
      error(("LineScanner test #%d failed!\nLine/expected/actual:\n\n%s"):format(
         ntests, table.concat(lines, "\n")
      ), 0)
   end
end

-- Tests from tests/issue_1.lua:

-- First line used to be annotated as excluded, but was not actually excluded.
test [[
   local thing = nil +
   print("test1")    +
]]

test [[
   local stuff = function (x) return x end +
   local thing = stuff({                   +
      b = { name = 'bob',                  ?
      },                                   +
      -- comment                           -
   })                                      ?
   print("test2")                          +
]]

test [[
   local stuff = function (x) return x end +
   local thing = stuff({                   +
      b = { name = 'bob',                  ?
      },                                   +
      -- comment                           -
   }                                       ?
   )                                       ?
   print("test2")                          +
]]

test [[
   if true then      -
      print("test3") +
   end               -
]]

test [[
   if true then      -
   end               -
   print("test3")    +
]]


test [[
   while true do     -
      print("test4") +
      break          ?
   end               -
]]

test [[
   local a, b = 1,2 +
   if               -
      a < b         +
   then             -
      a = b         +
   end              -
   print("test7")   +
]]

test [[
   local a,b = 1,2               +
   if a < b then                 +
      a = b                      +
   end;                          -
                                 -
   local function foo(f) f() end +
   foo(function()                +
      a = b                      +
   end)                          -
                                 -
   print("test8")                +
]]

test [[
   local function foo(f) -
      return function()  ?
         a = a           +
      end                -
   end                   -
   foo()()               +
                         -
   print("test9")        +
]]

-- Line 'c = 3' used to be annotated as excluded, but was not actually excluded.
test [[
   local s = {     +
      a = 1;       ?
      b = 2,       ?
      c = 3        +
   }               ?
                   -
   print("test10") +
]]

-- Line 'return 1, 2, function()' is supposed to be excluded,
-- but corresponding exclusion rule is bugged, see #27.
test [[
   local function foo(f)      -
      return 1, 2, function() +
         a = a                +
      end                     -
   end                        -
   local a,b,c = foo()        +
   c()                        +
                              -
   print("test11")            +
]]

-- Lines inside long strings.
test [=[
print([[         +
some long string -
]==]             -
still going      -
end]])           +
]=]

-- Assignments of long strings.
test [=[
local s = [[ ?
abc          -
]]           +
]=]

test [=[
t.k = [[ ?
abc      -
]]       +
]=]

-- Inline long comments.
test [=[
local function foo(--[[unused]] x) -
   return x                        +
end                                -
]=]

-- Chaotic whitespace.
test [=[
  while     true     do -
      end               -
]=]

-- Strange strings.
test [=[
local a = "[[\ ?
]]\            -
print(b)"      +
print(a)       +
]=]

test [=[
local a = ("\     +
local function(") +
]=]

print(("%d LineScanner tests passed."):format(ntests))
