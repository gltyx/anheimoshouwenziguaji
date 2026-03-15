---@diagnostic disable: undefined-global
-- ============================================================================
-- main.lua - 联网 FPS 游戏入口
-- 
-- 根据运行模式加载对应脚本：
-- - 服务器模式：加载 Server.lua
-- - 客户端模式：加载 Client.lua
-- ============================================================================

-- 预声明模块引用
local Module = nil

-- 根据模式加载对应模块
if IsServerMode() then
    Module = require("Server")
else
    Module = require("Client")
end

function Start() 
    -- 调用模块的 Start
    if Module and Module.Start then
        Module.Start()
    end
end

function Stop()
    -- 调用模块的 Stop
    if Module and Module.Stop then
        Module.Stop()
    end
end
