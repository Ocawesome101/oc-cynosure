-- object-based tty streams --

do
  local colors = {
    0x000000,
    0xFF0000,
    0x00FF00,
    0xFFFF00,
    0x0000FF,
    0xFF00FF,
    0x00FFFF,
    0xFFFFFF
  }

  local _stream = {}
  function _stream:write()
  end

  function _stream:read()
  end

  function _stream:close()
  end

  -- this is the raw function for creating TTYs over components
  -- userspace gets abstracted-away stuff
  function k.tty(gpu, screen)
    checkArg(1, gpu, "string")
    checkArg(2, screen, "string")
    local proxy = component.proxy(gpu)
    proxy.bind(screen)
    local new = setmetatable({
      gpu = proxy,
      cx = 0,
      cy = 0
    })
    new.w, new.h = proxy.maxResolution()
    proxy.setResolution(new.w, new.h)
    return new
  end
end
