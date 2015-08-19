---------------------------------------------------
-- Statistics collecting module.
-- Calling the module table is a shortcut to calling the <code>init()</code> method.
-- @class module
-- @name luacov.runner

local runner = {}

local stats = require("luacov.stats")
runner.defaults = require("luacov.defaults")

local debug = require("debug")

local new_anchor = newproxy or function() return {} end

-- Returns an anchor that runs fn when collected.
local function on_exit_wrap(fn)
   local anchor = new_anchor()
   debug.setmetatable(anchor, {__gc = fn})
   return anchor
end

local data
local statsfile
local tick
local paused = true
local ctr = 0

local filelist = {}
runner.filelist = filelist

-- Checks if a string matches at least one of patterns.
-- @param patterns array of patterns or nil
-- @param str string to match
-- @param on_empty return value in case of empty pattern array
local function match_any(patterns, str, on_empty)
   if not patterns or not patterns[1] then
      return on_empty
   end

   for _, pattern in ipairs(patterns) do
      if str:match(pattern) then
         return true
      end
   end

   return false
end

--------------------------------------------------
-- Uses LuaCov's configuration to check if a file is included for
-- coverage data collection.
-- @return true if file is included, false otherwise.
function runner.file_included(filename)
   -- Normalize file names before using patterns.
   filename = filename:gsub("\\", "/"):gsub("%.lua$", "")

   if filelist[filename] == nil then
      -- If include list is empty, everything is included by default.
      local included = match_any(runner.configuration.include, filename, true)
      -- If exclude list is empty, nothing is excluded by default.
      local excluded = match_any(runner.configuration.exclude, filename, false)
      filelist[filename] = included and not excluded
   end

   return filelist[filename]
end

local function on_line(_, line_nr)
   if tick then
      ctr = ctr + 1
      if ctr == runner.configuration.savestepsize then
         ctr = 0

         if not paused then
            stats.save(data, statsfile)
         end
      end
   end

   -- get name of processed file; ignore Lua code loaded from raw strings
   local name = debug.getinfo(2, "S").source
   if name:match("^@") then
      name = name:sub(2)
   elseif not runner.configuration.codefromstrings then
      return
   end

   if not runner.file_included(name) then
      return
   end

   local file = data[name]
   if not file then
      file = {max=0}
      data[name] = file
   end
   if line_nr > file.max then
      file.max = line_nr
   end
   file[line_nr] = (file[line_nr] or 0) + 1
end

------------------------------------------------------
-- Runs the reporter specified in configuration.
-- @param configuration if string, filename of config file (used to call <code>load_config</code>).
-- If table then config table (see file <code>luacov.default.lua</code> for an example).
-- If <code>configuration.reporter<code> is not set, runs the default reporter;
-- otherwise, it must be a module name in 'luacov.reporter' namespace.
-- The module must contain 'report' function, which is called without arguments.
function runner.run_report(configuration)
   configuration = runner.load_config(configuration)
   local reporter = "luacov.reporter"

   if configuration.reporter then
      reporter = reporter .. "." .. configuration.reporter
   end

   require(reporter).report()
end

local on_exit_run_once = false

local function on_exit()
   -- Lua >= 5.2 could call __gc when user call os.exit
   -- so this method could be called twice
   if on_exit_run_once then return end
   on_exit_run_once = true

   runner.pause()

   if runner.configuration.runreport then runner.run_report(runner.configuration) end
end

-- Returns true if the given filename exists.
local function file_exists(fname)
   local f = io.open(fname)

   if f then
      f:close()
      return true
   end
end

-- Sets configuration. If some options are missing, default values are used instead.
local function set_config(configuration)
   runner.configuration = {}

   for option, default_value in pairs(runner.defaults) do
      runner.configuration[option] = default_value
   end

   for option, value in pairs(configuration) do
      runner.configuration[option] = value
   end
end

------------------------------------------------------
-- Loads a valid configuration.
-- @param configuration user provided config (config-table or filename)
-- @return existing configuration if already set, otherwise loads a new
-- config from the provided data or the defaults.
-- When loading a new config, if some options are missing, default values
-- are used instead.
function runner.load_config(configuration)
   if not runner.configuration then
      if not configuration then
         -- nothing provided, load from default location if possible
         if file_exists(runner.defaults.configfile) then
            set_config(dofile(runner.defaults.configfile))
         else
            runner.configuration = runner.defaults
         end
      elseif type(configuration) == "string" then
         set_config(dofile(configuration))
      elseif type(configuration) == "table" then
         set_config(configuration)
      else
         error("Expected filename, config table or nil. Got " .. type(configuration))
      end
   end

   return runner.configuration
