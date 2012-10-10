-----------------------------------------------------
-- Manages the file with statistics (being) collected.
-- In general the module requires that its property <code>stats.statsfile</code>
-- has been set to the filename of the statsfile to create, load, etc.
-- @class module
-- @name luacov.stats
local M = {}

-----------------------------------------------------
-- Loads the stats file.
-- @return table with data
-- @return hitcount of the line with the most hits (to provide the widest number format for reporting)
function M.load()
   local data, most_hits = {}, 0
   local stats = io.open(M.statsfile, "r")
   if not stats then
      return nil
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

--------------------------------
-- Opens the statfile
-- @return filehandle
function M.start()
   return io.open(M.statsfile, "w")
end

--------------------------------
-- Closes the statfile
-- @param stats filehandle to the statsfile
function M.stop(stats)
   stats:close()
end

--------------------------------
-- Saves data to the statfile
-- @param data data to store
-- @param stats filehandle where to store
function M.save(data, stats)
   stats:seek("set")
   for filename, filedata in pairs(data) do
      local max = filedata.max
      stats:write(max, ":", filename, "\n")
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
