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

k.log(k.loglevels.info, "Starting\27[33m", _OSVERSION, "\27[37m")
