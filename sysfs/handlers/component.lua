-- sysfs: component event handlers

k.log(k.loglevels.info, "sysfs/handlers/component")

do
  local n = {}
  local gpus, screens = {}, {}

  local function update_ttys(a, c)
    if c == "gpu" then
      gpus[a] = false
    elseif c == "screen" then
      screens[a] = false
    end

    for gk, gv in pairs(gpus) do
      if not gv then
        for sk, sv in pairs(screens) do
          if not sv then
            k.create_tty(gk, sk)
            gpus[gk] = true
            screens[vk] = true
            break
          end
        end
      end
    end
  end

  local function added(addr, ctype)
    n[ctype] = n[ctype] or 0
    
    local path = "/sys/components/by-address/" .. addr
    local path2 = "/sys/components/by-type/" .. ctype .. "/" .. n[ctype]
    
    n[ctype] = n[ctype] + 1
    
    local s = k.sysfs.register(ctype, addr, path)
    if not s then
      s = k.sysfs.register("generic", addr, path)
      k.sysfs.register("generic", addr, path2)
    else
      k.sysfs.register(ctype, addr, path2)
    end

    if ctype == "gpu" or ctype == "screen" then
      update_ttys(addr, ctype)
    end
    
    return s
  end

  local function removed(addr, ctype)
    local path = "/sys/components/by-address/" .. addr
    local path2 = "/sys/components/by-type/" .. addr
    k.sysfs.unregister(path2)
    return k.sysfs.unregister(path)
  end

  k.event.register("component_added", added)
  k.event.register("component_removed", removed)
end
