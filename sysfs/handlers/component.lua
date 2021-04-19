-- sysfs: component event handlers

k.log(k.loglevels.info, "sysfs/handlers/component")

do
  local n = {}
  local function added(addr, ctype)
    n[ctype] = n[ctype] or 0
    local path = "/sys/dev/by-address/" .. addr
    local path2 = "/sys/dev/by-type/" .. ctype .. n[ctype]
    n[ctype] = n[ctype] + 1
    local s = k.sysfs.register(ctype, addr, path)
    if not s then
      s = k.sysfs.register("generic", addr, path)
      s = k.sysfs.register("generic", addr, path2)
    else
      k.sysfs.register(ctype, addr, path2)
    end
    return s
  end

  local function removed(addr, ctype)
    local path = "/sys/dev/by-address/" .. addr
    return k.sysfs.unregister(path)
  end

  k.event.register("component_added", added)
  k.event.register("component_removed", removed)
end
