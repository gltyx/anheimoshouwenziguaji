--[[
TestConnectAPI.lua - 测试 lobby:ConnectToGameServer() API

这个脚本用于测试新添加的多人游戏客户端 API：
1. lobby:HasGameServerInfo()
2. lobby:ConnectToGameServer(scene)

使用方法：
1. 运行游戏并加载此脚本
2. 使用 lobby API 创建/加入房间并开始游戏
3. 收到 NotifyGameStartEvent 后，测试 ConnectToGameServer
]]

local scene_ = nil
local testsPassed = 0
local testsFailed = 0

-- 打印测试结果
local function TestResult(name, passed, message)
    if passed then
        testsPassed = testsPassed + 1
        print(string.format("[PASS] %s", name))
    else
        testsFailed = testsFailed + 1
        print(string.format("[FAIL] %s - %s", name, message or ""))
    end
end

-- 测试 lobby 对象是否存在
local function TestLobbyExists()
    local exists = (lobby ~= nil)
    TestResult("lobby 对象存在", exists, "lobby is nil")
    return exists
end

-- 测试 HasGameServerInfo 方法
local function TestHasGameServerInfo()
    if not lobby then
        TestResult("HasGameServerInfo 方法", false, "lobby is nil")
        return false
    end
    
    -- 在没有 NotifyGameStartEvent 之前，应该返回 false
    local hasInfo = lobby:HasGameServerInfo()
    local methodExists = (hasInfo ~= nil)
    TestResult("HasGameServerInfo 方法存在", methodExists, "method returned nil")
    
    -- 初始状态应该没有服务器信息
    if methodExists then
        TestResult("初始状态无服务器信息", hasInfo == false, 
            "expected false, got " .. tostring(hasInfo))
    end
    
    return methodExists
end

-- 测试 ConnectToGameServer 方法（无服务器信息时应失败）
local function TestConnectWithoutServerInfo()
    if not lobby then
        TestResult("ConnectToGameServer (无信息)", false, "lobby is nil")
        return false
    end
    
    -- 创建测试场景
    local testScene = Scene()
    testScene:CreateComponent("Octree")
    
    -- 没有服务器信息时应该返回 false
    local result = lobby:ConnectToGameServer(testScene)
    TestResult("ConnectToGameServer (无服务器信息)", result == false, 
        "expected false, got " .. tostring(result))
    
    -- 清理
    testScene:Remove()
    
    return true
end

-- 测试 GetMyUserId 方法
local function TestGetMyUserId()
    if not lobby then
        TestResult("GetMyUserId 方法", false, "lobby is nil")
        return false
    end
    
    local userId = lobby:GetMyUserId()
    local valid = (userId ~= nil and type(userId) == "number")
    TestResult("GetMyUserId 返回有效数值", valid, 
        "got " .. type(userId) .. ": " .. tostring(userId))
    
    return valid
end

-- 运行所有基础测试
local function RunBasicTests()
    print("==========================================")
    print("开始测试 Multiplayer Client API")
    print("==========================================")
    print("")
    
    TestLobbyExists()
    TestHasGameServerInfo()
    TestConnectWithoutServerInfo()
    TestGetMyUserId()
    
    print("")
    print("==========================================")
    print(string.format("测试完成: %d 通过, %d 失败", testsPassed, testsFailed))
    print("==========================================")
    
    if testsFailed > 0 then
        print("[警告] 有测试失败，请检查 API 实现")
    else
        print("[成功] 所有基础测试通过!")
    end
end

