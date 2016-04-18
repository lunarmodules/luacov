local dir_sep = package.config:sub(1, 1)
-- Allow testing without installing.
package.path = "src" .. dir_sep .. "?.lua;"..package.path

local ntests = 0

-- files should map filenames to real filenames used in reporting
-- or to false if excluded.
local function test(config, files)
   ntests = ntests + 1

   local filenames = {}

   for file in pairs(files) do
      table.insert(filenames, file)
   end

   table.sort(filenames)

   package.loaded["luacov.runner"] = nil
   local runner = require("luacov.runner")
   runner.load_config(config)

   for _, filename in ipairs(filenames) do
      local expected = files[filename] and files[filename]:gsub("/", dir_sep)
      filename = filename:gsub("/", dir_sep)
      local actual = runner.file_included(filename) and runner.real_name(filename)

      if actual ~= expected then
         error(("File filtering test #%d failed!\nFile/expected/actual:\n%s %s %s"):format(
            ntests, filename, expected or "(excluded)", actual or "(excluded)"
         ), 0)
      end
   end
end

-- By default only luacov's own files are excluded.

test(nil, {
   ["foo.lua"] = "foo.lua",
   ["luacov/runner.lua"] = false
})

-- Inclusions and exclusions.

test({
   include = {"foo$", "bar$"}
}, {
   ["foo.lua"] = "foo.lua",
   ["path/bar.lua"] = "path/bar.lua",
   ["baz.lua"] = false
})

test({
   exclude = {"foo$", "bar$"}
}, {
   ["foo.lua"] = false,
   ["path/bar.lua"] = false,
   ["baz.lua"] = "baz.lua"
})

test({
   include = {"foo$", "bar$"},
   exclude = {"foo$", "baz$"}
}, {
   ["foo.lua"] = false,
   ["path/bar.lua"] = "path/bar.lua",
   ["path/baz.lua"] = false
})

-- Modules.

test({
   modules = {["foo"] = "src/foo.lua"}
}, {
   ["path/foo.lua"] = "src/foo.lua",
   ["bar.lua"] = false
})

test({
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

test({
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

-- Module priorities.

test({
   modules = {
      ["rock.*"] = "src",
      ["rock.foo"] = "foo.lua"
   }
}, {
   ["path/rock/foo.lua"] = "foo.lua",
   ["path/rock/bar.lua"] = "src/rock/bar.lua"
})

test({
   modules = {
      ["rock.*"] = "src",
      ["rock.*.*.*"] = "src"
   }
}, {
   ["path/rock/src/rock/foo.lua"] = "src/rock/foo.lua",
   ["path/rock/src/rock/foo/bar/baz.lua"] = "src/rock/foo/bar/baz.lua"
})

test({
   modules = {
      ["b"] = "b1.lua",
      ["a.b"] = "b2.lua"
   }
}, {
   ["path/b.lua"] = "b1.lua",
   ["path/a/b.lua"] = "b2.lua"
})

test({
   modules = {
      ["b"] = "b1.lua",
      ["c.b"] = "b2.lua"
   }
}, {
   ["path/b.lua"] = "b1.lua",
   ["path/c/b.lua"] = "b2.lua"
})

print(("%d file filtering tests passed."):format(ntests))
