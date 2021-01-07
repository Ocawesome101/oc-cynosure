-- kernel arguments

do
  local arg_pattern = "^(.-)=(.+)$"
  local orig_args = k.cmdline
  k.cmdline = {}

  for i=1, orig_args.n, 1 do
    local arg = orig_args[i]
    if arg:match(arg_pattern) then
      local k, v = arg:match(arg_pattern)
      if k and v then
        k.cmdline[k] = tonumber(v) or v
      end
    else
      k.cmdline[arg] = true
    end
  end
end
