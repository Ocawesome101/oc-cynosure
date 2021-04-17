-- thread: wrapper around coroutines

k.log(k.loglevels.info, "base/thread")

do
  local function handler(err)
    return debug.traceback(err, 3)
  end

  local old_coroutine = coroutine
  local _coroutine = {}
  _G.coroutine = _coroutine
  function _coroutine.create(func)
    checkArg(1, func, "function")
    return setmetatable({
      __thread = old_coroutine.create(function()
        return select(2, k.util.lassert(xpcall(func, handler)))
      end)
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

  function _coroutine:status()
    return old_coroutine.status(self.__thread)
  end

  for k,v in pairs(old_coroutine) do
    _coroutine[k] = _coroutine[k] or v
  end
end
