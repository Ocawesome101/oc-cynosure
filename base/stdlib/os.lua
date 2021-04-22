-- stdlib: os

do
  function os.execute()
    error("os.execute must be implemented by userspace", 0)
  end

  function os.setenv(k, v)
    local info = k.scheduler.info()
    info.env[k] = v
  end

  function os.getenv(k)
    local info = k.scheduler.info()
    
    if not k then
      return info.env
    end

    return info.env[k]
  end

  function os.sleep(n)
    checkArg(1, n, "number")

    local max = computer.uptime() + n
    repeat
      coroutine.yield(max - computer.uptime())
    until computer.uptime() >= max

    return true
  end
end
