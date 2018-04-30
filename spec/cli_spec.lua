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

local function exec(cmd)
   local status = os.execute(cmd)

   if type(status) == "number" then
      assert.is_equal(0, status)
   else
      assert.is_true(status)
   end
end

local function read_file(file)
   local handler = assert(io.open(file))
   local contents = assert(handler:read("*a"))
   handler:close()
   return contents
end

-- dir must be a subdir of spec/ containing expected.out or expected_file.
-- The file can contain 'X' to match any number of hits.
-- flags will be passed to luacov.
local function assert_cli(dir, enable_cluacov, expected_file, flags)
   local test_dir = "spec" .. dir_sep .. dir
   expected_file = expected_file or "expected.out"
   flags = flags or ""

   os.remove(test_dir .. dir_sep .. "luacov.stats.out")
   os.remove(test_dir .. dir_sep .. "luacov.report.out")

   finally(function()
      os.remove(test_dir .. dir_sep .. "luacov.stats.out")
      os.remove(test_dir .. dir_sep .. "luacov.report.out")
   end)

   local init_lua = "package.path=[[?.lua;../../src/?.lua;]]..package.path; corowrap = coroutine.wrap"
   init_lua = init_lua:gsub("/", dir_sep)

   if not enable_cluacov then
      init_lua = init_lua .. "; package.preload[ [[cluacov.version]] ] = error"
   end

   exec(("cd %q && %q -e %q -lluacov test.lua"):format(test_dir, lua, init_lua))

   local luacov_path = ("../../src/bin/luacov"):gsub("/", dir_sep)
   exec(("cd %q && %q -e %q %s %s"):format(test_dir, lua, init_lua, luacov_path, flags))

   expected_file = test_dir .. dir_sep .. expected_file
   local expected = read_file(expected_file)

   local actual_file = test_dir .. dir_sep .. "luacov.report.out"
   local actual = read_file(actual_file)

   local expected_pattern = "^" .. expected:gsub("%p", "%%%0"):gsub("X", "%%d+") .. "$"

   assert.does_match(expected_pattern, actual)
end

local function register_cli_tests(enable_cluacov)
   describe(enable_cluacov and "cli with cluacov" or "cli without cluacov", function()
      if enable_cluacov and not pcall(require, "cluacov.version") then
         pending("cluacov not found", function() end)
         return
      end

      it("handles simple files", function()
         assert_cli("simple", enable_cluacov)
      end)

      it("handles files with shebang", function()
         assert_cli("shebang", enable_cluacov)
      end)

      it("handles configs using file filtering", function()
         assert_cli("filefilter", enable_cluacov)
         assert_cli("filefilter", enable_cluacov, "expected2.out", "-c 2.luacov")
      end)

      it("handles files using coroutines", function()
         assert_cli("coroutines", enable_cluacov)
      end)

      it("handles files wrapping luacov debug hook", function()
         assert_cli("hook", enable_cluacov)
      end)

      it("handles files that execute other files with luacov", function()
         assert_cli("nested", enable_cluacov)
      end)

      if enable_cluacov then
         it("handles line filtering cases solved only by cluacov", function()
            assert_cli("cluacov", enable_cluacov)
         end)
      end
   end)
end

register_cli_tests(false)
register_cli_tests(true)
