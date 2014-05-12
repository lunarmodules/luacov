package = "LuaCov"
version = "scm-mot-1"
source = {
   url = "git://github.com/moteus/luacov",
   branch = "moteus",
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
   homepage = "http://luacov.luaforge.net/",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["luacov"                  ] = "src/luacov.lua",
    ["luacov.defaults"         ] = "src/luacov/defaults.lua",
    ["luacov.reporter"         ] = "src/luacov/reporter.lua",
    ["luacov.reporter.default" ] = "src/luacov/reporter/.default.lua",
    ["luacov.runner"           ] = "src/luacov/runner.lua",
    ["luacov.stats"            ] = "src/luacov/stats.lua",
    ["luacov.tick"             ] = "src/luacov/tick.lua",
  },
  install = {
    bin = {
      ["luacov"] = "src/bin/luacov",
    }
  }
}