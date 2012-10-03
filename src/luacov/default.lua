-- Example configuration file, copy and customize and store in your
-- project folder as '.luacov' 
return {

  -- default filename to load for config options if not provided
  -- only has effect in 'luacov.defaults.lua'
  ["configfile"] = ".luacov",
  
  -- filename to store stats collected
  ["statsfile"] = "luacov.stats.out",
  
  -- filename to store report
  ["reportfile"] = "luacov.report.out",
  
  -- Run reporter on completion? (won't work for ticks)
  runreport = false,
  
  -- Delete stats file after reporting? (only valid
  -- if runreport == true)
  deletestats = false,
  
  -- Patterns for files to exclude when reporting
  ["exclude"] = {
    "luacov.luacov.lua$",
    "luacov.reporter.lua$",
    "luacov.defaults.lua$",
    "luacov.runner.lua$",
    "luacov.stats.lua$",
    "luacov.tick.lua$",
  },

}