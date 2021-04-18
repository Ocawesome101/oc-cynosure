-- Cynosure kernel.  Should (TM) be mostly drop-in compatible with Paragon. --
-- Might even be better.  Famous last words!
-- Copyright (c) 2021 i develop things under the GNU GPLv3.

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
--#include "base/event.lua"
--#include "base/logger.lua"
--#include "base/hooks.lua"
--#include "base/util.lua"
--#include "base/security.lua"
--#include "base/shutdown.lua"
--#include "base/component.lua"
--#include "base/fsapi.lua"
--#include "base/stdlib.lua"
--#include "base/types.lua"
--#include "base/struct.lua"
--#include "base/syslog.lua"
--#include "base/thread.lua"
--#include "base/process.lua"
--#include "base/scheduler.lua"
--#include "sysfs/sysfs.lua"
--#include "includes.lua"
--#include "base/load_init.lua"
k.panic("Premature exit!")
