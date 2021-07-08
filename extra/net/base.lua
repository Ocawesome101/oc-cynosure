-- base networking --

k.log(k.loglevels.info, "extra/net/base")

do
  local protocols = {}
  k.net = {}

  local ppat = "^(.-)://(.+)"

  function k.net.socket(url, ...)
    checkArg(1, url, "string")
    local proto, rest = url:match(ppat)
    if not proto then
      return nil, "protocol unspecified"
    elseif not protocols[proto] then
      return nil, "bad protocol: " .. proto
    end

    return protocols[proto].socket(proto, rest, ...)
  end

  function k.net.request(url, ...)
    checkArg(1, url, "string")
    local proto, rest = url:match(ppat)
    if not proto then
      return nil, "protocol unspecified"
    elseif not protocols[proto] then
      return nil, "bad protocol: " .. proto
    end

    return protocols[proto].request(proto, rest, ...)
  end

  local hostname = "localhost"

  function k.net.hostname()
    return hostname
  end

  function k.net.sethostname(hn)
    checkArg(1, hn, "string")
    local perms = k.security.users.attributes(k.scheduler.info().owner).acls
    if not k.security.acl.has_permission(perms,
        k.security.acl.permissions.HOSTNAME) then
      return nil, "insufficient permission"
    end
    hostname = hn
    return true
  end

  k.hooks.add("sandbox", function()
    k.userspace.package.loaded.network = k.util.copy_table(k.net)
  end)

  --#include "extra/net/internet.lua"
end
