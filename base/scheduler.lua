-- scheduler

k.log(k.loglevels.info, "base/scheduler")

do
  local processes = {}
  local current

  local api = {}

  function api.spawn(args)
    checkArg(1, args.name, "string")
    checkArg(2, args.func, "function")
    
    local parent = processes[current or 0] or
      (api.info() and api.info().data.self) or {}
    
    local new = k.create_process {
      name = args.name,
      parent = parent.pid or 0,
      stdin = parent.stdin or (io and io.input()) or args.stdin,
      stdout = parent.stdout or (io and io.output()) or args.stdout,
      stderr = args.stderr or parent.stderr or (io and io.stderr),
      input = args.input or parent.stdin or (io and io.input()),
      output = args.output or parent.stdout or (io and io.output()),
      owner = args.owner or parent.owner or 0,
      env = parent.env
    }
    
    new:add_thread(args.func)
    processes[new.pid] = new
    
    if k.sysfs then
      assert(k.sysfs.register(k.sysfs.types.process, new, "/proc/"..math.floor(
        new.pid)))
    end
    
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
        push_signal = proc.push_signal,
        pull_signal = proc.pull_signal,
        io = proc.io,
        self = proc,
        handles = proc.handles,
        coroutine = proc.coroutine,
        env = proc.env
      }
    end
    
    return info
  end

  function api.kill(proc)
    checkArg(1, proc, "number", "nil")
    
    proc = proc or current.pid
    
    if not processes[proc] then
      return nil, "no such process"
    end
    
    processes[proc].dead = true
    
    return true
  end

  -- XXX: this is specifically for kernel use ***only*** and userspace does NOT
  -- XXX: get this function.  it is incredibly dangerous and should be used with
  -- XXX: the utmost caution.
  function api.get(pid)
    checkArg(1, pid, "number", current and "nil")
    pid = pid or current
    if not processes[pid] then
      return nil, "no such process"
    end
    return processes[pid]
  end

  local pullSignal = computer.pullSignal
  function api.loop()
    while next(processes) do
      local to_run = {}
      local going_to_run = {}
      local min_timeout = math.huge
    
      for k, v in pairs(processes) do
        if not v.stopped then
          if v.deadline - computer.uptime() < min_timeout then
            min_timeout = v.deadline - computer.uptime()
          end
        end
      
        if min_timeout <= 0 then
          min_timeout = 0
          break
        end
      end
      
      --k.log(k.loglevels.info, min_timeout)
      
      local sig = table.pack(pullSignal(min_timeout))
      k.event.handle(sig)

      for k, v in pairs(processes) do
        if (v.deadline <= computer.uptime() or #v.queue > 0 or sig.n > 0) and
            not (v.stopped or going_to_run[v.pid] or v.dead) then
          to_run[#to_run + 1] = v
      
          if v.resume_next then
            to_run[#to_run + 1] = v.resume_next
            going_to_run[v.resume_next.pid] = true
          end
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
        local ok, err = proc:resume(table.unpack(psig))
        
        if proc.dead or ok == "__internal_process_exit" or not ok then
          local exit = err or 0
        
          if type(err) == "string" then
            exit = 127
          else
            exit = err or 0
            err = "exited"
          end
          
          err = err or "died"
          if k.cmdline.log_process_death and
              k.cmdline.log_process_death ~= 0 then
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
          
          local ppt = "/proc/" .. math.floor(proc.pid)
          if k.sysfs then
            k.sysfs.unregister(ppt)
          end
          processes[proc.pid] = nil
        else
          proc.cputime = proc.cputime + computer.uptime() - start_time
          --proc.deadline = computer.uptime() + (tonumber(ok) or tonumber(err)
          --  or math.huge)
        end
      end
    end

    if not k.is_shutting_down then
      -- !! PANIC !!
      k.panic("all user processes died")
    end
  end

  k.scheduler = api
  
  -- sandbox hook for userspace 'process' api
  k.hooks.add("sandbox", function()
    local p = {}
    k.userspace.package.loaded.process = p
    
    function p.spawn(args)
      checkArg(1, args.name, "string")
      checkArg(2, args.func, "function")
    
      local sanitized = {
        func = args.func,
        name = args.name,
        stdin = args.stdin,
        stdout = args.stdout,
        input = args.input,
        output = args.output,
        stderr = args.stderr,
      }
      
      local new = api.spawn(sanitized)
      
      return new.pid
    end
    
    function p.kill(pid)
      checkArg(1, pid, "number", "nil")
      
      local cur = current
      local atmp = processes[pid]
      
      if not atmp then
        return true
      end
      
      if (atmp or {owner=current.owner}).owner ~= cur.owner and
         cur.owner ~= 0 then
        return nil, "permission denied"
      end
      
      return api.kill(pid)
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
        -- k.log(k.loglevels.info, "yield await", pid)
        signal = table.pack(coroutine.yield(0))
      until signal[1] == "process_died" and signal[2] == pid
      
      return signal[3], signal[4]
    end
    
    p.info = api.info
  end)
end
