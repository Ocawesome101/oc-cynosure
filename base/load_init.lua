-- load init, i guess

k.log(k.loglevels.info, "base/load_init")

-- we need to mount the root filesystem first
do
  if _G.__mtar_fs_tree then
    k.log(k.loglevels.info, "using MTAR filesystem tree as rootfs")
    k.fs.api.mount(__mtar_fs_tree, k.fs.api.types.NODE, "/")
  else
    local root, reftype = nil, "UUID"
    
    if k.cmdline.root then
      local rtype, ref = k.cmdline.root:match("^(.-)=(.+)$")
      reftype = rtype:upper() or "UUID"
      root = ref or k.cmdline.root
    elseif not computer.getBootAddress then
      -- still error, but slightly less hard
      k.panic("Cannot determine root filesystem!")
    else
      k.log(k.loglevels.warn,
        "\27[101;97mWARNING\27[39;49m use of computer.getBootAddress to detect the root filesystem is discouraged.")
      k.log(k.loglevels.warn,
        "\27[101;97mWARNING\27[39;49m specify root=UUID=<address> on the kernel command line to suppress this message.")
      root = computer.getBootAddress()
      reftype = "UUID"
    end
  
    local ok, err
    
    if reftype ~= "LABEL" then
      if reftype ~= "UUID" then
        k.log(k.loglevels.warn, "invalid rootspec type (expected LABEL or UUID, got ", reftype, ") - assuming UUID")
      end
    
      if not component.list("filesystem")[root] then
        for k, v in component.list("drive", true) do
          local ptable = k.fs.get_partition_table_driver(k)
      
          if ptable then
            for i=1, #ptable:list(), 1 do
              local part = ptable:partition(i)
          
              if part and (part.address == root) then
                root = part
                break
              end
            end
          end
        end
      end
  
      ok, err = k.fs.api.mount(root, k.fs.api.types.RAW, "/")
    elseif reftype == "LABEL" then
      local comp
      
      for k, v in component.list() do
        if v == "filesystem" then
          if component.invoke(k, "getLabel") == root then
            comp = root
            break
          end
        elseif v == "drive" then
          local ptable = k.fs.get_partition_table_driver(k)
      
          if ptable then
            for i=1, #ptable:list(), 1 do
              local part = ptable:partition(i)
          
              if part then
                if part.getLabel() == root then
                  comp = part
                  break
                end
              end
            end
          end
        end
      end
  
      if not comp then
        k.panic("Could not determine root filesystem from root=", k.cmdline.root)
      end
      
      ok, err = k.fs.api.mount(comp, k.fs.api.types.RAW, "/")
    end
  
    if not ok then
      k.panic(err)
    end
  end

  k.log(k.loglevels.info, "Mounted root filesystem")
  
  k.hooks.call("rootfs_mounted")

  -- mount the tmpfs
  k.fs.api.mount(component.proxy(computer.tmpAddress()), k.fs.api.types.RAW, "/tmp")
end

-- register components with the sysfs, if possible
do
  for k, v in component.list("carddock") do
    component.invoke(k, "bindComponent")
  end

  k.log(k.loglevels.info, "Registering components")
  for kk, v in component.list() do
    computer.pushSignal("component_added", kk, v)
   
    repeat
      local x = table.pack(computer.pullSignal())
      k.event.handle(x)
    until x[1] == "component_added"
  end
end

do
  k.log(k.loglevels.info, "Creating userspace sandbox")
  
  local sbox = k.util.copy_table(_G)
  
  k.userspace = sbox
  sbox._G = sbox
  
  k.hooks.call("sandbox", sbox)

  k.log(k.loglevels.info, "Loading init from",
                               k.cmdline.init or "/sbin/init.lua")
  
  local ok, err = loadfile(k.cmdline.init or "/sbin/init.lua")
  
  if not ok then
    k.panic(err)
  end
  
  local ios = k.create_fstream(k.logio, "rw")
  ios.buffer_mode = "none"
  ios.tty = 0
  
  k.scheduler.spawn {
    name = "init",
    func = ok,
    input = ios,
    output = ios,
    stdin = ios,
    stdout = ios,
    stderr = ios
  }

  k.log(k.loglevels.info, "Starting scheduler loop")
  k.scheduler.loop()
end
