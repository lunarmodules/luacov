local luacov_json_provider = require("luacov.reporter.json.provider")
local cjson = require("cjson")

local CJsonProvider = setmetatable({}, luacov_json_provider)
CJsonProvider.__index = CJsonProvider

function CJsonProvider:create_array() --luacheck: no self
   return setmetatable({}, cjson.array_mt)
end

function CJsonProvider:create_object() --luacheck: no self
   return {}
end

function CJsonProvider:encode(o) --luacheck: no self
   return cjson.encode(o)
end

return CJsonProvider