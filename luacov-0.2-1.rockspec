package = "LuaCov"
version = "0.2-1"
source = {
   url = "http://luaforge.net/frs/download.php/4053/luacov-0.2.tar.gz"
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
   type = "make",
   variables = {
      LUADIR = "$(LUADIR)",
      BINDIR = "$(BINDIR)"
   }
}
