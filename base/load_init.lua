-- load init, i guess

k.log(k.loglevels.info, "base/load_init")

-- we need to mount the root filesystem first
do
end

do
  k.log(k.loglevels.info, "Creating userspace sandbox")
  local sbox = k.util.copy(_G)
  k.userspace = sbox
  sbox._G = sbox
  k.hooks.call("sandbox", sbox)

  k.log(k.loglevels.info, "Loading init from",
                               k.cmdline.init or "/sbin/init.lua")
  local ok, err = loadfile(k.cmdline.init or "/sbin/init.lua")
  if not ok then
    k.panic(err)
  end
end
