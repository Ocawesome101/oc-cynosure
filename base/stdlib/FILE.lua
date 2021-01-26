-- implementation of the FILE* API --

k.log(k.loglevels.info, "base/stdlib/FILE*")

do
  local buffer = {}
  function buffer:read_byte()
    if self.buffer_mode ~= "none" then
      if #self.read_buffer == 0 then
        self.read_buffer = self.stream:read(self.buffer_size)
      end
      local dat = self.read_buffer:sub(-1)
      self.read_buffer = self.read_buffer:sub(1, -2)
      return dat
    else
      return self.stream:read(1)
    end
  end

  function buffer:write_byte(byte)
    if self.buffer_mode ~= "none" then
      if #self.write_buffer >= self.buffer_size then
        self.stream:write(self.write_buffer)
        self.write_buffer = ""
      end
      self.write_buffer = string.format("%s%s", self.write_buffer, byte)
    else
      return self.stream:write(byte)
    end
    return true
  end

  function buffer:read_line()
    local line = ""
    repeat
      local c = self:read_byte()
      line = string.format("%s%s", line, c or "")
    until c == "\n" or not c
    return line
  end

  local valid = {
    a = true,
    l = true,
    L = true,
    n = true
  }

  function buffer:read_formatted(fmt)
    checkArg(1, fmt, "string", "number")
    if type(fmt) == "number" then
      local read = ""
      repeat
        local byte = self:read_byte()
        read = string.format("%s%s", read, byte or "")
      until #read > fmt or not byte
      return read
    else
      fmt = fmt:gsub("%*", ""):sub(1,1)
      if #fmt == 0 or not valid[fmt] then
        error("bad argument to 'read' (invalid format)")
      end
      if fmt == "l" or fmt == "L" then
        local line = self:read_line()
        if fmt == "l" then
          line = line:sub(1, -2)
        end
        return line
      elseif fmt == "a" then
        local read = ""
        repeat
          local byte = self:read_byte()
          read = string.format("%s%s", read, byte or "")
        until not byte
        return read
      elseif fmt == "n" then
        local read = ""
        repeat
          local byte = self:read_byte()
          read = string.format("%s%s", read, byte or "")
        until not tonumber(byte)
        return tonumber(read)
      end
      error("bad argument to 'read' (invalid format)")
    end
  end

  function buffer:read(...)
    if self.closed then
      return nil, "bad file descriptor"
    end
    local args = table.pack(...)
    local read = {}
    for i=1, args.n, 1 do
      read[i] = buffer:read_formatted(args[i])
    end
    return table.unpack(read)
  end

  function buffer:write(...)
    if self.closed then
      return nil, "bad file descriptor"
    end
    local args = table.pack(...)
    local write = ""
    for i=1, #args, 1 do
      checkArg(i, args[i], "string", "number")
      args[i] = tostring(args[i])
      write = string.format("%s%s", write, args[i])
    end
    for i=1, #write, 1 do
      local char = write:sub(i,i)
      self:write_byte(char)
    end
    return true
  end

  function buffer:seek(whence, offset)
    checkArg(1, whence, "string")
    checkArg(2, offset, "number")
    if self.closed then
      return nil, "bad file descriptor"
    end
    self:flush()
    return self.stream:seek()
  end

  function buffer:flush()
    if self.closed then
      return nil, "bad file descriptor"
    end
    if #self.write_buffer > 0 then
      self.stream:write(self.write_buffer)
      self.write_buffer = ""
    end
    return true
  end

  function buffer:close()
    self:flush()
    self.closed = true
  end

  local fmt = {
    __index = buffer,
    __name = "FILE*"
  }
  function k.create_fstream(base)
    local new = {
      stream = base,
      buffer_size = 512,
      read_buffer = "",
      write_buffer = "",
      buffer_mode = "standard", -- standard, line, none
      closed = false
    }
    return setmetatable(new, fmt)
  end
end
