
--- Load luacov using this if you want it to periodically 
-- save the stats file. This is useful if your script is
-- a daemon (ie, does not properly terminate.)
module("luacov.tick", package.seeall)

require("luacov")
