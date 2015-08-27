-----------------------------------------------------
-- Manages the file with statistics (being) collected.
-- In general the module requires that its property <code>stats.statsfile</code>
-- has been set to the filename of the statsfile to create, load, etc.
-- @class module
-- @name luacov.stats
local stats = {}

-----------------------------------------------------
-- Loads the stats file.
-- @return table with data. The table maps filenames to stats tables.
-- Per-file tables map line numbers to hits or nils when there are no hits.
-- Additionally, .max field contains maximum line number
-- and .max_hits contains maximum number of hits in the file.
function stats.load()
   local data = {}
   local fd = io.open(stats.statsfile, "r")
   if not fd then
      return nil
   end
   while true do
      local max = fd:read("*n")
      if not max then
         break
      end
      local skip = fd:read(1)
      if skip ~= ":" then
         break
      end
      local filename = fd:read("*l")
      if not filename then
         break
      end
      data[filename] = {
         max = max,
         max_hits = 0
      }
      for i = 1, max do
         local hits = fd:read("*n")
         if not hits then
            break
         end
         local skip = fd:read(1)
         if skip ~= " " then
            break
         end
         if hits > 0 then
            data[filename][i] = hits
            data[filename].max_hits = math.max(data[filename].max_hits, hits)
         end
      end
   end
   fd:close()
   return data
end

--------------------------------
-- Opens the statfile
-- @return filehandle
function stats.start()
   return io.open(stats.statsfile, "w")
end

--------------------------------
-- Closes the statfile
-- @param fd filehandle to the statsfile
function stats.stop(fd)
   fd:close()
end

--------------------------------
-- Saves data to the statfile
-- @param data data to store
-- @param fd filehandle where to store
function stats.save(data, fd)
   fd:seek("set")
   for filename, filedata in pairs(data) do
      local max = filedata.max
      fd:write(max, ":", filename, "\n")
      for i = 1, max do
         local hits = filedata[i]
         if not hits then
            hits = 0
         end
         fd:write(hits, " ")
      end
      fd:write("\n")
   end
   fd:flush()
end

return stats
