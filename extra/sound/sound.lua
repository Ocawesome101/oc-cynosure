    sound = {
      voices = { [api.voice.SQUARE] = true, [api.voice.SINE] = true,
        [api.voice.TRIANGLE] = true, [api.voice.SAWTOOTH] = true,
        [api.voice.NOISE] = true },
      channels = 8,
      play = function(tab)
        local card = component_cache.sound
        if card then
          local dur = 0
          for i in pairs(tab) do
            local freq, _dur, vol, voi = table.unpack(tab[i])
            dur = math.max(dur, _dur)
            card.open(i)
            card.setFrequency(i, freq)
            card.setADSR(i, 0, _dur, 0.25, _dur // 2)
            if vol then card.setVolume(i, vol / 100) end
            if voi then card.setWave(i, card.modes[voi]) end
          end
          card.delay(dur or 0)
          for i=1, 10, 1 do card.process() end
          for i=1, #tab, 1 do card.close(i) end
        end
      end,
    },
