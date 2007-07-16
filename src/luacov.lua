
module("luacov", package.seeall)

local stats = require("luacov.stats")

data = stats.load_stats()

statsfile = stats.start_stats()

tick = package.loaded["luacov.tick"]
ctr = 0

local function on_line(_, line_nr)
   if tick then
      ctr = ctr + 1
      if ctr == 100 then
         ctr = 0
         stats.save_stats(data, statsfile)
      end
   end

   local name = debug.getinfo(2, "S").short_src
   local file = data[name]
   if not file then
      file = {}
      file.max = 0
      data[name] = file
   end
   if line_nr > file.max then
      file.max = line_nr
   end
   local current = file[line_nr]
   if not current then
      file[line_nr] = 1
   else
      file[line_nr] = current + 1
   end
end

local luacovlock = os.tmpname()

function on_exit()
   os.remove(luacovlock)
   stats.save_stats(data, statsfile)
   stats.stop_stats(statsfile)
end

if not tick then
   on_exit_trick = io.open(luacovlock, "w")
   debug.setmetatable(on_exit_trick, { __gc = on_exit } )
end

debug.sethook(on_line, "l")
