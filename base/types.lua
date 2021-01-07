-- custom types

k.log(k.loglevels.info, "base/types")

do
  local old_type = type
  function _G.type(obj)
    if type(obj) == "table" then
      local mt = getmetatable(obj) or {}
      return mt.__name or mt.__type or old_type(obj)
    else
      return old_type(obj)
    end
  end

  -- copied from machine.lua
  function _G.checkArg(n, have, ...)
    have = type(have)
    local function check(want, ...)
      if not want then
        return false
      else
        return have == want or check(...)
      end
    end
    if not check(...) then
      local msg = string.format("bad argument #%d (%s expected, got %s)",
                                n, table.concat(table.pack(...), " or "), have)
      error(msg, 2)
    end
  end
end
