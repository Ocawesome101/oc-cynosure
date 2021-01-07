-- Cynosure kernel.  Should (TM) be mostly drop-in compatible with Paragon. --
-- Might even be better.  Famous last words!

_G.k = { cmdline = table.pack(...), modules = {} }
do
  local start = computer.uptime()
  function k.uptime()
    return computer.uptime() - start
  end
end
--#include "base/args.lua"
--#include "base/version.lua"
--#include "base/tty.lua"
--#include "base/logger.lua"

-- temporary main loop
while true do
  computer.pullSignal()
end
