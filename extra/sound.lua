-- sound api v2:  emulate the sound card for everything --

k.log(k.loglevels.info, "extra/sound")

do
  local api = {}
  local tiers = {
    internal = 0,
    beep = 1,
    noise = 2,
    sound = 3,
    [0] = "internal",
    "beep",
    "noise",
    "sound"
  }

  local available = {
    internal = 1,
    beep = 0,
    noise = 0,
    sound = 0,
  }

  local proxies = {
    internal = {
      [computer.address()] = {
        beep = function(tab)
          return computer.beep(tab[1][1], tab[1][2])
        end
      }
    },
    beep = {},
    noise = {},
    sound = {}
  }
  
  local current = "internal"
  local caddr = computer.address()

  local function component_changed(sig, addr, ctype)
    if sig == "component_added" then
      if tiers[ctype] and tiers[ctype] > tiers[current] then
        current = ctype
        available[ctype] = math.max(1, available[ctype] + 1)
        proxies[ctype][addr] = component.proxy(addr)
      end
    else
      if tiers[ctype] then
        available[ctype] = math.min(0, available[ctype] - 1)
        proxies[ctype][addr] = nil
        if caddr == addr then
          for i=#tiers, 0, -1 do
            if available[tiers[i]] > 0 then
              current = tiers[i]
              caddr = next(proxies[current])
            end
          end
        end
      end
    end
  end

  k.event.register("component_added", component_changed)
  k.event.register("component_removed", component_changed)

  local handlers = {
    internal = {play = select(2, next(proxies.internal)).beep},
    --#include "extra/sound/beep.lua"
    --#include "extra/sound/noise.lua"
    --#include "extra/sound/sound.lua"
  }

  function api.play(notes)
    return handlers[current].play(notes)
  end
end
