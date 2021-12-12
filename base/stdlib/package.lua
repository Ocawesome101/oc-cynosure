-- package API.  this is probably the lib i copy-paste the most. --

k.log(k.loglevels.info, "base/stdlib/package")

do
  _G.package = {}
 
  local loaded = {
    os = os,
    io = io,
    math = math,
    string = string,
    table = table,
    users = k.users,
    sha3 = k.sha3,
    unicode = unicode
  }
  
  package.loaded = loaded
  package.path = "/lib/?.lua;/lib/lib?.lua;/lib/?/init.lua;/usr/lib/?.lua;/usr/lib/lib?.lua;/usr/lib/?/init.lua"
  
  local fs = k.fs.api

  local function libError(name, searched)
    local err = "module '%s' not found:\n\tno field package.loaded['%s']"
    err = err .. ("\n\tno file '%s'"):rep(#searched)
  
    return string.format(err, name, name, table.unpack(searched))
  end

  function package.searchpath(name, path, sep, rep)
    checkArg(1, name, "string")
    checkArg(2, path, "string")
    checkArg(3, sep, "string", "nil")
    checkArg(4, rep, "string", "nil")
    
    sep = "%" .. (sep or ".")
    rep = rep or "/"
    
    local searched = {}
    
    name = name:gsub(sep, rep)
    
    for search in path:gmatch("[^;]+") do
      search = search:gsub("%?", name)
    
      if fs.stat(search) then
        return search
      end
      
      searched[#searched + 1] = search
    end

    return nil, libError(name, searched)
  end

  package.protect = k.util.protect

  function package.delay(lib, file)
    local mt = {
      __index = function(tbl, key)
        setmetatable(lib, nil)
        setmetatable(lib.internal or {}, nil)
        ; -- this is just in case, because Lua is weird
        (k.userspace.dofile or dofile)(file)
    
        return tbl[key]
      end
    }

    if lib.internal then
      setmetatable(lib.internal, mt)
    end
    
    setmetatable(lib, mt)
  end

  -- let's define this here because WHY NOT
  -- now with shebang support!
  local shebang_pattern = "^#!(/.-)\n"
  local ldf_loading = {}
  local ldf_cache = {}
  local ldf_mem_thresh = tonumber(k.cmdline["loadcache.gc_threshold"]) or 4096
  local ldf_max_age = tonumber(k.cmdline["loadcache.max_age"]) or 60

  k.event.register("*", function()
    for k, v in pairs(ldf_cache) do
      if ldf.time < computer.uptime() - ldf_max_age then
        ldf_cache[k] = nil
      end
    end
    if computer.freeMemory() <= ldf_mem_thresh then
      ldf_cache = {}
    end
  end)

  function _G.loadfile(file, mode, env)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    checkArg(3, env, "table", "nil")

    if ldf_loading[file] then
      return nil, "file is already loading, likely due to a shebang error"
    end

    file = k.fs.clean(file)

    local fstat, err = k.fs.api.stat(file)
    if not fstat then
      return nil, err
    end

    if ldf_cache[file] and fstat.lastModified<=ldf_cache[file].lastModified then
      ldf_cache[file].time = computer.uptime()
      return ldf_cache[file].func
    end
    
    local handle, err = io.open(file, "r")
    if not handle then
      return nil, err
    end

    ldf_loading[file] = true
    
    local data = handle:read("a")
    handle:close()

    local shebang = data:match(shebang_pattern) 
    if shebang then
      if not shebang:match("lua") then
        if k.fsapi.stat(shebang .. ".lua") then shebang = shebang .. ".lua" end
        local ok, err = loadfile(shebang)
        ldf_loading[file] = false
        if not ok and err then
          return nil, "error loading interpreter: " .. err
        end
        return function(...) return ok(file, ...) end
      else
        data = data:gsub(shebang_pattern, "")
      end
    end

    ldf_loading[file] = false

    local ok, err = load(data, "="..file, "bt", env or k.userspace or _G)
    if ok then
      ldf_cache[file] = {
        func = ok,
        time = computer.uptime(),
        lastModified = fstat.lastModified
      }
    end
    return ok, err
  end

  function _G.dofile(file)
    checkArg(1, file, "string")
    
    local ok, err = loadfile(file)
    if not ok then
      error(err, 0)
    end
    
    local stat, ret = xpcall(ok, debug.traceback)
    if not stat and ret then
      error(ret, 0)
    end
    
    return ret
  end

  local k = k
  k.hooks.add("sandbox", function()
    k.userspace.k = nil
    
    local acl = k.security.acl
    local perms = acl.permissions
    
    local function wrap(f, p)
      return function(...)
        if not acl.user_has_permission(k.scheduler.info().owner,
            p) then
          error("permission denied", 0)
        end
    
        return f(...)
      end
    end

    k.userspace.component = nil
    k.userspace.computer = nil
    k.userspace.unicode = nil

    k.userspace.package.loaded.component = {}
    
    for f,v in pairs(component) do
      k.userspace.package.loaded.component[f] = wrap(v,
        perms.user.COMPONENTS)
    end
    
    local cpushsig = computer.pushSignal
    local pushSignal
    if k.cmdline["pushSignal.localized"] then
      pushSignal = function(...)
          return k.scheduler.info().data.self:push_signal(...)
      end
    elseif k.cmdline["pushSignal.unprotected"] then
      k.log(k.loglevels.warn, "\27[101;97mWARNING\27[m got kernel argument pushSignal.unprotected=1 but that option is dangerous - proceeding anyway")
      pushSignal = computer.pushSignal
    else
      -- blacklist these
      local blacklist = {
        key_down = true,
        key_up = true,
        component_added = true,
        component_removed = true
      }
      pushSignal = function(s, ...)
        checkArg(1, s, "string")
        if not blacklist[s] then
          return cpushsig(s, ...)
        else
          error("signal " .. s .. " cannot be created by userspace")
        end
      end
    end
    
    k.userspace.package.loaded.computer = {
      getDeviceInfo = wrap(computer.getDeviceInfo, perms.user.HWINFO),
      setArchitecture = wrap(computer.setArchitecture, perms.user.SETARCH),
      addUser = wrap(computer.addUser, perms.user.MANAGE_USERS),
      removeUser = wrap(computer.removeUser, perms.user.MANAGE_USERS),
      setBootAddress = wrap(computer.setBootAddress, perms.user.BOOTADDR),
      pullSignal = coroutine.yield,
      pushSignal = pushSignal
    }
    
    for f, v in pairs(computer) do
      k.userspace.package.loaded.computer[f] =
        k.userspace.package.loaded.computer[f] or v
    end
    
    k.userspace.package.loaded.unicode = k.util.copy_table(unicode)
    k.userspace.package.loaded.filesystem = k.util.copy_table(k.fs.api)
    
    local ufs = k.userspace.package.loaded.filesystem
    ufs.mount = wrap(k.fs.api.mount, perms.user.MOUNT)
    ufs.umount = wrap(k.fs.api.umount, perms.user.MOUNT)
    
    k.userspace.package.loaded.filetypes = k.util.copy_table(k.fs.types)

    k.userspace.package.loaded.users = k.util.copy_table(k.security.users)

    k.userspace.package.loaded.acls = k.util.copy_table(k.security.acl.permissions)

    local blacklist = {}
    for k in pairs(k.userspace.package.loaded) do blacklist[k] = true end

    local shadow = k.userspace.package.loaded
    k.userspace.package.loaded = setmetatable({}, {
      __newindex = function(t, k, v)
        if shadow[k] and blacklist[k] then
          error("cannot override protected library " .. k, 0)
        else
          shadow[k] = v
        end
      end,
      __index = shadow,
      __pairs = shadow,
      __ipairs = shadow,
      __metatable = {}
    })

    local loaded = k.userspace.package.loaded
    local loading = {}
    function k.userspace.require(module)
      if loaded[module] then
        return loaded[module]
      elseif not loading[module] then
        local library, status, step
  
        step, library, status = "not found",
            package.searchpath(module, package.path)
  
        if library then
          step, library, status = "loadfile failed", loadfile(library)
        end
  
        if library then
          loading[module] = true
          step, library, status = "load failed", pcall(library, module)
          loading[module] = false
        end
  
        assert(library, string.format("module '%s' %s:\n%s",
            module, step, status))
  
        loaded[module] = status
        return status
      else
        error("already loading: " .. module .. "\n" .. debug.traceback(), 2)
      end
    end
  end)
end
