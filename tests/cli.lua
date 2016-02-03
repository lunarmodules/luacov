local lua = arg[-1] or "lua"
local slash = lua:find("/")

-- Correct lua path so that it can be used from test directories.
if slash and slash ~= 1 then
   lua = "../../" .. lua
end

local ntests = 0

local function exec(cmd)
   local err_msg = ("CLI test #%d failed (%s)"):format(ntests, cmd)
   local ok = assert(os.execute(cmd), err_msg)
   assert(ok == 0 or ok == true, err_msg)
end

local function read(file)
   local handler = assert(io.open(file))
   local contents = assert(handler:read("*a"))
   handler:close()
   return contents
end

-- dir must be a subdir of tests/ containing expected.out or expected_file.
-- The file can contain 'H' to match any number of hits.
-- flags will be passed to luacov.
local function test(dir, expected_file, flags)
   ntests = ntests + 1
   local test_dir = "tests/" .. dir
   expected_file = expected_file or "expected.out"
   flags = flags or ""

   os.remove(test_dir .. "/luacov.stats.out")
   os.remove(test_dir .. "/luacov.report.out")
   local init_lua = "package.path=[[?.lua;../../src/?.lua;]]..package.path; corowrap = coroutine.wrap"
   exec(("cd %q && %q -e %q -lluacov test.lua"):format(
      test_dir, lua, init_lua))
   exec(("cd %q && %q -e %q ../../src/bin/luacov %s"):format(
      test_dir, lua, init_lua, flags))

   expected_file = test_dir .. "/" .. expected_file
   local expected = read(expected_file)
   local actual_file = test_dir .. "/luacov.report.out"
   local actual = read(actual_file)

   local ok

   if expected:find("H") then
      local expected_pattern = expected:gsub("%p", "%%%0"):gsub("H", "%%d+")
      ok = actual:match("^" .. expected_pattern .. "$")
   else
      ok = actual == expected
   end

   assert(ok, ("CLI test #%d failed (%s ~= %s)"):format(ntests, actual_file, expected_file))
   os.remove(test_dir .. "/luacov.stats.out")
   os.remove(test_dir .. "/luacov.report.out")
end

test("simple")

test("filefilter")
test("filefilter", "expected2.out", "-c 2.luacov")

test("coroutines")

print(("%d CLI tests passed."):format(ntests))
