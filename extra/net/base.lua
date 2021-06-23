-- base networking --

k.log(k.loglevels.info, "extra/net/base")

do
  local protocols = {}
  k.net = {}

  local ppat = "^(.-)://"

  function k.net.socket(url, ...)
    checkArg(1, url, "string")
    local proto = url:match(ppat)
    if not proto then
      return nil, "protocol unspecified"
    elseif not protocols[proto] then
      return nil, "bad protocol: " .. proto
    end
  end

  function k.net.request(url, ...)
    checkArg(1, url, "string")
    local proto = url:match(ppat)
    if not proto then
      return nil, "protocol unspecified"
    elseif not protocols[proto] then
      return nil, "bad protocol: " .. proto
    end
  end

  --#include "extra/net/internet.lua"
end
