---------------------------------------------------
-- Statistics collecting module.
-- Calling the module table is a shortcut to calling the <code>init()</code> method.
-- @class module
-- @name luacov.runner

local M = {}

local stats = require("luacov.stats")
M.defaults = require("luacov.defaults")

local unpack   = unpack or table.unpack
local pack     = table.pack or function(...) return { n = select('#', ...), ... } end

local data
local statsfile
local tick
local ctr = 0
local luacovlock = os.tmpname()

local filelist = {}
M.filelist = filelist

local function on_line(_, line_nr)
   if tick then
      ctr = ctr + 1
      if ctr == 100 then
         ctr = 0
         stats.save(data, statsfile)
      end
   end

   -- get name of processed file; ignore Lua code loaded from raw strings
   local name = debug.getinfo(2, "S").source
   if not name:match("^@") then
      return
   end
   name = name:sub(2)

   local r = filelist[name]
   if r == nil then  -- unknown file, check our in/exclude lists
      local include = false
      -- normalize paths in patterns
      local path = name:gsub("\\", "/"):gsub("%.lua$", "")
      if not M.configuration.include[1] then
         include = true  -- no include list --> then everything is included by default
      else
         include = false
         for _, p in ipairs(M.configuration.include or {}) do
            if path:match(p) then
               include = true
               break
            end
         end
      end
      if include and M.configuration.exclude[1] then
         for _, p in ipairs(M.configuration.exclude) do
            if path:match(p) then
               include = false
               break
            end
         end
      end
      if include then r = true else r = false end
      filelist[name] = r
   end
   if r == false then
     return  -- do not include
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

local function run_report()
  local success, error = pcall(function() require("luacov.reporter").report() end)
  if not success then
    print ("LuaCov reporting error; "..tostring(error))
  end
end

local function on_exit()
   os.remove(luacovlock)
   stats.save(data, statsfile)
   stats.stop(statsfile)

   if M.configuration.runreport then run_report() end
end

------------------------------------------------------
-- Loads a valid configuration.
-- @param configuration user provided config (config-table or filename)
-- @return existing configuration if already set, otherwise loads a new
-- config from the provided data or the defaults
function M.load_config(configuration)
  if not M.configuration then
    if not configuration then
      -- nothing provided, try and load from defaults
      local success
      success, configuration = pcall(dofile, M.defaults.configfile)
      if not success then
        configuration = M.defaults
      end
    elseif type(configuration) == "string" then
      configuration = dofile(configuration)
    elseif type(configuration) == "table" then
      -- do nothing
    else
      error("Expected filename, config table or nil. Got " .. type(configuration))
    end
    M.configuration = configuration
  end
  return M.configuration
end

--------------------------------------------------
-- Initializes LuaCov runner to start collecting data.
-- @param configuration if string, filename of config file (used to call <code>load_config</code>).
-- If table then config table (see file <code>luacov.default.lua</code> for an example)
function M.init(configuration)
  M.configuration = M.load_config(configuration)

  stats.statsfile = M.configuration.statsfile

  data = stats.load() or {}
  statsfile = stats.start()
  M.statsfile = statsfile
  tick = package.loaded["luacov.tick"]

   if not tick then
      M.on_exit_trick = io.open(luacovlock, "w")
      debug.setmetatable(M.on_exit_trick, { __gc = on_exit } )
   end
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
   coroutine.wrap = function(...)
      local co = rawcoroutinecreate(...)
      debug.sethook(co, on_line, "l")
      return function()
         local r = { coroutine.resume(co) }
         if not r[1] then
            error(r[2])
         end
         return unpack(r, 2)
      end
   end

end

--------------------------------------------------
-- Shuts down LucCov's runner.
-- This should only be called from daemon processes or sandboxes which have
-- disabled os.exit and other hooks that are used to determine shutdown.
function M.shutdown()
  on_exit()
end

-- Returns true if the given filename exists
local fileexists = function(fname)
  local f = io.open(fname)
  if f then
    f:close()
    return true
  end
end

-- gets the sourcefilename from a function
-- @param func function to lookup (if nil, it returns nil)
-- @return nil when given nil, or nil when no sourcefile found
local getsourcefile = function(func)
  if func == nil then return nil end
  assert(type(func)=="function")
  local d = debug.getinfo(func).source
  if d and d:sub(1,1) == "@" then
    return d:sub(2,-1)
  end
end

