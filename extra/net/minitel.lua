-- minitel driver --
-- code credit goes to Izaya - i've just adapted his OpenOS code --

k.log(k.loglevels.info, "extra/net/minitel")

do
  local listeners = {}
  local debug = k.cmdline["minitel.debug"] and k.cmdline["minitel.debug"] ~= 0
  local port = tonumber(k.cmdline["minitel.port"]) or 4096
  local retry = tonumber(k.cmdline["minitel.retries"]) or 10
  local route = true
  local sroutes = {}
  local rcache = setmetatable({}, {__index = sroutes})
  local rctime = 15

  local hostname = computer.address():sub(1, 8)

  local pqueue = {}
  local pcache = {}
  local pctime = 30

  local function dprint(...)
    if debug then
      k.log(k.loglevels.debug, ...)
    end
  end

  local modems = {}
  for addr, ct in component.list("modem") do
    modems[#modems+1] = component.proxy(addr)
  end
  for k, v in ipairs(modems) do
    v.open(port)
  end
  for addr, ct in component.list("tunnel") do
    modems[#modems+1] = component.proxy(addr)
  end

  local function genPacketID()
    local npID = ""
    for i=1, 16, 1 do
      npID = npID .. string.char(math.random(32, 126))
    end
    return npID
  end

  -- i've done my best to make this readable...
  local function sendPacket(packetID, packetType, dest, sender,
      vPort, data, repeatingFrom)
    if rcache[dest] then
      dprint("Cached", rcache[dest][1], "send", rcache[dest][2],
        cfg.port, packetID, packetType, dest, sender, vPort, data)

      if component.type(rcache[dest][1]) == "modem" then
        component.invoke(rcache[dest][1], "send", rcache[dest][2],
          cfg.port, packetID, packetType, dest, sender, vPort, data)
      elseif component.type(rcache[dest][1]) == "tunnel" then
        component.invoke(rcache[dest][1], "send", packetID, packetType, dest,
          sender, vPort, data)
      end
    else
      dprint("Not cached", cfg.port, packetID, packetType, dest,
        sender, vPort,data)
      for k, v in pairs(modems) do
        -- do not send message back to the wired or linked modem it came from
        -- the check for tunnels is for short circuiting `v.isWireless()`, which does not exist for tunnels
        if v.address ~= repeatingFrom or (v.type ~= "tunnel"
            and v.isWireless()) then
          if v.type == "modem" then
            v.broadcast(cfg.port, packetID, packetType, dest,
              sender, vPort, data)
            v.send(packetID, packetType, dest, sender, vPort, data)
          end
        end
      end
    end
  end

  local function pruneCache()
    for k,v in pairs(rcache) do
      dprint(k,v[3],computer.uptime())
      if v[3] < computer.uptime() then
        rcache[k] = nil
        dprint("pruned "..k.." from routing cache")
      end
    end
    for k,v in pairs(pcache) do
      if v < computer.uptime() then
        pcache[k] = nil
        dprint("pruned "..k.." from packet cache")
      end
    end
  end

  local function checkPCache(packetID)
    dprint(packetID)
    for k,v in pairs(pcache) do
      dprint(k)
      if k == packetID then return true end
    end
    return false
  end

  local function processPacket(_,localModem,from,pport,_,packetID,packetType,dest,sender,vPort,data)
    pruneCache()
    if pport == cfg.port or pport == 0 then -- for linked cards
    dprint(cfg.port,vPort,packetType,dest)
    if checkPCache(packetID) then return end
      if dest == hostname then
        if packetType == 1 then
          sendPacket(genPacketID(),2,sender,hostname,vPort,packetID)
        end
        if packetType == 2 then
          dprint("Dropping "..data.." from queue")
          pqueue[data] = nil
          computer.pushSignal("net_ack",data)
        end
        if packetType ~= 2 then
          computer.pushSignal("net_msg",sender,vPort,data)
        end
      elseif dest:sub(1,1) == "~" then -- broadcasts start with ~
        computer.pushSignal("net_broadcast",sender,vPort,data)
      elseif cfg.route then -- repeat packets if route is enabled
        sendPacket(packetID,packetType,dest,sender,vPort,data,localModem)
      end
      if not rcache[sender] then -- add the sender to the rcache
        dprint("rcache: "..sender..":", localModem,from,computer.uptime())
        rcache[sender] = {localModem,from,computer.uptime()+cfg.rctime}
      end
      if not pcache[packetID] then -- add the packet ID to the pcache
        pcache[packetID] = computer.uptime()+cfg.pctime
      end
    end
  end

  local function queuePacket(_,ptype,to,vPort,data,npID)
    npID = npID or genPacketID()
    if to == hostname or to == "localhost" then
      computer.pushSignal("net_msg",to,vPort,data)
      computer.pushSignal("net_ack",npID)
      return
    end
    pqueue[npID] = {ptype,to,vPort,data,0,0}
    dprint(npID,table.unpack(pqueue[npID]))
  end

  local function packetPusher()
    for k,v in pairs(pqueue) do
      if v[5] < computer.uptime() then
        dprint(k,v[1],v[2],hostname,v[3],v[4])
        sendPacket(k,v[1],v[2],hostname,v[3],v[4])
        if v[1] ~= 1 or v[6] == cfg.retrycount then
          pqueue[k] = nil
        else
          pqueue[k][5]=computer.uptime()+cfg.retry
          pqueue[k][6]=pqueue[k][6]+1
        end
      end
    end
  end

  k.event.register("modem_message", function(...)
    packetPusher()pruneCache()processPacket(...)end)
  
  k.event.register("*", function(...)
    packetPusher()
    pruneCache()
  end)

  -- now, the minitel API --
  
  local mtapi = {}
  local streamdelay = tonumber(k.cmdline["minitel.streamdelay"]) or 30
  local mto = tonumber(k.cmdline["minitel.mtu"]) or 4096
  local openports = {}

  -- layer 3: packets

  function mtapi.usend(to, port, data, npid)
    queuePacket(nil, 0, to, port, data, npid)
  end

  function mtapi.rsend(to, port, data, noblock)
     local pid, stime = genPacketID(), computer.uptime() + streamdelay
     queuePacket(nil, 1, to, port, data, pid)
     if noblock then return pid end
     local sig, rpid
     repeat
       sig, rpid = coroutine.yield(0.5)
     until (sig == "net_ack" and rpid == pid) or computer.uptime() > stime
     if not rpid then return false end
     return true
  end

  -- layer 4: ordered packets

  function mtapi.send(to, port, ldata)
    local tdata = {}
    if #ldata > mtu then
      for i=1, #ldata, mtu do
        tdata[#tdata+1] = ldata:sub(1, mtu)
        ldata = ldata:sub(mtu + 1)
      end
    else
      tdata = {ldata}
    end
    for k, v in ipairs(tdata) do
      if not mtapi.rsend(to, port, v) then
        return false
      end
    end
    return true
  end

  -- layer 5: sockets

  local _sock = {}

  function _sock:write(self, data)
    if self.state == "open" then
      if not mtapi.send(self.addr, self.port, data) then
        self:close()
        return nil, "timed out"
      end
    else
      return nil, "socket is closed"
    end
  end

  function _sock:read(self, length)
    length = length or "\n"
    local rdata = ""
    if type(length) == "number" then
      rdata = self.rbuffer:sub(1, length)
      self.rbuffer = self.rbuffer:sub(length + 1)
      return rdata
    elseif type(length) == "string" then
      if length:sub(1,1) == "a" or length:sub(1,2) == "*a" then
        rdata = self.rbuffer
        self.rbuffer = ""
        return rdata
      elseif #length == 1 then
        local pre, post = self.rbuffer:match("(.-)"..length.."(.*)")
        if pre and post then
          self.rbuffer = post
          return pre
        end
        return nil
      end
    end
  end

  local function socket(addr, port, sclose)
    local conn = setmetatable({
      addr = addr,
      port = tonumber(port),
      rbuffer = "",
      state = "open",
      sclose = sclose
    }, {__index = _sock})

    local function listener(_, f, p, d)
      if f == conn.addr and p == conn.port then
        if d == sclose then
          conn:close()
        else
          conn.rbuffer = conn.rbuffer .. d
        end
      end
    end

    local id = k.event.register("net_msg", listener)
    function conn:close()
      k.event.unregister(id)
      self.state = "closed"
      mtapi.rsend(addr, port, sclose)
    end

    return conn
  end
  
  k.hooks.add("sandbox", function()
    k.userspace.package.loaded["network.minitel"] = k.util.copy_table(mtapi)
  end)

  local proto = {}
  
  function proto.sethostname(hn)
    hostname = hn
  end
  
  -- extension: 'file' argument passed to 'openstream'
  local function open_socket(to, port, file)
    if not mtapi.rsend(to, port, "openstream", file) then
      return nil, "no ack from host"
    end
    local st = computer.uptime() + streamdelay
    local est = false
    local _, from, rport, data
    while true do
      repeat
        _, from, rport, data = coroutine.yield(streamdelay)
      until _ == "net_msg" or computer.uptime() > st
      
      if to == from and rport == port then
        if tonumber(data) then
          est = true
        end
        break
      end

      if st < computer.uptime() then
        return nil, "timed out"
      end
    end

    if not est then
      return nil, "refused"
    end

    data = tonumber(data)
    sclose = ""
    local _, from, nport, sclose
    repeat
      _, from, nport, sclose = coroutine.yield()
    until _ == "net_msg" and from == to and nport == data
    return socket(to, data, sclose)
  end


  function proto:listen(url, handler, unregisterOnSuccess)
    local hn, port = url:match("(.-):(%d+)")
    if hn ~= "localhost" or not (hn and port) then
      return nil, "bad URL: expected 'localhost:port'"
    end

    if handler then
      local id = 0

      local function listener(_, from, rport, data, data2)
        if rport == port and data == "openstream" then
          local nport = math.random(32768, 65535)
          local sclose = genPacketID()
          mtapi.rsend(from, rport, tostring(nport))
          mtapi.rsend(from, nport, sclose)
          if unregisterOnSuccess then k.event.unregister(id) end
          handler(socket(from, nport, sclose), data2)
        end
      end

      id = k.event.register("net_msg", listener)
      return true
    else
      local _, from, rport, data
      repeat
        _, from, rport, data = coroutine.yield()
      until _ == "net_msg"
      local nport = math.random(32768, 65535)
      local sclose = genPacketID()
      mtapi.rsend(from, rport, tostring(nport))
      mtapi.rsend(from, nport, sclose)
      return socket(from, nport, sclose)
    end
  end

  -- url format:
  -- hostname:port
  function proto:socket(url)
    local to, port = url:match("^(.-):(%d+)")
    if not (to and port) then
      return nil, "bad URL: expected 'hostname:port', got " .. url
    end
    return open_socket(to, tonumber(port))
  end

  -- hostname:port/path/to/file
  function proto:request(url)
    local to, port, file = url:match("^(.-):(%d+)/(.+)")
    if not (to and port and file) then
      return nil, "bad URL: expected 'hostname:port/file'"
    end
    return open_socket(to, tonumber(port), file)
  end

  protocols.mt = proto
  protocols.mtel = proto
  protocols.minitel = proto
end
