package = "LuaCov"
version = "scm-1"
source = {
   url = "git://github.com/keplerproject/luacov",
}
description = {
   summary = "Coverage analysis tool for Lua scripts",
   detailed = [[
      LuaCov is a simple coverage analysis tool for Lua scripts.
      When a Lua script is run with the luacov module, it
      generates a stats file. The luacov command-line script then
      processes this file generating a report indicating which code
      paths were not traversed, which is useful for verifying the
      effectiveness of a test suite.
   ]],
   homepage = "http://keplerproject.github.io/luacov/",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1, < 5.4"
}
build = {
  type = "builtin",
  modules = {
    ["luacov.defaults"] = "src/luacov/defaults.lua",
    ["luacov"] = "src/luacov.lua",
    ["luacov.reporter"] = "src/luacov/reporter.lua",
    ["luacov.reporter.default"] = "src/luacov/reporter/default.lua",
    ["luacov.runner"] = "src/luacov/runner.lua",
    ["luacov.stats"] = "src/luacov/stats.lua",
    ["luacov.tick"] = "src/luacov/tick.lua",
    ["luacov.hook"] = "src/luacov/hook.lua",
    ["luacov.util"] = "src/luacov/util.lua"
  },
  install = {
    bin = {
      ["luacov"] = "src/bin/luacov",
    }
  }
}
