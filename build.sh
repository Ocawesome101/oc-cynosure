#!/bin/bash

source .buildconfig

kmods=$(echo $KMODS | sed 's/,/\n/g')

rm -f includes.lua
touch includes.lua

for mod in $kmods; do
  printf "including module $mod\n"
  echo "--#include \"$mod.lua\"" >> includes.lua
done

$PREPROCESSOR init.lua kernel.lua
rm -f includes.lua
