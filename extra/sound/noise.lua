    {
      voices = { [api.voice.SQUARE] = true, [api.voice.SINE] = true,
        [api.voice.TRIANGLE] = true, [api.voice.SAWTOOTH] = true },
      channels = 8,
      play = function(tab)
        local card = component_cache.noise
        if card then
          for i=1, #tab, 1 do
            if tab[i][4] then card.setMode(i, tab[i][4]) end
            tab[i] = { tab[i][1], tab[i][2] / 1000}
          end
          card.play(tab)
        end
      end,
    },
