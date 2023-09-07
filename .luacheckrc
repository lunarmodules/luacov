std = "min"
include_files = {"src", "spec"}
exclude_files = {
   "spec/*/*",
   "src/luacov/reporter/html/static/*.js",
   "src/luacov/reporter/html/static/*.css",
}
files.spec.std = "+busted"
