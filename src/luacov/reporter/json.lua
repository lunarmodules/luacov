local luacov_reporter = require("luacov.reporter")
local luacov_json_provider = require("luacov.reporter.json.provider")

-- a concrete implementation
-- of a json provider
local json_provider

do
   -- an array containing registered json providers
   -- in descending order of preference.
   -- item fields:
   --    * rname: the selected provider
   --             as in luacov.reporter.json.providers.*
   --    * name:  the registered rock name on luarocks.org
   local providers = {
      {rname = "cjson",  name = "lua-cjson"},
      {rname = "dkjson", name = "dkjson"}
   }

   local json_ok

   -- list of providers that
   -- didn't meet minimal
   -- json encoding capabilities
   local providers_unmet_quality = {}

   for _, p in ipairs(providers) do
      json_ok, json_provider = luacov_json_provider.load_provider(p.rname)
      if json_ok and json_provider then
         -- test whether the json provider is able
         -- to encode an empty table as empty json array
         -- or not
         local empty_array = json_provider:create_array()
         if json_provider:encode(empty_array) ~= "[]" then
            json_ok = false
            json_provider = nil
         else
            -- test whether the json provider is able
            -- to encode an empty object as empty json object
            -- or not
            local empty_obj = json_provider:create_object()
            if json_provider:encode(empty_obj) ~= "{}" then
               json_ok = false
               json_provider = nil
            end
         end

         if json_ok and json_provider then
            break
         else
            table.insert(providers_unmet_quality, p.name)
         end
      end
   end

   if not (json_ok and json_provider) then
      local provider_names = {}
      for _, p in ipairs(providers) do
         table.insert(provider_names, p.name)
      end
      local msg = "In order to use the json reporter, " ..
                  "you must install a recent version of one " ..
                  "of the following libraries: " ..
                  table.concat(provider_names, ", ") ..
                  "."
      if #providers_unmet_quality > 0 then
         msg = msg ..
               " The libraries present in the system (" ..
               table.concat(providers_unmet_quality, ", ") ..
               ") didn't meet minimal json encoding capabilities."
      end
      error(msg)
   end
end

-- implementation for the json reporter
local reporter = {}

-- json format version
local format_version = "1"

-- a negative number
-- acting as a marker meant
-- to track lines not relevant
-- for coverage analysis
local NOT_RELEVANT_MARKER = -1

local JsonReporter = setmetatable({}, luacov_reporter.ReporterBase)
JsonReporter.__index = JsonReporter

function JsonReporter:on_start()
   self._json = {}
end

local function create_summary()
   local summary = json_provider:create_object()
   summary.hits = 0
   summary.miss = 0
   summary.coverage = 0
   return summary
end

local function eval_coverage(hits, miss)
   local total = hits + miss
   if total == 0 then
      total = 1
   end
   return hits / total
end

local function update_summary(summary, hits, miss)
   summary.hits = hits
   summary.miss = miss
   summary.coverage = eval_coverage(hits, miss)
end

function JsonReporter:on_new_file(filename)
   local file_entry = json_provider:create_object()
   file_entry.file = filename
   file_entry.summary = create_summary()
   file_entry.lines = json_provider:create_array()
   self._json[filename] = file_entry
end

function JsonReporter:on_file_error(filename, error_type, message) --luacheck: no self
   io.stderr:write(("Couldn't %s %s: %s\n"):format(error_type, filename, message))
end

local function push_line_on_report(self, filename, lineno, line, hits)
   local lines = self._json[filename].lines
   local new_line = json_provider:create_object()
   new_line.line_number = lineno
   new_line.hits = hits
   new_line.line = line
   table.insert(lines, new_line)
end

function JsonReporter:on_empty_line(filename, lineno, line)
   push_line_on_report(self, filename, lineno, line, NOT_RELEVANT_MARKER)
end

function JsonReporter:on_mis_line(filename, lineno, line)
   push_line_on_report(self, filename, lineno, line, 0)
end

function JsonReporter:on_hit_line(filename, lineno, line, hits)
   push_line_on_report(self, filename, lineno, line, hits)
end

function JsonReporter:on_end_file(filename, hits, miss)
   update_summary(self._json[filename].summary, hits, miss)
end

function JsonReporter:on_end()
   local result = json_provider:create_object()
   result.format_version = format_version
   result.files = json_provider:create_array()
   result.summary = create_summary()

   local hits, miss = 0, 0
   local json = self._json
   for _, filename in ipairs(self:files()) do
      local file_entry = json[filename]
      local file_summary = file_entry.summary
      table.insert(result.files, file_entry)

      hits = hits + file_summary.hits
      miss = miss + file_summary.miss
   end

   update_summary(result.summary, hits, miss)
   self:write(json_provider:encode(result))
end

function reporter.report()
   luacov_reporter.report(JsonReporter)
end

return reporter
