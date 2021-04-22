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
      acls = 8191,
      pass = k.util.to_hex(k.sha3.sha256("root")),
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
    
    pass = k.util.to_hex(k.sha3.sha256(pass))
    
    local udata = passwd[uid]
    
    if not udata then
      return nil, "no such user"
    end
    
    if pass == udata.pass then
      return true
    end
    
    return nil, "invalid password"
  end

  function api.exec_as(uid, pass, func, pname, wait)
    checkArg(1, uid, "number")
    checkArg(2, pass, "string")
    checkArg(3, func, "function")
    checkArg(4, pname, "string", "nil")
    checkArg(5, wait, "boolean", "nil")
    
    if not k.acl.user_has_permission(k.scheduler.info().owner,
        k.acl.permissions.user.SUDO) then
      return nil, "permission denied: no permission"
    end
    
    if not api.authenticate(uid, pass) then
      return nil, "permission denied: bad login"
    end
    
    local new = {
      func = func,
      name = pname or tostring(func),
      owner = uid,
    }
    
    local p = k.scheduler.spawn(new)
    
    if not wait then return end

    -- this is the only spot in the ENTIRE kernel where process.await is used
    return k.userspace.package.loaded.process.await(p.pid)
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
