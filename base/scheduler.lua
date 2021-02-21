-- scheduler

k.log(k.loglevels.info, "base/scheduler")

do
  local processes = {}
  local current

  local api = {}

  function api.spawn(args)
    checkArg(1, args.name, "string")
    checkArg(2, args.func, "function")
    local parent = current or {}
    local new = k.create_process {
      name = args.name,
      parent = parent.pid or 0,
      stdin = parent.stdin or args.stdin,
      stdout = parent.stdout or args.stdout,
      input = args.input,
      output = args.output,
      owner = parent.owner or 0,
    }
    new:add_thread(args.func)
    processes[new.pid] = new
    if k.sysfs then k.sysfs.add_to("proc", new) end
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
        handles = proc.handles,
        coroutine = proc.coroutine
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
  end

  local pullSignal = computer.pullSignal
  function api.loop()
    while processes[1] do
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
      for k, v in pairs(processes) do
        if (v.deadline <= computer.uptime() or #v.queue > 0 or sig.n > 0) and
            not (v.stopped or going_to_run[v.pid]) then
          to_run[#to_run + 1] = v
          if v.resume_next then
            to_run[#to_run + 1] = v.resume_next
            going_to_run[v.resume_next.pid] = true
          end
        end
      end
      for i, proc in ipairs(to_run) do
        local psig = sig
        current = i
        if #proc.queue > 0 then -- the process has queued signals
          proc:push_signal(table.unpack(sig))
          psig = proc:pull_signal()
        end
        local start_time = computer.uptime()
        local ok, err = proc:resume(table.unpack(psig))
        --k.log(k.loglevels.info, ok, err)
        if proc.dead or ok == "__internal_process_exit" or not ok then
          local exit = err or 0
          if type(err) == "string" then
            exit = 127
          else
            exit = err or 0
            err = "exited"
          end
          err = err or "died"
          k.log(k.loglevels.warn, "process died: ", proc.pid, exit, err)
          computer.pushSignal("process_died", proc.pid, exit, err)
          for k, v in pairs(proc.handles) do
            pcall(v.close, v)
          end
          processes[proc.pid] = nil
        else
          proc.cputime = proc.cputime + computer.uptime() - start_time
          proc.deadline = computer.uptime() + (tonumber(ok) or math.huge)
        end
      end
    end
    if not k.is_shutting_down then
      -- !! PANIC !!
      k.panic("init died")
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
        output = args.output
      }
      local new = api.spawn(sanitized)
      return new.pid
    end
    
    function p.kill(pid)
      checkArg(1, pid, "number", "nil")
      local cur = current
      local atmp = processes[pid]
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
    
    p.info = api.info
  end)
end
