-- sysfs API --

do
  local tree = {
    components = {dir = true},
    proc = {dir = true},
    dev = {dir = true},
    mounts = {
      dir = false,
      read = function(_, n)
        local mounts = k.fs.api.mounts()
      end,
      write = function()
        return nil, "bad file descriptor"
      end
    }
  }
end
