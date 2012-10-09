package = "LuaCov"
version = "0.3-1"
source = {
   url = "http://luaforge.net/frs/download.php/4053/luacov-0.3.tar.gz"
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
   license = "MIT/X11",
   homepage = "http://luacov.luaforge.net/"
}
dependencies = {
   "lua >= 5.0",
}
build = {
  type = "builtin",
  modules = {
    ["luacov.defaults"] = "src/luacov/defaults.lua",
    ["luacov.init"] = "src/luacov/init.lua",
    ["luacov.reporter"] = "src/luacov/reporter.lua",
    ["luacov.runner"] = "src/luacov/runner.lua",
    ["luacov.stats"] = "src/luacov/stats.lua",
    ["luacov.tick"] = "src/luacov/tick.lua",
  },
  install = {
    bin = {
      ["luacov"] = "src/bin/luacov",
      ["luacov.bat"] = "src/bin/luacov.bat",
      ["luacov_bootstrap"] = "src/bin/luacov_bootstrap"
    }
  }
}
