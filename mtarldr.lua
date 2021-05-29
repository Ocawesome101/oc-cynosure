-- self-extracting mtar loader thingy: header --
-- this is designed for minimal overhead, not speed.
-- Expects an MTAR V1 archive.  Will not work with V0.

local fs = component.proxy(computer.getBootAddress())
local gpu = component.proxy(component.list("gpu")())
gpu.bind(gpu.getScreen() or (component.list("screen")()))

-- filesystem tree
local tree = {__is_a_directory = true}

local handle = assert(fs.open("/init.lua", "r"))

local seq = {"|","/","-","\\"}
local si = 1

gpu.set(1, 1, "seeking to data section...")
local startoffset = 5106
-- seek in a hardcoded amount for speed reasons
fs.read(handle, 2048)
fs.read(handle, 2048)
fs.read(handle, 1010)
local last_time = computer.uptime()
repeat
  local c = fs.read(handle, 1)
  startoffset = startoffset + 1
  local t = computer.uptime()
  if t - last_time >= 0.1 then
    gpu.set(30, 1, tostring(startoffset))
    gpu.set(28, 1, seq[si])
    si = si + 1
    if not seq[si] then si = 1 end
    last_time = t
  end
until c == "\90" -- uppercase z: magic
assert(fs.read(handle, 1) == "\n") -- skip \n
gpu.fill(1,1,50,1," ")

local function split_path(path)
  local s = {}
  for _s in path:gmatch("[^\\/]+") do
    if _s == ".." then
      s[#s] = nil
    elseif s ~= "." then
      s[#s+1]=_s
    end
  end
  return s
end

local function add_to_tree(name, offset, len)
  local cur = tree
  local segments = split_path(name)
  if #segments == 0 then return end
  for i=1, #segments - 1, 1 do
    cur[segments[i]] = cur[segments[i]] or {__is_a_directory = true}
    cur = cur[segments[i]]
  end
  cur[segments[#segments]] = {offset = offset, length = len}
end

local function read(n, offset, rdata)
  if offset then fs.seek(handle, "set", offset) end
  local to_read = n
  local data = ""
  while to_read > 0 do
    local n = math.min(2048, to_read)
    to_read = to_read - n
    local chunk = fs.read(handle, n)
    if rdata then data = data .. (chunk or "") end
  end
  return data
end

local function read_header()
  -- skip V1 header
  fs.read(handle, 3)
  local namelen = fs.read(handle, 2)
  if not namelen then
    return nil
  end
  namelen = string.unpack(">I2", namelen)
  local name = read(namelen, nil, true)
  local flendat = fs.read(handle, 8)
  if not flendat then return end
  local flen = string.unpack(">I8", flendat)
  local offset = fs.seek(handle, "cur", 0)
  gpu.fill(1, 2, 50, 1, " ")
  gpu.set(1, 2, "filename = " .. name)
  read(flen)
  add_to_tree(name, offset, flen)
  return true
end

gpu.set(1, 1, "reading file headers... ")
local i = 0
repeat
  gpu.set(24, 1, tostring(i))
  i = i + 1
until not read_header()

-- create the mtar fs node --

local function find(f)
  if f == "/" or f == "" then
    return tree
  end

  local s = split_path(f)
  local c = tree
  
  for i=1, #s, 1 do
    if s[i] == "__is_a_directory" then
      return nil, "file not found"
    end
  
    if not c[s[i]] then
      return nil, "file not found"
    end

    c = c[s[i]]
  end

  return c
end

local obj = {}

function obj:stat(f)
  checkArg(1, f, "string")
  
  local n, e = find(f)
  
  if n then
    return {
      permissions = 365,
      owner = 0,
      group = 0,
      lastModified = 0,
      size = 0,
      isDirectory = not not n.__is_a_directory,
      type = n.__is_a_directory and 2 or 1
    }
  else
    return nil, e
  end
end

function obj:touch()
  return nil, "device is read-only"
end

function obj:remove()
  return nil, "device is read-only"
end

function obj:list(d)
  local n, e = find(d)
  
  if not n then return nil, e end
  if not n.__is_a_directory then return nil, "not a directory" end
  
  local f = {}
  
  for k, v in pairs(n) do
    if k ~= "__is_a_directory" then
      f[#f+1] = tostring(k)
    end
  end
  
  return f
end

local function ferr()
  return nil, "bad file descriptor"
end

local _handle = {}

function _handle:read(n)
  checkArg(1, n, "number")
  if self.fptr >= self.node.length then return nil end
  n = math.min(self.fptr + n, self.node.length)
  local data = read(n - self.fptr, self.fptr + self.node.offset, true)
  self.fptr = n-- + 1
  return data
end

_handle.write = ferr

function _handle:seek(origin, offset)
  checkArg(1, origin, "string")
  checkArg(2, offset, "number", "nil")
  local n = (origin == "cur" and self.fptr) or (origin == "set" and 0) or
    (origin == "end" and self.node.length) or
    (error("bad offset to 'seek' (expected one of: cur, set, end, got "
      .. origin .. ")"))
  n = n + (offset or 0)
  if n < 0 or n > self.node.length then
    return nil, "cannot seek there"
  end
  self.fptr = n
  return n
end

function _handle:close()
  if self.closed then
    return ferr()
  end
  
  self.closed = true
end

function obj:open(f, m)
  checkArg(1, f, "string")
  checkArg(2, m, "string")

  if m:match("[w%+]") then
    return nil, "device is read-only"
  end
  
  local n, e = find(f)
  
  if not n then return nil, e end
  if n.__is_a_directory then return nil, "is a directory" end

  local new = setmetatable({
    node = n, --data = read(n.length, n.offset, true),
    mode = m,
    fptr = 0
  }, {__index = _handle})

  return new
end

obj.node = {getLabel = function() return "mtarfs" end}

_G.__mtar_fs_tree = obj

local hdl = assert(obj:open("/init.lua", "r"))
local ldme = hdl:read(hdl.node.length)
hdl:close()

assert(load(ldme, "=mtarfs:/init.lua", "t", _G))()

-- concatenate mtar data past this line
--[=======[Z
