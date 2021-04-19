-- sysfs: Process handler

k.log(k.loglevels.info, "sysfs/handlers/process")

do
  local function mknew(proc)
    checkArg(1, proc, "process")
    
    local base = {
      dir = true,
      handles = {
        dir = true,
      },
      cputime = util.fmkfile(proc, "cputime"),
      name = util.mkfile(proc.name),
      threads = util.fmkfile(proc, "threads"),
      owner = util.mkfile(proc.owner),
      deadline = util.fmkfile(proc, "deadline"),
      stopped = util.fmkfile(proc, "stopped"),
      waiting = util.fmkfile(proc, "waiting")
    }

    local mt = {
      __index = function(t, k)
        k = tonumber(k) or k
        if not proc.handles[k] then
          return nil, k.fs.errors.file_not_found
        else
          return {dir = false, open = function(m)
            -- you are not allowed to access other
            -- people's files!
            return nil, "permission denied"
          end}
        end
      end,
      __pairs = function(t)
        local iter = pairs(t)
        return function()
          return (iter())
        end
      end
    }
    mt.__ipairs = mt.__pairs

    setmetatable(base, mt)

    return base
  end

  k.sysfs.handle("process", mknew)
end
