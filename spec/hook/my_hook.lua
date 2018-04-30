local runner = require "luacov.runner"
return function(_, line) runner.debug_hook(_, line, 3) end
