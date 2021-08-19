    beep = {
      voices = { [api.voice.SINE] = true },
      channels = 8,
      play = function(tab)
        local bcard = component_cache.beep
        if bcard then
          local o = tab
          tab = {}
          for i=1, #o, 1 do
            tab[o[i][1]] = o[i][2] / 1000
          end
          bcard.play(tab)
        else
          return nil, "no beep card installed"
        end
      end,
      mode = function() end
    },
