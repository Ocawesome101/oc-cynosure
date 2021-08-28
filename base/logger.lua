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
      msg = string.format("%s%s%s", msg, tostring(args[i]), i < args.n and " " or "")
    end
    return msg
  end

  if lgpu and lscr then
    k.logio = k.create_tty(lgpu, lscr)
    
    if k.cmdline.bootsplash then
      local lgpu = component.proxy(lgpu)
      function k.log() end

      -- TODO custom bootsplash support
      local splash = {
        "   ⢀⣠⣴⣾⠿⠿⢿⣿⣶⣤⣀    ",
        " ⢀⣴⣿⣿⠋     ⠉⠻⢿⣷⣄  ",
        "⢀⣾⣿⣿⠏        ⠈⣿⣿⣆ ",
        "⣾⣿⣿⡟   ⢀⣾⣿⣿⣦⣄⣠⣿⣿⣿⡆",
        "⣿⣿⣿⠁   ⠘⠿⢿⣿⣿⣿⣿⣿⣿⣿⡇",
        "⢻⣿⣿⣄⡀     ⠉⢻⣿⣿⣿⣿⣿⠃",
        " ⢻⣿⣿⣿⣿⣶⣆⡀  ⢸⣿⣿⣿⣿⠃ ",
        "  ⠙⢿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⠟⠁  ",
        "    ⠈⠙⠻⠿⠿⠿⠿⠛⠉     ",
        "                  ",
        "     CYNOSURE     ",
      }

      lgpu.setBackground(0)
      lgpu.setForeground(0x66B6FF)
      local w, h = lgpu.maxResolution()
      local x, y = (w // 2) - (#splash[1] // 2) + 2, (h // 2) - (#splash // 2)
      lgpu.setResolution(w, h)
      lgpu.fill(1, 1, w, h, " ")
      for i, line in ipairs(splash) do
        lgpu.set(x, y + i - 1, line)
      end
    else
      function k.log(level, ...)
        local msg = safe_concat(...)
        msg = msg:gsub("\t", "  ")
  
        if k.util and not k.util.concat then
          k.util.concat = safe_concat
        end
      
        if (tonumber(k.cmdline.loglevel) or 1) <= level then
          k.logio:write(string.format("[\27[35m%4.4f\27[37m] %s\n", k.uptime(),
            msg))
        end
        return true
      end
    end
  else
    k.logio = nil
    function k.log()
    end
  end

  local raw_pullsignal = computer.pullSignal
  
  function k.panic(...)
    local msg = safe_concat(...)
  
    computer.beep(440, 0.25)
    computer.beep(380, 0.25)

    -- if there's no log I/O, just die
    if not k.logio then
      error(msg)
    end
    
    k.log(k.loglevels.panic, "-- \27[91mbegin stacktrace\27[37m --")
    
    local traceback = debug.traceback(msg, 2)
      :gsub("\t", "  ")
      :gsub("([^\n]+):(%d+):", "\27[96m%1\27[37m:\27[95m%2\27[37m:")
      :gsub("'([^']+)'\n", "\27[93m'%1'\27[37m\n")
    
    for line in traceback:gmatch("[^\n]+") do
      k.log(k.loglevels.panic, line)
    end

    k.log(k.loglevels.panic, "-- \27[91mend stacktrace\27[37m --")
    k.log(k.loglevels.panic, "\27[93m!! \27[91mPANIC\27[93m !!\27[37m")
    
    while true do raw_pullsignal() end
  end
end

k.log(math.huge, "Starting\27[93m", _OSVERSION, "\27[37m")
