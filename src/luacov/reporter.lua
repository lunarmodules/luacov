------------------------
-- Report module, will transform statistics file into a report.
-- @class module
-- @name luacov.reporter
local reporter = {}

--- Utility function to make patterns more readable
local function fixup(pat)
   return pat:gsub(" ", " +")                  -- ' ' represents "at least one space"
             :gsub("=", " *= *")               -- '=' may be surrounded by spaces
             :gsub("%(", " *%%( *")            -- '(' may be surrounded by spaces
             :gsub("%)", " *%%) *")            -- ')' may be surrounded by spaces
             :gsub("<ID>", " *[%%w_]+ *")      -- identifier
             :gsub("<FULLID>", " *[%%w._]+ *") -- identifier
             :gsub("<BEGIN_LONG_STRING>", "%%[(=*)%%[[^]]* *")
             :gsub("<IDS>", "[%%w_, ]+")       -- comma-separated identifiers
             :gsub("<ARGS>", "[%%w_, \"'%%.]*") -- comma-separated arguments
             :gsub("<FIELDNAME>", "%%[? *[\"'%%w_]+ *%%]?") -- field, possibly like ["this"]
             :gsub(" %* ", " ")                -- collapse consecutive spacing rules
             :gsub(" %+ %*", " +")             -- collapse consecutive spacing rules
end

local long_string_1 = "^() *" .. fixup"<ID>=<BEGIN_LONG_STRING>$"
local long_string_2 = "^() *" .. fixup"local <ID>=<BEGIN_LONG_STRING>$"

local function check_long_string(line, in_long_string, ls_equals, linecount)
   local long_string
   if not linecount then
      if line:match("%[=*%[") then
         long_string, ls_equals = line:match(long_string_1)
         if not long_string then
            long_string, ls_equals = line:match(long_string_2)
         end
      end
   end
   ls_equals = ls_equals or ""
   if long_string then
      in_long_string = true
   elseif in_long_string and line:match("%]"..ls_equals.."%]") then
      in_long_string = false
   end
   return in_long_string, ls_equals or ""
end

--- Lines that are always excluded from accounting
local exclusions = {
   { false, "^#!" },     -- Unix hash-bang magic line
   { true, "" },         -- Empty line
   { true, fixup "end,?" },    -- Single "end"
   { true, fixup "else" },     -- Single "else"
   { true, fixup "repeat" },   -- Single "repeat"
   { true, fixup "do" },       -- Single "do"
   { true, fixup "while true do" }, -- "while true do" generates no code
   { true, fixup "if true then" }, -- "if true then" generates no code
   { true, fixup "local <IDS>" }, -- "local var1, ..., varN"
   { true, fixup "local <IDS>=" }, -- "local var1, ..., varN ="
   { true, fixup "local function(<ARGS>)" }, -- "local function(arg1, ..., argN)"
   { true, fixup "local function <ID>(<ARGS>)" }, -- "local function f (arg1, ..., argN)"
}

--- Lines that are only excluded from accounting when they have 0 hits
local hit0_exclusions = {
   { true, "[%w_,='\" ]+," }, -- "var1 var2," multi columns table stuff
   { true, fixup "<FIELDNAME>=.+," }, -- "[123] = 23," "['foo'] = "asd","
   { true, fixup "<ARGS>*function(<ARGS>)" }, -- "1,2,function(...)"
   { true, fixup "function(<ARGS>)" }, -- "local a = function(arg1, ..., argN)"
   { true, fixup "local <ID>=function(<ARGS>)" }, -- "local a = function(arg1, ..., argN)"
   { true, fixup "<FULLID>=function(<ARGS>)" }, -- "a = function(arg1, ..., argN)"
   { true, fixup "break" }, -- "break" generates no trace in Lua 5.2
   { true, "{" }, -- "{" opening table
   { true, "}" }, -- "{" closing table
   { true, fixup "})" }, -- function closer
   { true, fixup ")" }, -- function closer
}

local function excluded_(exclusions,line)
   for _, e in ipairs(exclusions) do
      if e[1] then
         if line:match("^ *"..e[2].." *$") or line:match("^ *"..e[2].." *%-%-") then return true end
      else
         if line:match(e[2]) then return true end
      end
   end
   return false
end

local function excluded(line, hits)
   return excluded_(exclusions, line)
      or (hits == 0 and excluded_(hit0_exclusions,line))
end

----------------------------------------------------------------
local ReporterBase = {} do
ReporterBase.__index = ReporterBase

function ReporterBase:new(conf)
   local stats = require("luacov.stats")

   stats.statsfile = conf.statsfile
   local data, most_hits = stats.load()

   if not data then
      return nil, "Could not load stats file " .. conf.statsfile .. ".", most_hits
   end

   local out, err = io.open(conf.reportfile, "w")
   if not out then return nil, err end

   local o = setmetatable({
      _out  = out;
      _cfg  = conf;
      _data = data;
      _mhit = most_hits;
   }, self)
  
  return o
end

function ReporterBase:config()
   return self._cfg
end

function ReporterBase:max_hits()
   return self._mhit
end

function ReporterBase:write(...)
   return self._out:write(...)
end

function ReporterBase:close()
   self._out:close()
   self._private = nil
end

local function norm_path(filename)
   -- normalize paths in patterns
   return (filename
      :gsub("\\", "/")
      :gsub("%.lua$", "")
   )
end

