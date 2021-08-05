    {
      voices = { [api.voice.SQUARE] = true, [api.voice.SINE] = true,
        [api.voice.TRIANGLE] = true, [api.voice.SAWTOOTH] = true,
        [api.voice.NOISE] = true },
      channels = 8,
      play = function(tab)
        local card = component_cache.sound
        if card then
          for i=1, #tab, 1 do
            local freq, dur, vol, voi = table.unpack(tab[i])
            card.open(i)
            card.setFrequency(i, freq)
            card.setADSR(tab[i], 0, dur, 0.25, dur // 2)
            if vol then card.setVolume(i, vol / 100) end
            if voi then card.setWave(i, voi) end
            card.delay()
          end
          card.process()
          for i=1, #tab, 1 do card.close(i) end
        end
      end,
    },