end

--------------------------------------------------
-- Pauses LuaCov's runner.
-- Saves collected data and stops, allowing other processes to write to
-- the same stats file. Data is still collected during pause.
function runner.pause()
   if paused then
      return
   end

   paused = true
   stats.save(data, statsfile)
   stats.stop(statsfile)
   -- Reset data, so that after resuming it could be added to data loaded
   -- from the stats file, possibly updated from another process.
   data = {}
end

--------------------------------------------------
-- Resumes LuaCov's runner.
-- Reloads stats file, possibly updated from other processes,
-- and continues saving collected data.
function runner.resume()
   if not paused then
      return
   end

   local loaded = stats.load() or {}

   if data then
      -- Merge collected and loaded data.
      for name, file in pairs(loaded) do
         if data[name] then
            data[name].max = math.max(data[name].max, file.max)

            -- Remove 'max' key so that it does not appear when iterating
            -- over 'file'.
            file.max = nil
            
            for line_nr, run_nr in pairs(file) do
               data[name][line_nr] = (data[name][line_nr] or 0) + run_nr
            end
         else
            data[name] = file
         end
      end
   else
      data = loaded
   end

   statsfile = stats.start()
   runner.statsfile = statsfile


   if not tick then
      -- As __gc hooks are called in reverse order of their creation,
      -- and stats file has a __gc hook closing it,
      -- the exit __gc hook writing data to stats file must be recreated
      -- after stats file is reopened.

      if runner.on_exit_trick then
         -- Deactivate previous handler.
         getmetatable(runner.on_exit_trick).__gc = nil
      end

      runner.on_exit_trick = on_exit_wrap(on_exit)
   end

   paused = false
end

--------------------------------------------------
-- Initializes LuaCov runner to start collecting data.
-- @param configuration if string, filename of config file (used to call <code>load_config</code>).
-- If table then config table (see file <code>luacov.default.lua</code> for an example)
function runner.init(configuration)
   runner.configuration = runner.load_config(configuration)
   stats.statsfile = runner.configuration.statsfile
   tick = package.loaded["luacov.tick"]
   runner.resume()

   -- metatable trick on filehandle won't work if Lua exits through
   -- os.exit() hence wrap that with exit code as well
   local rawexit = os.exit
   os.exit = function(...)
      on_exit()
      rawexit(...)
   end

   debug.sethook(on_line, "l")

   -- debug must be set for each coroutine separately
   -- hence wrap coroutine function to set the hook there
   -- as well
   local rawcoroutinecreate = coroutine.create
   coroutine.create = function(...)
      local co = rawcoroutinecreate(...)
      debug.sethook(co, on_line, "l")
      return co
   end

   -- Version of assert which handles non-string errors properly.
   local function safeassert(ok, ...)
      if ok then
         return ...
      else
         error(..., 0)
      end
   end

   coroutine.wrap = function(...)
      local co = rawcoroutinecreate(...)
      debug.sethook(co, on_line, "l")
      return function(...)
         return safeassert(coroutine.resume(co, ...))
      end
   end

end

--------------------------------------------------
-- Shuts down LuaCov's runner.
-- This should only be called from daemon processes or sandboxes which have
-- disabled os.exit and other hooks that are used to determine shutdown.
function runner.shutdown()
  on_exit()
end

-- Gets the sourcefilename from a function.
-- @param func function to lookup.
-- @return sourcefilename or nil when not found.
local function getsourcefile(func)
   assert(type(func) == "function")
   local d = debug.getinfo(func).source
   if d and d:sub(1, 1) == "@" then
      return d:sub(2)
   end
end

-- Looks for a function inside a table.
-- @param searched set of already checked tables.
local function findfunction(t, searched)
   if searched[t] then
      return
   end

   searched[t] = true

   for k, v in pairs(t) do
      if type(v) == "function" then
         return v
      elseif type(v) == "table" then
         local func = findfunction(v, searched)
         if func then return func end
      end
   end
end

