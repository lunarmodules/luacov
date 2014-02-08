------------------------
-- Report module, will transform statistics file into a report.
-- @class module
-- @name luacov.reporter
local M = {}

local function check_long_string(line, in_long_string, ls_equals, linecount)
   local long_string
   if not linecount then
      long_string, ls_equals = line:match("^()%s*[%w_]+%s*=%s*%[(=*)%[[^]]*$")
      if not long_string then
         long_string, ls_equals = line:match("^()%s*local%s*[%w_]+%s*=%s*%[(=*)%[%s*$")
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
local exclusions =
{
   { false, "^#!" },     -- Unix hash-bang magic line
   { true, "" },         -- Empty line
   { true, "end,?" },    -- Single "end"
   { true, "else" },     -- Single "else"
   { true, "repeat" },   -- Single "repeat"
   { true, "do" },       -- Single "do"
   { true, "while%s+" },       -- Single "do"
   { true, "do" },       -- Single "do"
   { true, "local%s+[%w_,%s]+" }, -- "local var1, ..., varN"
   { true, "local%s+[%w_,%s]+%s*=" }, -- "local var1, ..., varN ="
   { true, "local%s+function%s*%([%w_,%s%.]*%)" }, -- "local function(arg1, ..., argN)"
   { true, "local%s+function%s+[%w_]*%s*%([%w_,%s%.]*%)" }, -- "local function f (arg1, ..., argN)"
}

--- Lines that are only excluded from accounting when they have 0 hits
local hit0_exclusions =
{
   { true, "[%w_,='\"%s]+%s*," }, -- "var1 var2," multi columns table stuff
   { true, "%[?%s*[\"'%w_]+%s*%]?%s=.+," }, -- "[123] = 23," "['foo'] = "asd","
   { true, "[%w_,'\"%s]*function%s*%([%w_,%s%.]*%)" }, -- "1,2,function(...)"
   { true, "local%s+[%w_]+%s*=%s*function%s*%([%w_,%s%.]*%)" }, -- "local a = function(arg1, ..., argN)"
   { true, "[%w%._]+%s*=%s*function%s*%([%w_,%s%.]*%)" }, -- "a = function(arg1, ..., argN)"
   { true, "{%s*" }, -- "{" opening table
   { true, "}" }, -- "{" closing table
}

------------------------
-- Starts the report generator
-- To load a config, use <code>luacov.runner</code> to load
-- settings and then start the report.
-- @example# local runner = require("luacov.runner")
-- local reporter = require("luacov.reporter")
-- runner.load_config()
-- table.insert(luacov.configuration.include, "thisfile")
-- reporter.report()
function M.report()
   local luacov = require("luacov.runner")
   local stats = require("luacov.stats")
  
   local configuration = luacov.load_config()
   stats.statsfile = configuration.statsfile

   local data, most_hits = stats.load()

   if not data then
      print("Could not load stats file "..configuration.statsfile..".")
      print("Run your Lua program with -lluacov and then rerun luacov.")
      os.exit(1)
   end

   local report = io.open(configuration.reportfile, "w")

   local names = {}
   for filename, _ in pairs(data) do
      local include = false
      -- normalize paths in patterns
      local path = filename:gsub("/", "."):gsub("\\", "."):gsub("%.lua$", "")
      if not configuration.include[1] then
         include = true
      else
         include = false
         for _, p in ipairs(configuration.include) do
            if path:match(p) then
               include = true
               break
            end
         end
      end
      if include and configuration.exclude[1] then
         for _, p in ipairs(configuration.exclude) do
            if path:match(p) then
               include = false
               break
            end
         end
      end
      if include then
         table.insert(names, filename)
      end
   end

   table.sort(names)

   local summary = {}
   local most_hits_length = ("%d"):format(most_hits):len()
   local empty_format = (" "):rep(most_hits_length+1)
   local zero_format = ("*"):rep(most_hits_length).."0"
   local count_format = ("%% %dd"):format(most_hits_length+1)

   local function excluded(exclusions,line)
      for _, e in ipairs(exclusions) do
         if e[1] then
            if line:match("^%s*"..e[2].."%s*$") or line:match("^%s*"..e[2].."%s*%-%-") then return true end
         else
            if line:match(e[2]) then return true end
         end
      end
      return false
   end

   for _, filename in ipairs(names) do
      local filedata = data[filename]
      local file = io.open(filename, "r")
      if file then
         report:write("\n")
         report:write("==============================================================================\n")
         report:write(filename, "\n")
         report:write("==============================================================================\n")
         local line_nr = 1
         local file_hits, file_miss = 0, 0
         local block_comment, equals = false, ""
         local in_long_string, ls_equals = false, ""
         while true do
            local line = file:read("*l")
            if not line then break end
            local true_line = line

            local new_block_comment = false
            if not block_comment then
               local l, equals = line:match("^(.*)%-%-%[(=*)%[")
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
            if block_comment or in_long_string or excluded(exclusions,line) or (hits == 0 and excluded(hit0_exclusions,line)) then
               report:write(empty_format)
            else
               if hits == 0 then
                  file_miss = file_miss + 1
                  report:write(zero_format)
               else
                  file_hits = file_hits + 1
                  report:write(count_format:format(hits))
               end
            end
            report:write("\t", true_line, "\n")
            if new_block_comment then block_comment = true end
            line_nr = line_nr + 1
            summary[filename] = {
               hits = file_hits,
               miss = file_miss
            }
         end
         file:close()
      end
   end

   report:write("\n")
   report:write("==============================================================================\n")
   report:write("Summary\n")
   report:write("==============================================================================\n")
   report:write("\n")
   
   local function write_total(hits, miss, filename)
      report:write(hits, "\t", miss, "\t", ("%.2f%%"):format(hits/(hits+miss)*100.0), "\t", filename, "\n")
   end
   
   local total_hits, total_miss = 0, 0
   for _, filename in ipairs(names) do
      local s = summary[filename]
      if s then
         write_total(s.hits, s.miss, filename)
         total_hits = total_hits + s.hits
         total_miss = total_miss + s.miss
      end
   end
   report:write("------------------------\n")
   write_total(total_hits, total_miss, "")

   report:close()

   if configuration.deletestats then
      os.remove(configuration.statsfile)
   end
end

return M
