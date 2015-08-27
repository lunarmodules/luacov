--- Global configuration file. Copy, customize and store in your
-- project folder as '.luacov' for project specific configuration.
-- If some options are missing, their default values from this file
-- will be used.
-- @class module
-- @name luacov.defaults
return {

  -- default filename to load for config options if not provided
  -- only has effect in 'luacov.defaults.lua'
  ["configfile"] = ".luacov",

  -- filename to store stats collected
  ["statsfile"] = "luacov.stats.out",

  -- filename to store report
  ["reportfile"] = "luacov.report.out",

  -- luacov.stats file updating frequency.
  -- The lower this value - the more frequenty results will be written out to luacov.stats
  -- You may want to reduce this value for short lived scripts (to for example 2) to avoid losing coverage data.
  ["savestepsize"] = 100,

  -- Run reporter on completion? (won't work for ticks)
  runreport = false,

  -- Delete stats file after reporting?
  deletestats = false,
  
  -- Process Lua code loaded from raw strings
  -- (that is, when the 'source' field in the debug info
  -- does not start with '@')
  codefromstrings = false,

  -- Patterns for files to include when reporting
  -- all will be included if nothing is listed
  -- (exclude overrules include, do not include
  -- the .lua extension, path separator is always '/')
  ["include"] = {
  },

  -- Patterns for files to exclude when reporting
  -- all will be included if nothing is listed
  -- (exclude overrules include, do not include
  -- the .lua extension, path separator is always '/')
  ["exclude"] = {
    "luacov$",
    "luacov/reporter$",
    "luacov/defaults$",
    "luacov/runner$",
    "luacov/stats$",
    "luacov/tick$",
  },

  -- Table mapping names of modules to be included to their filenames.
  -- Has no effect if empty.
  -- Real filenames mentioned here will be used for reporting
  -- even if the modules have been installed elsewhere.
  -- Module name can contain '*' wildcard to match groups of modules,
  -- in this case corresponding path will be used as a prefix directory
  -- where modules from the group are located.
  -- Example:
  -- modules = {
  --   ["some_rock"] = "src/some_rock.lua",
  --   ["some_rock.*"] = "src"
  -- }
  modules = {
  },

}
