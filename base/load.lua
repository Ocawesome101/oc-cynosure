-- wrap load() to forcibly insert yields --

k.log(k.loglevels.info, "base/load")

if (not k.cmdline.no_force_yields) then
  local patterns = {
    { "if([ %(])(.-)([ %)])then([ \n])", "if%1%2%3then%4__internal_yield() " },
    { "elseif([ %(])(.-)([ %)])then([ \n])", "elseif%1%2%3then%4__internal_yield() " },
    { "([ \n])else([ \n])", "%1else%2__internal_yield() " },
    { "while([ %(])(.-)([ %)])do([ \n])", "while%1%2%3do%4__internal_yield() " },
    { "for([ %(])(.-)([ %)])do([ \n])", "for%1%2%3do%4__internal_yield() " },
    { "repeat([ \n])", "repeat%1__internal_yield() " },
  }

  local old_load = load

  local max_time = tonumber(k.cmdline.max_process_time) or 0.5

  local function process_section(s)
    for i=1, #patterns, 1 do
      s = s:gsub(patterns[i][1], patterns[i][2])
    end
    return s
  end

  local function process(chunk)
    local i = 1
    local ret = ""
    local nq = 0
    local in_blocks = {}
    while true do
      local nextquote = chunk:find("[^\\][\"']", i)
      if nextquote then
        local ch = chunk:sub(i, nextquote)
        i = nextquote + 1
        nq = nq + 1
        if nq % 2 == 1 then
          ch = process_section(ch)
        end
        ret = ret .. ch
      else
        local nbs, nbe = chunk:find("%[=*%[", i)
        if nbs and nbe then
          ret = ret .. process_section(chunk:sub(i, nbs - 1))
          local match = chunk:find("%]" .. ("="):rep((nbe - nbs) - 1) .. "%]")
          if not match then
            -- the Lua parser will error here, no point in processing further
            ret = ret .. chunk:sub(nbs)
            break
          end
          local ch = chunk:sub(nbs, match)
          ret = ret .. ch --:sub(1,-2)
          i = match + 1
        else
          ret = ret .. process_section(chunk:sub(i))
          i = #chunk
          break
        end
      end
    end

    if i < #chunk then ret = ret .. process_section(chunk:sub(i)) end

    return ret
  end

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

    chunk = process(chunk)

    if k.cmdline.debug_load then
      local handle = io.open("/load.txt", "a")
      handle:write(" -- load: ", name or "(no name)", " --\n", chunk)
      handle:close()
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
