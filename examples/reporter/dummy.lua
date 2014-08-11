--- Example of basic luacov reporter
--
-- Installation
--   copy this file to luacov/reporter/dummy.lua
--
-- Usage
--   call `luacov -r dummy`

local luacov_reporter = require"luacov.reporter"

local ReporterBase = luacov_reporter.ReporterBase

-- ReporterBase provide
--  write(str) - write string to output file
--  config()   - return configuration table

local DummyReporter = setmetatable({}, ReporterBase) do
DummyReporter.__index = DummyReporter

function DummyReporter:new(conf)
  ReporterBase.new(self, conf)
end

function DummyReporter:on_start()
end

function DummyReporter:on_new_file(filename)
end

function DummyReporter:on_empty_line(filename, lineno, line)
end

function DummyReporter:on_mis_line(filename, lineno, line)
end

function DummyReporter:on_hit_line(filename, lineno, line, hits)
end

function DummyReporter:on_end_file(filename, hits, miss)
end

function DummyReporter:on_end()
end

end

local reporter = {}

function reporter.report()
   return luacov_reporter.report(DummyReporter)
end

return reporter
