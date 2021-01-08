-- processes

k.log(k.loglevels.info, "base/process")

do
  local process = {}
  
  local pid = 0
  function k.create_process(args)
    pid = pid + 1
    return setmetatable({
      name = args.name,
      pid = pid,
      threads = {}
    }, {
      __index = process,
      __name = "process",
    })
  end
end
