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
    handle:write(inc)
  end
  handle:close()
  io.write(ex("./luacomp init.lua -Okernel.lua"))
  log("warn", "cleaning up")
  os.remove("includes.lua")
end
