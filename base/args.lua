-- kernel arguments

do
  local arg_pattern = "^(.-)=(.+)$"
  local orig_args = k.args
  k.args = {}

  for i=1, orig_args.n, 1 do
    local arg = orig_args[i]
    if arg:match(arg_pattern) then
      local k, v = arg:match(arg_pattern)
      if k and v then
        k.args[k] = v
      end
    else
      k.args[arg] = true
    end
  end
end