local function file_included(self, filename)
   local cfg = self._cfg
   if (not cfg.include) or (not cfg.include[1]) then
      return true
   end

   local path = norm_path(filename)

   for _, p in ipairs(cfg.include) do
      if path:match(p) then return true end
   end

   return false
end

local function file_excluded(self, filename)
   local cfg = self._cfg
   if (not cfg.exclude) or (not cfg.exclude[1]) then
     return false
   end

   local path = norm_path(filename)

   for _, p in ipairs(cfg.exclude) do
      if path:match(p) then return true end
   end

   return false
end

function ReporterBase:files()
   local data = self._data

   local names = {}
   for filename, _ in pairs(data) do
      if file_included(self,filename) and not file_excluded(self, filename) then
         names[#names + 1] = filename
      end
   end
   table.sort(names)

   return names
end

function ReporterBase:stats(filename)
   return self._data[filename]
end

function ReporterBase:on_start()
end

function ReporterBase:on_new_file(filename)
end

function ReporterBase:on_empty_line(filename, lineno, line)
end

function ReporterBase:on_mis_line(filename, lineno, line)
end

function ReporterBase:on_hit_line(filename, lineno, line, hits)
end

function ReporterBase:on_end_file(filename, hits, miss)
end

function ReporterBase:on_end()
end

function ReporterBase:run()
   self:on_start()

   for _, filename in ipairs(self:files()) do
      local file = io.open(filename, "r")
      local file_hits, file_miss = 0, 0
      local ok, err
      if file then ok, err = pcall(function() -- try
         self:on_new_file(filename)
         local filedata = self:stats(filename)

         local line_nr = 1
         local block_comment, equals = false, ""
         local in_long_string, ls_equals = false, ""

         while true do
            local line = file:read("*l")
            if not line then break end
            local true_line = line

            local new_block_comment = false
            if not block_comment then
               local l
               l, equals = line:match("^(.*)%-%-%[(=*)%[")
               if l then
                  line = l
                  new_block_comment = true
               end
               in_long_string, ls_equals = check_long_string(line, in_long_string, ls_equals, filedata[line_nr])
            else
               local l = line:match("%]"..equals.."%](.*)$")
               if l then
                  line = l
                  block_comment = false
               end
            end

            local hits = filedata[line_nr] or 0
            if block_comment or in_long_string or excluded(line, hits) then
               self:on_empty_line(filename, line_nr, true_line)
            else
               if hits == 0 then
                  self:on_mis_line(filename, line_nr, true_line)
                  file_miss = file_miss + 1
               else
                  self:on_hit_line(filename, line_nr, true_line, hits)
                  file_hits = file_hits + 1
               end
            end

            if new_block_comment then block_comment = true end

            line_nr = line_nr + 1
         end
      end) -- finally
         file:close()
         assert(ok, err)
         self:on_end_file(filename, file_hits, file_miss)
      end
   end

   self:on_end()
end

end
----------------------------------------------------------------

----------------------------------------------------------------
local DefaultReporter = setmetatable({}, ReporterBase) do
DefaultReporter.__index = DefaultReporter

function DefaultReporter:on_start()
   local most_hits = self:max_hits()
   local most_hits_length = #("%d"):format(most_hits)

   self._summary      = {}
   self._empty_format = (" "):rep(most_hits_length + 1)
   self._zero_format  = ("*"):rep(most_hits_length).."0"
   self._count_format = ("%% %dd"):format(most_hits_length+1)
end

function DefaultReporter:on_new_file(filename)
   self:write("\n")
   self:write("==============================================================================\n")
   self:write(filename, "\n")
   self:write("==============================================================================\n")
end

function DefaultReporter:on_empty_line(filename, lineno, line)
   self:write(self._empty_format, "\t", line, "\n")
end

function DefaultReporter:on_mis_line(filename, lineno, line)
   self:write(self._zero_format, "\t", line, "\n")
end

function DefaultReporter:on_hit_line(filename, lineno, line, hits)
   self:write(self._count_format:format(hits), "\t", line, "\n")
end

function DefaultReporter:on_end_file(filename, hits, miss)
   self._summary[filename] = { hits = hits, miss = miss }
end

function DefaultReporter:on_end()
   self:write("\n")
   self:write("==============================================================================\n")
   self:write("Summary\n")
   self:write("==============================================================================\n")
   self:write("\n")

   local function write_total(hits, miss, filename)
      local total = hits + miss
      if total == 0 then total = 1 end

      self:write(hits, "\t", miss, "\t", ("%.2f%%"):format(hits/(total)*100.0), "\t", filename, "\n")
   end

   local total_hits, total_miss = 0, 0
   for _, filename in ipairs(self:files()) do
      local s = self._summary[filename]
      if s then
         write_total(s.hits, s.miss, filename)
         total_hits = total_hits + s.hits
         total_miss = total_miss + s.miss
      end
   end
   self:write("------------------------\n")
   write_total(total_hits, total_miss, "")
end

end
----------------------------------------------------------------

function reporter.report(reporter_class)
   local luacov = require("luacov.runner")
   local configuration = luacov.load_config()

   reporter_class = reporter_class or DefaultReporter

   local rep, err = reporter_class:new(configuration)

   if not rep then
      print(err)
      print("Run your Lua program with -lluacov and then rerun luacov.")
      os.exit(1)
   end

   rep:run()

   rep:close()

   if configuration.deletestats then
      os.remove(configuration.statsfile)
   end
end

reporter.ReporterBase    = ReporterBase

reporter.DefaultReporter = DefaultReporter

return reporter
