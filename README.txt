Cynosure
========

A hopefully decent Unix-like kernel for OpenComputers.  Could be considered an
attempt at a better Paragon.

Requires Lua 5.3.  Executing `./build` will build the kernel.  Put it as
`init.lua` to load Cynosure directly from a managed filesystem, or load it from
a boot loader and pass command-line arguments.  Cynosure is flexible!

Main goals:
  - Faster VT100 emulation than Paragon or Monolith
    o  Benchmarks show a nearly 2x improvement - almost as fast as raw GPU
       access!
  - Better scheduler and pipes, perhaps more integrated
  - Better dynamic module loading
  - Better unmanaged filesystem interface
  - Lighter on memory, i.e. works on 192KB of RAM
    o  The kernel boots on 192KB of RAM, and ULOS loads on 256KB.
  - Relatively small footprint, both memory and storage, of minimal kernel

Core Features
=============
Some of these may be unrealistic.  These are subject to change.
  - Every resource is represented to userspace as a file
    o Process creation is still done via specific API due to various
          intricacies of the Lua language.  Could be done through sending
          bytecode or raw source code over a pipe, but that would be unnecessary
          complexity;
    o The following basic file structure is followed:
      > Root filesystem mounted at "/", as per standard;
      > devfs and procfs mounted under "/sys/{dev,proc}" for memory reasons -
          it's lighter on memory to create one RAM-based filesystem rather than
          2 of them;
      > Process information may be read from "/sys/proc/{pid}"
      > Devices are accessible through "/sys/dev/{device_id}{number}" (TODO)
        - Device names:
          o `hdN`: refers to internal filesystem nodes
          o `fdN`: refers to external filesystem nodes, i.e. floppy disks
          o `ttyN`: refers to a teletype device, usually a stream to a local
                        VT100 terminal (i.e., one running on the local machine)
      > Filesystem mounts in "/sys/mounts"
        - </sys/mounts>:
            /sys/dev/hd0: /
            /sys/dev/fd0: /mnt/openos
  - Full-featured and fast VT100 emulation (see above)
  - Hook system
  - Multi-user system supporting ACLs and permissions
  - Process-based scheduling
    o Signals are managed per-process through a queue
      > Easier inter-thread communication
      > Achieved through wrapping computer.{push,pull}Signal
  - Advanced piping support
    - Hopefully thread-safe
  - Crude pre-emptive multitasking support by wrapping load() to forcibly insert yields
    o This can be disabled on the kernel command line with the 'no_force_yields' option
    o The timeout may be adjusted from its default of 0.5s with the 'max_process_time=NUMBER' option
