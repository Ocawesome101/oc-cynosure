-- Cynosure kernel.  Should (TM) be mostly drop-in compatible with Paragon. --
-- Might even be better.  Famous last words!

_G.k = { cmdline = table.pack(...), modules = {} }
do
  local start = computer.uptime()
  function k.uptime()
    return computer.uptime() - start
  end
end

-- kernel arguments

do
  local arg_pattern = "^(.-)=(.+)$"
  local orig_args = k.cmdline
  k.cmdline = {}

  for i=1, orig_args.n, 1 do
    local arg = orig_args[i]
    if arg:match(arg_pattern) then
      local k, v = arg:match(arg_pattern)
      if k and v then
        k.cmdline[k] = tonumber(v) or v
      end
    else
      k.cmdline[arg] = true
    end
  end
end


-- kernel version info --

do
  k._NAME = "Cynosure"
  k._RELEASE = "0" -- not released yet
  k._VERSION = ""
  _G._OSVERSION = string.format("%s r%s %s", k._NAME, k._RELEASE, k._VERSION)
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

  local function write(self, str)
    for line in str:gmatch("([^\n]+)") do
      local rline = line
      while #rline > 0 do
        local to_write
        rline, to_write = pop(rline, self.w - self.cx + 1)
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
      elseif n > 39 and n < 48 then
        self.bg = colors[n - 39]
      end
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
      cx = 1,
      cy = 1,
      fg = 0xFFFFFF,
      bg = 0,
    }, {__index = _stream})
    new.w, new.h = proxy.maxResolution()
    proxy.setResolution(new.w, new.h)
    proxy.fill(1, 1, new.w, new.h, " ")
    for _, keyboard in pairs(component.invoke(screen, "getKeyboards")) do
      new.keyboards[keyboard] = true
    end
    return new
  end
end


-- early boot logger

do
  local levels = {
    debug = 0,
    info = 1,
    warn = 64,
    error = 128,
    panic = 256,
  }
  k.loglevels = levels

  local lgpu = component.list("gpu", true)()
  local lscr = component.list("screen", true)()

  local function safe_concat(...)
    local args = table.pack(...)
    local msg = ""
    for i=1, args.n, 1 do
      msg = string.format("%s%s ", msg, tostring(args[i]))
    end
    return msg
  end

  if lgpu and lscr then
    k.logio = k.create_tty(lgpu, lscr)
    function k.log(level, ...)
      local msg = safe_concat(...)
      if (tonumber(k.cmdline.loglevel) or 1) <= level then
        k.logio:write(string.format("[%4.4f] %s\n", k.uptime(), msg))
      end
      return true
    end
  else
    k.logio = nil
    function k.log()
    end
  end
end

k.log(k.loglevels.info, "Starting", _OSVERSION)


-- kernel hooks

k.log(k.loglevels.info, "base/hooks")

do
  k.hooks = {}
  local hooks = {}
  function k.hooks.add(name, func)
    checkArg(1, name, "string")
    checkArg(2, func, "function")
    hooks[name] = hooks[name] or {}
    table.insert(hooks[name], func)
  end

  function k.hooks.call(name, ...)
    if hooks[name] then
      for k, v in ipairs(hooks[name]) do
        v(...)
      end
    end
  end
end


-- some shutdown related stuff

k.log(k.loglevels.info, "base/shutdown")

do
  local shutdown = computer.shutdown
  function k.shutdown(rbt)
    k.hooks.call("shutdown", rbt)
    shutdown(rbt)
  end
end


-- some component API conveniences

k.log(k.loglevels.info, "base/component")

do
  function component.get(addr, mkpx)
    checkArg(1, addr, "string")
    checkArg(2, mkpx, "boolean", "nil")
    local pat = string.format("^%s", addr:gsub("%-", "%%-"))
    for k, v in component.list() do
      if k:match(pat) then
        return mkpx and component.proxy(k) or k
      end
    end
    return nil, "no such component"
  end

  setmetatable(component, {
    __index = function(t, k)
      local addr = component.list(k)()
      if not addr then
        error(string.format("no component of type '%s'", k))
      end
      return component.proxy(addr)
    end
  })
end


-- fsapi: VFS and misc filesystem infrastructure

k.log(k.loglevels.info, "base/fsapi")

do
  local fs = {}

  -- This VFS should support directory overlays, fs mounting, and directory
  --    mounting, hopefully all seamlessly.
  -- mounts["/"] = { proxy = ..., children = {["/bin"] = "/usr/bin", ...}}
  local mounts = {}

  local function split()
  end

  k.fs = fs
end


-- custom types

k.log(k.loglevels.info, "base/types")

do
  local old_type = type
  function _G.type(obj)
    if type(obj) == "table" then
      local mt = getmetatable(obj) or {}
      return mt.__name or mt.__type or old_type(obj)
    else
      return old_type(obj)
    end
  end

  -- copied from machine.lua
  function _G.checkArg(n, have, ...)
    have = type(have)
    local function check(want, ...)
      if not want then
        return false
      else
        return have == want or check(...)
      end
    end
    if not check(...) then
      local msg = string.format("bad argument #%d (%s expected, got %s)",
                                n, table.concat(table.pack(...), " or "), have)
      error(msg, 2)
    end
  end
end


-- thread: wrapper around coroutines

k.log(k.loglevels.info, "base/thread")

do
  local old_coroutine = coroutine
  local _coroutine = {}
  _G.coroutine = _coroutine
  function _coroutine.create(func)
    checkArg(1, func, "function")
    return setmetatable({
      __thread = old_coroutine.create(func)
    },
    {
      __index = _coroutine,
      __name = "thread"
    })
  end

  function _coroutine.wrap(fnth)
    checkArg(1, fnth, "function", "thread")
    if type(fnth) == "function" then fnth = _coroutine.create(fnth) end
    return function(...)
      return select(2, fnth:resume(...))
    end
  end

  function _coroutine:resume(...)
    return old_coroutine.resume(self.__thread, ...)
  end

  -- build iterable table
  local iter = {}
  for k, v in pairs(old_coroutine) do
    iter[k] = v
  end
  for k, v in pairs(_coroutine) do
    iter[k] = v
  end

  setmetatable(_coroutine, {
    __index = function(t, k)
      if k.scheduler then
        local process = k.scheduler.current()
        if process.coroutine_handler[k] then
          return process.coroutine_handler[k]
        end
      end
      return old_coroutine[k]
    end,
    __pairs = function()
      return pairs(iter)
    end
  })
end


-- processes

k.log(k.loglevels.info, "base/process")

do
  function k.create_process()
  end
end


-- scheduler

k.log(k.loglevels.info, "base/scheduler")

do
end






-- temporary main loop
while true do
  computer.pullSignal()
end
