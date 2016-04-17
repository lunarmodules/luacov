------------------------
-- Report module, will transform statistics file into a report.
-- @class module
-- @name luacov.reporter
local reporter = {}

local luacov = require("luacov.runner")

-- Raw version of string.gsub
local function replace(s, old, new)
   old = old:gsub("%p", "%%%0")
   new = new:gsub("%%", "%%%%")
   return (s:gsub(old, new))
end

local fixups = {
   { "=", " ?= ?" }, -- '=' may be surrounded by spaces
   { "(", " ?%( ?" }, -- '(' may be surrounded by spaces
   { ")", " ?%) ?" }, -- ')' may be surrounded by spaces
   { "<ID>", "[%w_]+" }, -- identifier
   { "<FULLID>", "[%w_]+[%[%.]?[%w_']*%]?" }, -- identifier, possibly indexed once
   { "<IDS>", "[%w_ ]+,[%w_, ]+" }, -- at least two comma-separated identifiers
   { "<ARGS>", "[%w_, '%.]*" }, -- comma-separated arguments
   { "<FIELDNAME>", "%[? ?['%w_]+ ?%]?" }, -- field, possibly like ["this"]
   { "<PARENS>", "[ %(]*" }, -- optional opening parentheses
}

-- Utility function to make patterns more readable
local function fixup(pat)
   for _, fixup_pair in ipairs(fixups) do
      pat = replace(pat, fixup_pair[1], fixup_pair[2])
   end

   return pat
end

--- Lines that are always excluded from accounting
local any_hits_exclusions = {
   "", -- Empty line
   "end[,; %)]*", -- Single "end"
   "else", -- Single "else"
   "repeat", -- Single "repeat"
   "do", -- Single "do"
   "if", -- Single "if"
   "then", -- Single "then"
   "while true do", -- "while true do" generates no code
   "if true then", -- "if true then" generates no code
   fixup "local <ID>", -- "local var"
   fixup "local <ID>=", -- "local var ="
   fixup "local <IDS>", -- "local var1, ..., varN"
   fixup "local <IDS>=", -- "local var1, ..., varN ="
   fixup "local function <ID>", -- "local function f (arg1, ..., argN)"
}

--- Lines that are only excluded from accounting when they have 0 hits
local zero_hits_exclusions = {
   "[%w_,=' ]+,", -- "var1 var2," multi columns table stuff
   fixup "<FIELDNAME>=.+[,;]", -- "[123] = 23," "['foo'] = "asd","
   fixup "<FIELDNAME>=function", -- "[123] = function(...)"
   fixup "<FIELDNAME>=<PARENS>'", -- "[123] = [[", possibly with opening parens
   "return function", -- "return function(arg1, ..., argN)"
   "function", -- "function(arg1, ..., argN)"
   fixup "local <ID>=function", -- "local a = function(arg1, ..., argN)"
   fixup "local <ID>=<PARENS>'", -- "local a = [[", possibly with opening parens
   fixup "local <ID>=nil", -- "local a = nil; local b = nil" produces no trace for the second statement
   fixup "<FULLID>=<PARENS>'", -- "a.b = [[", possibly with opening parens
   fixup "<FULLID>=function", -- "a = function(arg1, ..., argN)"
   "} ?,", -- "}," generates no trace if the table ends with a key-value pair
   "} ?, ?function", -- same with "}, function(...)"
   "break", -- "break" generates no trace in Lua 5.2+
   "{", -- "{" opening table
   "}?[ %)]*", -- optional "{" closing table, possibly with several closing parens
}

local function excluded(exclusions, line)
   for _, e in ipairs(exclusions) do
      if line:match("^ *"..e.." *$") then
         return true
      end
   end

   return false
end

local LineScanner = {} do
LineScanner.__index = LineScanner

function LineScanner:new()
   return setmetatable({first = true, comment = false, after_function = false}, self)
end

function LineScanner:find(pattern)
   return self.line:find(pattern, self.i)
end

-- Skips string literal with quote stored as self.quote.
-- @return boolean indicating success.
function LineScanner:skip_string()
   -- Look for closing quote, possibly after even number of backslashes.
   local _, quote_i = self:find("^(\\*)%1"..self.quote)
   if not quote_i then
      _, quote_i = self:find("[^\\](\\*)%1"..self.quote)
   end

   if quote_i then
      self.i = quote_i + 1
      self.quote = nil
      table.insert(self.simple_line_buffer, "'")
      return true
   else
      return false
   end
end

-- Skips long string literal with equal signs stored as self.equals.
-- @return boolean indicating success.
function LineScanner:skip_long_string()
   local _, bracket_i = self:find("%]"..self.equals.."%]")

   if bracket_i then
      self.i = bracket_i + 1
      self.equals = nil

      if self.comment then
         self.comment = false
      else
         table.insert(self.simple_line_buffer, "'")
      end

      return true
   else
      return false
   end
