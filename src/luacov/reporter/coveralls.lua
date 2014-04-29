local json = require "json"
local luacov_reporter = require "luacov.reporter"

local ReporterBase = luacov_reporter.ReporterBase

local CoverallsReporter = setmetatable({}, ReporterBase) do
CoverallsReporter.__index = CoverallsReporter

local EMPTY = json.decode('null')
local ZERO  = 0

function CoverallsReporter:new(conf)
  local o, err = ReporterBase.new(self, conf)
  if not o then return nil, err end

  -- @todo check repo_token (os.getenv("REPO_TOKEN"))
  o._private.service_name   = 'travis-ci'
  o._private.service_job_id = os.getenv("TRAVIS_JOB_ID")
  if not o._private.service_job_id then
    o:close()
    return nil, "You should run this only on Travis-CI."
  end
  o._private.source_files   = json.util.InitArray{}

  return o
end

function CoverallsReporter:on_start()
end

function CoverallsReporter:on_new_file(filename)
  self._private.current_file = {
    name     = filename;
    source   = {};
    coverage = json.util.InitArray{};
  }
end

function CoverallsReporter:on_empty_line(filename, lineno, line)
  local source_file = self._private.current_file
  table.insert(source_file.coverage, EMPTY)
  table.insert(source_file.source, line)
end

function CoverallsReporter:on_mis_line(filename, lineno, line)
  local source_file = self._private.current_file
  table.insert(source_file.coverage, ZERO)
  table.insert(source_file.source, line)
end

function CoverallsReporter:on_hit_line(filename, lineno, line, hits)
  local source_file = self._private.current_file
  table.insert(source_file.coverage, hits)
  table.insert(source_file.source, line)
end

function CoverallsReporter:on_end_file(filename, hits, miss)
  local source_file = self._private.current_file
  source_file.source = table.concat(source_file.source, "\n")
  table.insert(self._private.source_files, source_file)
end

function CoverallsReporter:on_end()
  local msg = json.encode{
    service_name   = self._private.service_name;
    service_job_id = self._private.service_job_id;
    source_files   = self._private.source_files;
  }
  self:write(msg)
end

end

local M = {}

function M.report()
  return luacov_reporter.report(CoverallsReporter)
end

return M
