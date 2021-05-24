-- load /etc/passwd, if it exists

k.log(k.loglevels.info, "base/passwd_init")

k.hooks.add("rootfs_mounted", function()
  local p1 = "(%d+):([^:]+):([0-9a-fA-F]+):(%d+):([^:]+):([^:]+)"
  local p2 = "(%d+):([^:]+):([0-9a-fA-F]+):(%d+):([^:]+)"
  local p3 = "(%d+):([^:]+):([0-9a-fA-F]+):(%d+)"

  k.log(k.loglevels.info, "Reading /etc/passwd")

  local handle, err = io.open("/etc/passwd", "r")
  if not handle then
    k.log(k.loglevels.info, "Failed opening /etc/passwd:", err)
  else
    local data = {}
    
    for line in handle:lines("l") do
      -- user ID, user name, password hash, ACLs, home directory,
      -- preferred shell
      local uid, uname, pass, acls, home, shell
      uid, uname, pass, acls, home, shell = line:match(p1)
      if not uid then
        uid, uname, pass, acls, home = line:match(p2)
      end
      if not uid then
        uid, uname, pass, acls = line:match(p3)
      end
      uid = tonumber(uid)
      if not uid then
        k.log(k.loglevels.info, "Invalid line:", line, "- skipping")
      else
        data[uid] = {
          name = uname,
          pass = pass,
          acls = tonumber(acls),
          home = home,
          shell = shell
        }
      end
    end
  
    handle:close()
  
    k.log(k.loglevels.info, "Registering user data")
  
    k.security.users.prime(data)

    k.log(k.loglevels.info,
      "Successfully registered user data from /etc/passwd")
  end

  k.hooks.add("shutdown", function()
    k.log(k.loglevels.info, "Saving user data to /etc/passwd")
    local handle, err = io.open("/etc/passwd", "w")
    if not handle then
      k.log(k.loglevels.warn, "failed saving /etc/passwd:", err)
      return
    end
    for k, v in pairs(k.passwd) do
      local data = string.format("%d:%s:%s:%d:%s:%s\n",
        k, v.name, v.pass, v.acls, v.home or ("/home/"..v.name),
        v.shell or "/bin/lsh")
      handle:write(data)
    end
    handle:close()
  end)
end)
