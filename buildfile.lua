-- requires environment variables

_G.main = function()
  local incl = (os.getenv "KMODS") or ""
  local include = {}
  for inc in incl:gmatch "[^,]+" do
    log("info", "including module ", inc)
    include[#include + 1] = inc
  end
  log("warn", "writing includes.lua")
  local handle = assert(io.open("includes.lua", "w"))
  for _,inc in ipairs(include) do
    handle:write("--#include \"", inc, ".lua\"\n")
  end
  handle:close()
  ex("../utils/proc.lua init.lua kernel.lua")
  log("warn", "cleaning up")
  --os.remove("includes.lua")
end
