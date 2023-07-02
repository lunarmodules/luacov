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

local function check_status (status)
   if type(status) == "number" then
      assert.is_equal(0, status)
   else
      assert.is_true(status)
   end
end

local function exec(cmd, pre, post)

  if pre then
    check_status(os.execute(pre))
  end

  check_status(os.execute(cmd))

  if post then
    check_status(os.execute(post))
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
local function assert_cli(dir, enable_cluacov, expected_file, flags, configfp)

   local prefix = ""
   local precmd = nil
   local postcmd = nil

   if configfp and dir_sep == "\\" then
     precmd = ("setx LUACOV_CONFIG=%q"):format(configfp)
     postcmd = ("setx LUACOV_CONFIG="):format(configfp)
   elseif configfp then
     prefix = ("LUACOV_CONFIG=%q"):format(configfp)
   end

   local test_dir = "spec" .. dir_sep .. dir
   local _, nestingLevel = dir:gsub("/", "")

   expected_file = expected_file or "expected.out"
   flags = flags or ""

   os.remove(test_dir .. dir_sep .. "luacov.stats.out")
   os.remove(test_dir .. dir_sep .. "luacov.report.out")

   finally(function()
      os.remove(test_dir .. dir_sep .. "luacov.stats.out")
      os.remove(test_dir .. dir_sep .. "luacov.report.out")
   end)

   local src_path = string.rep("../", nestingLevel + 2) .. "src"
   local init_lua = "package.path=[[?.lua;" .. src_path .. "/?.lua;]]..package.path; corowrap = coroutine.wrap"
   init_lua = init_lua:gsub("/", dir_sep)

   if not enable_cluacov then
      init_lua = init_lua .. "; package.preload[ [[cluacov.version]] ] = error"
   end

   exec(("cd %q && %s %q -e %q -lluacov test.lua %s"):format(test_dir, prefix, lua, init_lua, flags), precmd, postcmd)

   local luacov_path = (src_path .. "/bin/luacov"):gsub("/", dir_sep)
   exec(("cd %q && %s %q -e %q %s %s"):format(test_dir, prefix, lua, init_lua, luacov_path, flags), precmd, postcmd)

   expected_file = test_dir .. dir_sep .. expected_file
   local expected = read_file(expected_file)

   local actual_file = test_dir .. dir_sep .. "luacov.report.out"
   local actual = read_file(actual_file)

   local expected_pattern = "^" .. expected:gsub("%p", "%%%0"):gsub("X", "%%d+"):gsub("%%%/", "[/\\\\]") .. "$"

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

      it("handles configs using directory filtering", function()
         assert_cli("dirfilter", enable_cluacov)
         assert_cli("dirfilter", enable_cluacov, "expected2.out", "-c 2.luacov")
         assert_cli("dirfilter", enable_cluacov, "expected3.out", "-c 3.luacov")
         assert_cli("dirfilter", enable_cluacov, "expected4.out", "-c 4.luacov")
      end)

      if not enable_cluacov then

         it("handles configs using including of untested files", function()
            assert_cli("includeuntestedfiles", enable_cluacov)
            assert_cli("includeuntestedfiles", enable_cluacov, "expected2.out", "-c 2.luacov")
            assert_cli("includeuntestedfiles", enable_cluacov, "expected3.out", "-c 3.luacov")
            assert_cli("includeuntestedfiles/subdir", enable_cluacov)
         end)

      end

      it("handles files using coroutines", function()
         assert_cli("coroutines", enable_cluacov)
      end)

      it("handles files wrapping luacov debug hook", function()
         assert_cli("hook", enable_cluacov)
      end)

      it("handles files that execute other files with luacov", function()
         assert_cli("nested", enable_cluacov)
      end)

      if enable_cluacov and _VERSION ~= "Lua 5.4" then
         it("handles line filtering cases solved only by cluacov", function()
            assert_cli("cluacov", enable_cluacov)
         end)
      end

      it("handles configs specified via LUACOV_CONFIG", function()
         assert_cli("LUACOV_CONFIG", enable_cluacov, nil, nil, "luacov.config.lua")
      end)

   end)
end

register_cli_tests(false)
register_cli_tests(true)
