---------------------------------------------------
-- Utility module.
-- @class module
-- @name luacov.util
local util = {}

--- Library require
local lfs_ok, lfs = pcall(require, "lfs")
if not lfs_ok then
   error("The option includeuntestedfiles requires the lfs module (from luafilesystem) to be installed.")
end

--- Removes a prefix from a string if it's present.
-- @param str a string.
-- @param prefix a prefix string.
-- @return original string if does not start with prefix
-- or string without prefix.
function util.unprefix(str, prefix)
   if str:sub(1, #prefix) == prefix then
      return str:sub(#prefix + 1)
   else
      return str
   end
end

-- Returns contents of a file or nil + error message.
local function read_file(name)
   local f, open_err = io.open(name, "rb")

   if not f then
      return nil, util.unprefix(open_err, name .. ": ")
   end

   local contents, read_err = f:read("*a")
   f:close()

   if contents then
      return contents
   else
      return nil, read_err
   end
end

--- Loads a string.
-- @param str a string.
-- @param[opt] env environment table.
-- @param[opt] chunkname chunk name.
function util.load_string(str, env, chunkname)
   if _VERSION:find("5%.1") then
      local func, err = loadstring(str, chunkname) -- luacheck: compat

      if not func then
         return nil, err
      end

      if env then
         setfenv(func, env) -- luacheck: compat
      end

      return func
   else
      return load(str, chunkname, "bt", env or _ENV) -- luacheck: compat
   end
end

--- Load a config file.
-- Reads, loads and runs a Lua file in an environment.
-- @param name file name.
-- @param env environment table.
-- @return true and the first return value of config on success,
-- nil + error type + error message on failure, where error type
-- can be "read", "load" or "run".
function util.load_config(name, env)
   local src, read_err = read_file(name)

   if not src then
      return nil, "read", read_err
   end

   local func, load_err = util.load_string(src, env, "@config")

   if not func then
      return nil, "load", "line " .. util.unprefix(load_err, "config:")
   end

   local ok, ret = pcall(func)

   if not ok then
      return nil, "run", "line " .. util.unprefix(ret, "config:")
   end

   return true, ret
end

--- Checks if a file exists.
-- @param name file name.
-- @return true if file can be opened, false otherwise.
function util.file_exists(name)
   local f = io.open(name)

   if f then
      f:close()
      return true
   else
      return false
   end
end

--- Returns directory path separator
-- @return directory path separator
function util.get_dir_sep()
   local dir_sep = package.config:sub(1, 1)
   if not dir_sep:find("[/\\]") then
      dir_sep = "/"
   end

   return dir_sep
end

--- Returns current directory path
-- @return current directory path
function util.get_cur_dir()
   local dir_sep = util.get_dir_sep()
   return lfs.currentdir() .. dir_sep
end

--- Join multiple path components.
-- Concatenates multiple path components into a single path, using the appropriate directory separator.
-- @param first the first path component.
-- @param ... additional path components.
-- @return a single string representing the combined path.
function util.pathjoin(first, ...)
   local seconds = {...}
   local res = first
   local dir_sep = util.get_dir_sep()

   for _, s in ipairs(seconds) do
      if util.string_ends_with(res, dir_sep) then
         res = res .. s
      else
         res = res .. dir_sep .. s
      end
   end

   return res
end

--- Check if a path is a directory.
-- Determines whether the given path corresponds to a directory.
-- @param path the file system path to check.
-- @return true if the path is a directory, false otherwise.
function util.is_dir(path)
   local attr = lfs.attributes(path)
   return attr and attr.mode == "directory"
end

--- List files in a directory.
-- Retrieves a list of filenames in the specified directory, excluding "." and "..".
-- @param path the file system path of the directory to list.
-- @return a table containing the names of the files in the directory.
function util.listdir(path)
   local files = {}

   for filename in lfs.dir(path) do
      if filename ~= "." and filename ~= ".." then
         table.insert(files, filename)
      end
   end

   return files
end

--- Check if a string ends with a specified substring.
-- Determines whether the given string ends with the specified ending substring.
-- @param str the string to check.
-- @param ending the substring to look for at the end of the string.
-- @return true if the string ends with the specified substring, false otherwise.
function util.string_ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

return util
