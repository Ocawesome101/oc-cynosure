-- getgpu - get the gpu associated with a tty --

k.log(k.loglevels.info, "extra/ustty")

do
  k.gpus = {}
  local deletable = {}

  k.gpus[0] = k.logio.gpu

  k.hooks.add("sandbox", function()
    k.userspace.package.loaded.tty = {
      -- get the GPU associated with a TTY
      getgpu = function(id)
        checkArg(1, id, "number")

        if not k.gpus[id] then
          return nil, "terminal not registered"
        end

        return k.gpus[id]
      end,

      -- create a TTY on top of a GPU and optional screen
      create = function(gpu, screen)
        if type(gpu) == "table" then screen = screen or gpu.getScreen() end
        local raw = k.create_tty(gpu, screen)
        deletable[raw.ttyn] = raw
        local prox = io.open(string.format("/sys/dev/tty%d", raw.ttyn), "rw")
        prox.tty = raw.ttyn
        prox.buffer_mode = "none"
        return prox
      end,

      -- cleanly delete a user-created TTY
      delete = function(id)
        checkArg(1, id, "number")
        if not deletable[id] then
          return nil, "tty " .. id
            .. " is not user-created and cannot be deregistered"
        end
        deletable[id]:close()
        return true
      end
    }
  end)
end
