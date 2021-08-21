-- object-based tty streams --

do
  local colors = {
    0x000000,
    0xaa0000,
    0x00aa00,
    0xaa5500,
    0x0000aa,
    0xaa00aa,
    0x00aaaa,
    0xaaaaaa,
    0x555555,
    0xff5555,
    0x55ff55,
    0xffff55,
    0x5555ff,
    0xff55ff,
    0x55ffff,
    0xffffff
  }

  -- pop characters from the end of a string
  local function pop(str, n)
    local ret = str:sub(1, n)
    local also = str:sub(#ret + 1, -1)
 
    return also, ret
  end

  local function wrap_cursor(self)
    while self.cx > self.w do
    --if self.cx > self.w then
      self.cx, self.cy = math.max(1, self.cx - self.w), self.cy + 1
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
    local wrapped = false
    while #rline > 0 do
      local to_write
      rline, to_write = pop(rline, self.w - self.cx + 1)
      
      self.gpu.set(self.cx, self.cy, to_write)
      
      self.cx = self.cx + #to_write
      wrapped = self.cx > self.w
      
      wrap_cursor(self)
    end
    return wrapped
  end

  local function write(self, lines)
    while #lines > 0 do
      local next_nl = lines:find("\n")

      if next_nl then
        local ln
        lines, ln = pop(lines, next_nl - 1)
        lines = lines:sub(2) -- take off the newline
        
        local w = writeline(self, ln)

        if not w then
          self.cx, self.cy = 1, self.cy + 1
        end

        wrap_cursor(self)
      else
        writeline(self, lines)
        break
      end
    end
  end

  local commands, control = {}, {}
  local separators = {
    standard = "[",
    control = "?"
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
  
    self.cx = math.max(1, math.min(self.w, x))
    self.cy = math.max(1, math.min(self.h, y))
    
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

  -- adjust some terminal attributes - foreground/background color and local
  -- echo.  for more control {ESC}?c may be desirable.
  function commands:m(args)
    args[1] = args[1] or 0
    for i=1, #args, 1 do
      local n = args[i]
      if n == 0 then
        self.fg = colors[8]
        self.bg = colors[1]
        self.gpu.setForeground(self.fg)
        self.gpu.setBackground(self.bg)
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
      elseif n > 89 and n < 98 then
        self.fg = colors[n - 81]
        self.gpu.setForeground(self.fg)
      elseif n > 99 and n < 108 then
        self.bg = colors[n - 91]
        self.gpu.setBackground(self.bg)
      end
    end
  end

  function commands:n(args)
    local n = args[1] or 0

    if n == 6 then
      self.rb = string.format("%s\27[%d;%dR", self.rb, self.cy, self.cx)
    end
  end

  function commands:S(args)
    local n = args[1] or 1
    self.gpu.copy(1, 1, self.w, self.h, 0, -n)
    self.gpu.fill(1, self.h, self.w, n, " ")
  end

  function commands:T(args)
    local n = args[1] or 1
    self.gpu.copy(1, 1, self.w, self.h, 0, n)
    self.gpu.fill(1, 1, self.w, n, " ")
  end

  -- adjust more terminal attributes
  -- codes:
  --   - 0: reset
  --   - 1: enable echo
  --   - 2: enable line mode
  --   - 3: enable raw mode
  --   - 11: disable echo
  --   - 12: disable line mode
  --   - 13: disable raw mode
  function control:c(args)
    args[1] = args[1] or 0
    
    for i=1, #args, 1 do
      local n = args[i]

      if n == 0 then -- (re)set configuration to sane defaults
        -- echo text that the user has entered?
        self.attributes.echo = true
        
        -- buffer input by line?
        self.attributes.line = true
        
        -- whether to send raw key input data according to the VT100 spec,
        -- rather than e.g. changing \r -> \n and capturing backspace
        self.attributes.raw = false

        -- whether to show the terminal cursor
        self.attributes.cursor = true
      elseif n == 1 then
        self.attributes.echo = true
      elseif n == 2 then
        self.attributes.line = true
      elseif n == 3 then
        self.attributes.raw = true
      elseif n == 4 then
        self.attributes.cursor = true
      elseif n == 11 then
        self.attributes.echo = false
      elseif n == 12 then
        self.attributes.line = false
      elseif n == 13 then
        self.attributes.raw = false
      elseif n == 14 then
        self.attributes.cursor = false
      end
    end
  end

  -- adjust signal behavior
  -- 0: reset
  -- 1: disable INT on ^C
  -- 2: disable keyboard STOP on ^Z
  -- 3: disable HUP on ^D
  -- 11: enable INT
  -- 12: enable STOP
  -- 13: enable HUP
  function control:s(args)
    args[1] = args[1] or 0
    for i=1, #args, 1 do
      local n = args[i]
      if n == 0 then
        self.disabled = {}
      elseif n == 1 then
        self.disabled.C = true
      elseif n == 2 then
        self.disabled.Z = true
      elseif n == 3 then
        self.disabled.D = true
      elseif n == 11 then
        self.disabled.C = false
      elseif n == 12 then
        self.disabled.Z = false
      elseif n == 13 then
        self.disabled.D = false
      end
    end
  end

  local _stream = {}

  local function temp(...)
    return ...
  end

  function _stream:write(...)
    checkArg(1, ..., "string")

    local str = (k.util and k.util.concat or temp)(...)

    if self.attributes.line and not k.cmdline.nottylinebuffer then
      self.wb = self.wb .. str
      if self.wb:find("\n") then
        local ln = self.wb:match("(.-\n)")
        self.wb = self.wb:sub(#ln + 1)
        return self:write_str(ln)
      elseif #self.wb > 2048 then
        local ln = self.wb
        self.wb = ""
        return self:write_str(ln)
      end
    else
      return self:write_str(str)
    end
  end

  -- This is where most of the heavy lifting happens.  I've attempted to make
  -- this function fairly optimized, but there's only so much one can do given
  -- OpenComputers's call budget limits and wrapped string library.
  function _stream:write_str(str)
    local gpu = self.gpu
    local time = computer.uptime()
    
    -- TODO: cursor logic is a bit brute-force currently, there are certain
    -- TODO: scenarios where cursor manipulation is unnecessary
    if self.attributes.cursor then
      local c, f, b = gpu.get(self.cx, self.cy)
      gpu.setForeground(b)
      gpu.setBackground(f)
      gpu.set(self.cx, self.cy, c)
      gpu.setForeground(self.fg)
      gpu.setBackground(self.bg)
    end
    
    -- lazily convert tabs
    str = str:gsub("\t", "  ")
    
    while #str > 0 do
      if computer.uptime() - time >= 4.8 then -- almost TLWY
        time = computer.uptime()
        computer.pullSignal(0) -- yield so we don't die
      end

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

          local separator, raw_args, code = esc:match(
            "\27([%[%?])([%d;]*)([a-zA-Z])")
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
        -- handle BEL and \r
        if str:find("\a") then
          computer.beep()
        end
        str = str:gsub("\a", "")
        str = str:gsub("\r", "\27[G")

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

    if self.attributes.cursor then
      c, f, b = gpu.get(self.cx, self.cy)
    
      gpu.setForeground(b)
      gpu.setBackground(f)
      gpu.set(self.cx, self.cy, c)
      gpu.setForeground(self.fg)
      gpu.setBackground(self.bg)
    end
    
    return true
  end

  function _stream:flush()
    if #self.wb > 0 then
      self:write_str(self.wb)
      self.wb = ""
    end
    return true
  end

  -- aliases of key scan codes to key inputs
  local aliases = {
    [200] = "\27[A", -- up
    [208] = "\27[B", -- down
    [205] = "\27[C", -- right
    [203] = "\27[D", -- left
  }

  local sigacts = {
    D = 1, -- hangup, TODO: check this is correct
    C = 2, -- interrupt
    Z = 18, -- keyboard stop
  }

  function _stream:key_down(...)
    local signal = table.pack(...)

    if not self.keyboards[signal[2]] then
      return
    end

    if signal[3] == 0 and signal[4] == 0 then
      return
    end
    
    local char = aliases[signal[4]] or
              (signal[3] > 255 and unicode.char or string.char)(signal[3])
    local ch = signal[3]
    local tw = char

    if ch == 0 and not aliases[signal[4]] then
      return
    end
    
    if #char == 1 and ch == 0 then
      char = ""
      tw = ""
    elseif char:match("\27%[[ABCD]") then
      tw = string.format("^[%s", char:sub(-1))
    elseif #char == 1 and ch < 32 then
      local tch = string.char(
          (ch == 0 and 32) or
          (ch < 27 and ch + 96) or
          (ch == 27 and 91) or -- [
          (ch == 28 and 92) or -- \
          (ch == 29 and 93) or -- ]
          (ch == 30 and 126) or
          (ch == 31 and 63) or ch
        ):upper()
    
      if sigacts[tch] and not self.disabled[tch] and k.scheduler.processes
          and not self.attributes.raw then
        -- fairly stupid method of determining the foreground process:
        -- find the highest PID associated with this TTY
        -- yeah, it's stupid, but it should work in most cases.
        -- and where it doesn't the shell should handle it.
        local mxp = 0

        for _k, v in pairs(k.scheduler.processes) do
          --k.log(k.loglevels.error, _k, v.name)
          if v.io.stderr.tty == self.ttyn then
            mxp = math.max(mxp, _k)
          elseif v.io.stdin.tty == self.ttyn then
            mxp = math.max(mxp, _k)
          elseif v.io.stdout.tty == self.ttyn then
            mxp = math.max(mxp, _k)
          end
        end

        --k.log(k.loglevels.error, "sending", sigacts[tch], "to", mxp == 0 and mxp or k.scheduler.processes[mxp].name)

        if mxp > 0 then
          k.scheduler.processes[mxp]:signal(sigacts[tch])
        end

        self.rb = ""
        if tch == "\4" then self.rb = tch end
        char = ""
      end

      tw = "^" .. tch
    end
    
    if not self.attributes.raw then
      if ch == 13 then
        char = "\n"
        tw = "\n"
      elseif ch == 8 then
        if #self.rb > 0 then
          tw = "\27[D \27[D"
          self.rb = self.rb:sub(1, -2)
        else
          tw = ""
        end
        char = ""
      end
    end
    
    if self.attributes.echo then
      self:write_str(tw or "")
    end
    
    self.rb = string.format("%s%s", self.rb, char)
  end

  function _stream:clipboard(...)
    local signal = table.pack(...)

    for c in signal[3]:gmatch(".") do
      self:key_down(signal[1], signal[2], c:byte(), 0)
    end
  end
  
  function _stream:read(n)
    checkArg(1, n, "number")

    self:flush()

    local dd = self.disabled.D or self.attributes.raw

    if self.attributes.line then
      while (not self.rb:find("\n")) or (self.rb:find("\n") < n)
          and not (self.rb:find("\4") and not dd) do
        coroutine.yield()
      end
    else
      while #self.rb < n and (self.attributes.raw or not
          (self.rb:find("\4") and not dd)) do
        coroutine.yield()
      end
    end

    if self.rb:find("\4") and not dd then
      self.rb = ""
      return nil
    end

    local data = self.rb:sub(1, n)
    self.rb = self.rb:sub(n + 1)
    -- component.invoke(component.list("ocemu")(), "log", '"'..data..'"', #data)
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
    k.event.unregister(self.clip_handler_id)
    if self.ttyn then k.sysfs.unregister("/dev/tty"..self.ttyn) end
    return true
  end

  local ttyn = 0

  -- this is the raw function for creating TTYs over components
  -- userspace gets somewhat-abstracted-away stuff
  function k.create_tty(gpu, screen)
    checkArg(1, gpu, "string")
    checkArg(2, screen, "string")

    local proxy = component.proxy(gpu)

    proxy.bind(screen)
    proxy.setForeground(colors[8])
    proxy.setBackground(colors[1])

    proxy.setDepth(proxy.maxDepth())
    -- optimizations for no color on T1
    if proxy.getDepth() == 1 then
      local fg, bg = proxy.setForeground, proxy.setBackground
      local f, b = colors[1], colors[8]
      function proxy.setForeground(c)
        if c >= 0xAAAAAA or c <= 0x111111 and f ~= c then
          fg(c)
        end
        f = c
      end
      function proxy.setBackground(c)
        if c >= 0xAAAAAA or c <= 0x111111 and b ~= c then
          bg(c)
        end
        b = c
      end
      proxy.getBackground = function()return f end
      proxy.getForeground = function()return b end
    end

    -- userspace will never directly see this, so it doesn't really matter what
    -- we put in this table
    local new = setmetatable({
      attributes = {echo=true,line=true,raw=false,cursor=false}, -- terminal attributes
      disabled = {}, -- disabled signals
      keyboards = {}, -- all attached keyboards on terminal initialization
      in_esc = false, -- was a partial escape sequence written
      gpu = proxy, -- the associated GPU
      esc = "", -- the escape sequence buffer
      cx = 1, -- the cursor's X position
      cy = 1, -- the cursor's Y position
      fg = colors[8], -- the current foreground color
      bg = colors[1], -- the current background color
      rb = "", -- a buffer of characters read from the input
      wb = "", -- line buffering at its finest
    }, {__index = _stream})

    -- avoid gpu.getResolution calls
    new.w, new.h = proxy.maxResolution()

    proxy.setResolution(new.w, new.h)
    proxy.fill(1, 1, new.w, new.h, " ")
    
    -- register all keyboards attached to the screen
    for _, keyboard in pairs(component.invoke(screen, "getKeyboards")) do
      new.keyboards[keyboard] = true
    end
    
    -- register a keypress handler
    new.key_handler_id = k.event.register("key_down", function(...)
      return new:key_down(...)
    end)

    new.clip_handler_id = k.event.register("clipboard", function(...)
      return new:clipboard(...)
    end)
    
    -- register the TTY with the sysfs
    if k.sysfs then
      k.sysfs.register(k.sysfs.types.tty, new, "/dev/tty"..ttyn)
      new.ttyn = ttyn
    end

    new.tty = ttyn

    if k.gpus then
      k.gpus[ttyn] = proxy
    end
    
    ttyn = ttyn + 1
    
    return new
  end
end
