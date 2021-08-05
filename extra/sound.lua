-- sound subsystem for Cynosure --

k.log(k.loglevels.info, "extra/sound")

do
  k.log(k.loglevels.debug, "registering sound-related component detection")

  local api = {
    MAX_CHANNELS = 1,
    CARD_TYPE = "computer.beep", -- also beep, noise, sound
    voice = {
      SQUARE = "square",
      SINE = "sine",
      TRIANGLE = "triangle",
      SAWTOOTH = "sawtooth",
      NOISE = "noise",
    }
  }

  local component_cache = {}
  
  -- all handlers must contain:
  -- a table of supported voices
  -- the maximum number of channels
  -- a play(tab) function to play simultaneous notes
  --   through { frequency, ms[, volume][, voice] } pairs contained in
  --   `tab`
  -- a mode(chan, voice) function to set the voice
  --   for each channel
  local card_handlers = {
    ["computer.beep"] = {
      voices = { [api.voice.SINE] = true },
      channels = 1,
      play = function(tab)
        local freq, dur = table.unpack(select(2, next(tab)))
        dur = dur / 1000 -- ms -> s
        computer.beep(freq, dur)
      end
    },
    --#include "extra/sound/beep.lua"
    --#include "extra/sound/noise.lua"
    --#include "extra/sound/sound.lua"
  }

  local chandler = function(s, add, typ)
    s = s == "component_added"
    if s then
      if typ == "beep" or typ == "noise" or typ == "sound" then
        local card = component_cache[typ] or add
        if type(card) == "string" then
          component_cache[typ] = component.proxy(card)
        end
      end
    elseif component_cache[typ] == add then
      component_cache[typ] = component.list(typ, true)()
      if component_cache[typ] then
        component_cache[typ] = component.proxy(component_cache[typ])
      end
    end
  end

  local id = k.event.register("component_added", chandler)
  k.event.register("component_removed", chandler)

  k.hooks.add("sandbox", function()
    k.userspace.package.loaded.sound = package.protect(api)
  end)
end
