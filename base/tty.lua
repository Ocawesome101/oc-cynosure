-- object-based tty streams --

do
  local colors = {
    0x000000,
    0xFF0000,
    0x00FF00,
    0xFFFF00,
    0x0000FF,
    0xFF00FF,
    0x00AAFF,
    0xFFFFFF
  }

  -- pop characters from the end of a string
  local function pop(str, n)
    local ret = str:sub(1, n)
    local also = str:sub(#ret + 1, -1)
    return also, ret
  end

  local function wrap_cursor(self)
    while self.cx > self.w do
      self.cx, self.cy = self.cx - self.w, self.cy + 1
    end
    while self.cx < 1 do
      self.cx, self.cy = self.w + self.cx, self.cy - 1
    end
    while self.cy < 1 do
      self.cy = self.cy + 1
      self.gpu.copy(1, 1, self.w, self.h, 0, 1)
      self.gpu.fill(1, 1, self.w, 1, " ")
    end
    while self.cy > self.h do
      self.cy = self.cy - 1
      self.gpu.copy(1, 1, self.w, self.h, 0, -1)
      self.gpu.fill(1, self.h, self.w, 1, " ")
    end
  end

  local function writeline(self, rline)
    while #rline > 0 do
      local to_write
      rline, to_write = pop(rline, self.w - self.cx + 1)
      self.gpu.set(self.cx, self.cy, to_write)
      self.cx = self.cx + #to_write
      wrap_cursor(self)
    end
  end

  local function write(self, lines)
    while #lines > 0 do
      local next_nl = lines:find("\n")
      if next_nl then
        local ln
        lines, ln = pop(lines, next_nl - 1)
        lines = lines:sub(2) -- take off the newline
        writeline(self, ln)
        self.cx, self.cy = 1, self.cy + 1
        wrap_cursor(self)
      else
        writeline(self, lines)
        lines = ""
      end
    end
  end

  local commands, control = {}, {}
  local separators = {
    standard = "[",
    control = "("
  }

  -- move cursor up N[=1] lines
  function commands:A(args)
    local n = math.max(args[1] or 0, 1)
    self.cy = self.cy - n
  end

  -- move cursor down N[=1] lines
  function commands:B(args)
    local n = math.max(args[1] or 0, 1)
    self.cy = self.cy + n
  end

  -- move cursor right N[=1] lines
  function commands:C(args)
    local n = math.max(args[1] or 0, 1)
    self.cx = self.cx + n
  end

  -- move cursor left N[=1] lines
  function commands:D(args)
    local n = math.max(args[1] or 0, 1)
    self.cx = self.cx - n
  end

  function commands:G()
    self.cx = 1
  end

  function commands:H(args)
    local y, x = 1, 1
    y = args[1] or y
    x = args[2] or x
    self.cx = x
    self.cy = y
    wrap_cursor(self)
  end

  -- clear a portion of the screen
  function commands:J(args)
    local n = args[1] or 0
    if n == 0 then
      self.gpu.fill(1, self.cy, self.w, self.h, " ")
    elseif n == 1 then
      self.gpu.fill(1, 1, self.w, self.cy, " ")
    elseif n == 2 then
      self.gpu.fill(1, 1, self.w, self.h, " ")
    end
  end
  
  -- clear a portion of the current line
  function commands:K(args)
    local n = args[1] or 0
    if n == 0 then
      self.gpu.fill(self.cx, self.cy, self.w, 1, " ")
    elseif n == 1 then
      self.gpu.fill(1, self.cy, self.cx, 1, " ")
    elseif n == 2 then
      self.gpu.fill(1, self.cy, self.w, 1, " ")
    end
  end

  -- adjust terminal attributes
  function commands:m(args)
    args[1] = args[1] or 0
    for i=1, #args, 1 do
      local n = args[i]
      if n == 0 then
        self.fg = colors[8]
        self.bg = colors[1]
        self.attributes.echo = true
      elseif n == 8 then
        self.attributes.echo = false
      elseif n == 28 then
        self.attributes.echo = true
      elseif n > 29 and n < 38 then
        self.fg = colors[n - 29]
        self.gpu.setForeground(self.fg)
      elseif n == 39 then
        self.fg = colors[8]
        self.gpu.setForeground(self.fg)
      elseif n > 39 and n < 48 then
        self.bg = colors[n - 39]
        self.gpu.setBackground(self.bg)
      elseif n == 49 then
        self.bg = colors[1]
        self.gpu.setBackground(self.bg)
      end
    end
  end

  function commands:n(args)
    local n = args[1] or 0
    if n == 6 then
      self.rb = string.format("%s\27[%d;%dR", self.cy, self.cx)
    end
  end

  -- adjust more terminal attributes
  function control:c(args)
    args[1] = args[1] or 0
    for i=1, #args, 1 do
      local n = args[i]
      if n == 0 then -- (re)set configuration to sane defaults
        -- echo text that the user has entered
        self.attributes.echo = true
        -- buffer input by line
        self.attributes.line = true
        -- send raw key input data according to the VT100 spec
        self.attributes.raw = false
      -- these numbers aren't random - they're the ASCII codes of the most
      -- reasonable corresponding characters
      elseif n == 82 then
        self.attributes.raw = true
      elseif n == 114 then
        self.attributes.raw = false
      end
    end
  end

  local _stream = {}
  -- This is where most of the heavy lifting happens.  I've attempted to make
  --   this function fairly optimized, but there's only so much one can do given
  --   OpenComputers's call budget limits and wrapped string library.
  function _stream:write(str)
    local gpu = self.gpu
    -- TODO: cursor logic is a bit brute-force currently, there are certain
    -- TODO: scenarios where cursor manipulation is unnecessary
    local c, f, b = gpu.get(self.cx, self.cy)
    gpu.setForeground(b)
    gpu.setBackground(f)
    gpu.set(self.cx, self.cy, c)
    gpu.setForeground(self.fg)
    gpu.setBackground(self.bg)
    while #str > 0 do
      if self.in_esc then
        local esc_end = str:find("[a-zA-Z]")
        if not esc_end then
          self.esc = string.format("%s%s", self.esc, str)
        else
          self.in_esc = false
          local finish
          str, finish = pop(str, esc_end)
          local esc = string.format("%s%s", self.esc, finish)
          self.esc = ""
          local separator, raw_args, code = esc:match("\27([%[%(])([%d;]*)([a-zA-Z])")
          raw_args = raw_args or "0"
          local args = {}
          for arg in raw_args:gmatch("([^;]+)") do
            args[#args + 1] = tonumber(arg) or 0
          end
          if separator == separators.standard and commands[code] then
            commands[code](self, args)
          elseif separator == separators.control and control[code] then
            control[code](self, args)
          end
          wrap_cursor(self)
        end
      else
        local next_esc = str:find("\27")
        if next_esc then
          self.in_esc = true
          self.esc = ""
          local ln
          str, ln = pop(str, next_esc - 1)
          write(self, ln)
        else
          write(self, str)
          str = ""
        end
      end
    end

    c, f, b = gpu.get(self.cx, self.cy)
    gpu.setForeground(b)
    gpu.setBackground(f)
    gpu.set(self.cx, self.cy, c)
    gpu.setForeground(self.fg)
    gpu.setBackground(self.bg)
    return true
  end

  -- TODO: proper line buffering for output
  function _stream:flush()
    return true
  end

  -- aliases of key scan codes to key inputs
  local aliases = {
    [200] = "\27[A", -- up
    [208] = "\27[B", -- down
    [205] = "\27[C", -- right
    [203] = "\27[D", -- left
  }

  function _stream:key_down(...)
    local signal = table.pack(...)
    local char = aliases[signal[4]] or
              (signal[3] > 255 and unicode.char or string.char)(signal[3])
    if self.attributes.raw and self.echo then
      local ch = signal[3]
      if #char == 1 then
        char = ("^" .. string.char(
            (ch == 0 and 32) or
            (ch < 27 and ch + 96) or
            (ch == 27 and "[") or
            (ch == 28 and "\\") or
            (ch == 29 and "]") or
            (ch == 30 and "~") or
            (ch == 31 and "?") or ch
          ):upper()
        )
      end
    else
      if char == "\13" then char = "\n"
      elseif char == "\8" then self:write("\8 \8") end
    end
    if self.echo then
      self:write(char)
    end
    self.rb = string.format("%s%s", self.rb, char)
  end
  
  function _stream:read(n)
    repeat
      coroutine.yield()
    until #self.rb >= n and ((not self.attributes.line) or
                                  self.rb:find("\n") >= n)
    local data = self.rb:sub(1, n)
    self.rb = self.rb:sub(#data + 1)
    return data
  end

  local function closed()
    return nil, "stream closed"
  end

  function _stream:close()
    self.closed = true
    self.read = closed
    self.write = closed
    self.flush = closed
    self.close = closed
    k.event.unregister(self.key_handler_id)
    return true
  end

  -- this is the raw function for creating TTYs over components
  -- userspace gets abstracted-away stuff
  function k.create_tty(gpu, screen)
    checkArg(1, gpu, "string")
    checkArg(2, screen, "string")
    local proxy = component.proxy(gpu)
    proxy.bind(screen)
    -- userspace will never directly see this, so it doesn't really matter what
    -- we put in this table
    local new = setmetatable({
      attributes = {}, -- terminal attributes
      keyboards = {}, -- all attached keyboards on terminal initialization
      in_esc = false,
      gpu = proxy,
      esc = "",
      cx = 1,
      cy = 1,
      fg = 0xFFFFFF,
      bg = 0,
      rb = ""
    }, {__index = _stream})
    new.w, new.h = proxy.maxResolution()
    proxy.setResolution(new.w, new.h)
    proxy.fill(1, 1, new.w, new.h, " ")
    for _, keyboard in pairs(component.invoke(screen, "getKeyboards")) do
      new.keyboards[keyboard] = true
    end
    new.key_handler_id = k.event.register("key_down", function(...)
      return new:key_down(...)
    end)
    return new
  end
end
