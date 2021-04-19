-- sysfs API --

k.log(k.loglevels.info, "sysfs/sysfs")

do
  local tree = {
    components = {
      dir = true,
      ["by-address"] = {dir = true},
      ["by-type"] = {dir = true}
    },
    proc = {dir = true},
    dev = {
      dir = true,
      stdin = {
        dir = false,
        open = function()
          return io.stdin
        end
      },
      stdout = {
        dir = false,
        open = function()
          return io.stdout
        end
      },
      stderr = {
        dir = false,
        open = function()
          return io.stderr
        end
      },
    },
    mounts = {
      dir = false,
      read = function(h)
        if h.__has_been_read then
          return nil
        end

        local mounts = k.fs.api.mounts()
        local ret = ""
        
        for k, v in pairs(mounts) do
          ret = string.format("%s%s\n", ret, k..": "..v)
        end
        
        h.__has_been_read = true
        
        return ret
      end,
      write = function()
        return nil, "bad file descriptor"
      end
    }
  }

  local function find(f)
    k.log(k.loglevels.info, "SYSFS FIND:", f)

    if f == "/" or f == "" then
      return tree
    end

    local s = k.fs.split(f)
    local c = tree
    
    for i=1, #s, 1 do
      k.log(k.loglevels.info, "SYSFS CHECK SEGMENT:", s[i])
      if s[i] == "dir" then
        return nil, k.fs.errors.file_not_found
      end
    
      if not c[s[i]] then
        return nil, k.fs.errors.file_not_found
      end

      k.log(k.loglevels.info, "SYSFS SEGMENT IS VALID")
      
      c = c[s[i]]
    end

    return c
  end

  local obj = {}

  function obj:stat(f)
    checkArg(1, f, "string")
    
    local n, e = find(f)
    
    if n then
      return {
        permissions = 365,
        owner = 0,
        group = 0,
        lastModified = 0,
        size = 0,
        isDirectory = not not n.dir
      }
    else
      return nil, e
    end
  end

  function obj:touch()
    return nil, k.fs.errors.read_only
  end

  function obj:remove()
    return nil, k.fs.errors.read_only
  end

  function obj:list(d)
    local n, e = find(d)
    
    if not n then return nil, e end
    if not n.dir then return nil, k.fs.errors.not_a_directory end
    
    local f = {}
    
    for k, v in pairs(e) do
      if k ~= "dir" then
        f[#f+1] = k
      end
    end
    
    return f
  end

  local function ferr()
    return nil, "bad file descriptor"
  end

  local function fclose(self)
    if self.closed then
      return ferr()
    end
    
    self.closed = true
  end

  function obj:open(f, m)
    checkArg(1, f, "string")
    checkArg(2, m, "string")
    
    local n, e = find(f)
    
    if not n then return nil, e end
    if n.dir then return nil, k.fs.errors.is_a_directory end

    if n.open then return n.open(m) end
    
    return {
      read = n.read or ferr,
      write = n.write or ferr,
      seek = n.seek or ferr,
      close = n.close or fclose
    }
  end

  -- now here's the API
  local api = {}
  api.types = {
    generic = "generic",
    process = "process",
    directory = "directory"
  }
  typedef("string", "SYSFS_NODE")

  local handlers = {}

  function api.register(otype, node, path)
    checkArg(1, otype, "SYSFS_NODE")
    assert(type(node) ~= "nil", "bad argument #2 (value expected, got nil)")
    checkArg(3, path, "string")

    if not handlers[otype] then
      return nil, string.format("sysfs: node type '%s' not handled", otype)
    end

    local segments = k.fs.split(path)
    local nname = segments[#segments]
    local n, e = find(table.concat(segments, "/", 1, #segments - 1))

    if not n then
      return nil, e
    end

    local nn, ee = handlers[otype](node)
    if not nn then
      return nil, ee
    end

    n[nname] = nn

    return true
  end

  function api.retrieve(path)
    checkArg(1, path, "string")
    return find(path)
  end

  function api.unregister(path)
    checkArg(1, path, "string")
    
    local segments = fs.split(path)
    local ppath = table.concat(segments, "/", 1, #segments - 1)
    
    local node = segments[#segments]
    if node == "dir" then
      return nil, fs.errors.file_not_found
    end

    local n, e = find(ppath)
    if not n then
      return nil, e
    end

    if not n[node] then
      return nil, fs.errors.file_not_found
    end

    n[node] = nil

    return true
  end
  
  function api.handle(otype, mkobj)
    checkArg(1, otype, "SYSFS_NODE")
    checkArg(2, mkobj, "function")

    api.types[otype] = otype
    handlers[otype] = mkobj

    return true
  end
  
  k.sysfs = api

  -- we have to hook this here since the root filesystem isn't mounted yet
  -- when the kernel reaches this point.
  k.hooks.add("sandbox", function()
    assert(k.fs.api.mount(obj, k.fs.api.types.NODE, "sys"))
    -- Adding the sysfs API to userspace is probably not necessary for most
    -- things.  If it does end up being necessary I'll do it.
    --k.userspace.package.loaded.sysfs = k.util.copy_table(api)
  end)
end

--#include "sysfs/handlers.lua"
