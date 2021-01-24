-- implementation of the FILE* API --

k.log(k.loglevels.info, "base/stdlib/FILE*")

do
  local buffer = {}
  local fmt = {
    __index = buffer,
    __name = "FILE*"
  }
  function k.create_fstream(base)
    local new = {
      stream = base
    }
    return setmetatable(new, fmt)
  end
end
