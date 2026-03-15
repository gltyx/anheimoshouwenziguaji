--[[
SimpleChat.lua - 最简单的联网聊天示例

这个示例展示了如何使用 UrhoX 多人游戏 API：
1. 监听游戏开始事件
2. 使用 lobby:ConnectToGameServer() 安全连接
3. 使用引擎原生 API 发送和接收远程事件

设计原则：最小封装，AI Agent 友好
- 连接：使用 lobby:ConnectToGameServer()（安全，隐藏服务器地址）
- 事件收发：使用引擎原生 API（LLM 已有知识）
]]

-- 可选：使用 NetworkUtils 辅助工具
-- local NetworkUtils = require("urhox-libs.Network.NetworkUtils")

local scene_ = nil
local connected_ = false

function Start()
    -- 创建最小场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    
    -- 注册远程事件（使用引擎原生 API）
    -- 客户端发送给服务器
    network:RegisterRemoteEvent("ChatMessage")
    -- 服务器广播给所有客户端
    network:RegisterRemoteEvent("ChatBroadcast")
    
    -- 订阅事件
    SubscribeToEvent("NotifyGameStartEvent", "OnGameStart")
    SubscribeToEvent("ChatBroadcast", "OnChatReceived")
    SubscribeToEvent("ServerConnected", "OnConnected")
    SubscribeToEvent("ServerDisconnected", "OnDisconnected")
    SubscribeToEvent("ConnectFailed", "OnConnectFailed")
    
    -- 订阅键盘输入用于测试
    SubscribeToEvent("KeyDown", "OnKeyDown")
    
    print("==========================================")
    print("SimpleChat 示例已启动")
    print("==========================================")
    print("等待游戏开始事件 (NotifyGameStartEvent)...")
    print("")
    print("使用步骤:")
    print("1. 确保已通过 lobby API 开始游戏")
    print("2. 收到 NotifyGameStartEvent 后自动连接")
    print("3. 按 1-5 发送测试消息")
    print("==========================================")
end

-- 游戏开始事件处理
function OnGameStart(eventType, eventData)
    local success = eventData["Success"]:GetBool()
    
    if not success then
        local errorCode = eventData["ErrorCode"]:GetInt()
        print(string.format("[错误] 游戏开始失败，错误码: %d", errorCode))
        return
    end
    
    print("[信息] 收到游戏开始通知，正在连接服务器...")
    
    -- 检查是否有服务器信息
    if not lobby:HasGameServerInfo() then
        print("[错误] 没有有效的服务器信息")
        return
    end
    
    -- 使用安全连接 API（不暴露服务器地址）
    local result = lobby:ConnectToGameServer(scene_)
    
    if result then
        print("[信息] 连接请求已发送，等待连接结果...")
    else
        print("[错误] 连接请求发送失败")
    end
end

-- 连接成功
function OnConnected(eventType, eventData)
    connected_ = true
    print("==========================================")
    print("[成功] 已连接到游戏服务器!")
    print("==========================================")
    
    -- 发送一条欢迎消息
    SendChatMessage("大家好，我加入了聊天室！")
end

-- 连接断开
function OnDisconnected(eventType, eventData)
    connected_ = false
    print("[信息] 与服务器断开连接")
end

-- 连接失败
function OnConnectFailed(eventType, eventData)
    print("[错误] 连接服务器失败")
end

-- 发送聊天消息
function SendChatMessage(message)
    if not connected_ then
        print("[警告] 未连接到服务器，无法发送消息")
        return
    end
    
    local connection = network:GetServerConnection()
    if not connection then
        print("[警告] 没有服务器连接")
        return
    end
    
    -- 使用引擎原生 API 构建和发送事件
    local eventData = VariantMap()
    eventData["Message"] = Variant(message)
    eventData["Sender"] = Variant(lobby:GetMyUserId())
    eventData["Timestamp"] = Variant(time:GetElapsedTime())
    
    -- 发送远程事件（可靠传输）
    connection:SendRemoteEvent("ChatMessage", true, eventData)
    
    print(string.format("[我]: %s", message))
end

-- 接收聊天消息
function OnChatReceived(eventType, eventData)
    local sender = eventData["Sender"]:GetInt()
    local message = eventData["Message"]:GetString()
    local timestamp = eventData["Timestamp"]:GetFloat()
    
    -- 不显示自己发的消息（避免重复）
    local myUserId = lobby:GetMyUserId()
    if sender == myUserId then
        return
    end
    
    print(string.format("[玩家 %d]: %s", sender, message))
end

-- 键盘输入处理（测试用）
function OnKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    -- 数字键 1-5 发送预设消息
    if key == KEY_1 then
        SendChatMessage("你好!")
    elseif key == KEY_2 then
        SendChatMessage("准备好了吗?")
    elseif key == KEY_3 then
        SendChatMessage("开始游戏!")
    elseif key == KEY_4 then
        SendChatMessage("再见!")
    elseif key == KEY_5 then
        SendChatMessage("这是一条测试消息 - " .. os.date("%H:%M:%S"))
    end
end

function Stop()
    print("SimpleChat 示例已停止")
    if connected_ then
        network:Disconnect()
    end
end

