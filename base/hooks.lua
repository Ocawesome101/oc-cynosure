-- kernel hooks

k.log(k.loglevels.info, "base/hooks")

do
  local hooks = {}
  k.hooks = {}
  
  function k.hooks.add(name, func)
    checkArg(1, name, "string")
    checkArg(2, func, "function")

    hooks[name] = hooks[name] or {}
    table.insert(hooks[name], func)
  end

  function k.hooks.call(name, ...)
    checkArg(1, name, "string")

    k.logio:write(":: calling hook " .. name .. "\n")
    if hooks[name] then
      for k, v in ipairs(hooks[name]) do
        v(...)
      end
    end
  end
end
