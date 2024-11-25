local util = require("luacov.util")

describe("Util", function()
   describe("pathjoin", function()
      it("smoke", function()
         local get_dir_sep_origin = util.get_dir_sep
         finally(function()
            util.get_dir_sep = get_dir_sep_origin
         end)

         util.get_dir_sep = function()
            return "-"
         end

         local res = util.pathjoin("too", "foo")
         assert.equals(res, 'too-foo')
      end)
   end)

   describe("is_dir", function()
      it("is dir", function()
         local filename = util.pathjoin(util.get_cur_dir(), "src")
         local res = util.is_dir(filename)
         assert.truthy(res)
      end)

      it("is file", function()
         local filename = util.pathjoin(util.get_cur_dir(), "README.md")
         local res = util.is_dir(filename)
         assert.falsy(res)
      end)
   end)

   describe("listdir", function()
      it("smoke", function()
         local path = util.pathjoin(util.get_cur_dir(), "src", "luacov", "reporter")
         local res = util.listdir(path)
         table.sort(res)

         assert.same(res, {"default.lua", "html", "html.lua"})
      end)
   end)

   describe("string_ends_with", function()
      it("match at the end", function()
         local res = util.string_ends_with("too foo bar", "bar")
         assert.truthy(res)
      end)

      it("match at the beginning", function()
         local res = util.string_ends_with("too foo bar", "too")
         assert.falsy(res)
      end)

      it("match at the middle", function()
         local res = util.string_ends_with("too foo bar", "foo")
         assert.falsy(res)
      end)

      it("mismatch", function()
         local res = util.string_ends_with("too foo bar", "abc")
         assert.falsy(res)
      end)

      it("search is empty", function()
         local res = util.string_ends_with("too foo bar", "")
         assert.truthy(res)
      end)

      it("empty source", function()
         local res = util.string_ends_with("", "hello")
         assert.falsy(res)
      end)

      it("empty all", function()
         local res = util.string_ends_with("", "")
         assert.truthy(res)
      end)
   end)
end)
