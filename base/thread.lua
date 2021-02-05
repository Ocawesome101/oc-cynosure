-- thread: wrapper around coroutines

k.log(k.loglevels.info, "base/thread")

do
  local old_coroutine = coroutine
  local _coroutine = {}
  _G.coroutine = _coroutine
  function _coroutine.create(func)
    checkArg(1, func, "function")
    return setmetatable({
      __thread = old_coroutine.create(func)
    },
    {
      __index = _coroutine,
      __name = "thread"
    })
  end

  function _coroutine.wrap(fnth)
    checkArg(1, fnth, "function", "thread")
    if type(fnth) == "function" then fnth = _coroutine.create(fnth) end
    return function(...)
      return select(2, fnth:resume(...))
    end
  end

  function _coroutine:resume(...)
    return old_coroutine.resume(self.__thread, ...)
  end

  setmetatable(_coroutine, {
    __index = function(t, k)
      if k.scheduler then
        local process = k.scheduler.info()
        if process.data.coroutine[k] then
          return process.data.coroutine[k]
        end
      end
      return old_coroutine[k]
    end,
    __pairs = function()
      -- build iterable table
      local iter = k.util.merge_tables(old_coroutine,
                      _coroutine,
                      (k.scheduler and k.scheduler.info().data.coroutine or {}))
      return pairs(iter)
    end,
    __metatable = {}
  })
end