-- @param name string;   filename,
--             string;   modulename as passed to require(),
--             function; where containing file is looked up,
--             table;    module table where containing file is looked up
local function getfilename(name)
  if type(name)=="function" then
    return getsourcefile(name)
  elseif type(name)=="table" then
    --lookup a function in the given table and return
    local recurse = {}
	local function ff(t)
	  if recurse[t] then return nil end
	  if type(t)=="function" then return t end
	  if type(t)~="table" then return nil end
	  for k,v in pairs(t) do
	    if type(v)=="function" then return v end
	    if type(v)=="table" then
	      recurse[t] = true
	      local result = ff(v)
	      if result then return result end
	    end
	  end
	  return nil -- no function found
	end
    return getsourcefile(ff(name))
  elseif type(name)=="string" and fileexists(name) then
    return name
  elseif type(name)=="string" then
    local success, result = pcall(require, name)
    if success then
      if type(result)=="table" or type(result)=="function" then
        return getfilename(result)
      else
        error("Module '" .. name .. "' did not return a result to lookup its file name")
      end
    else
      error("Module/file '" .. name .. "' was not found")
    end
  else
    error("Bad argument: "..tostring(name))
  end
end

-- Escape a filename, replacing all magic string pattern matches, ()+-*?[]
-- remove .lua extension, and replace dir seps by '/'.
-- Returns nil if given nil.
local escapefilename = function(name)
  if name == nil then return nil end
  return name:gsub("%.lua$", ""):gsub("%.","%%%."):gsub("\\", "/"):gsub("%(","%%%("):gsub("%)","%%%)"):gsub("%+","%%%+"):gsub("%*","%%%*"):gsub("%-","%%%-"):gsub("%?","%%%?"):gsub("%[","%%%["):gsub("%]","%%%]")
end

local function addfiletolist(name, list)
  local f = "^"..escapefilename(getfilename(name)).."$"
  table.insert(list, f)
  return f
end

local function addtreetolist(name, level, list)
  local f = escapefilename(getfilename(name))
  if level or f:match("/init$") then
    local cpos, pos = 0, nil
    while true do
      pos = f:find("/", cpos+1, true)
      if not pos then break end
      cpos = pos
    end
    f = f:sub(1,cpos-1)   -- chop last part...
  end
  local t = "^"..f.."/"   -- the tree behind the file
  f = "^"..f.."$"         -- the file
  table.insert(list, f)
  table.insert(list, t)
  return f, t
end

-- returns a pcall result, with the initial 'true' value removed
local function checkresult(...)
  local t = pack(...)
  if t[1] then
    return unpack(t, 2, t.n)   -- success, strip 'true' value
  else
    return nil, unpack(t, 2, t.n) -- failure; nil + error
  end
end

-------------------------------------------------------------------
-- Adds a file to the exclude list (see <code>defaults.lua</code>).
-- If passed a function, then through debuginfo the source filename is collected. In case of a table
-- it will recursively search teh table for a function, which is then resolved to a filename through debuginfo.
-- If the parameter is a string, it will first check if a file by that name exists. If it doesn't exist
-- it will call <code>require(name)</code> to load a module by that name, and the result of require (function or
-- table expected) is used as described above to get the sourcefile.
-- @param name string;   literal filename,
--             string;   modulename as passed to require(),
--             function; where containing file is looked up,
--             table;    module table where containing file is looked up
-- @return the pattern as added to the list, or nil + error
function M.excludefile(name)
  return checkresult(pcall(addfiletolist, name, M.configuration.exclude))
end
-------------------------------------------------------------------
-- Adds a file to the include list (see <code>defaults.lua</code>).
-- @param name see <code>excludefile</code>
-- @return the pattern as added to the list, or nil + error
function M.includefile(name)
  return checkresult(pcall(addfiletolist, name, M.configuration.include))
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
function M.excludetree(name, level)
  return checkresult(pcall(addtreetolist, name, level, M.configuration.exclude))
end
-------------------------------------------------------------------
-- Adds a tree to the include list (see <code>defaults.lua</code>).
-- @param name see <code>excludefile</code>
-- @param level see <code>includetree</code>
-- @return the 2 patterns as added to the list (file and tree), or nil + error
function M.includetree(name, level)
  return checkresult(pcall(addtreetolist, name, level, M.configuration.include))
end


return setmetatable(M, { ["__call"] = function(self, configfile) M.init(configfile) end })
