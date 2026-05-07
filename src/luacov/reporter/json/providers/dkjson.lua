local luacov_json_provider = require("luacov.reporter.json.provider")
local dkjson = require("dkjson")

local DKJsonProvider = setmetatable({}, luacov_json_provider)
DKJsonProvider.__index = DKJsonProvider

function DKJsonProvider:create_array() --luacheck: no self
   return setmetatable({}, { __jsontype = "array" })
end

function DKJsonProvider:create_object() --luacheck: no self
   return setmetatable({}, { __jsontype = "object" })
end

function DKJsonProvider:encode(o) --luacheck: no self
   return dkjson.encode(o)
end

return DKJsonProvider