end

-- Skips function arguments.
-- @return boolean indicating success.
function LineScanner:skip_args()
   local _, paren_i = self:find("%)")

   if paren_i then
      self.i = paren_i + 1
      self.args = nil
      return true
   else
      return false
   end
end

function LineScanner:skip_whitespace()
   local next_i = self:find("%S") or #self.line + 1

   if next_i ~= self.i then
      self.i = next_i
      table.insert(self.simple_line_buffer, " ")
   end
end

function LineScanner:skip_number()
   if self:find("^0[xX]") then
      self.i = self.i + 2
   end

   local _
   _, _, self.i = self:find("^[%x%.]*()")

   if self:find("^[eEpP][%+%-]") then
      -- Skip exponent, too.
      self.i = self.i + 2
      _, _, self.i = self:find("^[%x%.]*()")
   end

   -- Skip LuaJIT number suffixes (i, ll, ull).
   _, _, self.i = self:find("^[iull]*()")
   table.insert(self.simple_line_buffer, "0")
end

function LineScanner:skip_name()
   -- It is guaranteed that the first character matches "%a_".
   local _, _, name = self:find("^([%w_]*)")
   self.i = self.i + #name
   table.insert(self.simple_line_buffer, name)

   if name == "function" then
      -- This flag indicates that the next pair of parentheses (function args) must be skipped.
      self.after_function = true
   end
end

-- Consumes and analyzes a line.
-- @return boolean indicating whether line must be excluded.
-- @return boolean indicating whether line must be excluded if not hit.
function LineScanner:consume(line)
   if self.first then
      self.first = false

      if line:match("^#!") then
         -- Ignore Unix hash-bang magic line.
         return true, true
      end
   end

   self.line = line
   -- As scanner goes through the line, it puts its simplified parts into buffer.
   -- Identifiers and punctuation are preserved. Whitespace is replaced with single space.
   -- Literal strings are replaced with "''", so that a string literal
   -- containing special characters does not confuse exclusion rules.
   -- Numbers are replaced with "0".
   -- Function declaration arguments are removed.
   self.simple_line_buffer = {}
   self.i = 1

   while self.i <= #line do
      -- One iteration of this loop handles one token, where
      -- string literal start and end are considered distinct tokens.
      if self.quote then
         if not self:skip_string() then
            -- String literal ends on another line.
            break
         end
      elseif self.equals then
         if not self:skip_long_string() then
            -- Long string literal or comment ends on another line.
            break
         end
      elseif self.args then
         if not self:skip_args() then
            -- Function arguments end on another line.
            break
         end
      else
         self:skip_whitespace()

         if self:find("^%.%d") then
            self.i = self.i + 1
         end

         if self:find("^%d") then
            self:skip_number()
         elseif self:find("^[%a_]") then
            self:skip_name()
         else
            if self:find("^%-%-") then
               self.comment = true
               self.i = self.i + 2
            end

            local _, bracket_i, equals = self:find("^%[(=*)%[")
            if equals then
               self.i = bracket_i + 1
               self.equals = equals

               if not self.comment then
                  table.insert(self.simple_line_buffer, "'")
               end
            elseif self.comment then
               -- Simple comment, skip line.
               self.comment = false
               break
            else
               local char = line:sub(self.i, self.i)

               if char == "." then
                  -- Dot can't be saved as one character because of
                  -- ".." and "..." tokens and the fact that number literals
                  -- can start with one.
                  local _, _, dots = self:find("^(%.*)")
                  self.i = self.i + #dots
                  table.insert(self.simple_line_buffer, dots)
               else
                  self.i = self.i + 1

                  if char == "'" or char == '"' then
                     table.insert(self.simple_line_buffer, "'")
                     self.quote = char
                  elseif self.after_function and char == "(" then
                     -- This is the opening parenthesis of function declaration args.
                     self.after_function = false
                     self.args = true
                  else
                     -- Save other punctuation literally.
                     -- This inserts an empty string when at the end of line,
                     -- which is fine.
                     table.insert(self.simple_line_buffer, char)
                  end
               end
            end
         end
      end
   end

   local simple_line = table.concat(self.simple_line_buffer)
   return excluded(any_hits_exclusions, simple_line), excluded(zero_hits_exclusions, simple_line)
end

end

----------------------------------------------------------------
--- Basic reporter class stub.
-- Implements 'new', 'run' and 'close' methods required by `report`.
-- Provides some helper methods and stubs to be overridden by child classes.
-- @usage
-- local MyReporter = setmetatable({}, ReporterBase)
-- MyReporter.__index = MyReporter
-- function MyReporter:on_hit_line(...)
--    self:write(("File %s: hit line %s %d times"):format(...))
-- end
-- @type ReporterBase
local ReporterBase = {} do
ReporterBase.__index = ReporterBase

