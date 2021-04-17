-- custom types

k.log(k.loglevels.info, "base/types")

do
  local old_type = type
  function _G.type(obj)
    if old_type(obj) == "table" then
      local s, mt = pcall(getmetatable, obj)
      
      if not s and mt then
        -- getting the metatable failed, so it's protected.
        -- instead, we should tostring() it - if the __name
        -- field is set, we can let the Lua VM get the
        -- """type""" for us.
        local t = tostring(obj):gsub(" [%x+]$", "")
        return t
      end
       
      -- either there is a metatable or ....not. If
      -- we have gotten this far, the metatable was
      -- at least not protected, so we can carry on
      -- as normal.  And yes, i have put waaaay too
      -- much effort into making this comment be
      -- almost a rectangular box :)
      mt = mt or {}
 
      return mt.__name or mt.__type or old_type(obj)
    else
      return old_type(obj)
    end
  end

  -- ok time for cursed shit: aliasing one type to another
  -- i will at least blacklist the default Lua types
  local cannot_alias = {
    string = true,
    number = true,
    boolean = true,
    ["nil"] = true,
    ["function"] = true,
    table = true,
    userdata = true
  }
  local defs = {}
  
  -- ex. typedef("number", "int")
  function _G.typedef(t1, t2)
    checkArg(1, t1, "string")
    checkArg(2, t2, "string")
  
    if cannot_alias[t2] then
      error("attempt to override default type")
    end
    
    defs[t2] = t1
    
    return true
  end

  -- copied from machine.lua
  function _G.checkArg(n, have, ...)
    have = type(have)
    
    local function check(want, ...)
      if not want then
        return false
      else
        return have == want or defs[want] == have or check(...)
      end
    end
    
    if not check(...) then
      local msg = string.format("bad argument #%d (%s expected, got %s)",
                                n, table.concat(table.pack(...), " or "), have)
      error(msg, 2)
    end
  end
end
