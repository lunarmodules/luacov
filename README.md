<div align="center">
    <h1>LuaCov</h1>
    <img src="./docs/logo/luacov-144x144.png" width="144" />
    <p align="center">
        Coverage analyzer for Lua
    </p>    
    <p>
        <a href="https://travis-ci.org/keplerproject/luacov">
            <img src="https://travis-ci.org/keplerproject/luacov.svg?branch=master" alt="Build Status">
        </a>
        <a href="https://ci.appveyor.com/project/mpeterv/luacov">
            <img src="https://ci.appveyor.com/api/projects/status/dd9gk87cpkqo5s58?svg=true" alt="Windows build status">
        </a>
    </p>
</div>

<br>


## Overview

LuaCov is a simple coverage analyzer for [Lua](http://www.lua.org) scripts.
When a Lua script is run with the `luacov` module loaded, it generates a stats
file with the number of executions of each line of the script and its loaded
modules. The `luacov` command-line script then processes this file generating
a report file which allows one to visualize which code paths were not
traversed, which is useful for verifying the effectiveness of a test suite.

LuaCov is free software and, like Lua, is released under the
[MIT License](https://www.lua.org/license.html).

## Download and Installation

LuaCov can be downloaded from its
[Github downloads page](https://github.com/keplerproject/luacov/releases).

It can also be installed using Luarocks:

```
luarocks install luacov
```

In order to additionally install experimental C extensions that improve
performance and analysis accuracy install
[CLuaCov](https://github.com/mpeterv/cluacov) package instead:

```
luarocks install cluacov
```

LuaCov is written in pure Lua and has no external dependencies.

## Instructions

Using LuaCov consists of two steps: running your script to collect coverage
data, and then running `luacov` on the collected data to generate a report
(see [configuration](#configuration) below for other options).

To collect coverage data, your script needs to load the `luacov` Lua module.
This can be done from the command-line, without modifying your script, like
this:

    lua -lluacov test.lua

Alternatively, you can add `require("luacov")` to the first line of your
script.

Once the script is run, a file called `luacov.stats.out` is generated. If the
file already exists, statistics are _added_ to it. This is useful, for
example, for making a series of runs with different input parameters in a test
suite. To start the accounting from scratch, just delete the stats file.

To generate a report, just run the `luacov` command-line script. It expects to
find a file named `luacov.stats.out` in the current directory, and outputs a
file named `luacov.report.out`. The script takes the following parameters:

    luacov [-c=configfile] [filename...]

For the `-c` option see below at [configuration](#configuration). The filenames
(actually Lua patterns) indicate the files to include in the report, specifying
them here equals to adding them to the `include` list in the configuration
file, with `.lua` extension stripped.

This is an example output of the report file:

```
==============================================================================
test.lua
==============================================================================
 1 if 10 > 100 then
*0    print("I don't think this line will execute.")
   else
 1    print("Hello, LuaCov!")
   end
```

Note that to generate this report, `luacov` reads the source files. Therefore,
it expects to find them in the same location they were when the `luacov`
module ran (the stats file stores the filenames, but not the sources
themselves).

To silence missed line reporting for a group of lines, place inline options
`luacov: disable` and `luacov: enable` in short comments around them:

```lua
if SOME_DEBUG_CONDITION_THAT_IS_ALWAYS_FALSE_IN_TESTS then
   -- luacov: disable

   -- Lines here are not marked as missed even though they are not covered.

   -- luacov: enable
end
```

LuaCov saves its stats upon normal program termination. If your program is a
daemon -- in other words, if it does not terminate normally -- you can use the
`luacov.tick` module or `tick` configuration option, which periodically saves
the stats file. For example, to run (on Unix systems) LuaCov on
[Xavante](httpsf://keplerproject.github.io/xavante/), just modify the first line
of `xavante_start.lua` so it reads:

```
#!/usr/bin/env lua -lluacov.tick
```

or add

```lua
tick = true
```

to `.luacov` config file.


## Configuration

LuaCov includes several configuration options, which have their defaults
stored in `src/luacov/defaults.lua`. These are the global defaults. To use
project specific configuration, create a Lua script setting options as globals
or returning a table with some options and store it as `.luacov` in the project
directory from where `luacov` is being run. For example, this config informs
LuaCov that only `foo` module and its submodules should be covered and that
they are located inside `src` directory:

```lua
modules = {
   ["foo"] = "src/foo/init.lua",
   ["foo.*"] = "src"
}
```

For a full list of options, see
[`luacov.defaults` documentation](https://keplerproject.github.io/luacov/doc/modules/luacov.defaults.html).

## Custom reporter engines

LuaCov supports custom reporter engines, which are distributed as separate
packages. Check them out!

* Cobertura: https://github.com/britzl/luacov-cobertura
* Coveralls: https://github.com/moteus/luacov-coveralls
* Console: https://github.com/spacewander/luacov-console

## Using development version

After cloning this repo, these commands may be useful:

* `luarocks make` to install LuaCov from local sources;
* `busted` to run tests using [busted](https://github.com/Olivine-Labs/busted).
* `ldoc .` to regenerate documentation using
  [LDoc](https://github.com/stevedonovan/LDoc).
* `luacheck .` to lint using [Luacheck](https://github.com/mpeterv/luacheck).

## Credits

LuaCov was designed and implemented by Hisham Muhammad as a tool for testing
[LuaRocks](https://luarocks.org/).
