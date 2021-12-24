-- sysfs: EEPROM component handler

k.log(k.loglevels.info, "sysfs/handlers/eeprom")

do
  local function mknew(addr)
    local proxy = component.proxy(addr)

    return {
      dir = true,
      address = util.mkfile(addr),
      type = util.mkfile(proxy.type),
      slot = util.mkfile(tostring(proxy.slot)),
      data = util.fnmkfile(
        function()
          return proxy.getData() or ""
        end,
        function(_, s)
          proxy.setData(s)
        end
      ),
      code = util.fnmkfile(
        function()
          return proxy.get() or ""
        end,
        function(_, s)
          proxy.set(s)
        end
      )
    }
  end

  k.sysfs.handle("eeprom", mknew)
end
