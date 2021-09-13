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

  function k.net.listen(url, ...)
    checkArg(1, url, "string")
    local proto, rest = url:match(ppat)
    if not proto then
      return nil, "protocol unspecified"
    elseif not protocols[proto] then
      return nil, "bad protocol: " .. proto
    elseif not protocols[proto].listen then
      return nil, "protocol does not support listening"
    end

    return protocols[proto].listen(proto, rest, ...)
  end

  local hostname = "localhost"

  function k.net.hostname()
    return hostname
  end

  function k.net.sethostname(hn)
    checkArg(1, hn, "string")
    local perms = k.security.users.attributes(k.scheduler.info().owner).acls
    if not k.security.acl.has_permission(perms,
        k.security.acl.permissions.user.HOSTNAME) then
      return nil, "insufficient permission"
    end
    hostname = hn
    for k, v in pairs(protocols) do
      if v.sethostname then
        v.sethostname(hn)
      end
    end
    return true
  end

  k.hooks.add("sandbox", function()
    k.userspace.package.loaded.network = k.util.copy_table(k.net)
  end)

  --#include "extra/net/internet.lua"
  --#include "extra/net/minitel.lua"
end
