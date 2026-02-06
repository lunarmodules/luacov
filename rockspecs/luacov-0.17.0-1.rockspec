local package_name = "luacov"
local package_version = "0.17.0"
local rockspec_revision = "1"
local github_account_name = "lunarmodules"
local github_repo_name = "luacov"


package = package_name
version = package_version.."-"..rockspec_revision

source = {
   url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
   branch = (package_version == "scm") and "master" or nil,
   tag = (package_version ~= "scm") and ("v"..package_version) or nil,
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
   homepage = "https://"..github_account_name..".github.io"..github_repo_name.."/",
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
