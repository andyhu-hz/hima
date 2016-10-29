local skynet = require "skynet"
require "skynet.manager"	
local gateserver = require "snax.gateserver"
local netpack = require "netpack"
local socketdriver = require "socketdriver"

local loginservice = tonumber(...)

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}
skynet.register ".oauth_master"

local vcode_table = {}
local handler = {}

function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socketdriver.send(fd, package)
end

function handler.connect(fd, ipaddr)
	gateserver.openclient(fd) 
    print("oauth server connect", fd, ipaddr)
end

function handler.disconnect(fd)
	gateserver.closeclient(fd)
    print("oauth server disconnect", fd)
end

function handler.error(fd, msg)
    print("oauth server connection error", fd)
end

function handler.open(source, conf)
    print("oauth server connection open", source)
end

function genr_vcode()
	vcode = ""
	math.randomseed(os.time())
    for i=1,6 do 
		vcode = vcode .. math.random(0, 9)
	end
	return vcode
end

function handler.message(fd, msg, sz)
	local phone = netpack.tostring(msg, sz)
	vcode = genr_vcode()
	
	--send the vcode to the logind 
	vcode_table[phone] = vcode
	
	--send the vcode to the phone via short message
	send_package(fd, vcode)
	--todo
end

function handler.warning(fd, size)
    print("oauth server connection warning", fd)
end

local CMD = {}

function CMD.auth_request(source, phone, vcode)
	if vcode_table[phone] == vcode then
		return true
	else
		return false
	end
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)