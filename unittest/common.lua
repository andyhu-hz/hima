package.path = "../3rd/skynet/lualib/?.lua;" .. package.path
package.cpath = "../3rd/skynet/luaclib/?.so;" .. package.cpath
package.path = "../src/?.lua;" .. package.path

local socket = require "clientsocket"

local function writeline(fd, text)
	socket.send(fd, text .. "\n")
end

local function unpack_line(text)
	local from = text:find("\n", 1, true)
	if from then
		return text:sub(1, from-1), text:sub(from+1)
	end
	return nil, text
end