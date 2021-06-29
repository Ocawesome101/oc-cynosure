-- kernel arguments

do
  local arg_pattern = "^(.-)=(.+)$"
  local orig_args = k.cmdline
  k.cmdline = {}

  for i=1, #orig_args, 1 do
    local karg = orig_args[i]
    
    if karg:match(arg_pattern) then
      local ka, v = karg:match(arg_pattern)
    
      if ka and v then
        k.cmdline[ka] = tonumber(v) or v
      end
    else
      k.cmdline[karg] = true
    end
  end
end
