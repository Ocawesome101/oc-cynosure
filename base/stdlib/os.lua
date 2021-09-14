-- stdlib: os

do
  function os.execute()
    error("os.execute must be implemented by userspace", 0)
  end

  function os.setenv(K, v)
    local info = k.scheduler.info()
    if not info then return end
    info.data.env[K] = v
  end

  function os.getenv(K)
    local info = k.scheduler.info()

    if not info then return end
    
    if not K then
      return info.data.env
    end

    return info.data.env[K]
  end

  function os.sleep(n)
    checkArg(1, n, "number")

    local max = computer.uptime() + n
    repeat
      coroutine.yield(max - computer.uptime())
    until computer.uptime() >= max

    return true
  end

  function os.exit(n)
    checkArg(1, n, "number", "nil")
    n = n or 0
    coroutine.yield("__internal_process_exit", n)
  end
end
