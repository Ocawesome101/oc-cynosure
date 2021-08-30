-- users --

k.log(k.loglevels.info, "base/security/users")

--#include "base/security/sha3.lua"

do
  local api = {}

  -- default root data so we can at least run init as root
  -- the kernel should overwrite this with `users.prime()`
  -- and data from /etc/passwd later on
  -- but for now this will suffice
  local passwd = {
    [0] = {
      name = "root",
      home = "/root",
      shell = "/bin/lsh",
      acls = 8191,
      pass = k.util.to_hex(k.sha3.sha256("root")),
    }
  }

  k.hooks.add("shutdown", function()
    -- put this here so base/passwd_init can have it
    k.passwd = passwd
  end)

  function api.prime(data)
    checkArg(1, data, "table")
 
    api.prime = nil
    passwd = data
    k.passwd = data
    
    return true
  end

  function api.authenticate(uid, pass)
    checkArg(1, uid, "number")
    checkArg(2, pass, "string")
    
    pass = k.util.to_hex(k.sha3.sha256(pass))
    
    local udata = passwd[uid]
    
    if not udata then
      os.sleep(1)
      return nil, "no such user"
    end
    
    if pass == udata.pass then
      return true
    end
    
    os.sleep(1)
    return nil, "invalid password"
  end

  function api.exec_as(uid, pass, func, pname, wait)
    checkArg(1, uid, "number")
    checkArg(2, pass, "string")
    checkArg(3, func, "function")
    checkArg(4, pname, "string", "nil")
    checkArg(5, wait, "boolean", "nil")
    
    if k.scheduler.info().owner ~= 0 then
      if not k.security.acl.user_has_permission(k.scheduler.info().owner,
          k.security.acl.permissions.user.SUDO) then
        return nil, "permission denied: no permission"
      end
    
      if not api.authenticate(uid, pass) then
        return nil, "permission denied: bad login"
      end
    end
    
    local new = {
      func = func,
      name = pname or tostring(func),
      owner = uid,
      env = {
        USER = passwd[uid].name,
        UID = tostring(uid),
        SHELL = passwd[uid].shell,
        HOME = passwd[uid].home,
      }
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

  function api.usermod(attributes)
    checkArg(1, attributes, "table")
    attributes.uid = tonumber(attributes.uid) or (#passwd + 1)

    k.log(k.loglevels.debug, "changing attributes for user " .. attributes.uid)
    
    local current = k.scheduler.info().owner or 0
    
    if not passwd[attributes.uid] then
      assert(attributes.name, "usermod: a username is required")
      assert(attributes.pass, "usermod: a password is required")
      assert(attributes.acls, "usermod: ACL data is required")
      assert(type(attributes.acls) == "table","usermod: ACL data must be a table")
    else
      if attributes.pass and current ~= 0 and current ~= attributes.uid then
        -- only root can change someone else's password
        return nil, "cannot change password: permission denied"
      end
      for k, v in pairs(passwd[attributes.uid]) do
        attributes[k] = attributes[k] or v
      end
    end

    attributes.home = attributes.home or "/home/" .. attributes.name
    k.log(k.loglevels.debug, "shell = " .. attributes.shell)
    attributes.shell = (attributes.shell or "/bin/lsh"):gsub("%.lua$", "")
    k.log(k.loglevels.debug, "shell = " .. attributes.shell)

    local acl = k.security.acl
    if type(attributes.acls) == "table" then
      local acls = 0
      
      for k, v in pairs(attributes.acls) do
        if acl.permissions.user[k] and v then
          acls = acls | acl.permissions.user[k]
          if not acl.user_has_permission(current, acl.permissions.user[k])
              and current ~= 0 then
            return nil, k .. ": ACL permission denied"
          end
        else
          return nil, k .. ": no such ACL"
        end
      end

      attributes.acls = acls
    end

    passwd[tonumber(attributes.uid)] = attributes

    return true
  end

  function api.remove(uid)
    checkArg(1, uid, "number")
    if not passwd[uid] then
      return nil, "no such user"
    end

    if not k.security.acl.user_has_permission(k.scheduler.info().owner,
        k.security.acl.permissions.user.MANAGE_USERS) then
      return nil, "permission denied"
    end

    passwd[uid] = nil
    
    return true
  end
  
  k.security.users = api
end
