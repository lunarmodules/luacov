package = "luacov"
version = "scm-1"
source = {
   url = "git+https://github.com/lunarmodules/luacov.git",
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
   homepage = "https://lunarmodules.github.io/luacov/",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "datafile",
}
build = {
   type = "builtin",
   modules = {
      luacov = "src/luacov.lua",
      ["luacov.defaults"] = "src/luacov/defaults.lua",
      ["luacov.hook"] = "src/luacov/hook.lua",
      ["luacov.linescanner"] = "src/luacov/linescanner.lua",
      ["luacov.reporter"] = "src/luacov/reporter.lua",
      ["luacov.reporter.default"] = "src/luacov/reporter/default.lua",
      ["luacov.reporter.html"] = "src/luacov/reporter/html.lua",
      ["luacov.reporter.html.template"] = "src/luacov/reporter/html/template.lua",
      ["luacov.runner"] = "src/luacov/runner.lua",
      ["luacov.stats"] = "src/luacov/stats.lua",
      ["luacov.tick"] = "src/luacov/tick.lua",
      ["luacov.util"] = "src/luacov/util.lua"
   },
   install = {
      bin = {
         luacov = "src/bin/luacov"
      },
   },
   copy_directories = {
      "src/luacov/reporter/html/static",
   },
}
