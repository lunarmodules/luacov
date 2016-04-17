-----------------------------------------------------
-- Manages the file with statistics (being) collected.
-- @class module
-- @name luacov.stats
local stats = {}

-----------------------------------------------------
-- Loads the stats file.
-- @param statsfile path to the stats file.
-- @return table with data. The table maps filenames to stats tables.
-- Per-file tables map line numbers to hits or nils when there are no hits.
-- Additionally, .max field contains maximum line number
-- and .max_hits contains maximum number of hits in the file.
function stats.load(statsfile)
   local data = {}
   local fd = io.open(statsfile, "r")
   if not fd then
      return nil
   end
   while true do
      local max = fd:read("*n")
      if not max then
         break
      end
      if fd:read(1) ~= ":" then
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
         if fd:read(1) ~= " " then
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
-- Saves data to the statfile
-- @param statsfile path to the stats file.
-- @param data data to store
function stats.save(statsfile, data)
   local fd = io.open(statsfile, "w")

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
   fd:close()
end

return stats
