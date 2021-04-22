-- system log API hook for userspace

k.log(k.loglevels.info, "base/syslog")

do
  local mt = {
    __name = "syslog"
  }

  local syslog = {}
  local open = {}

  function syslog.open(pname)
    checkArg(1, pname, "string", "nil")

    pname = pname or k.scheduler.info().name

    local n = math.random(1, 999999999)
    open[n] = pname
    
    return n
  end

  function syslog.write(n, ...)
    checkArg(1, n, "number")
    
    if not open[n] then
      return nil, "bad file descriptor"
    end
    
    k.log(k.loglevels.info, open[n] .. ":", ...)

    return true
  end

  function syslog.close(n)
    checkArg(1, n, "number")
    
    if not open[n] then
      return nil, "bad file descriptor"
    end
    
    open[n] = nil

    return true
  end

  k.hooks.add("sandbox", function()
    k.userspace.package.loaded.syslog = k.util.copy_table(syslog)
  end)
end
