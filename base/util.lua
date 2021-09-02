-- some utilities --

k.log(k.loglevels.info, "base/util")

do
  local util = {}
  
  function util.merge_tables(a, b)
    for k, v in pairs(b) do
      if not a[k] then
        a[k] = v
      end
    end
  
    return a
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
      __pairs = function() return pairs(tbl) end,
      __ipairs = function() return ipairs(tbl) end,
      __metatable = {}
    }
  
    return setmetatable(new, mt)
  end

  -- create hopefully memory-friendly copies of tables
  -- uses metatable magic
  -- this is a bit like util.protect except tables are still writable
  -- even i still don't fully understand how this works, but it works
  -- nonetheless
  --[[disabled due to some issues i was having
  if computer.totalMemory() < 262144 then
    -- if we have 256k or less memory, use the mem-friendly function
    function util.copy_table(tbl)
      if type(tbl) ~= "table" then return tbl end
      local shadow = {}
      local copy_mt = {
        __index = function(_, k)
          local item = rawget(shadow, k) or rawget(tbl, k)
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
  else--]] do
    -- from https://lua-users.org/wiki/CopyTable
    local function deepcopy(orig, copies)
      copies = copies or {}
      local orig_type = type(orig)
      local copy
    
      if orig_type == 'table' then
        if copies[orig] then
          copy = copies[orig]
        else
          copy = {}
          copies[orig] = copy
      
          for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
          end
          
          setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
      else -- number, string, boolean, etc
        copy = orig
      end

      return copy
    end

    function util.copy_table(t)
      return deepcopy(t)
    end
  end

  function util.to_hex(str)
    local ret = ""
    
    for char in str:gmatch(".") do
      ret = string.format("%s%02x", ret, string.byte(char))
    end
    
    return ret
  end

  -- lassert: local assert
  -- removes the "init:123" from errors (fires at level 0)
  function util.lassert(a, ...)
    if not a then error(..., 0) else return a, ... end
  end

  -- pipes for IPC and shells and things
  do
    local _pipe = {}

    function _pipe:read(n)
      if self.closed and #self.rb == 0 then
        return nil
      end
      if not self.closed then
        while #self.rb < n do
          if self.from ~= 0 then
            k.scheduler.info().data.self.resume_next = self.from
          end
          coroutine.yield()
        end
      end
      local data = self.rb:sub(1, n)
      self.rb = self.rb:sub(n + 1)
      return data
    end

    function _pipe:write(dat)
      if self.closed then
        k.scheduler.signal(nil, k.scheduler.signals.pipe)
        return nil, "broken pipe"
      end
      self.rb = self.rb .. dat
      return true
    end

    function _pipe:flush()
      return true
    end

    function _pipe:close()
      self.closed = true
      return true
    end

    function util.make_pipe()
      local new = k.create_fstream(setmetatable({
        from = 0, -- the process providing output
        to = 0, -- the process reading input
        rb = "",
      }, {__index = _pipe}), "rw")
      new.buffer_mode = "none"
      return new
    end

    k.hooks.add("sandbox", function()
      k.userspace.package.loaded.pipe = {
        create = util.make_pipe
      }
    end)
  end

  k.util = util
end
