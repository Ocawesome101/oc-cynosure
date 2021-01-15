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

  -- create memory-friendly copies of tables
  -- uses metatable weirdness
  -- this is a bit like util.protect
  function util.copy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local shadow = {}
    local copy_mt = {
      __index = function(_, k)
        local item = shadow[k] or tbl[k]
        return util.copy(item)
      end,
      __pairs = function()
        local iter = {}
        for k, v in pairs(tbl) do
          iter[k] = util.copy(v)
        end
        for k, v in pairs(shadow) do
          iter[k] = v
        end
        return pairs(iter)
      end
      -- no __metatable: leaving this metatable exposed isn't a huge
      -- deal, since there's no way to access `tbl` for writing using any
      -- of the functions in it.
    }
    copy_mt.__ipairs = copy_mt.__pairs
    return setmetatable(shadow, copy_mt)
  end

  k.util = util
end
