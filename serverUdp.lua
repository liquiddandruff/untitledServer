local socket = require "socket"

serverUdp = class:new()

function serverUdp:init(portNumber)
	self.clients 	= {}
	self.handshake 	= nil
	self.callbacks 	= {
		recv = nil,
		connect = nil,
		disconnect = nil,
	}
	self.ping = {msg = "!", time = 2, max = 5}
	self.port = portNumber

	-- Create the socket, set the port and listen.
	self.socket = socket.udp()
	self.socket:settimeout(0)
	self.socket:setsockname("*", self.port)
	print("Listening on port "..portNumber)	
end

function serverUdp:update(dt)
	local currTime = love.timer.getTime()
	local data, clientid = self:receive()
	while data do
		local client = self.clients[clientid]
		local hsfilter, conn = data:match("^(.+)([%+%-])\n?$")	--should optimize handshake split
		local hs, otherhalf
		
		if hsfilter then 
			--hs,otherhalf = hsfilter:match("^(.-):(.+)$") 		
			hs,otherhalf = hsfilter:match("^(%S*) (.*)$") 
		end
		
		if hs == self.handshake then
			if conn == "+" then
				-- If we already knew the client, ignore.
				if not client then
					client = {counter = 0, ping = 0, t1 = currTime, t2 = currTime}
					if self.callbacks.connect then
						self.callbacks.connect(otherhalf, clientid)
					end
				end
			elseif conn == "-" then
				-- Ignore unknown clients (perhaps they timed out before?).
				if client then
					client = nil
					if self.callbacks.disconnect then
						self.callbacks.disconnect(otherhalf, clientid)
					end
				end	
			end
		elseif data ~= self.ping.msg then
			-- Filter out ping messages and call the recv callback.
			if self.callbacks.recv then
				self.callbacks.recv(data, clientid)
			end
		else
			-- Mark as ping received, -dt because dt is added after, which means a net result of 0.
			if client and client.t1 then
				client.t2 = currTime
				client.ping = 100 * (client.t2 - client.t1)
				print(clientid,tostring(client.ping).." MS")
				client.t1 = nil
			end
		end
		data, clientid = self:receive()
	end
	if self.ping then
		-- Calculate each client's ping. If it exceeds the limit we set, disconnect the client.
		for id, client in pairs(self.clients) do
			client.counter = client.counter + dt
			if client.counter > self.ping.time then
				self:send(self.ping.msg..tostring(math.round(client.ping)), id)
				client.t1 = currTime
				client.counter = 0
			end
			print(currTime - client.t2)
			if (currTime - client.t2) > self.ping.max then
				print("kicked")
				if self.callbacks.disconnect then
					self.callbacks.disconnect("",id)
				end
				self.clients[id] = nil
			end	
		end
	end
end

function serverUdp:send(data, clientid)		-- do send(data,from,to) to prevent returning data to sender
	-- We conviently use ip:port as clientid.
	if clientid then
		local ip, port = clientid:match("^(.-):(%d+)$")
		self.socket:sendto(data, ip, tonumber(port))
	else
		for clientid, _ in pairs(self.clients) do
			local ip, port = clientid:match("^(.-):(%d+)$")
			self.socket:sendto(data, ip, tonumber(port))
			print(data.." sent to "..clientid)
		end
	end
end

function serverUdp:receive()
	local data, ip, port = self.socket:receivefrom()
	if data then
		local id = ip .. ":" .. port
		return data, id
	end
	return nil, "No message."
end
