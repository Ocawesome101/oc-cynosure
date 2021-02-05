-- scheduler

k.log(k.loglevels.info, "base/scheduler")

do
  local processes = {}
  local current

  local api = {}

  function api.spawn(args)
    checkArg(1, args.name, "string")
    checkArg(2, args.func, "function")
    local new = k.create_process({name = args.name})
    new:add_thread(args.func)
    processes[new.pid] = new
    if k.procfs then k.procfs.add(new) end
    return new
  end

  function api.info(pid)
    checkArg(1, pid, "number", "nil")
    local proc
    if pid then proc = processes[pid]
    else proc = current end
    if not proc then
      return nil, "no such process"
    end
    local info = {
      pid = proc.pid,
      waiting = proc.waiting,
      stopped = proc.stopped,
      deadline = proc.deadline,
      n_threads = #proc.threads,
      status = proc.status
    }
    if proc.pid == current.pid then
      info.data = {
        push_signal = proc.push_signal,
        pull_signal = proc.pull_signal,
        io = proc.io,
        handles = proc.handles,
        coroutine = proc.handlers
      }
    end
    return info
  end

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
        if #proc.queue > 0 then -- the process has queued signals
          proc:push_signal(table.unpack(sig))
        end
        local ok, err = proc:resume(table.unpack(psig))
      end
    end
    if not k.is_shutting_down then
      -- !! PANIC !!
      k.panic("init died")
    end
  end

  k.scheduler = api
end
