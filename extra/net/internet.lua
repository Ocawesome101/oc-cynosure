-- internet component for the 'net' api --

k.log(k.loglevels.info, "extra/net/internet")

do
  local proto = {}

  local iaddr, ipx
  local function get_internet()
    if not (iaddr and component.methods(iaddr)) then
      iaddr = component.list("internet")()
    end
    if iaddr and ((ipx and ipx.address ~= iaddr) or not ipx) then
      ipx = component.proxy(iaddr)
    end
    return ipx
  end

  local _base_stream = {}

  function _base_stream:read(n)
    checkArg(1, n, "number")
    if not self.base then
      return nil, "_base_stream is closed"
    end
    local data = ""
    repeat
      local chunk = self.base.read(n - #data)
      data = data .. (chunk or "")
    until (not chunk) or #data == n
    if #data == 0 then return nil end
    return data
  end

  function _base_stream:write(data)
    checkArg(1, data, "string")
    if not self.base then
      return nil, "_base_stream is closed"
    end
    while #data > 0 do
      local written, err = self.base.write(data)
      if not written then
        return nil, err
      end
      data = data:sub(written + 1)
    end
    return true
  end

  function _base_stream:close()
    if self._base_stream then
      self._base_stream.close()
      self._base_stream = nil
    end
    return true
  end

  function proto:socket(url, port)
    local inetcard = get_internet()
    if not inetcard then
      return nil, "no internet card installed"
    end
    local base, err = inetcard._base_stream(self .. "://" .. url, port)
    if not base then
      return nil, err
    end
    return setmetatable({base = base}, {__index = _base_stream})
  end

  function proto:request(url, data, headers, method)
    checkArg(1, url, "string")
    checkArg(2, data, "string", "table", "nil")
    checkArg(3, headers, "table", "nil")
    checkArg(4, method, "string", "nil")

    local inetcard = get_internet()
    if not inetcard then
      return nil, "no internet card installed"
    end

    local post
    if type(data) == "string" then
      post = data
    elseif type(data) == "table" then
      for k,v in pairs(data) do
        post = (post and (post .. "&") or "")
          .. tostring(k) .. "=" .. tostring(v)
      end
    end

    local base, err = inetcard.request(self .. "://" .. url, post, headers, method)
    if not base then
      return nil, err
    end

    local ok, err
    repeat
      ok, err = base.finishConnect()
    until ok or err
    if not ok then return nil, err end

    return setmetatable({base = base}, {__index = _base_stream})
  end

  protocols.https = proto
  protocols.http = proto
end
