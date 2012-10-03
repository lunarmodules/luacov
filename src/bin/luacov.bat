@ECHO OFF
for %%X in (luajit.exe) do (set FOUND=%%~$PATH:X)
if defined FOUND (
  set cmd=luajit
) else (
  for %%X in (lua.exe) do (set FOUND=%%~$PATH:X)
  if defined FOUND (
    set cmd=lua
  )
)
if "%cmd%"=="" (
  echo "LuaCov requires that a valid execution environment be specified (or that you have lua or luajit accessible in your PATH). Aborting."
) else (
  call "%~dp0%cmd%" "%~dp0luacov_bootstrap" %*
)
