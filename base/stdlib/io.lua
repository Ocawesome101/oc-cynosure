-- io library --

k.log(k.loglevels.info, "base/stdlib/io")

do
  local fs = k.fs.api
 
  local mt = {
    __index = function(t, k)
      local info = k.scheduler.info()
  
      if info.data.io[k] then
        return info.data.io[k]
      end
      
      return nil
    end,
    __newindex = function(t, k, v)
      local info = k.scheduler.info()
      info.data.io[k] = v
    end
  }

  _G.io = {}
  
  function io.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
  
    mode = mode or "r"
    
    local handle, err = fs.open(file, mode)
    if not handle then
      return nil, err
    end
    
    return k.create_fstream(handle, mode)
  end

  -- popen should be defined in userspace so the shell can handle it
  -- tmpfile should be defined in userspace also
  -- it turns out that defining things PUC Lua can pass off to the shell
  -- *when you don't have a shell* is rather difficult and so, instead of
  -- weird hacks like in Paragon or Monolith, I just leave it up to userspace.
  function io.popen()
    return nil, "io.popen unsupported at kernel level"
  end

  function io.tmpfile()
    return nil, "io.tmpfile unsupported at kernel level"
  end

  function io.read(...)
    return io.input():read(...)
  end

  function io.write(...)
    return io.output():write(...)
  end

  function io.lines(file, fmt)
    file = file or io.stdin
    checkArg(1, file, "FILE*")

    if type(file) == "string" then
      file = assert(io.open(file, "r"))
    end
    
    return file:lines(fmt)
  end

  local function stream(kk)
    return function(v)
      checkArg(1, v, "FILE*")

      local t = k.scheduler.info().data.io
    
      if v then
        t[kk] = v
      end
      
      return t[kk]
    end
  end

  io.input = stream("input")
  io.output = stream("output")

  function io.type(stream)
    assert(stream, "bad argument #1 (value expected)")
    
    if type(stream) == "FILE*" then
      if stream.closed then
        return "closed file"
      end
    
      return "file"
    end

    return nil
  end

  function io.flush(s)
    s = s or io.stdout
    checkArg(1, s, "FILE*")

    return s:flush()
  end

  function io.close(stream)
    checkArg(1, stream, "FILE*")

    if stream == io.stdin or stream == io.stdout or stream == io.stderr then
      return nil, "cannot close standard file"
    end
    
    return stream:close()
  end

  setmetatable(io, mt)

  function _G.print(...)
    local args = table.pack(...)
   
    for i=1, args.n, 1 do
      args[i] = tostring(args[i])
    end
    
    return io.write(table.concat(args, "  ", 1, args.n), "\n")
  end
end
