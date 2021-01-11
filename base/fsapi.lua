-- fsapi: VFS and misc filesystem infrastructure

k.log(k.loglevels.info, "base/fsapi")

do
  local fs = {}

  -- This VFS should support directory overlays, fs mounting, and directory
  --    mounting, hopefully all seamlessly.
  -- mounts["/"] = { node = ..., children = {["/bin"] = "/usr/bin", ...}}
  local mounts = {}

  local function split(path)
    local segments = {}
    for seg in path:gmatch("[^/]+") do
    end
  end

  local function resolve()
  end

  local registered = {partition_tables = {}, filesystems = {}}

  local _managed = {}
  function _managed:stat()
  end
  function _managed:touch()
  end
  function _managed:remove()
  end
  function _managed:open()
  end
  local function create_node_from_managed(proxy)
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

  k.fs = fs
end
