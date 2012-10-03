--- Loads luacov and immediately starts it by calling the module table
-- without a configfile
-- usefull for calling from the commandline backward compatible;
--   lua -lluacov sometest.lua 
require("luacov.runner")()
