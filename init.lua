-- Cynosure kernel.  Should (TM) be mostly drop-in compatible with Paragon. --
-- Might even be better.  Famous last words!

_G.k = { args = table.pack(...), modules = {} }
--#include "base/args.lua"
--#include "base/version.lua"
--#include "base/tty.lua"
--#include "base/logger.lua"
