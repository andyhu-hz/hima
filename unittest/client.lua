package.path = "../3rd/skynet/lualib/?.lua;" .. package.path
package.cpath = "../3rd/skynet/luaclib/?.so;" .. package.cpath
package.path = "../src/?.lua;" .. package.path

local socket = require "clientsocket"
local crypt = require "crypt"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

--package & unpackage binary package
local function pack_binary(text) 
	 return string.pack(">s2", text) 
end

local function unpack_binary(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end
	return text:sub(3, 2+s), text:sub(3+s)
end

--package & unpackage text package
local function pack_text(text) 
	return text .. "\n" 
end

local function unpack_text(text)
	local from = text:find("\n", 1, true)
	if from then
		return text:sub(1, from-1), text:sub(from+1)
	end
	return nil, text
end

--send and receive package function
local function send_package(fd, pack_func, text)
	socket.send(fd, pack_func(text))
end

local function recv_package(fd, unpack_func)
	local last = ""
	
	local function try_recv(fd, last)
		local result
		result, last = unpack_func(last)
		if result then
			return result, last
		end
		local r = socket.recv(fd)
		if not r then
			return nil, last
		end
		if r == "" then
			error "Server closed"
		end
		return unpack_func(last .. r)
	end

	while true do
		local result
		result, last = try_recv(fd, last)
		if result then
			return result
		end
		socket.usleep(100)
	end
end

--connect to oauth server 127.0.0.1:5000
local fd = assert(socket.connect("127.0.0.1", 5000))
local phone = "15988189905"
send_package(fd, pack_binary, phone)

local vcode = recv_package(fd, unpack_binary)
print("phone=" .. phone .. ", vcode=" .. vcode)
socket.close(fd)

--connect to login server 127.0.0.1:6000
--[[
Protocol:
	line (\n) based text protocol

	1. Server->Client : base64(8bytes random challenge)
	2. Client->Server : base64(8bytes handshake client key)
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : base64(DH-Exchange(server key))
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : base64(HMAC(challenge, secret))
	7. Client->Server : DES(secret, base64(token))
	8. Server : call auth_handler(token) -> server, uid (A user defined method)
	9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	10. Server->Client : 200 base64(subid)

Error Code:
	400 Bad Request . challenge failed
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 base64(subid)
]]

local fd = assert(socket.connect("127.0.0.1", 6000))

local challenge = crypt.base64decode(recv_package(fd, unpack_text))

local clientkey = crypt.randomkey()
send_package(fd, pack_text, crypt.base64encode(crypt.dhexchange(clientkey)))
local secret = crypt.dhsecret(crypt.base64decode(recv_package(fd, unpack_text)), clientkey)
print("sceret is ", crypt.hexencode(secret))

local hmac = crypt.hmac64(challenge, secret)
send_package(fd, pack_text, crypt.base64encode(hmac))

local token = {
	user = phone,
	server = "hima",
	pass = vcode,
}

local function encode_token(token)
	return string.format("%s@%s:%s",
		crypt.base64encode(token.user),
		crypt.base64encode(token.server),
		crypt.base64encode(token.pass))
end

local etoken = crypt.desencode(secret, encode_token(token))
local b = crypt.base64encode(etoken)
send_package(fd, pack_text, crypt.base64encode(etoken))

local result = recv_package(fd, unpack_text)
print(result)

local code = tonumber(string.sub(result, 1, 3))
assert(code == 200)
socket.close(fd)

local subid = crypt.base64decode(string.sub(result, 5))

print("login ok, subid=", subid)
os.exit()

----- connect to game server

local function send_request(v, session)
	local size = #v + 4
	local package = string.pack(">I2", size)..v..string.pack(">I4", session)
	socket.send(fd, package)
	return v, session
end

local function recv_response(v)
	local size = #v - 5
	local content, ok, session = string.unpack("c"..tostring(size).."B>I4", v)
	return ok ~=0 , content, session
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local readpackage = unpack_f(unpack_package)

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end

local text = "echo"
local index = 1

print("connect")
fd = assert(socket.connect("127.0.0.1", 8888))
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)


send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print(readpackage())
print("===>",send_request(text,0))
-- don't recv response
-- print("<===",recv_response(readpackage()))

print("disconnect")
socket.close(fd)

index = index + 1

print("connect again")
fd = assert(socket.connect("127.0.0.1", 8888))
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print(readpackage())
print("===>",send_request("fake",0))	-- request again (use last session 0, so the request message is fake)
print("===>",send_request("again",1))	-- request again (use new session)
print("<===",recv_response(readpackage()))
print("<===",recv_response(readpackage()))


print("disconnect")
socket.close(fd)

