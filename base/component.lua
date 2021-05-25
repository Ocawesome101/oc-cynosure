-- some component API conveniences

k.log(k.loglevels.info, "base/component")

do
  function component.get(addr, mkpx)
    checkArg(1, addr, "string")
    checkArg(2, mkpx, "boolean", "nil")
    
    for k, v in component.list() do
      if k:sub(1, #addr) == addr then
        return mkpx and component.proxy(k) or k
      end
    end
    
    return nil, "no such component"
  end

  setmetatable(component, {
    __index = function(t, k)
      local addr = component.list(k)()
      if not addr then
        error(string.format("no component of type '%s'", k))
      end
    
      return component.proxy(addr)
    end
  })
end
