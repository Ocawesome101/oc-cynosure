-- package API.  this is probably the lib i copy-paste the most. --

do
  _G.package = {}
  local loaded = {
    os = os,
    io = io,
    math = math,
    string = string,
    table = table,
    unicode = unicode
  }
  package.loaded = loaded
  package.path = "/lib/?.lua;/lib/lib?.lua;/lib/?/init.lua"
  local fs = fs.api

  local function libError(name, searched)
    local err = "module '%s' not found:\n\tno field package.loaded['%s']"
    err = err .. ("\n\tno file '%s'"):rep(#searched)
    error(string.format(err, name, name, table.unpack(searched)))
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
    return nil, searched
  end

  package.protect = k.util.protect

  function package.delay(lib, file)
    local mt = {
      __index = function(tbl, key)
        setmetatable(lib, nil)
        setmetatable(lib.internal or {}, nil)
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
  function _G.loadfile(file, mode, env)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    checkArg(3, env, "table", "nil")
    local handle, err = io.open(file, "r")
    if not handle then
      return nil, err
    end
    local data = handle:read("a")
    handle:close()
    return load(data, "="..file, "bt", k.userspace or _G)
  end

  function _G.dofile(file)
    checkArg(1, file, "string")
    local ok, err = loadfile(file)
    if not ok then
      error(err)
    end
    local stat, ret = xpcall(ok, debug.traceback)
    if not stat and ret then
      error(ret)
    end
    return ret
  end
end
