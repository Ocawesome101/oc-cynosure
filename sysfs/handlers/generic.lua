-- sysfs: Generic component handler

k.log(k.loglevels.info, "sysfs/handlers/generic")

do
  local function mknew(addr)
    return {
      dir = true,
      address = util.mkfile(addr),
      type = util.mkfile(component.type(addr)),
      slot = util.mkfile(tostring(component.slot(addr)))
    }
  end

  k.sysfs.handle("generic", mknew)
end
