#!/usr/bin/env lua

local luacov = require("luacov.stats")

local data = luacov.load_stats()

if not data then
   print("Could not load stats file "..luacov.statsfile..".")
   print("Run your Lua program with -lluacov and then rerun luacov.")
   os.exit(1)
end

local report = io.open("luacov.report.out", "w")

local names = {}
for filename, _ in pairs(data) do
   table.insert(names, filename)
end

table.sort(names)

for _, filename in ipairs(names) do
   local filedata = data[filename]
   local file = io.open(filename, "r")
   if file then
      report:write("\n")
      report:write("==============================================================================\n")
      report:write(filename, "\n")
      report:write("==============================================================================\n")
      local line_nr = 1
      while true do
         local line = file:read("*l")
         if not line then break end
         if line:match("^%s*%-%-") -- Comment line
         or line:match("^%s*$")    -- Empty line
         or line:match("^%s*end,?%s*$") -- Single "end"
         or line:match("^%s*else%s*$") -- Single "else"
         or line:match("^#!") -- Unix hash-bang magic line
         then
            report:write("\t", line, "\n")
         else
            local hits = filedata[line_nr]
            if not hits then hits = 0 end
            report:write(hits, "\t", line, "\n")
         end
         line_nr = line_nr + 1
      end
   end
end
