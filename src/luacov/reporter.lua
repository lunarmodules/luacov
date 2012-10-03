local M = {}

function M.report()
  local luacov = require("luacov.runner")
  local stats = require("luacov.stats")
  
  local configuration = luacov.load_config()
  stats.statsfile = configuration.statsfile

  local data, most_hits = stats.load()

  if not data then
     print("Could not load stats file "..luacov.statsfile..".")
     print("Run your Lua program with -lluacov and then rerun luacov.")
     os.exit(1)
  end

  local report = io.open(configuration.reportfile, "w")

  local names = {}
  for filename, _ in pairs(data) do
    local include = false
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

  local most_hits_length = ("%d"):format(most_hits):len()
  local empty_format = (" "):rep(most_hits_length+1)
  local false_negative_format = ("!%% %dd"):format(most_hits_length)
  local zero_format = ("*"):rep(most_hits_length).."0"
  local count_format = ("%% %dd"):format(most_hits_length+1)

  local exclusions =
  {
     { false, "^#!" },     -- Unix hash-bang magic line
     { true, "" },         -- Empty line
     { true, "end,?" },    -- Single "end"
     { true, "else" },     -- Single "else"
     { true, "repeat" },   -- Single "repeat"
     { true, "do" },       -- Single "do"
     { true, "local%s+[%w_,%s]+" }, -- "local var1, ..., varN"
     { true, "local%s+[%w_,%s]+%s*=" }, -- "local var1, ..., varN ="
     { true, "local%s+function%s*%([%w_,%s]*%)" }, -- "local function(arg1, ..., argN)"
     { true, "local%s+function%s+[%w_]*%s*%([%w_,%s]*%)" }, -- "local function f (arg1, ..., argN)"
  }

  local function excluded(line)
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
        block_comment, equals = false, ""
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
           else
              local l = line:match("%]"..equals.."%](.*)$")
              if l then
                 line = l
                 block_comment = false
              end
           end

           local hits = filedata[line_nr] or 0
           if block_comment or excluded(line) then
              if hits > 0 then
                 report:write(false_negative_format:format(hits))
              else
                 report:write(empty_format)
              end
           else
              if hits == 0 then
                 report:write(zero_format)
              else
                 report:write(count_format:format(hits))
              end
           end
           report:write("\t", true_line, "\n")
           if new_block_comment then block_comment = true end
           line_nr = line_nr + 1
        end
        file:close()
     end
  end
  report:close()

  -- delete stats file if set to do so
  if configuration.deletestats then
    os.remove(configuration.statsfile)
  end
end

return M