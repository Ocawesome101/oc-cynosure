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
    link = 3
  }

  -- This VFS should support directory overlays, fs mounting, and directory
  --    mounting, hopefully all seamlessly.
  -- mounts["/"] = { node = ..., children = {["/bin"] = "/usr/bin", ...}}
  local mounts = {}

  local function split(path)
    local segments = {}
    for seg in path:gmatch("[^/]+") do
    end
    return segments
  end

  local function resolve(path)
  end

  local registered = {partition_tables = {}, filesystems = {}}

  local _managed = {}
  function _managed:stat(file)
    if not self.node.exists(file) then
      return nil, fs.errors.file_not_found
    end
    return {
      permissions = self:info().read_only and 365 or 511,
      isDirectory = self.node.isDirectory(file),
      owner       = -1,
      group       = -1,
      lastModified= self.node.lastModified(file),
      size        = self.node.size(file)
    }
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
    if self.node.isDirectory(file) then
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
    return setmetatable({
      node = proxy
    }, fs_mt)
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
    local node, err = resolve(file)
  end

  k.fs = fs
end
