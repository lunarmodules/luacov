local dir_sep = package.config:sub(1, 1)

local function assert_filefilter(config, files)
   package.loaded["luacov.runner"] = nil
   local runner = require("luacov.runner")
   runner.load_config(config)

   local expected = {}
   local actual = {}

   for fname, expected_result in pairs(files) do
      expected_result = expected_result and expected_result:gsub("/", dir_sep)
      local filename = fname:gsub("/", dir_sep)
      local actual_result = runner.file_included(filename) and runner.real_name(filename)

      expected[filename] = expected_result
      actual[filename] = actual_result
   end

   assert.is_same(expected, actual)
end

describe("file filtering", function()
   it("excludes only luacov's own files by default", function()
      assert_filefilter(nil, {
         ["foo.lua"] = "foo.lua",
         ["luacov/runner.lua"] = false
      })
   end)

   it("includes only files matching include patterns", function()
      assert_filefilter({
         include = {"foo$", "bar$"}
      }, {
         ["foo.lua"] = "foo.lua",
         ["path/bar.lua"] = "path/bar.lua",
         ["baz.lua"] = false
      })
   end)

   it("excludes files matching exclude patterns", function()
      assert_filefilter({
         exclude = {"foo$", "bar$"}
      }, {
         ["foo.lua"] = false,
         ["path/bar.lua"] = false,
         ["baz.lua"] = "baz.lua"
      })
   end)

   it("prioritizes exclude patterns over include patterns", function()
      assert_filefilter({
         include = {"foo$", "bar$"},
         exclude = {"foo$", "baz$"}
      }, {
         ["foo.lua"] = false,
         ["path/bar.lua"] = "path/bar.lua",
         ["path/baz.lua"] = false
      })
   end)

   it("remaps paths according to module table", function()
      assert_filefilter({
         modules = {["foo"] = "src/foo.lua"}
      }, {
         ["path/foo.lua"] = "src/foo.lua",
         ["bar.lua"] = false
      })
   end)

   it("excludes modules matching exclude patterns", function()
      assert_filefilter({
         modules = {
            ["rock.foo"] = "src/rock/foo.lua",
            ["rock.bar"] = "src/rock/bar.lua",
            ["rock.baz"] = "src/rock/baz/init.lua"
         },
         exclude = {"bar$"}
      }, {
         ["path/rock/foo.lua"] = "src/rock/foo.lua",
         ["path/rock/bar.lua"] = false,
         ["path/rock/baz/init.lua"] = "src/rock/baz/init.lua"
      })
   end)

   it("supports wildcard modules but still excludes modules matching exclude patterns", function()
      assert_filefilter({
         modules = {
            ["rock"] = "src/rock.lua",
            ["rock.*"] = "src"
         },
         exclude = {"bar$"}
      }, {
         ["path1/rock.lua"] = "src/rock.lua",
         ["path2/rock/foo.lua"] = "src/rock/foo.lua",
         ["path3/rock/bar.lua"] = false
      })
   end)

   it("prioritizes explicit modules over wildcard modules when mapping filenames", function()
      assert_filefilter({
         modules = {
            ["rock.*"] = "src",
            ["rock.foo"] = "foo.lua"
         }
      }, {
         ["path/rock/foo.lua"] = "foo.lua",
         ["path/rock/bar.lua"] = "src/rock/bar.lua"
      })
   end)

   it("prioritizes shorter wildcard rules when mapping filenames", function()
      assert_filefilter({
         modules = {
            ["rock.*"] = "src",
            ["rock.*.*.*"] = "src"
         }
      }, {
         ["path/rock/src/rock/foo.lua"] = "src/rock/foo.lua",
         ["path/rock/src/rock/foo/bar/baz.lua"] = "src/rock/foo/bar/baz.lua"
      })
   end)

   it("prioritizes shorter explicit rules when mapping filenames", function()
      assert_filefilter({
         modules = {
            ["b"] = "b1.lua",
            ["a.b"] = "b2.lua"
         }
      }, {
         ["path/b.lua"] = "b1.lua",
         ["path/a/b.lua"] = "b2.lua"
      })

      assert_filefilter({
         modules = {
            ["b"] = "b1.lua",
            ["c.b"] = "b2.lua"
         }
      }, {
         ["path/b.lua"] = "b1.lua",
         ["path/c/b.lua"] = "b2.lua"
      })
   end)
end)
