-- access control lists, mostly --

k.log(k.loglevels.info, "base/security/access_control")

do
  -- this implementation of ACLs is fairly basic.
  -- it only supports boolean on-off permissions rather than, say,
  -- allowing users only to log on at certain times of day.
  local permissions = {
    user = {
      CAN_SUDO = 1,
      CAN_MOUNT = 2,
      OPEN_UNOWNED = 4,
    },
    file = {
      OWNER_READ = 1,
      OWNER_WRITE = 2,
      OWNER_EXEC = 4,
      GROUP_READ = 8,
      GROUP_WRITE = 16,
      GROUP_EXEC = 32,
      OTHER_READ = 64,
      OTHER_WRITE = 128,
      OTHER_EXEC = 256
    }
    
  }
  local acl = {}

  acl.permissions = permissions

  function acl.user_has_permission(uid, permission)
    checkArg(1, uid, "string")
    checkArg(2, permission, "number")
    local attributes, err = k.users.attributes(uid)
    if not attributes then
      return nil, err
    end
    return acl.has_permission(attributes.acls, permission)
  end

  function acl.has_permission(perms, permission)
    checkArg(1, perms, "number")
    checkArg(2, permission, "number")
    return perms & permission ~= 0
  end

  k.security.acl = acl
end
