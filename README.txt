Cynosure
========

A hopefully decent Unix-like kernel for OpenComputers.  Could be considered an
attempt at a better Paragon.

Requires Lua 5.3.  `build.sh` will build the kernel.  Put it as `init.lua` to
load Cynosure directly from a managed filesystem, or load it from a boot loader
and pass command-line arguments.  Cynosure is flexible!

Main goals:
  - Faster VT100 emulation than Paragon or Monolith
  - Better scheduler and pipes, perhaps more integrated
  - Better dynamic module loading
  - Better unmanaged filesystem interface
  - Lighter on memory, i.e. works on 192KB of RAM
  - Relatively small footprint, both memory and storage, of minimal kernel

Core Features
=============
  - Full-featured and fast VT100 emulation
  - Hook system
  - User system
  - Process-based scheduling
  - Advanced piping support
    - Hopefully thread-safe
