-- users --

k.log(k.loglevels.info, "base/security/users")

--#include "base/security/sha3.lua"

do
  local api = {}

  -- default root data so we can at least run init as root
  -- init should overwrite this with `users.prime()` later on
  -- but for now this will suffice
  local passwd = {
    [0] = {
      name = "root",
      home = "/root",
      shell = "/bin/rc",
      acls = 8191
    }
  }

  function api.prime(data)
    checkArg(1, data, "table")
    k.userspace.package.loaded.users.prime = nil
    passwd = data
    return true
  end

  function api.authenticate(uid, pass)
    checkArg(1, uid, "number")
    checkArg(2, pass, "string")
    pass = k.util.to_hex(pass)
    local udata = passwd[uid]
    if not udata then
      return nil, "no such user"
    end
    if pass == udata.pass then
      return true
    end
    return nil, "invalid password"
  end

  function api.exec_as(uid, pass, func)
    checkArg(1, uid, "number")
    checkArg(2, pass, "string")
    checkArg(3, func, "function")
  end

  function api.get_uid(uname)
    checkArg(1, uname, "string")
    for uid, udata in pairs(passwd) do
      if udata.name == uname then
        return uid
      end
    end
    return nil, "no such user"
  end

  function api.attributes(uid)
    checkArg(1, uid, "number")
    local udata = passwd[uid]
    if not udata then
      return nil, "no such user"
    end
    return {
      name = udata.name,
      home = udata.home,
      shell = udata.shell,
      acls = udata.acls
    }
  end

  k.security.users = api
end
