-- processes
-- mostly glorified coroutine sets

k.log(k.loglevels.info, "base/process")

do
  local process = {}
  local proc_mt = {
    __index = process,
    __name = "process"
  }

  function process:resume(...)
    for k, v in pairs(self.threads) do
      local result = table.pack(v:resume(...))
      if v:status() == "dead" then
        self.threads[k] = nil
        if not result[1] then
          self:push_signal("thread_died", v.id)
        end
      end
    end
    if not next(self.threads) then
      self.dead = true
    end
    return true
  end

  local id = 0
  function process:add_thread(func)
    checkArg(1, func, "function")
    local new = coroutine.create(func)
    id = id + 1
    new.id = id
    self.threads[#self.threads + 1] = new
    return id
  end

  function process:status()
    return self.coroutine:status()
  end

  local c_pushSignal = computer.pushSignal
  function process:push_signal(...)
    local signal = table.pack(...)
    table.insert(self.queue, signal)
    -- this is how we tell computer.pullSignal that we've pushed a signal
    -- not the best way of doing it but It Works(TM)
    c_pushSignal("signal_pushed", self.pid)
    return true
  end

  -- we wrap computer.pullSignal later to use this
  -- there are no timeouts, computer.pullSignal still manages that
  function process:pull_signal()
    if #self.queue > 0 then
      return table.remove(self.queue, 1)
    end
  end

  local pid = 0
  function k.create_process(args)
    pid = pid + 1
    local new = setmetatable({
      name = args.name,
      pid = pid,
      io = {
        stdin = args.stdin or {},
        stdout = args.stdout or {},
        stderr = args.stderr or {}
      },
      threads = {},
      waiting = true,
      stopped = false,
      handles = {},
      deadline = 0,
      coroutine = {} -- overrides for some coroutine methods
                     -- potentially used in pipes
    }, proc_mt)
    for k, v in pairs(args) do
      new[k] = v
    end
    new.coroutine.status = function(self)
      if self.dead then
        return "dead"
      elseif self.stopped then
        return "stopped"
      elseif self.waiting then
        return "waiting"
      else
        return "running"
      end
    end
    return new
  end
end
