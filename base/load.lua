-- wrap load() to forcibly insert yields --

k.log(k.loglevels.info, "base/load")

if (not k.cmdline.no_force_yields) then
  local patterns = {
    { "if([ %(])(.-)([ %)])then([ \n])", "if%1%2%3then%4__internal_yield() " },
    { "while([ %(])(.-)([ %)])do([ \n])", "while%1%2%3do%4__internal_yield() " },
    { "for([ %(])(.-)([ %)])do([ \n])", "for%1%2%3do%4__internal_yield() " },
    { "repeat([ \n])", "repeat%1__internal_yield() " },
  }

  local old_load = load

  local max_time = tonumber(k.cmdline.max_process_time) or 0.5

  function _G.load(chunk, name, mode, env)
    checkArg(1, chunk, "function", "string")
    checkArg(2, name, "string", "nil")
    checkArg(3, mode, "string", "nil")
    checkArg(4, env, "table", "nil")

    local data = ""
    if type(chunk) == "string" then
      data = chunk
    else
      repeat
        local ch = chunk()
        data = data .. (ch or "")
      until not ch
    end

    for i=1, #patterns, 1 do
      chunk = chunk:gsub(patterns[i][1], patterns[i][2])
    end

    local last_yield = computer.uptime()
    env.__internal_yield = function()
      if computer.uptime() - last_yield > max_time then
        last_yield = computer.uptime()
        coroutine.yield(0)
      end
    end

    return old_load(chunk, name, mode, env)
  end
end
