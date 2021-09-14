-- implementation of the FILE* API --

k.log(k.loglevels.info, "base/stdlib/FILE*")

do
  local buffer = {}
 
  function buffer:read_byte()
    if __internal_yield then __internal_yield(1) end
    if self.buffer_mode ~= "none" and self.buffer_mode ~= "pipe" then
      if (not self.read_buffer) or #self.read_buffer == 0 then
        self.read_buffer = self.base:read(self.buffer_size)
      end
  
      if not self.read_buffer then
        self.closed = true
        return nil
      end
      
      local dat = self.read_buffer:sub(1,1)
      self.read_buffer = self.read_buffer:sub(2, -1)
      
      return dat
    else
      return self.base:read(1)
    end
  end

  function buffer:write_byte(byte)
    if self.buffer_mode ~= "none" then
      if #self.write_buffer >= self.buffer_size then
        self.base:write(self.write_buffer)
        self.write_buffer = ""
      end
      
      self.write_buffer = string.format("%s%s", self.write_buffer, byte)
    else
      return self.base:write(byte)
    end

    return true
  end

  function buffer:read_line()
    local line = ""
    
    repeat
      local c = self:read_byte()
      line = line .. (c or "")
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
      if fmt == 0 then return "" end
      local read = ""
    
      repeat
        local byte = self:read_byte()
        read = read .. (byte or "")
      until #read >= fmt or not byte
      
      return read
    else
      fmt = fmt:gsub("%*", ""):sub(1,1)
      
      if #fmt == 0 or not valid[fmt] then
        error("bad argument to 'read' (invalid format)")
      end
      
      if fmt == "l" or fmt == "L" then
        local line = self:read_line()
      
        if #line == 0 then
          return nil
        end

        if fmt == "l" then
          line = line:gsub("\n", "")
        end
        
        return line
      elseif fmt == "a" then
        local read = ""
        
        repeat
          local byte = self:read_byte()
          read = read .. (byte or "")
        until not byte
        
        return read
      elseif fmt == "n" then
        local read = ""
        
        repeat
          local byte = self:read_byte()
          if not tonumber(byte) then
            -- TODO: this breaks with no buffering
            self.read_buffer = byte .. self.read_buffer
          else
            read = read .. (byte or "")
          end
        until not tonumber(byte)
        
        return tonumber(read)
      end

      error("bad argument to 'read' (invalid format)")
    end
  end

  function buffer:read(...)
    if self.buffer_mode == "pipe" then
      if self.closed and #self.base.rb == 0 then
        return nil, "bad file descriptor"
      end
    elseif self.closed or not self.mode.r then
      return nil, "bad file descriptor"
    end
    
    local args = table.pack(...)
    if args.n == 0 then args[1] = "l" args.n = 1 end
    
    local read = {}
    for i=1, args.n, 1 do
      read[i] = self:read_formatted(args[i])
    end
    
    return table.unpack(read)
  end

  function buffer:lines(format)
    format = format or "l"
    
    return function()
      return self:read(format)
    end
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
    
    if self.buffer_mode == "none" then
      -- a-ha! performance shortcut!
      -- because writing in a chunk is much faster
      return self.base:write(write)
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
    return self.base:seek()
  end

  function buffer:flush()
    if self.closed then
      return nil, "bad file descriptor"
    end
    
    if #self.write_buffer > 0 then
      self.base:write(self.write_buffer)
      self.write_buffer = ""
    end

    if self.base.flush then
      self.base:flush()
    end
    
    return true
  end

  function buffer:close()
    self:flush()
    self.base:close()
    self.closed = true
  end

  local fmt = {
    __index = buffer,
    -- __metatable = {},
    __name = "FILE*"
  }

  function k.create_fstream(base, mode)
    checkArg(1, base, "table")
    checkArg(2, mode, "string")
  
    local new = {
      base = base,
      buffer_size = 512,
      read_buffer = "",
      write_buffer = "",
      buffer_mode = "standard", -- standard, line, none
      closed = false,
      mode = {}
    }
    
    for c in mode:gmatch(".") do
      new.mode[c] = true
    end
    
    setmetatable(new, fmt)
    return new
  end

  k.hooks.add("sandbox", function()
    k.userspace.package.loaded.fstream = {
      create = k.create_fstream
    }
  end)
end
