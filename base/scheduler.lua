-- scheduler

k.log(k.loglevels.info, "base/scheduler")

do
  local globalenv = {
    UID = 0,
    USER = "root",
    TERM = "cynosure",
    PWD = "/",
    HOSTNAME = "localhost"
  }

  local processes = {}
  local current

  local api = {}

  api.signals = {
    hangup = 1,
    interrupt = 2,
    quit = 3,
    kill = 9,
    pipe = 13,
    stop = 17,
    kbdstop = 18,
    continue = 19
  }

  function api.spawn(args)
    checkArg(1, args.name, "string")
    checkArg(2, args.func, "function")
    
    local parent = processes[current or 0] or
      (api.info() and api.info().data.self) or {}
    
    local new = k.create_process {
      name = args.name,
      parent = parent.pid or 0,
      stdin = args.stdin or parent.stdin or (io and io.input()),
      stdout = args.stdout or parent.stdout or (io and io.output()),
      stderr = args.stderr or parent.stderr or (io and io.stderr),
      input = args.input or parent.stdin or (io and io.input()),
      output = args.output or parent.stdout or (io and io.output()),
      owner = args.owner or parent.owner or 0,
      env = args.env or {}
    }

    for k, v in pairs(parent.env or globalenv) do
      new.env[k] = new.env[k] or v
    end

    new:add_thread(args.func)
    processes[new.pid] = new
    
    assert(k.sysfs.register(k.sysfs.types.process, new, "/proc/"..math.floor(
        new.pid)))
    
    return new
  end

  function api.info(pid)
    checkArg(1, pid, "number", "nil")
    
    pid = pid or current
    
    local proc = processes[pid]
    if not proc then
      return nil, "no such process"
    end

    local info = {
      pid = proc.pid,
      name = proc.name,
      waiting = proc.waiting,
      stopped = proc.stopped,
      deadline = proc.deadline,
      n_threads = #proc.threads,
      status = proc:status(),
      cputime = proc.cputime,
      owner = proc.owner
    }
    
    if proc.pid == current then
      info.data = {
        io = proc.io,
        self = proc,
        handles = proc.handles,
        coroutine = proc.coroutine,
        env = proc.env
      }
    end
    
    return info
  end

  function api.kill(proc, signal)
    checkArg(1, proc, "number", "nil")
    checkArg(2, signal, "number")
    
    proc = proc or current.pid
    
    if not processes[proc] then
      return nil, "no such process"
    end
    
    processes[proc]:signal(signal)
    
    return true
  end

  -- XXX: this is specifically for kernel use ***only*** - userspace does NOT
  -- XXX: get this function.  it is incredibly dangerous and should be used with
  -- XXX: the utmost caution.
  api.processes = processes
  function api.get(pid)
    checkArg(1, pid, "number", current and "nil")
    pid = pid or current
    if not processes[pid] then
      return nil, "no such process"
    end
    return processes[pid]
  end

  local function closeFile(file)
    if file.close and not file.tty then pcall(file.close, file) end
  end

  local function handleDeath(proc, exit, err, ok)
    local exit = err or 0
    err = err or ok

    if type(err) == "string" then
      exit = 127
    else
      exit = err or 0
      err = "exited"
    end

    err = err or "died"
    if (k.cmdline.log_process_death and
        k.cmdline.log_process_death ~= 0) then
      -- if we can, put the process death info on the same stderr stream
      -- belonging to the process that died
      if proc.io.stderr and proc.io.stderr.write then
        local old_logio = k.logio
        k.logio = proc.io.stderr
        k.log(k.loglevels.info, "process died:", proc.pid, exit, err)
        k.logio = old_logio
      else
        k.log(k.loglevels.warn, "process died:", proc.pid, exit, err)
      end
    end

    computer.pushSignal("process_died", proc.pid, exit, err)

    for k, v in pairs(proc.handles) do
      pcall(v.close, v)
    end
    for k,v in pairs(proc.io) do closeFile(v) end

    local ppt = "/proc/" .. math.floor(proc.pid)
    k.sysfs.unregister(ppt)
    
    processes[proc.pid] = nil
  end

  local pullSignal = computer.pullSignal
  function api.loop()
    while next(processes) do
      local to_run = {}
      local going_to_run = {}
      local min_timeout = math.huge
    
      for _, v in pairs(processes) do
        if not v.stopped then
          min_timeout = math.min(min_timeout, v.deadline - computer.uptime())
        end
      
        if min_timeout <= 0 then
          min_timeout = 0
          break
        end
      end
      
      --k.log(k.loglevels.info, min_timeout)
      
      local sig = table.pack(pullSignal(min_timeout))
      k.event.handle(sig)

      for _, v in pairs(processes) do
        if (v.deadline <= computer.uptime() or #v.queue > 0 or sig.n > 0) and
            not (v.stopped or going_to_run[v.pid] or v.dead) then
          to_run[#to_run + 1] = v
      
          if v.resume_next then
            to_run[#to_run + 1] = v.resume_next
            going_to_run[v.resume_next.pid] = true
          end
        elseif v.dead then
          handleDeath(v, v.exit_code or 1, v.status or "killed")
        end
      end

      for i, proc in ipairs(to_run) do
        local psig = sig
        current = proc.pid
      
        if #proc.queue > 0 then
          -- the process has queued signals
          -- but we don't want to drop this signal
          proc:push_signal(table.unpack(sig))
          
          psig = proc:pull_signal() -- pop a signal
        end
        
        local start_time = computer.uptime()
        local aok, ok, err = proc:resume(table.unpack(psig))

        if proc.dead or ok == "__internal_process_exit" or not aok then
          handleDeath(proc, exit, err, ok)
        else
          proc.cputime = proc.cputime + computer.uptime() - start_time
          proc.deadline = computer.uptime() + (tonumber(ok) or tonumber(err)
            or math.huge)
        end
      end
    end

    if not k.is_shutting_down then
      -- !! PANIC !!
      k.panic("all user processes died")
    end
  end

  k.scheduler = api

  k.hooks.add("shutdown", function()
    if not k.is_shutting_down then
      return
    end

    k.log(k.loglevels.info, "shutdown: sending shutdown signal")

    for pid, proc in pairs(processes) do
      proc:resume("shutdown")
    end

    k.log(k.loglevels.info, "shutdown: waiting 1s for processes to exit")
    os.sleep(1)

    k.log(k.loglevels.info, "shutdown: killing all processes")

    for pid, proc in pairs(processes) do
      if pid ~= current then -- hack to make sure shutdown carries on
        proc.dead = true
      end
    end

    coroutine.yield(0) -- clean up
  end)
  
  -- sandbox hook for userspace 'process' api
  k.hooks.add("sandbox", function()
    local p = {}
    k.userspace.package.loaded.process = p
    
    function p.spawn(args)
      checkArg(1, args, "table")
      checkArg("name", args.name, "string")
      checkArg("func", args.func, "function")
      checkArg("env", args.env, "table", "nil")
      checkArg("stdin", args.stdin, "FILE*", "nil")
      checkArg("stdout", args.stdout, "FILE*", "nil")
      checkArg("stderr", args.stderr, "FILE*", "nil")
      checkArg("input", args.input, "FILE*", "nil")
      checkArg("output", args.output, "FILE*", "nil")
    
      local sanitized = {
        func = args.func,
        name = args.name,
        stdin = args.stdin,
        stdout = args.stdout,
        input = args.input,
        output = args.output,
        stderr = args.stderr,
        env = args.env
      }
      
      local new = api.spawn(sanitized)
      
      return new.pid
    end
    
    function p.kill(pid, signal)
      checkArg(1, pid, "number", "nil")
      checkArg(2, signal, "number")
      
      local cur = processes[current]
      local atmp = processes[pid]
      
      if not atmp then
        return true
      end
      
      if (atmp or {owner=processes[current].owner}).owner ~= cur.owner and
         cur.owner ~= 0 then
        return nil, "permission denied"
      end
      
      return api.kill(pid, signal)
    end
    
    function p.list()
      local pr = {}
      
      for k, v in pairs(processes) do
        pr[#pr+1]=k
      end
      
      table.sort(pr)
      return pr
    end

    -- this is not provided at the kernel level
    -- largely because there is no real use for it
    -- returns: exit status, exit message
    function p.await(pid)
      checkArg(1, pid, "number")
      
      local signal = {}
      
      if not processes[pid] then
        return nil, "no such process"
      end
      
      repeat
        -- busywait until the process dies
        signal = table.pack(coroutine.yield())
      until signal[1] == "process_died" and signal[2] == pid
      
      return signal[3], signal[4]
    end
    
    p.info = api.info

    p.signals = k.util.copy_table(api.signals)
  end)
end
