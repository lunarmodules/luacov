--- Loads <code>luacov.runner</code> and immediately starts it by calling the module table
-- without a configfile. It will use project defaults or, if not set, global defaults.
-- Usefull for calling from the commandline backward compatible with older versions
-- @class module
-- @name luacov
-- @example  lua -lluacov sometest.lua 
require("luacov.runner")()
