-- sysfs: TTY device handling

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
end
