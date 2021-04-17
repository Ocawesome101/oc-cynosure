-- sysfs API --

do
  local tree = {
    components = {dir = true},
    proc = {dir = true},
    dev = {dir = true},
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
    if f == "/" then
      return tree
    end
    local s = k.fs.split(f)
    local c = tree
    for i=1, #s, 1 do
      if s[i] == "dir" then
        return nil, k.fs.errors.file_not_found
      end
      if not c[s[i]] then
        return nil, k.fs.errors.file_not_found
      end
      c = c[s[i]]
    end
    return c
  end

  local obj = {}

  function obj:stat(f)
    checkArg(1, f, "string")
    local n, e = find(f)
    local e = tree[f]
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
    return {
      read = n.read or ferr,
      write = n.write or ferr,
      seek = n.seek or ferr,
      close = n.close or fclose
    }
  end

  -- we have to hook this here since the root filesystem isn't mounted yet
  -- when the kernel reaches this point
  k.hooks.add("sandbox", function()
    assert(k.fs.api.mount(obj, k.fs.api.types.NODE, "/sys"))
  end)
end
