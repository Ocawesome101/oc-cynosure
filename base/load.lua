-- wrap load() to forcibly insert yields --

k.log(k.loglevels.info, "base/load")

if (not k.cmdline.no_force_yields) then
  local patterns = {
    --[[
    { "if([ %(])(.-)([ %)])then([ \n])", "if%1%2%3then%4__internal_yield() " },
    { "elseif([ %(])(.-)([ %)])then([ \n])", "elseif%1%2%3then%4__internal_yield() " },
    { "([ \n])else([ \n])", "%1else%2__internal_yield() " },--]]
    { "([%);\n ])do([ \n%(])", "%1do%2__internal_yield() "},
    { "([%);\n ])repeat([ \n%(])", "%1repeat%2__internal_yield() " },
  }

  local old_load = load

  local max_time = tonumber(k.cmdline.max_process_time) or 0.1

  local function gsub(s)
    for i=1, #patterns, 1 do
      s = s:gsub(patterns[i][1], patterns[i][2])
    end
    return s
  end

  local function process(code)
    local wrapped = ""
    local in_str = false

    while #code > 0 do
      local chunk, quote = code:match("(.-)([%[\"'])()")
      if not quote then
        wrapped = wrapped .. code
        break
      end
      code = code:sub(#chunk + 2)
      if quote == '"' or quote == "'" then
        if in_str == quote then
          in_str = false
          wrapped = wrapped .. chunk .. quote
        elseif not in_str then
          in_str = quote
          wrapped = wrapped .. chunk .. quote
        else
          wrapped = wrapped .. gsub(chunk) .. quote
        end
      elseif quote == "[" then
        local prefix = "%]"
        if code:sub(1,1) == "[" then
          prefix = "%]%]"
          code = code:sub(2)
          wrapped = wrapped .. gsub(chunk) .. quote .. "["
        elseif code:sub(1,1) == "=" then
          local pch = code:match("(=-%[)")
          if not pch then -- syntax error
            return wrapped .. chunk .. quote .. code
          end
          prefix = prefix .. pch:sub(1, -2) .. "%]"
          code = code:sub(#pch+1)
          wrapped = wrapped .. gsub(chunk) .. "[" .. pch
        else
          wrapped = wrapped .. gsub(chunk) .. quote
        end

        if #prefix > 2 then
          local strend = code:match(".-"..prefix)
          code = code:sub(#strend+1)
          wrapped = wrapped .. strend
        end
      end
    end
    return wrapped
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
      handle:write(" == load: ", name or "(no name)", " ==\n", chunk)
      handle:close()
    end

    env = env or k.userspace or _G

    local ok, err = old_load(chunk, name, mode, env)
    if not ok then
      return nil, err
    end
    
    local ysq = {}
    return function(...)
      local last_yield = computer.uptime()
      local old_iyield = env.__internal_yield
      local old_cyield = env.coroutine.yield
      
      env.__internal_yield = function(tto)
        if computer.uptime() - last_yield >= (tto or max_time) then
          last_yield = computer.uptime()
          local msg = table.pack(old_cyield(0.05))
          if msg.n > 0 then ysq[#ysq+1] = msg end
        end
      end
      
      env.coroutine.yield = function(...)
        if #ysq > 0 then
          return table.unpack(table.remove(ysq, 1))
        end
        last_yield = computer.uptime()
        local msg = table.pack(old_cyield(...))
        ysq[#ysq+1] = msg
        return table.unpack(table.remove(ysq, 1))
      end
      
      local result = table.pack(ok(...))
      env.__internal_yield = old_iyield
      env.coroutine.yield = old_cyield

      return table.unpack(result)
    end
  end
end
