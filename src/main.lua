local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local max_client = 100000

skynet.start(function()
    print("Running hima server under skynet directory")
    --skynet.uniqueservice("protoloader")
    local console = skynet.newservice("console")
    skynet.newservice("debug_console",8000)
    --skynet.newservice("simpledb")
	
    local loginserver = skynet.newservice("logind")	
	
	local oauth = skynet.newservice("oauth", loginserver)
	skynet.call(oauth, "lua", "open", {
	    address = "127.0.0.1", -- 监听地址 127.0.0.1
	    port = 5000,    -- 监听端口 5000
	    maxclient = max_client,   -- 最多允许 max_client 个外部连接同时建立
	    nodelay = true,     -- 给外部连接设置  TCP_NODELAY 属性
	})
	
	local gate = skynet.newservice("gated", loginserver)

	skynet.call(gate, "lua", "open" , {
		port = 7000,
		maxclient = max_client,
		servername = "hima",
	})
	
    skynet.exit()
end)
