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
    local result
    for k, v in ipairs(self.threads) do
      result = result or table.pack(v:resume(...))
  
      if v:status() == "dead" then
        table.remove(self.threads, k)
      
        if not result[1] then
          self:push_signal("thread_died", v.id)
        
          return nil, result[2]
        end
      end
    end

    if not next(self.threads) then
      self.dead = true
    end
    
    return table.unpack(result)
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
    return true
  end

  -- there are no timeouts, the scheduler manages that
  function process:pull_signal()
    if #self.queue > 0 then
      return table.remove(self.queue, 1)
    end
  end

  local pid = 0

  -- default signal handlers
  local defaultHandlers = {
    [0] = function() end,
    [1] = function(self) self.status = "got SIGHUP" self.dead = true end,
    [2] = function(self) self.status = "interrupted" self.dead = true end,
    [3] = function(self) self.status = "got SIGQUIT" self.dead = true end,
    [9] = function(self) self.status = "killed" self.dead = true end,
    [13] = function(self) self.status = "broken pipe" self.dead = true end,
    [18] = function(self) self.stopped = true end,
  }
  
  function k.create_process(args)
    pid = pid + 1
  
    local new
    new = setmetatable({
      name = args.name,
      pid = pid,
      io = {
        stdin = args.stdin or {},
        input = args.input or args.stdin or {},
        stdout = args.stdout or {},
        output = args.output or args.stdout or {},
        stderr = args.stderr or args.stdout or {}
      },
      queue = {},
      threads = {},
      waiting = true,
      stopped = false,
      handles = {},
      coroutine = {},
      cputime = 0,
      deadline = 0,
      env = args.env and k.util.copy_table(args.env) or {},
      signal = setmetatable({}, {
        __call = function(_, self, s)
          -- don't block SIGSTOP or SIGCONT
          if s == 17 or s == 19 then
            self.stopped = s == 17
            return true
          end
          -- and don't block SIGKILL, unless we're init
          if self.pid ~= 1 and s == 9 then
            self.status = "killed" self.dead = true return true end
          if self.signal[s] then
            return self.signal[s](self)
          else
            return (defaultHandlers[s] or defaultHandlers[0])(self)
          end
        end,
        __index = defaultHandlers
      })
    }, proc_mt)
    
    args.stdin, args.stdout, args.stderr,
                  args.input, args.output = nil, nil, nil, nil, nil
    
    for k, v in pairs(args) do
      new[k] = v
    end

    new.handles[0] = new.stdin
    new.handles[1] = new.stdout
    new.handles[2] = new.stderr
    
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
