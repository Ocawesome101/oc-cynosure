-- sysfs: Directory generator

do
  local function mknew()
    return { dir = true }
  end

  k.sysfs.handle("directory", mknew)
end
