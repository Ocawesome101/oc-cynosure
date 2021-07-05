-- getgpu - get the gpu associated with a tty --

do
  k.gpus = {}

  k.gpus[0] = k.logio.gpu

  k.hooks.add("sandbox", function()
    function k.userspace.package.loaded.getgpu(id)
      checkArg(1, id, "number")

      if not k.gpus[id] then
        return nil, "terminal not registered"
      end

      return k.gpus[id]
    end
  end)
end
