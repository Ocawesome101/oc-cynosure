-- requires environment variables

_G.main = () ->
  incl = (os.getenv "KMODS") or ""
  include = {}
  for inc in incl\gmatch "[^,]+" do
    log "info", "including module ", inc
    include[#include + 1] = inc
  log "warn", "writing includes.lua"
  handle = assert io.open "includes.lua", "w"
  for inc in *include do handle\write inc
  handle\close!
  ex "./luacomp init.lua -Okernel.lua"
  log "warn", "cleaning up"
  os.remove "includes.lua"
