#!/bin/bash
set -e
./luacomp init.lua -Okernel.lua
if [ "$1" = "ocvm" ] ; then
  ocvm ../..
fi
