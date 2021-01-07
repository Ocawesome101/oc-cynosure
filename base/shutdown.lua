-- some shutdown related stuff

k.log(k.loglevels.info, "base/shutdown")

do
  local shutdown = computer.shutdown
  function k.shutdown(rbt)
    k.hooks.call("shutdown", rbt)
    shutdown(rbt)
  end
end