-- Gets source filename from a file name, module name, function or table.
-- @param name string;   filename,
--             string;   modulename as passed to require(),
--             function; where containing file is looked up,
--             table;    module table where containing file is looked up
-- @raise error message if could not find source filename.
-- @return source filename.
local function getfilename(name)
   if type(name) == "function" then
      local sourcefile = getsourcefile(name)

      if not sourcefile then
         error("Could not infer source filename")
      end

      return sourcefile
   elseif type(name) == "table" then
      local func = findfunction(name, {})

      if not func then
         error("Could not find a function within " .. tostring(name))
      end

      return getfilename(func)
   else
      if type(name) ~= "string" then
         error("Bad argument: " .. tostring(name))
      end

      if file_exists(name) then
         return name
      end

      local success, result = pcall(require, name)

      if not success then
         error("Module/file '" .. name .. "' was not found")
      end

      if type(result) ~= "table" and type(result) ~= "function" then
         error("Module '" .. name .. "' did not return a result to lookup its file name")
      end

      return getfilename(result)
   end
end

-- Escapes a filename.
-- Escapes magic pattern characters, removes .lua extension
-- and replaces dir seps by '/'.
local function escapefilename(name)
   return name:gsub("%.lua$", ""):gsub("[%%%^%$%.%(%)%[%]%+%*%-%?]","%%%0"):gsub("\\", "/")
end

local function addfiletolist(name, list)
  local f = "^"..escapefilename(getfilename(name)).."$"
  table.insert(list, f)
  return f
end

local function addtreetolist(name, level, list)
   local f = escapefilename(getfilename(name))

   if level or f:match("/init$") then
      -- chop the last backslash and everything after it
      f = f:match("^(.*)/") or f
   end

   local t = "^"..f.."/"   -- the tree behind the file
   f = "^"..f.."$"         -- the file
   table.insert(list, f)
   table.insert(list, t)
   return f, t
end

-- Returns a pcall result, with the initial 'true' value removed
-- and 'false' replaced with nil.
local function checkresult(ok, ...)
   if ok then
      return ... -- success, strip 'true' value
   else
      return nil, ... -- failure; nil + error
   end
end

-------------------------------------------------------------------
-- Adds a file to the exclude list (see <code>defaults.lua</code>).
-- If passed a function, then through debuginfo the source filename is collected. In case of a table
-- it will recursively search the table for a function, which is then resolved to a filename through debuginfo.
-- If the parameter is a string, it will first check if a file by that name exists. If it doesn't exist
-- it will call <code>require(name)</code> to load a module by that name, and the result of require (function or
-- table expected) is used as described above to get the sourcefile.
-- @param name string;   literal filename,
--             string;   modulename as passed to require(),
--             function; where containing file is looked up,
--             table;    module table where containing file is looked up
-- @return the pattern as added to the list, or nil + error
function runner.excludefile(name)
  return checkresult(pcall(addfiletolist, name, runner.configuration.exclude))
end
-------------------------------------------------------------------
-- Adds a file to the include list (see <code>defaults.lua</code>).
-- @param name see <code>excludefile</code>
-- @return the pattern as added to the list, or nil + error
function runner.includefile(name)
  return checkresult(pcall(addfiletolist, name, runner.configuration.include))
end
-------------------------------------------------------------------
-- Adds a tree to the exclude list (see <code>defaults.lua</code>).
-- If <code>name = 'luacov'</code> and <code>level = nil</code> then
-- module 'luacov' (luacov.lua) and the tree 'luacov' (containing `luacov/runner.lua` etc.) is excluded.
-- If <code>name = 'pl.path'</code> and <code>level = true</code> then
-- module 'pl' (pl.lua) and the tree 'pl' (containing `pl/path.lua` etc.) is excluded.
-- NOTE: in case of an 'init.lua' file, the 'level' parameter will always be set
-- @param name see <code>excludefile</code>
-- @param level if truthy then one level up is added, including the tree
-- @return the 2 patterns as added to the list (file and tree), or nil + error
function runner.excludetree(name, level)
  return checkresult(pcall(addtreetolist, name, level, runner.configuration.exclude))
end
-------------------------------------------------------------------
-- Adds a tree to the include list (see <code>defaults.lua</code>).
-- @param name see <code>excludefile</code>
-- @param level see <code>includetree</code>
-- @return the 2 patterns as added to the list (file and tree), or nil + error
function runner.includetree(name, level)
  return checkresult(pcall(addtreetolist, name, level, runner.configuration.include))
end


return setmetatable(runner, { ["__call"] = function(self, configfile) runner.init(configfile) end })
