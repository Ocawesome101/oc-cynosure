-- fsapi: VFS and misc filesystem infrastructure

k.log(k.loglevels.info, "base/fsapi")

do
  local fs = {}

  -- This VFS should support directory overlays, fs mounting, and directory
  --    mounting, hopefully all seamlessly.
  -- mounts["/"] = { proxy = ..., children = {["/bin"] = "/usr/bin", ...}}
  local mounts = {}

  local function split()
  end

  k.fs = fs
end
