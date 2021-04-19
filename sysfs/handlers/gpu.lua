-- sysfs: GPU hander

do
  local function mknew(addr)
    local proxy = component.proxy(addr)
    local new = {
      dir = true,
      address = util.mkfile(addr),
      slot = util.mkfile(proxy.slot),
      type = util.mkfile(proxy.type),
      resolution = util.fnmkfile(
        function()
          return string.format("%d %d", proxy.getResolution())
        end,
        function(_, s)
          local w, h = s:match("(%d+) (%d+)")
        
          w = tonumber(w)
          h = tonumber(h)
        
          if not (w and h) then
            return nil
          end

          proxy.setResolution(w, h)
        end
      ),
      foreground = util.fnmkfile(
        function()
          return tostring(proxy.getForeground())
        end,
        function(_, s)
          s = tonumber(s)
          if not s then
            return nil
          end

          proxy.setForeground(s)
        end
      ),
      background = util.fnmkfile(
        function()
          return tostring(proxy.getBackground())
        end,
        function(_, s)
          s = tonumber(s)
          if not s then
            return nil
          end

          proxy.setBackground(s)
        end
      ),
      maxResolution = util.fnmkfile(
        function()
          return string.format("%d %d", proxy.maxResolution())
        end
      ),
      maxDepth = util.fnmkfile(
        function()
          return tostring(proxy.maxDepth())
        end
      ),
      depth = util.fnmkfile(
        function()
          return tostring(proxy.getDepth())
        end,
        function(_, s)
          s = tonumber(s)
          if not s then
            return nil
          end

          proxy.setDepth(s)
        end
      ),
      screen = util.fnmkfile(
        function()
          return tostring(proxy.getScreen())
        end,
        function(_, s)
          if not component.type(s) == "screen" then
            return nil
          end

          proxy.bind(s)
        end
      )
    }
  end

  k.sysfs.register("gpu", mknew)
end
