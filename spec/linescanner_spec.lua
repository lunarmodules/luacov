local LineScanner = require("luacov.linescanner")

local function assert_linescan(expected_source)
   local scanner = LineScanner:new()
   assert.is_table(scanner)

   local actual_lines = {}

   for expected_line in expected_source:gmatch("([^\n]*)\n") do
      local line = expected_line:sub(1, -2)

      local always_excluded, excluded_when_not_hit = scanner:consume(line)
      local actual_symbol = always_excluded and "-" or (excluded_when_not_hit and "?" or "+")
      local actual_line = line .. actual_symbol
      table.insert(actual_lines, actual_line)
   end

   local actual_source = table.concat(actual_lines, "\n") .. "\n"

   assert.is_equal(expected_source, actual_source)
end

describe("linescanner", function()
   it("includes simple calls", function()
      assert_linescan([[
print("test") +
]])
   end)

   it("excludes shebang line", function()
      assert_linescan([[
#!/usr/bin/env rm -
#!another one     +
]])
   end)

   it("is not sure if assignment of nil to a local should be included", function()
      assert_linescan([[
local thing = nil ?
]])
   end)

   it("inludes function assignments", function()
      assert_linescan([[
local stuff = function (x) return x end +
]])
   end)

   it("handles dangling paren after table end (same line)", function()
      assert_linescan([[
local thing = stuff({  +
   b = { name = 'bob', ?
   },                  ?
   -- comment          -
})                     ?
]])
   end)

   it("handles dangling paren after table end (next line)", function()
      assert_linescan([[
local thing = stuff({  +
   b = { name = 'bob', ?
   },                  ?
   -- comment          -
}                      ?
)                      ?
]])
   end)

   it("excludes 'if true then'", function()
      assert_linescan([[
if true then      -
   print("test") +
end               -
]])
   end)

   it("excludes 'while true do'", function()
      assert_linescan([[
while true do     -
   print("test") +
   break          ?
end               -
]])
   end)

   it("excludes 'if', 'then', and 'end' with nothing else on the line", function()
      assert_linescan([[
local a, b = 1,2 +
if               -
   a < b         +
then             -
   a = b         +
end              -
print("test")    +
]])
   end)

   it("excludes 'end' followed by semicolons or parens", function()
      assert_linescan([[
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
print(not_end)                +
]])
   end)

   it("is not sure about 'return function()'", function()
      assert_linescan([[
local function foo(f) -
   return function()  ?
      a = a           +
   end                -
end                   -
foo()()               +
]])
   end)

   it("is not sure about table fields", function()
      -- Line 'c = 3' should be excluded, but can not because it looks like an assignment.
      assert_linescan([[
local s = {     +
   a = 1;       ?
   b = 2,       ?
   c = 3        +
}               ?
]])
   end)

   it("includes 'return ..., function()'", function()
      -- There is a rule that intends to exclude lines like 'return 1, 2, function()', but it is bugged (see #27).
      -- TODO: remove that rule.
      assert_linescan([[
local function foo(f)      -
   return 1, 2, function() +
      a = a                +
   end                     -
end                        -
local a,b,c = foo()        +
c()                        +
]])
   end)

   it("excludes lines within long strings", function()
      assert_linescan([=[
print([[         +
some long string -
]==]             -
still going      -
end]])           +
]=])
   end)

   it("excludes lines within assigned long strings, and doubts the assignment", function()
      assert_linescan([=[
local s = [[ ?
abc          -
]]           +
]=])

      assert_linescan([=[
s = [[ ?
abc    -
]]     +
]=])

      assert_linescan([=[
t.k = [[ ?
abc      -
]]       +
]=])

      assert_linescan([=[
t.k1.k2 = [[ +
abc          -
]]           +
]=])

      assert_linescan([=[
t["k"] = [[ ?
abc         -
]]          +
]=])
   end)

   it("ignores inline long comments", function()
      assert_linescan([=[
local function foo(--[[unused]] x) -
   return x                        +
end                                -
]=])
   end)

   it("applies same rules even when whitespace is strange", function()
      assert_linescan([=[
  while     true     do -
      end               -
]=])
   end)

   it("ignores lines within short strings", function()
      assert_linescan([=[
local a = "[[\ ?
]]\            -
print(b)"      +
print(a)       +
]=])

      assert_linescan([=[
local a = ("\     ?
local function(") +
]=])

      assert_linescan([=[
local a = ([[   ?
format %string  -
]]):format(var) +
]=])
   end)

   it("ignores function declarations spanning multiple lines", function()
      assert_linescan([[
local function fff(a, -
   b,                 -
   c)                 -
   return a + b + c   +
end                   -
]])

      assert_linescan([[
local function fff( -
      a, b, c)      -
   return a + b + c +
end                 -
]])

      assert_linescan([[
local function fff  -
      (a, b, c)     -
   return a + b + c +
end                 -
]])
   end)

   it("handles local declarations", function()
      assert_linescan([[
local function f() end +
local x                -
local x, y             -
local x =              -
1                      ?
local x, y =           -
2, 3                   +
local x, y = 2,        +
3                      ?
local x = (            ?
   a + b)              +
local x, y = (         ?
   a + b), c           +
]])

      assert_linescan([[
local x = nil     ?
                  -
for i = 1, 100 do +
   x = 1          +
end               -
]])
   end)

   it("handles multiline declarations in tables", function()
      assert_linescan([=[
local t = {           +
   ["1"] = function() ?
      foo()           +
   end,               -
   ["2"] = ([[        ?
      %s              -
   ]]):format(var),   +
   ["3"] = [[         ?
      bar()           -
   ]]                 +
}                     ?
]=])
   end)

   it("handles single expressions in tables and calls", function()
      assert_linescan([=[
local x = {  +
   1,        ?
   2         ?
}            ?
local y = {  +
   3,        ?
   id        ?
}            ?
local z = {  +
   ""        ?
}            ?
local a = f( +
   true      ?
)            ?
local b = {  +
   id[1]     ?
}            ?
local c = {  +
   id.abcd   ?
}            ?
local d = {  +
   id.k1.k2  +
}            ?
local e = {  +
   {},       ?
   {}        ?
}            ?
local f = {  +
   {foo}     +
}            ?
]=])

      assert_linescan([=[
local t1 = {   +
   1,          ?
   2}          ?
local t2 = f({ +
   1,          ?
   false})     ?
local t3 = {   +
   var}        +
]=])
   end)

   it("doubts table endings", function()
      assert_linescan([[
local v = f({ +
   a = "foo", ?
   x = y      +
},            ?
function(g)   ?
   g()        +
end)          -
]])

      assert_linescan([[
local v = f({  +
   a = "foo",  ?
   x = y       +
}, function(g) ?
   g()         +
end)           -
]])
   end)

   it("supports inline 'enable' and 'disable' options", function()
      assert_linescan([[
outside()              +
-- luacov: enable      -
explicitly_enabled()   +
-- luacov: disable     -
disabled()             -
-- luacov: disable     -
still_disabled()       -
-- luacov: enable      -
enabled()              +
-- luacov: unknown     -
unknown_opts_ignored() +
]])
   end)
end)
