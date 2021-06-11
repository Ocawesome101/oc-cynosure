-- wrap load() to forcibly insert yields --

k.log(k.loglevels.info, "base/load")

if k.cmdline.force_yields then
  local patterns = {
    { "if([ %(])(.-)([ %)])then([ \n])", "if%1%2%3then%4coroutine.yield(0)" },
    { "while([ %(])(.-)([ %)])do([ \n])", "while%1%2%3do%4coroutine.yield(0) " },
    { "for([ %(])(.-)([ %)])do([ \n])", "for%1%2%3do%4coroutine.yield(0) " },
    { "repeat([ \n])", "repeat%1coroutine.yield(0) " },
  }

  local old_load = load

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

    return old_load(chunk, name, mode, env)
  end
end
