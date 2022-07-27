std = "min"
include_files = {"src", "spec"}
exclude_files = {
   "spec/*/*",
   "src/luacov/reporter/html/*.js",
   "src/luacov/reporter/html/*.css",
}
files.spec.std = "+busted"
