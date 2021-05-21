-- sysfs handlers

k.log(k.loglevels.info, "sysfs/handlers")

do
  local util = {}
  function util.mkfile(data)
    local data = data
    return {
      dir = false,
      read = function(self, n)
        self.__ptr = self.__ptr or 0
        if self.__ptr >= #data then
          return nil
        else
          self.__ptr = self.__ptr + n
          return data:sub(self.__ptr - n, self.__ptr)
        end
      end
    }
  end

  function util.fmkfile(tab, k, w)
    return {
      dir = false,
      read = function(self)
        if self.__read then
          return nil
        end

        self.__read = true
        return tostring(tab[k])
      end,
      write = w and function(self, d)
        tab[k] = tonumber(d) or d
      end or nil
    }
  end

  function util.fnmkfile(r, w)
    return {
      dir = false,
      read = function(s)
        if s.__read then
          return nil
        end

        s.__read = true
        return r()
      end,
      write = w
    }
  end

--#include "sysfs/handlers/generic.lua"
--#include "sysfs/handlers/directory.lua"
--#include "sysfs/handlers/process.lua"
--#include "sysfs/handlers/tty.lua"

-- component-specific handlers
--#include "sysfs/handlers/gpu.lua"
--#include "sysfs/handlers/filesystem.lua"

-- component event handler
--#include "sysfs/handlers/component.lua"

end -- sysfs handlers: Done
