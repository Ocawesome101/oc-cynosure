-- Cynosure kernel.  Should (TM) be mostly drop-in compatible with Paragon. --
-- Might even be better.  Famous last words!

_G.k = { args = table.pack(...), modules = {} }

-- kernel arguments

do
  local arg_pattern = "^(.-)=(.+)$"
  local orig_args = k.args
  k.args = {}

  for i=1, orig_args.n, 1 do
    local arg = orig_args[i]
    if arg:match(arg_pattern) then
      local k, v = arg:match(arg_pattern)
      if k and v then
        k.args[k] = v
      end
    else
      k.args[arg] = true
    end
  end
end


-- kernel version info --

do
  k._NAME = "Cynosure"
  k._RELEASE = "0" -- not released yet
  k._VERSION = ""
end


-- object-based tty streams --

do
  local colors = {
    0x000000,
    0xFF0000,
    0x00FF00,
    0xFFFF00,
    0x0000FF,
    0xFF00FF,
    0x00FFFF,
    0xFFFFFF
  }

  -- pop characters from the end of a string
  local function pop(str, n)
    local ret = str:sub(1, n)
    local also = str:sub(#ret + 1)
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

  local function write(self, str)
    for line in str:gmatch("[^\n]+") do
      while #line > 0 do
        local to_write
        to_write, line = pop(line, self.w - self.cx + 1)
        self.gpu.set(self.cx, self.cy, to_write)
        self.cx = self.cx + #to_write
        wrap_cursor(self)
      end
      self.cx, self.cy = 1, self.cy + 1
      wrap_cursor(self)
    end
  end

  local commands, control = {}, {}
  local separators = {
    standard = "[",
    control = "("
  }

  -- move cursor up N[=1] lines
  function commands:A(args)
    local n = args[1] or 1
    self.cy = self.cy - n
  end

  -- move cursor down N[=1] lines
  function commands:B(args)
    local n = args[1] or 1
    self.cy = self.cy + n
  end

  -- move cursor right N[=1] lines
  function commands:C(args)
    local n = args[1] or 1
    self.cx = self.cx + n
  end

  -- move cursor left N[=1] lines
  function commands:D(args)
    local n = args[1] or 1
    self.cx = self.cx - n
  end

  -- clear a portion of the screen
  function commands:J(args)
  end
  
  -- clear a portion of the current line
  function commands:K(args)
  end

  -- adjust terminal attributes
  function commands:m(args)
  end


  -- adjust more terminal attributes
  function control:c(args)
    args[1] = args[1] or 0
    for i=1, #args, 1 do
      local arg = args[i]
      if arg == 0 then -- (re)set configuration to sane defaults
        -- echo text that the user has entered
        self.attributes.echo = true
        -- buffer input by line
        self.attributes.line = true
        -- send raw key input data according to the VT100 spec
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
          break
        else
          self.in_esc = false
          local finish
          str, finish = pop(str, esc_end)
          local esc = string.format("%s%s", self.esc, str)
          self.esc = ""
          local raw_args, separator, code = esc:match("\27(^%d)([%d;]+)([a-zA-Z])")
          local args = {}
          for arg in raw_args:match("([^;]+)") do
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
          str, ln = pop(str, next_esc)
          write(self)
        else
          write(self, str)
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

  -- This function returns a single key press every time it is called.  Later
  --   APIs (the pty module) use this as a keypress listener
  function _stream:read()
    local signal
    repeat
      signal = table.pack(computer.pullSignal())
    until signal[1] == "key_down" and self.keyboards[signal[2]]
                                  and (signal[3] > 0 or aliases[signal[4]])
    return aliases[signal[4]] or --                                   :)
              (signal[3] > 255 and unicode.char or string.char)(signal[3])
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
      attributes = {}, -- used by other things but not directly by this terminal
      keyboards = {}, -- all attached keyboards on terminal initialization
      in_esc = false,
      gpu = proxy,
      esc = "",
      cx = 0,
      cy = 0,
      fg = 0xFFFFFF,
      bg = 0,
    }, {__index = _stream})
    new.w, new.h = proxy.maxResolution()
    proxy.setResolution(new.w, new.h)
    for _, keyboard in pairs(component.invoke(screen, "getKeyboards")) do
      new.keyboards[keyboard] = true
    end
    return new
  end
end



