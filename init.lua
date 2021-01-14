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
--#include "base/hooks.lua"
--#include "base/util.lua"
--#include "base/shutdown.lua"
--#include "base/component.lua"
--#include "base/fsapi.lua"
--#include "base/types.lua"
--#include "base/thread.lua"
--#include "base/process.lua"
--#include "base/scheduler.lua"
--#include "includes.lua"
--#include "base/load_init.lua"

-- temporary main loop
while true do
  computer.pullSignal()
end
