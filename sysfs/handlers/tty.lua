-- sysfs: TTY device handling

k.log(k.loglevels.info, "sysfs/handlers/tty")

do
  local function mknew(tty)
    return {
      dir = false,
      read = function(_, n)
        return tty:read(n)
      end,
      write = function(_, d)
        return tty:write(d)
      end
    }
  end

  k.sysfs.handle("tty", mknew)

  k.sysfs.register("tty", k.logio, "/dev/console")
  k.sysfs.register("tty", k.logio, "/dev/tty0")
end
