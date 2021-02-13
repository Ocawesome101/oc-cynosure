-- event handling --

do
  local event = {}
  local handlers = {}

  local pull = computer.pullSignal
  computer.pullSignalOld = pull

  function computer.pullSignal(timeout)
    checkArg(1, timeout, "number", "nil")
    local sig = table.pack(pull(timeout))
    if sig.n == 0 then return nil end
    for _, v in pairs(handlers) do
      if v.signal == sig[1] then
        v.callback(table.unpack(sig))
      end
    end
    return table.unpack(sig)
  end

  local n = 0
  function event.register(sig, call)
    checkArg(1, sig, "string")
    checkArg(2, call, "function")
    n = n + 1
    handlers[n] = {signal=sig,callback=call}
    return n
  end

  function event.unregister(id)
    checkArg(1, id, "number")
    handlers[id] = nil
    return true
  end

  k.event = event
end
