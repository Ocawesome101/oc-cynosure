-- requires environment variables

_G.env = {}

for line in io.lines(".buildconfig") do
  local k, v = line:match("^(.-)=(.+)$")
  if v == "true" then v = true
  elseif v == "false" then v = false
  else v = tonumber(v) or v end
  env[k] = os.getenv(k) or v
end

_G.main = function(arg)
  local incl = env.KMODS or os.getenv("KMODS") or ""
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
  assert(loadfile(os.getenv("PREPROCESSOR") or "../utils/proc.lua"))("init.lua", "kernel.lua")
  log("warn", "cleaning up")
  --os.remove("includes.lua")
end
