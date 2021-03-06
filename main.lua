--libs
require("libs/SECS")
vec	= require 'libs/hump/vector'

require("serverUdp")
require("libs/utils")
require("buffer")

--[[
Packets
ID_0 = Player Join Notif/Player list update
ID_1 = Movement
ID_2 = Information
]]
function love.run()
    math.randomseed(os.time())
    math.random() math.random()

    if love.load then love.load(arg) end

    local dt = 0

    -- Main loop time.
    while true do
        -- Process events.
        if love.event then
            love.event.pump()
            for e,a,b,c,d in love.event.poll() do
                if e == "quit" then
                    if not love.quit or not love.quit() then
                        if love.audio then
                            love.audio.stop()
                        end
                        return
                    end
                end
                love.handlers[e](a,b,c,d)
            end
        end

        -- Update dt, as we'll be passing it to update
        if love.timer then
            love.timer.step()
            dt = love.timer.getDelta()
        end

        -- Call update and draw
        if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled
        if love.graphics then
            love.graphics.clear()
            if love.draw then love.draw() end
        end

        if love.timer then love.timer.sleep(0.001) end
        if love.graphics then love.graphics.present() end

    end

end

local moveBuffer

function love.load() 
	--globals
	lg					= love.graphics		
	lt					= love.timer
	screenW				= lg.getWidth()
	screenH				= lg.getHeight()
	screenWc			= screenW*0.5
	screenHc			= screenH*0.5
	
	frameTimeDelta		= 0
	tSinceLastPacket 	= 0

	font =	{	default 		= lg.newFont(18),
				tiny			= lg.newFont(10),
				small 			= lg.newFont(15),
				large 			= lg.newFont(32),
				huge 			= lg.newFont(72)		}
	lg.setFont(font["tiny"])
	charHeight 			= lg.getFont():getHeight()
	logHeight			= math.floor((screenH*0.25)/charHeight)
	
	logAnchor			= charHeight*logHeight + charHeight
	logTitleX			= (screenW-95)*0.5-font["tiny"]:getWidth("Data")*0.5
	
	lg.setBackgroundColor(0,0,0)
	love.mouse.setGrab(false)
	love.mouse.setVisible(true)

	local format = string.format
	function client_data(header, body, clientid)
		server.log("Header: "..header.."  Body: "..body)
		--local header, body = data:match("^(ID_%d)(.+)$")		-- ID_NUM %d = single numeric value
		--local header, body = data:match("^(%S*) (.*)")		-- ID_NUM %d = single numeric value
		if not server.clients[clientid] then 
			print("Received "..header.." from unknown client:", clientid)
			return
		end

		if header == "ID_1" then		
			server.test = server.test + 1
			
			local packet = format("%s %s %s", "ID_1", body, clientid)
			moveBuffer:push(body.." "..clientid,clientid)
		elseif	header == "ID_2" then
			local name = body
			server.clients[clientid].name = name
			
			local packet = format("%s %s %s", "ID_2", body, clientid)
			server:send(packet)
		end
	end
	
	function client_connect(data, clientid)
		server.clients[clientid].joinTime = lt.getTime()
		--local x,y,health = data:match("^(.-):(.-):(.+)$")
		--print("x: "..x.." y: "..y.." health: "..health)
		server.log("Client Connected: "..clientid)
		
		local packet = format("%s %s", server.handshake, clientid)
		server:send(packet, clientid)
		for _clientid, _ in pairs(server.clients) do
			if clientid ~= _clientid then
				-- Notify current clients about new client
				local toUsers 	= format("%s %s", "ID_0", clientid)
				server:send(toUsers,_clientid)

				-- Notify new client about current clients	
				local toUser	= format("%s %s", "ID_0", _clientid)
				server:send(toUser,clientid)
				
				local name = server.clients[_clientid].name
				if name then
					-- Notify new client about current client name		
					local packet = format("%s %s %s", "ID_2", server.clients[_clientid].name, _clientid)
					server:send(packet, clientid)
				end
				
			end
			
		end		
		
	end
	
	function client_disconnect(data,clientid)
		server.log("Client Disconnected: "..clientid)
		local packet = format("%s %s", "ID_0", clientid)
		server:send(packet)
	end
	

    server 				= serverUdp:new("4141")
	
	server._log 		= {}
	
	server.test 		= 0
	server.callbacks 	= {
		recv 			= client_data,
		connect 		= client_connect,
		disconnect 		= client_disconnect
	}
	
	function server.connected()
		local connected = 0
		for clientid, _ in pairs(server.clients) do
			connected = connected + 1
		end	
		return connected
	end 
	
	function server.timestamp()
		local timestamp = string.sub(os.date(),10)			--removes date, keeps time
		local hour = tonumber(string.sub(timestamp,1,2))	--12 hour timestamp
		timestamp = (hour > 12 and hour - 12 or hour)..string.sub(timestamp,3)
		return timestamp
	end
	
	function server.log(text)
		local entry = server:timestamp().." : "..text
		table.insert(server._log,1,entry)	
		--print(entry)
	end
	
	moveBuffer			= buffer:new(server, "ID_1", 0.05)
	server.log("Listening on port "..server.port)
end

function love.update(dt)
	frameTimeDelta					= dt
	local connectionsLastTick		= server:connected()
	
	server:update(dt)
	moveBuffer:update(dt)
	
	local connectionsThisTick		= server:connected()
	if connectionsThisTick ~= connectionsLastTick then
		server.log("Player list sent to "..connectionsThisTick.." clients")
		
		local packet = string.format("%s $", "Players online: "..connectionsThisTick)
		server:send(packet)
		
		--server:send("Players online: "..connectionsThisTick)
	end
	
	tSinceLastPacket				= tSinceLastPacket + dt
	if tSinceLastPacket > 1 then
	
		server.log("Data sent to "..connectionsThisTick.." clients")
		
		if connectionsThisTick > 1 then
			local packet = string.format("%s $", connectionsThisTick)
			server:send(packet)
			
			--server:send(connectionsThisTick)
			
		end
		tSinceLastPacket = 0
		server.test = 0
	end
	
end

function love.draw()
	local charHeight 	= charHeight
	local screenW 		= screenW
	local screenH 		= screenH
	local logAnchor	= logAnchor
	
	lg.print(frameTimeDelta,screenW-90,0)
	lg.print("test: "..tostring(server.test),screenW-90,screenH-charHeight)
	
	lg.rectangle("line",0,0,screenW-95,logAnchor)

	for i = 1,logHeight do
		lg.point(4,logAnchor-i*charHeight)
	end
	
	lg.print("Data",logTitleX,0)
	
	for i,v in ipairs(server._log) do
		lg.print(v,0,logAnchor-i*charHeight)
		if i == logHeight then return end
	end
end