function ReporterBase:new(conf)
   local stats = require("luacov.stats")

   stats.statsfile = conf.statsfile
   local data = stats.load()

   if not data then
      return nil, "Could not load stats file " .. conf.statsfile .. "."
   end

   local files = {}
   local filtered_data = {}
   local max_hits = 0

   -- Several original paths can map to one real path,
   -- their stats should be merged in this case.
   for filename, file_stats in pairs(data) do
      if luacov.file_included(filename) then
         filename = luacov.real_name(filename)

         if filtered_data[filename] then
            luacov.update_stats(filtered_data[filename], file_stats)
         else
            table.insert(files, filename)
            filtered_data[filename] = file_stats
         end

         max_hits = math.max(max_hits, filtered_data[filename].max_hits)
      end
   end

   table.sort(files)

   local out, err = io.open(conf.reportfile, "w")
   if not out then return nil, err end

   local o = setmetatable({
      _out  = out,
      _cfg  = conf,
      _data = filtered_data,
      _files = files,
      _mhit = max_hits,
   }, self)
  
   return o
end

--- Returns configuration table.
-- @see luacov.defaults
function ReporterBase:config()
   return self._cfg
end

--- Returns maximum number of hits per line in all coverage data.
function ReporterBase:max_hits()
   return self._mhit
end

--- Writes strings to report file.
-- @param ... strings.
function ReporterBase:write(...)
   return self._out:write(...)
end

function ReporterBase:close()
   self._out:close()
   self._private = nil
end

--- Returns array of filenames to be reported.
function ReporterBase:files()
   return self._files
end

--- Returns coverage data for a file.
-- @param filename name of the file.
-- @see luacov.stats.load
function ReporterBase:stats(filename)
   return self._data[filename]
end

--- Stub method called before reporting.
function ReporterBase:on_start()
end

--- Stub method called before processing a file.
-- @param filename name of the file.
function ReporterBase:on_new_file(filename)
end

--- Stub method called for each empty source line
-- and other lines that can't be hit.
-- @param filename name of the file.
-- @param lineno line number.
-- @param line the line itself as a string.
function ReporterBase:on_empty_line(filename, lineno, line)
end

--- Stub method called for each missed source line.
-- @param filename name of the file.
-- @param lineno line number.
-- @param line the line itself as a string.
function ReporterBase:on_mis_line(filename, lineno, line)
end

--- Stub method called for each hit source line.
-- @param filename name of the file.
-- @param lineno line number.
-- @param line the line itself as a string.
-- @param hits number of times the line was hit. Should be positive.
function ReporterBase:on_hit_line(filename, lineno, line, hits)
end

--- Stub method called after a file has been processed.
-- @param filename name of the file.
-- @param hits total number of hit lines in the file.
-- @param miss total number of missed lines in the file.
function ReporterBase:on_end_file(filename, hits, miss)
end

--- Stub method called after reporting.
function ReporterBase:on_end()
end

function ReporterBase:run()
   self:on_start()

   for _, filename in ipairs(self:files()) do
      local file = io.open(filename, "r")

      if not file then
         print("Could not open file " .. filename)
      else
         self:on_new_file(filename)
         local file_hits, file_miss = 0, 0
         local filedata = self:stats(filename)

         local line_nr = 1
         local scanner = LineScanner:new()

         while true do
            local line = file:read("*l")
            if not line then break end

            local always_excluded, excluded_when_not_hit = scanner:consume(line)
            local hits = filedata[line_nr] or 0

            if always_excluded or (excluded_when_not_hit and hits == 0) then
               self:on_empty_line(filename, line_nr, line)
            elseif hits == 0 then
               self:on_mis_line(filename, line_nr, line)
               file_miss = file_miss + 1
            else
               self:on_hit_line(filename, line_nr, line, hits)
               file_hits = file_hits + 1
            end

            line_nr = line_nr + 1
         end

         file:close()
         self:on_end_file(filename, file_hits, file_miss)
      end
   end

   self:on_end()
end

end
--- @section end
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

--- Runs the report generator.
-- To load a config, use `luacov.runner.load_config` first.
-- @param[opt] reporter_class custom reporter class. Will be
-- instantiated using 'new' method with configuration
-- (see `luacov.defaults`) as the argument. It should
-- return nil + error if something went wrong.
-- After acquiring a reporter object its 'run' and 'close'
-- methods will be called.
-- The easiest way to implement a custom reporter class is to
-- extend `ReporterBase`.
function reporter.report(reporter_class)
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

reporter.LineScanner     = LineScanner

return reporter
