---------------------------------------------------
-- Statistics collecting module.
-- @class module
-- @name luacov.runner

local M = {}

local stats = require("luacov.stats")
M.defaults = require("luacov.defaults")

local data
local statsfile
local tick
local ctr = 0
local luacovlock = os.tmpname()

local booting = true
local skip = {}
M.skip = skip

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

   -- skip 'luacov.lua' in coverage report
   if booting then
      skip[name] = true
      booting = false
   end

   if skip[name] then
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
-- Loads a valid configuration
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
-- Initializes LuaCov runner to start collecting data
-- @param configuration if string, filename of config file (used to call <code>load_config</code>).
-- If table then config table (see file <code>luacov.default.lua</code> for an example)
function init(configuration)
  M.configuration = M.load_config(configuration)

  stats.statsfile = M.configuration.statsfile

  data = stats.load()
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

return setmetatable(M, { ["__call"] = function(self, configfile) init(configfile) end })
