std = "min"

not_globals = {
   -- deprecated Lua 5.0 functions
   "string.len",
   "table.getn",
}

include_files = {
   "**/*.lua",
   "**/*.rockspec",
   ".busted",
   ".luacheckrc",
}

exclude_files = {
   "spec/*/*",
   "src/luacov/reporter/html/static/*.js",
   "src/luacov/reporter/html/static/*.css",

   -- The Github Actions Lua Environment
    ".lua",
    ".luarocks",
    ".install",
}

files["spec/**/*.lua"] = {
   std = "+busted",
}
