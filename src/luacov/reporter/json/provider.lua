local BaseProvider = {}
BaseProvider.__index = BaseProvider

function BaseProvider.load_provider(name)
   assert(type(name) == "string", "`name' must be a string referencing the json provider")
   local ok, provider_class = pcall(require, "luacov.reporter.json.providers." .. name)
   if not ok then
      return false, "Failed to load " .. name
   end
   return true, provider_class:new()
end

function BaseProvider:new()
   return setmetatable({}, self)
end

function BaseProvider:create_array() --luacheck: no self
   error("This is an abstract method. Please, implement the creation of arrays.")
end

function BaseProvider:create_object() --luacheck: no self
   error("This is an abstract method. Please, implement the creation of plain objects.")
end

function BaseProvider:encode(o) --luacheck: no unused args
   error("This is an abstract method. Please, implement the encoding.")
end

return BaseProvider