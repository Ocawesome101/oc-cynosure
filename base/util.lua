-- some utilities --

k.log(k.loglevels.info, "base/util")

do
  local util = {}
  function util.merge_tables()
  end

  -- here we override rawset() in order to properly protect tables
  local _rawset = rawset
  local blacklist = setmetatable({}, {__mode = "k"})
  function _G.rawset(t, k, v)
    if not blacklist[t] then
      return _rawset(t, k, v)
    else
      -- this will error
      t[k] = v
    end
  end

  local function protecc()
    error("attempt to modify a write-protected table")
  end

  function util.protect(tbl)
    local new = {}
    local mt = {
      __index = tbl,
      __newindex = protecc,
      __pairs = tbl,
      __metatable = {}
    }
    return setmetatable(new, mt)
  end

  k.util = util
end
