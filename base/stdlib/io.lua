-- io library --

k.log(k.loglevels.info, "base/stdlib/io")

do
  local fs = k.fs.api
  local mt = {
    __index = function(t, k)
      local info = k.scheduler.info()
      if info.io[k] then
        return info.io[k]
      end
      return nil
    end,
    __newindex = function(t, k, v)
      local info = k.scheduler.info()
      if info.io[k] then
        info.io[k] = v
      end
      rawset(t, k, v)
    end
  }

  _G.io = {}
  function io.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    mode = mode or "r"
    local handle, err = fs.open(file)
    if not handle then
      return nil, err
    end
    return k.create_fstream(handle, mode)
  end

  -- popen should be defined in userspace so the shell can handle it
  -- tmpfile should be defined in userspace also
  function io.popen()
    return nil, "io.popen unsupported at kernel level"
  end

  function io.read(...)
    return io.input():read(...)
  end

  function io.write(...)
    return io.output():write(...)
  end

  function io.lines(file, fmt)
    file = file or io.stdin
    return file:lines(fmt)
  end

  local function stream(k)
    return function(v)
      local t = k.scheduler.info().io
      if v then
        t[k] = v
      end
      return t[k]
    end
  end

  io.input = stream("input")
  io.output = stream("output")

  function io.type(stream)
    assert(stream, "bad argument #1 (value expected)")
    if tostring(stream):match("FILE") then
      if stream.closed then
        return "closed file"
      end
      return "file"
    end
    return nil
  end

  function io.flush(s)
    s = s or io.stdout
    return s:flush()
  end

  function io.close(stream)
    if stream == io.stdin or stream == io.stdout or stream == io.stderr then
      return nil, "cannot close standard file"
    end
    return stream:close()
  end

  setmetatable(io, mt)
end
