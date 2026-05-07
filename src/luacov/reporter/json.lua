local luacov_reporter = require("luacov.reporter")

-- allow multiple json libraries
-- to provide the encoding
-- of the final json report.
local json_providers = {
   {rname = "cjson",  name = "lua-cjson"},
   {rname = "dkjson", name = "dkjson"}
}

local function encode_json_with_provider(provider, provider_name, obj)
   local ok, json_lib = pcall(require, provider)
   if not ok then
      return nil, "Failed to load the json library " .. provider_name
   end

   local json_str = json_lib.encode(obj)
   if type(json_str) ~= "string" then
      return nil, "Failed to encode report with the library " .. provider_name
   end
   return json_str
end

local function write_encoded_json(self, obj)
   local json_str, err
   for _, provider in ipairs(json_providers) do
      json_str, err = encode_json_with_provider(provider.rname, provider.name, obj)
      if json_str then
         self:write(json_str)
         return
      end
   end
   local provider_names = {}
   for _, provider in ipairs(json_providers) do
      table.insert(provider_names, provider.name)
   end
   io.stderr:write(
     "In order to use the json reporter, " ..
     "you must install one of the following libraries: " ..
     table.concat(provider_names, ", ") ..
     "\n"
  )
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

function JsonReporter:on_new_file(filename)
   self._json[filename] = {
      summary = { hits = 0, miss = 0, coverage = 0 },
      lines = {}
   }
end

function JsonReporter:on_file_error(filename, error_type, message)
   io.stderr:write(("Couldn't %s %s: %s\n"):format(error_type, filename, message))
end

local function push_line_on_report(self, filename, lineno, line, hits)
   local lines = self._json[filename].lines
   local new_line = { line_number = lineno, hits = hits, line = line }
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

local function eval_coverage(hits, miss)
   local total = hits + miss
   if total == 0 then
      total = 1
   end
   return hits / total
end

function JsonReporter:on_end_file(filename, hits, miss)
   local summary = self._json[filename].summary
   summary.hits = hits
   summary.miss = miss
   summary.coverage = eval_coverage(hits, miss)
end

function JsonReporter:on_end()
   local result = { format_version = format_version, files = {} }
   local hits, miss = 0, 0
   local json = self._json or {}
   for i, filename in ipairs(self:files()) do
      local file_data = json[filename]
      if file_data then
         local file_summary = file_data.summary
         table.insert(result.files, {
            file = filename,
            lines = file_data.lines,
            summary = file_summary
         })
         hits = hits + file_summary.hits
         miss = miss + file_summary.miss
      end
   end
   result.summary = {
      hits = hits,
      miss = miss,
      coverage = eval_coverage(hits, miss)
   }
   write_encoded_json(self, result)
end

function reporter.report()
   luacov_reporter.report(JsonReporter)
end

return reporter
