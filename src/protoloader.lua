-- module proto as examples/proto.lua
package.path = "../../src/?.lua;" .. package.path

local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local proto = require "protocol"

skynet.start(function()
    sprotoloader.save(proto.c2s, 1)
    sprotoloader.save(proto.s2c, 2)
    --print("package.path = " .. package.path)
    -- don't call skynet.exit() , because sproto.core may unload and the global slot become invalid
end)
