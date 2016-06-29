------------------------
-- Report module, will transform statistics file into a report.
-- @class module
-- @name luacov.reporter
local reporter = {}

local luacov = require("luacov.runner")
local util = require("luacov.util")

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
   { "<FULLID>", "x ?[%[%.]? ?[ntfx0']* ?%]?" }, -- identifier, possibly indexed once
   { "<IDS>", "x ?, ?x[x, ]*" }, -- at least two comma-separated identifiers
   { "<FIELDNAME>", "%[? ?[ntfx0']+ ?%]?" }, -- field, possibly like ["this"]
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
   "while t do", -- "while true do" generates no code
   "if t then", -- "if true then" generates no code
   "local x", -- "local var"
   fixup "local x=", -- "local var ="
   fixup "local <IDS>", -- "local var1, ..., varN"
   fixup "local <IDS>=", -- "local var1, ..., varN ="
   "local function x", -- "local function f (arg1, ..., argN)"
}

--- Lines that are only excluded from accounting when they have 0 hits
local zero_hits_exclusions = {
   "[ntfx0',= ]+,", -- "var1 var2," multi columns table stuff
   "{ ?} ?,", -- Empty table before comma leaves no trace in tables and calls
   fixup "<FIELDNAME>=.+[,;]", -- "[123] = 23," "['foo'] = "asd","
   fixup "<FIELDNAME>=function", -- "[123] = function(...)"
   fixup "<FIELDNAME>=<PARENS>'", -- "[123] = [[", possibly with opening parens
   "return function", -- "return function(arg1, ..., argN)"
   "function", -- "function(arg1, ..., argN)"
   "[ntfx0]", -- Single token expressions leave no trace in tables, function calls and sometimes assignments
   "''", -- Same for strings
   "{ ?}", -- Same for empty tables
   fixup "<FULLID>", -- Same for local variables indexed once
   fixup "local x=function", -- "local a = function(arg1, ..., argN)"
   fixup "local x=<PARENS>'", -- "local a = [[", possibly with opening parens
   fixup "local x=(<PARENS>", -- "local a = (", possibly with several parens
   fixup "local <IDS>=(<PARENS>", -- "local a, b = (", possibly with several parens
   fixup "local x=n", -- "local a = nil; local b = nil" produces no trace for the second statement
   fixup "<FULLID>=<PARENS>'", -- "a.b = [[", possibly with opening parens
   fixup "<FULLID>=function", -- "a = function(arg1, ..., argN)"
   "} ?,", -- "}," generates no trace if the table ends with a key-value pair
   "} ?, ?function", -- same with "}, function(...)"
   "break", -- "break" generates no trace in Lua 5.2+
   "{", -- "{" opening table
   "}?[ %)]*", -- optional closing paren, possibly with several closing parens
   "[ntf0']+ ?}[ %)]*" -- a constant at the end of a table, possibly with closing parens (for LuaJIT)
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

local keywords = {["nil"] = "n", ["true"] = "t", ["false"] = "f"}

for _, keyword in ipairs({
      "and", "break", "do", "else", "elseif", "end", "for", "function", "goto", "if",
      "in", "local", "not", "or", "repeat", "return", "then", "until", "while"}) do
   keywords[keyword] = keyword
end

function LineScanner:skip_name()
   -- It is guaranteed that the first character matches "%a_".
   local _, _, name = self:find("^([%w_]*)")
   self.i = self.i + #name

   if keywords[name] then
      name = keywords[name]
   else
      name = "x"
   end

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
   -- Punctuation is preserved. Whitespace is replaced with single space.
   -- Literal strings are replaced with "''", so that a string literal
   -- containing special characters does not confuse exclusion rules.
   -- Numbers are replaced with "0".
   -- Identifiers are replaced with "x".
   -- Literal keywords (nil, true and false) are replaced with "n", "t" and "f",
   -- other keywords are preserved.
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
   local data = stats.load(conf.statsfile)

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

-- Stub methods follow.
-- luacheck: push no unused args

--- Stub method called before reporting.
function ReporterBase:on_start()
end

--- Stub method called before processing a file.
-- @param filename name of the file.
function ReporterBase:on_new_file(filename)
end

--- Stub method called if a file couldn't be processed due to an error.
-- @param filename name of the file.
-- @param error_type "open", "read" or "load".
-- @param message error message.
function ReporterBase:on_file_error(filename, error_type, message)
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

-- luacheck: pop

local cluacov_ok = pcall(require, "cluacov.version")
local deepactivelines

if cluacov_ok then
   deepactivelines = require("cluacov.deepactivelines")
end

function ReporterBase:_run_file(filename)
   local file, open_err = io.open(filename)

   if not file then
      self:on_file_error(filename, "open", util.unprefix(open_err, filename .. ": "))
      return
   end

   local active_lines

   if cluacov_ok then
      local src, read_err = file:read("*a")

      if not src then
         self:on_file_error(filename, "read", read_err)
         return
      end

      local func, load_err = util.load_string(src, nil, "@file")

      if not func then
         self:on_file_error(filename, "load", "line " .. util.unprefix(load_err, "file:"))
         return
      end

      active_lines = deepactivelines.get(func)
      file:seek("set")
   end

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
      local included = not always_excluded and (not excluded_when_not_hit or hits ~= 0)

      if cluacov_ok then
         included = included and active_lines[line_nr]
      end

      if included then
         if hits == 0 then
            self:on_mis_line(filename, line_nr, line)
            file_miss = file_miss + 1
         else
            self:on_hit_line(filename, line_nr, line, hits)
            file_hits = file_hits + 1
         end
      else
         self:on_empty_line(filename, line_nr, line)
      end

      line_nr = line_nr + 1
   end

   file:close()
   self:on_end_file(filename, file_hits, file_miss)
end

function ReporterBase:run()
   self:on_start()

   for _, filename in ipairs(self:files()) do
      self:_run_file(filename)
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
   self._printed_first_header = false
end

function DefaultReporter:on_new_file(filename)
   self:write(("="):rep(78), "\n")
   self:write(filename, "\n")
   self:write(("="):rep(78), "\n")
end

function DefaultReporter:on_file_error(filename, error_type, message) --luacheck: no self
   io.stderr:write(("Couldn't %s %s: %s\n"):format(error_type, filename, message))
end

function DefaultReporter:on_empty_line(_, _, line)
   if line == "" then
      self:write("\n")
   else
      self:write(self._empty_format, " ", line, "\n")
   end
end

function DefaultReporter:on_mis_line(_, _, line)
   self:write(self._zero_format, " ", line, "\n")
end

function DefaultReporter:on_hit_line(_, _, line, hits)
   self:write(self._count_format:format(hits), " ", line, "\n")
end

function DefaultReporter:on_end_file(filename, hits, miss)
   self._summary[filename] = { hits = hits, miss = miss }
   self:write("\n")
end

local function coverage_to_string(hits, missed)
   local total = hits + missed

   if total == 0 then
      total = 1
   end

   return ("%.2f%%"):format(hits/total*100.0)
end

function DefaultReporter:on_end()
   self:write(("="):rep(78), "\n")
   self:write("Summary\n")
   self:write(("="):rep(78), "\n")
   self:write("\n")

   local lines = {{"File", "Hits", "Missed", "Coverage"}}
   local total_hits, total_missed = 0, 0

   for _, filename in ipairs(self:files()) do
      local summary = self._summary[filename]

      if summary then
         local hits, missed = summary.hits, summary.miss

         table.insert(lines, {
            filename,
            tostring(summary.hits),
            tostring(summary.miss),
            coverage_to_string(hits, missed)
         })

         total_hits = total_hits + hits
         total_missed = total_missed + missed
      end
   end

   table.insert(lines, {
      "Total",
      tostring(total_hits),
      tostring(total_missed),
      coverage_to_string(total_hits, total_missed)
   })

   local max_column_lengths = {}

   for _, line in ipairs(lines) do
      for column_nr, column in ipairs(line) do
         max_column_lengths[column_nr] = math.max(max_column_lengths[column_nr] or -1, #column)
      end
   end

   local table_width = #max_column_lengths - 1

   for _, column_length in ipairs(max_column_lengths) do
      table_width = table_width + column_length
   end


   for line_nr, line in ipairs(lines) do
      if line_nr == #lines or line_nr == 2 then
         self:write(("-"):rep(table_width), "\n")
      end

      for column_nr, column in ipairs(line) do
         self:write(column)

         if column_nr == #line then
            self:write("\n")
         else
            self:write((" "):rep(max_column_lengths[column_nr] - #column + 1))
         end
      end
   end
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