-- 收到 NotifyGameStartEvent 后的测试
local function TestConnectWithServerInfo()
    print("")
    print("==========================================")
    print("测试 ConnectToGameServer (有服务器信息)")
    print("==========================================")
    
    -- 检查是否有服务器信息
    local hasInfo = lobby:HasGameServerInfo()
    TestResult("HasGameServerInfo 返回 true", hasInfo == true,
        "expected true after NotifyGameStartEvent")
    
    if not hasInfo then
        print("[跳过] 无法测试连接，没有服务器信息")
        return
    end
    
    -- 尝试连接
    print("[信息] 尝试连接到游戏服务器...")
    local result = lobby:ConnectToGameServer(scene_)
    TestResult("ConnectToGameServer 返回 true", result == true,
        "expected true, got " .. tostring(result))
    
    print("")
    print(string.format("连接测试完成: %d 通过, %d 失败", testsPassed, testsFailed))
end

function Start()
    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    
    -- 订阅事件
    SubscribeToEvent("NotifyGameStartEvent", "OnNotifyGameStart")
    SubscribeToEvent("ServerConnected", "OnServerConnected")
    SubscribeToEvent("ServerDisconnected", "OnServerDisconnected")
    SubscribeToEvent("ConnectFailed", "OnConnectFailed")
    SubscribeToEvent("KeyDown", "OnKeyDown")
    
    -- 运行基础测试
    RunBasicTests()
    
    print("")
    print("==========================================")
    print("交互测试说明")
    print("==========================================")
    print("按 T: 重新运行基础测试")
    print("按 C: 测试 ConnectToGameServer (需要先有 NotifyGameStartEvent)")
    print("按 I: 显示当前状态信息")
    print("==========================================")
end

function OnNotifyGameStart(eventType, eventData)
    local success = eventData["Success"]:GetBool()
    
    print("")
    print("==========================================")
    print("收到 NotifyGameStartEvent")
    print("==========================================")
    print(string.format("Success: %s", tostring(success)))
    
    if success then
        local serverIP = eventData["ServerIP"]:GetString()
        local serverPort = eventData["ServerPort"]:GetInt()
        print(string.format("ServerIP: %s (已隐藏完整地址)", string.sub(serverIP, 1, 4) .. "..."))
        print(string.format("ServerPort: %d", serverPort))
        
        -- 自动运行连接测试
        TestConnectWithServerInfo()
    else
        local errorCode = eventData["ErrorCode"]:GetInt()
        print(string.format("ErrorCode: %d", errorCode))
    end
end

function OnServerConnected(eventType, eventData)
    print("")
    print("==========================================")
    print("[成功] 已连接到游戏服务器!")
    print("==========================================")
    testsPassed = testsPassed + 1
end

function OnServerDisconnected(eventType, eventData)
    print("[信息] 与服务器断开连接")
end

function OnConnectFailed(eventType, eventData)
    print("[错误] 连接服务器失败")
    testsFailed = testsFailed + 1
end

function OnKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    if key == KEY_T then
        -- 重新运行测试
        testsPassed = 0
        testsFailed = 0
        RunBasicTests()
    elseif key == KEY_C then
        -- 测试连接
        TestConnectWithServerInfo()
    elseif key == KEY_I then
        -- 显示状态
        print("")
        print("==========================================")
        print("当前状态信息")
        print("==========================================")
        print(string.format("lobby 存在: %s", tostring(lobby ~= nil)))
        if lobby then
            print(string.format("UserId: %d", lobby:GetMyUserId()))
            print(string.format("HasGameServerInfo: %s", tostring(lobby:HasGameServerInfo())))
            print(string.format("IsOnline: %s", tostring(lobby:IsOnline())))
            print(string.format("IsInLobby: %s", tostring(lobby:IsInLobby())))
            print(string.format("IsInGame: %s", tostring(lobby:IsInGame())))
        end
        local serverConn = network:GetServerConnection()
        print(string.format("ServerConnection: %s", tostring(serverConn ~= nil)))
        print("==========================================")
    end
end

function Stop()
    print("")
    print("==========================================")
    print("测试结束")
    print(string.format("总计: %d 通过, %d 失败", testsPassed, testsFailed))
    print("==========================================")
    
    if network:GetServerConnection() then
        network:Disconnect()
    end
end

