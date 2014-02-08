package = "LuaCov"
version = "0.5-1"
source = {
   url = "git://github.com/keplerproject/luacov",
   tag = "v0.5"
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
   homepage = "http://keplerproject.github.com/luacov/",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      luacov = "src/luacov.lua",
      ['luacov.defaults'] = "src/luacov/defaults.lua",
      ['luacov.reporter'] = "src/luacov/reporter.lua",
      ['luacov.runner'] = "src/luacov/runner.lua",
      ['luacov.stats'] = "src/luacov/stats.lua",
      ['luacov.tick'] = "src/luacov/tick.lua"
   },
   install = {
      bin = {
         luacov = "src/bin/luacov"
      }
   }
}
