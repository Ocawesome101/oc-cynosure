-- sysfs: filesystem handler

k.log(k.loglevels.info, "sysfs/handlers/filesystem")

do
  local function mknew(addr)
    local proxy = component.proxy(addr)
    
    local new = {
      dir = true,
      address = util.mkfile(addr),
      slot = util.mkfile(proxy.slot),
      type = util.mkfile(proxy.type),
      label = util.fnmkfile(
        function()
          return proxy.getLabel() or "unlabeled"
        end,
        function(_, s)
          proxy.setLabel(s:match("^(.-)\n"))
        end
      ),
      spaceUsed = util.fnmkfile(
        function()
          return string.format("%d", proxy.spaceUsed())
        end
      ),
      spaceTotal = util.fnmkfile(
        function()
          return string.format("%d", proxy.spaceTotal())
        end
      ),
      isReadOnly = util.fnmkfile(
        function()
          return tostring(proxy.isReadOnly())
        end
      ),
      mounts = util.fnmkfile(
        function()
          local mounts = k.fs.api.mounts()
          local ret = ""
          for k,v in pairs(mounts) do
            if v == addr then
              ret = ret .. k .. "\n"
            end
          end
          return ret
        end
      )
    }

    return new
  end

  k.sysfs.handle("filesystem", mknew)
end
