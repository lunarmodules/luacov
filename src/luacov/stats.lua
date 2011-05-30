
local M = {}

local statsfile = "luacov.stats.out"
local stats

function M.load()
   local data, most_hits = {}, 0
   stats = io.open(statsfile, "r")
   if not stats then
      return data
   end
   while true do
      local nlines = stats:read("*n")
      if not nlines then
         break
      end
      local skip = stats:read(1)
      if skip ~= ":" then
         break
      end
      local filename = stats:read("*l")
      if not filename then
         break
      end
      data[filename] = {
         max=nlines
      }
      for i = 1, nlines do
         local hits = stats:read("*n")
         if not hits then
            break
         end
         local skip = stats:read(1)
         if skip ~= " " then
            break
         end
         if hits > 0 then
            data[filename][i] = hits
            most_hits = math.max(most_hits, hits)
         end
      end
   end
   stats:close()
   return data, most_hits
end

function M.start()
   return io.open(statsfile, "w")
end

function M.stop(stats)
   stats:close()
end

function M.save(data, stats)
   stats:seek("set")
   for filename, filedata in pairs(data) do
      local max = filedata.max
      stats:write(filedata.max, ":", filename, "\n")
      for i = 1, max do
         local hits = filedata[i]
         if not hits then
            hits = 0
         end
         stats:write(hits, " ")
      end
      stats:write("\n")
   end
   stats:flush()
end

return M
