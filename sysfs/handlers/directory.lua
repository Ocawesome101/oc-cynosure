-- sysfs: Directory generator

k.log(k.loglevels.info, "sysfs/handlers/directory")

do
  local function mknew()
    return { dir = true }
  end

  k.sysfs.handle("directory", mknew)
end
