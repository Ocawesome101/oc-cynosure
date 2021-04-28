-- some shutdown related stuff

k.log(k.loglevels.info, "base/shutdown")

do
  local shutdown = computer.shutdown
  
  function k.shutdown(rbt)
    k.is_shutting_down = true
    k.hooks.call("shutdown", rbt)
    k.log(k.loglevels.info, "shutdown: shutting down")
    shutdown(rbt)
  end

  computer.shutdown = k.shutdown
end
