buffer = class:new()

local server = nil

function buffer:init(Xserver, header, catchTime)
	server 			= Xserver
	self.buffer 	= {}
	self.headerS 	= header.." "
	self.catchTime 	= catchTime
	self.curTime 	= 0
	self.bufferLen	= 0
end

function buffer:push(packetBody, clientID)
	--self.buffer[clientID] = packet
	--bad stuff happens since it gets called every time
	self.bufferLen = self.bufferLen + 1
	self.buffer[self.bufferLen] = {packet = packetBody, id = clientID}
	
	
	--table.insert(self.buffer,{packet = packetBody, id = clientID})
end

function buffer:flush()
	local bufferLen = self.bufferLen
	
	-- loop through each entry in the buffer
	for i = 1, bufferLen do
	
		-- prepare the needed packets which this current id is missing
		local toSend = {}
		local toSendLen = 0
		local currID = self.buffer[i].id
		
		-- determine the needed packets by testing each id for equality, then add the missing packets to current id
		for y = 1, bufferLen do
			local this = self.buffer[y]
			if currID ~= this.id then
				toSendLen = toSendLen + 1
				toSend[toSendLen] = this.packet
			end
		end
		
		-- self.headerS = self.header.." " to fit packet standard
		local combined = self.headerS
		
		-- combine the needed packets into one
		for i = 1, toSendLen do
			combined = combined..toSend[i].."|" -- unique character to seperate individual packets
		end
		--print(string.format("\n\nTO:%s DATA:%s LEN:%d\n\n",v.id,combined,string.len(combined)))
		-- don't send if packet has no information
		if combined ~= self.headerS then
			server:send(combined,currID)
		end
	end	
	
	-- clear the buffer
	self.buffer = {}
	self.bufferLen = 0
end

function buffer:update(dt)
	self.curTime = self.curTime + dt
	if self.curTime > self.catchTime then
		self:flush()
		self.curTime = 0--self.curTime - self.catchTime
	end
end

function buffer:draw()

end