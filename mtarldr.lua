-- self-extracting mtar loader thingy: header --
-- this is designed for minimal overhead, not speed. --

local fs = component.proxy(computer.getBootAddress())

-- filesystem tree
local tree = {}

local handle = fs.open("/release.mtar", "r")

local startoffset = 0
repeat
  local c = handle:read(1)
  startoffset = startoffset + 1
until c == "\90" -- uppercase z: magic

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
  for i=1, #segments - 1, 1 do
    cur[segments[i]] = {__is_a_directory = true}
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
  local init = fs.read(handle, 2)
  local version = 0
  if init == "\255\255" then
    fs.read(handle, 1)
    version = 1
  elseif init == "\0\0" or not init then
    return nil
  end
  local namelen
  if version == 1 then
    namelen = fs.read(handle, 2)
  else
    namelen = init
  end
  namelen = string.unpack(">I2", namelen)
  local name = read(namelen)
  local flen
  if version == 0 then
    flen = string.unpack(">I2", fs.read(handle, 2))
  else
    flen = string.unpack(">I8", fs.read(handle, 8))
  end
  local offset = fs.seek(file, "cur")
  read(flen)
  add_to_tree(name, offset, flen)
end

-- concatenate mtar data past this line
--Z
