#!/usr/bin/env lua
-- a Lua script for building things :)

-- usage: build.lua [-Ifile1,file2,file3,...] [ocvm]

local args = {...}
local pop = table.remove
args[1] = args[1] or ""
-- -Imisc/fs/openfs,misc/devfs,misc/fs/foxfs
local include = {}
do
  local inc_arg = args[1]
  if inc_arg:match("-I(.+)") then
    pop(args, 1)
    local files = inc_arg:sub(3)
    for f in files:gmatch("[^,]+") do
      -- ensure all files have a .lua extension
      include[#include + 1] = f:gsub("([^%.][^l][^u][^a])$", "%1.lua")
    end
  end
end

print("\27[92m-> \27[39mWriting temporary file includes.lua")
local handle = assert(io.open("includes.lua", "w"))
for i=1, #include, 1 do
  handle:write(string.format("--#include \"%s\"\n", include[i]))
end
handle:close()

os.execute("./luacomp init.lua -Okernel.lua")
os.remove("includes.lua")
