-- fsapi: VFS and misc filesystem infrastructure

k.log(k.loglevels.info, "base/fsapi")

do
  local fs = {}

  -- common error codes
  fs.errors = {
    file_not_found = "no such file or directory",
    is_a_directory = "is a directory",
    not_a_directory = "not a directory",
    read_only = "target is read-only",
    failed_read = "failed opening file for reading",
    failed_write = "failed opening file for writing",
    file_exists = "file already exists"
  }

  -- standard file types
  fs.types = {
    file = 1,
    directory = 2,
    link = 3,
    special = 4
  }

  -- This VFS should support directory overlays, fs mounting, and directory
  --    mounting, hopefully all seamlessly.
  -- mounts["/"] = { node = ..., children = {["bin"] = "usr/bin", ...}}
  local mounts = {}
  fs.mounts = mounts

  local function split(path)
    local segments = {}
    
    for seg in path:gmatch("[^/]+") do
      if seg == ".." then
        segments[#segments] = nil
      elseif seg ~= "." then
        segments[#segments + 1] = seg
      end
    end
    
    return segments
  end

  fs.split = split

  -- "clean" a path
  local function clean(path)
    return table.concat(split(path), "/")
  end

  fs.clean = clean

  local faux = {children = mounts}
  local resolving = {}

  local function resolve(path, must_exist)
    if resolving[path] then
      return nil, "recursive mount detected"
    end
    
    path = clean(path)
    resolving[path] = true

    local current, parent = mounts["/"] or faux

    if not mounts["/"] then
      resolving[path] = nil
      return nil, "root filesystem is not mounted!"
    end

    if path == "" or path == "/" then
      resolving[path] = nil
      return mounts["/"], nil, ""
    end
    
    if current.children[path] then
      resolving[path] = nil
      return current.children[path], nil, ""
    end
    
    local segments = split(path)
    
    local base_n = 1 -- we may have to traverse multiple mounts
    
    for i=1, #segments, 1 do
      local try = table.concat(segments, "/", base_n, i)
    
      if current.children[try] then
        base_n = i + 1 -- we are now at this stage of the path
        local next_node = current.children[try]
      
        if type(next_node) == "string" then
          local err
          next_node, err = resolve(next_node)
        
          if not next_node then
            resolving[path] = false
            return nil, err
          end
        end
        
        parent = current
        current = next_node
      elseif not current.node:stat(try) then
        resolving[path] = false

        return nil, fs.errors.file_not_found
      end
    end
    
    resolving[path] = false
    local ret = "/"..table.concat(segments, "/", base_n, #segments)
    
    if must_exist and not current.node:stat(ret) then
      return nil, fs.errors.file_not_found
    end
    
    return current, parent, ret
  end

  local registered = {partition_tables = {}, filesystems = {}}

  local _managed = {}
  function _managed:info()
    return {
      read_only = self.node.isReadOnly(),
      address = self.node.address
    }
  end

  function _managed:stat(file)
    checkArg(1, file, "string")

    if not self.node.exists(file) then
      return nil, fs.errors.file_not_found
    end
    
    local info = {
      permissions = self:info().read_only and 365 or 511,
      type        = self.node.isDirectory(file) and fs.types.directory or fs.types.file,
      isDirectory = self.node.isDirectory(file),
      owner       = -1,
      group       = -1,
      lastModified= self.node.lastModified(file),
      size        = self.node.size(file)
    }

    if file:sub(1, -4) == ".lua" then
      info.permissions = info.permissions | k.security.acl.permissions.file.OWNER_EXEC
      info.permissions = info.permissions | k.security.acl.permissions.file.GROUP_EXEC
      info.permissions = info.permissions | k.security.acl.permissions.file.OTHER_EXEC
    end

    return info
  end

  function _managed:touch(file, ftype)
    checkArg(1, file, "string")
    checkArg(2, ftype, "number", "nil")
    
    if self.node.isReadOnly() then
      return nil, fs.errors.read_only
    end
    
    if self.node.exists(file) then
      return nil, fs.errors.file_exists
    end
    
    if ftype == fs.types.file or not ftype then
      local fd = self.node.open(file, "w")
    
      if not fd then
        return nil, fs.errors.failed_write
      end
      
      self.node.write(fd, "")
      self.node.close(fd)
    elseif ftype == fs.types.directory then
      local ok, err = self.node.makeDirectory(file)
      
      if not ok then
        return nil, err or "unknown error"
      end
    elseif ftype == fs.types.link then
      return nil, "unsupported operation"
    end
    
    return true
  end
  
  function _managed:remove(file)
    checkArg(1, file, "string")
    
    if not self.node.exists(file) then
      return nil, fs.errors.file_not_found
    end
    
    if self.node.isDirectory(file) and #(self.node.list(file) or {}) > 0 then
      return nil, fs.errors.is_a_directory
    end
    
    return self.node.remove(file)
  end

  function _managed:list(path)
    checkArg(1, path, "string")
    
    if not self.node.exists(path) then
      return nil, fs.errors.file_not_found
    elseif not self.node.isDirectory(path) then
      return nil, fs.errors.not_a_directory
    end
    
    local files = self.node.list(path) or {}
    
    return files
  end
  
  local function fread(s, n)
    return s.node.read(s.fd, n)
  end

  local function fwrite(s, d)
    return s.node.write(s.fd, d)
  end

  local function fseek(s, w, o)
    return s.node.seek(s.fd, w, o)
  end

  local function fclose(s)
    return s.node.close(s.fd)
  end

  function _managed:open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
    
    if (mode == "r" or mode == "a") and not self.node.exists(file) then
      return nil, fs.errors.file_not_found
    end
    
    local fd = {
      fd = self.node.open(file, mode or "r"),
      node = self.node,
      read = fread,
      write = fwrite,
      seek = fseek,
      close = fclose
    }
    
    return fd
  end
  
  local fs_mt = {__index = _managed}
  local function create_node_from_managed(proxy)
    return setmetatable({node = proxy}, fs_mt)
  end

  local function create_node_from_unmanaged(proxy)
    local fs_superblock = proxy.readSector(1)
    
    for k, v in pairs(registered.filesystems) do
      if v.is_valid_superblock(superblock) then
        return v.new(proxy)
      end
    end
    
    return nil, "no compatible filesystem driver available"
  end

  fs.PARTITION_TABLE = "partition_tables"
  fs.FILESYSTEM = "filesystems"
  
  function fs.register(category, driver)
    if not registered[category] then
      return nil, "no such category: " .. category
    end
  
    table.insert(registered[category], driver)
    return true
  end

  function fs.get_partition_table_driver(filesystem)
    checkArg(1, filesystem, "string", "table")
    
    if type(filesystem) == "string" then
      filesystem = component.proxy(filesystem)
    end
    
    if filesystem.type == "filesystem" then
      return nil, "managed filesystem has no partition table"
    else -- unmanaged drive - perfect
      for k, v in pairs(registered.partition_tables) do
        if v.has_valid_superblock(proxy) then
          return v.create(proxy)
        end
      end
    end
    
    return nil, "no compatible partition table driver available"
  end

  function fs.get_filesystem_driver(filesystem)
    checkArg(1, filesystem, "string", "table")
    
    if type(filesystem) == "string" then
      filesystem = component.proxy(filesystem)
    end
    
    if filesystem.type == "filesystem" then
      return create_node_from_managed(filesystem)
    else
      return create_node_from_unmanaged(filesystem)
    end
  end

  -- actual filesystem API now
  fs.api = {}
  
  function fs.api.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string", "nil")
  
    mode = mode or "r"

    if mode:match("[wa]") then
      fs.api.touch(file)
    end

    local node, err, path = resolve(file)
    if not node then
      return nil, err
    end
    
    local data = node.node:stat(path)
    local user = (k.scheduler.info() or {owner=0}).owner
    -- TODO: groups
    
    do
      local perms = k.security.acl.permissions.file
      local rperm, wperm
    
      if data.owner ~= user then
        rperm = perms.OTHER_READ
        wperm = perms.OTHER_WRITE
      else
        rperm = perms.OWNER_READ
        wperm = perms.OWNER_WRITE
      end
      
      if ((mode == "r" and not
          k.security.acl.has_permission(data.permissions, rperm)) or
          ((mode == "w" or mode == "a") and not
          k.security.acl.has_permission(data.permissions, wperm))) and not
          k.security.acl.user_has_permission(user,
          k.security.acl.permissions.OPEN_UNOWNED) then
        return nil, "permission denied"
      end
    end
    
    return node.node:open(path, mode)
  end

  function fs.api.stat(file)
    checkArg(1, file, "string")
    
    local node, err, path = resolve(file)
    
    if not node then
      return nil, err
    end

    return node.node:stat(path)
  end

  function fs.api.touch(file, ftype)
    checkArg(1, file, "string")
    checkArg(2, ftype, "number", "nil")
    
    ftype = ftype or fs.types.file
    
    local root, base = file:match("^(/?.+)/([^/]+)/?$")
    root = root or "/"
    base = base or file
    
    local node, err, path = resolve(root)
    
    if not node then
      return nil, err
    end
    
    return node.node:touch(path .. "/" .. base, ftype)
  end

  local n = {}
  function fs.api.list(path)
    checkArg(1, path, "string")
    
    local node, err, fpath = resolve(path, true)

    if not node then
      return nil, err
    end

    local ok, err = node.node:list(fpath)
    if not ok and err then
      return nil, err
    end

    ok = ok or {}
    local used = {}
    for _, v in pairs(ok) do used[v] = true end

    if node.children then
      for k in pairs(node.children) do
        if not k:match(".+/.+") then
          local info = fs.api.stat(path.."/"..k)
          if (info or n).isDirectory then
            k = k .. "/"
          end
          if info and not used[k] then
            ok[#ok + 1] = k
          end
        end
      end
    end
   
    return ok
  end

  function fs.api.remove(file)
    checkArg(1, file, "string")
    
    local node, err, path = resolve(file)
    
    if not node then
      return nil, err
    end
    
    return node.node:remove(path)
  end

  local mounted = {}

  fs.api.types = {
    RAW = 0,
    NODE = 1,
    OVERLAY = 2,
  }
  
  function fs.api.mount(node, fstype, path)
    checkArg(1, node, "string", "table")
    checkArg(2, fstype, "number")
    checkArg(2, path, "string")
    
    local device, err = node
    
    if fstype ~= fs.api.types.RAW then
      -- TODO: properly check object methods first
      goto skip
    end
    
    device, err = fs.get_filesystem_driver(node)
    if not device then
      local sdev, serr = k.sysfs.retrieve(node)
      if not sdev then return nil, serr end
      device, err = fs.get_filesystem_driver(sdev)
    end
    
    ::skip::

    if type(device) == "string" and fstype ~= fs.types.OVERLAY then
      device = component.proxy(device)
      if (not device) then
        return nil, "no such component"
      elseif device.type ~= "filesystem" and device.type ~= "drive" then
        return nil, "component is not a drive or filesystem"
      end

      if device.type == "filesystem" then
        device = create_node_from_managed(device)
      else
        device = create_node_from_unmanaged(device)
      end
    end

    if not device then
      return nil, err
    end

    if device.type == "filesystem" then
    end
    
    path = clean(path)
    if path == "" then path = "/" end
    
    local root, fname = path:match("^(/?.+)/([^/]+)/?$")
    root = root or "/"
    fname = fname or path
    
    local pnode, err, rpath
    
    if path == "/" then
      mounts["/"] = {node = device, children = {}}
      mounted["/"] = (device.node and device.node.getLabel
        and device.node.getLabel()) or device.node
        and device.node.address or "unknown"
      return true
    else
      pnode, err, rpath = resolve(root)
    end

    if not pnode then
      return nil, err
    end
    
    local full = clean(string.format("%s/%s", rpath, fname))
    if full == "" then full = "/" end

    if type(device) == "string" then
      pnode.children[full] = device
    else
      pnode.children[full] = {node=device, children={}}
      mounted[path]=(device.node and device.node.getLabel
        and device.node.getLabel()) or device.node
        and device.node.address or "unknown"
    end
    
    return true
  end

  function fs.api.umount(path)
    checkArg(1, path, "string")
    
    path = clean(path)
    
    local root, fname = path:match("^(/?.+)/([^/]+)/?$")
    root = root or "/"
    fname = fname or path
    
    local node, err, rpath = resolve(root)
    
    if not node then
      return nil, err
    end
    
    local full = clean(string.format("%s/%s", rpath, fname))
    node.children[full] = nil
    mounted[path] = nil
    
    return true
  end

  function fs.api.mounts()
    local new = {}
    -- prevent programs from meddling with these
    for k,v in pairs(mounted) do new[("/"..k):gsub("[\\/]+", "/")] = v end
    return new
  end

  k.fs = fs
end
