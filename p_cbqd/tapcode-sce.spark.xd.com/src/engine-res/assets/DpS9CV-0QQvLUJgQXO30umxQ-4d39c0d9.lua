--[[
urhox-libs/Lobby/main.lua - Lobby 入口脚本

当 settings.json 中包含 max_players 字段时，UrhoXRuntime 会自动加载此脚本。
此脚本负责：
1. 显示 Lobby UI（快速匹配、房间浏览、创建房间）
2. 处理匹配/开局流程
3. 连接到游戏服务器
4. 收到服务器准备就绪事件后切换到游戏脚本

使用的事件：
- ServerConnected: 连接游戏服务器成功（但服务器可能还在加载资源）
- ServerProgress: 服务器加载进度（包含 Progress 和 Status 字段）
- ServerReady: 服务器准备就绪（资源加载完成，可以开始游戏）
- ConnectFailed: 连接游戏服务器失败
- RequestSwitchToGameScript: 请求切换到游戏脚本（C++ 处理）
]]

-- iOS calling GetArguments crashes, replace with empty table
if GetPlatform() == "iOS" then
    function GetArguments()
        return {}
    end
end

pcall(require, 'LuaScripts.Utilities.EnginePreview')
local LobbyUI = require("urhox-libs.Lobby.LobbyUI")

-- 全局状态
local isConnecting_ = false
local isServerConnected_ = false
local isBackgroundMatch_ = false  -- 后台匹配模式标志
local isMultiDebugMode_ = false  -- 多开调试模式标志

-- 事件订阅用的 Node 和 ScriptObject（避免全局订阅覆盖）
local eventNode_ = nil
local eventScriptObject_ = nil
local pendingReconnect_ = false

-- 服务器准备就绪处理
local function OnServerReady()
    print("[Lobby] Server is ready!")

    -- 禁用 Lobby UI（停止渲染和事件处理，但保留在内存中）
    LobbyUI.SetEnabled(false)

    -- 如果是后台匹配模式，不需要发送切换事件（已经在启动时发送过了）
    if isBackgroundMatch_ then
        print("[Lobby] Background match mode, skip RequestSwitchToGameScript")
        return
    end

    -- 发送事件请求切换到游戏脚本
    -- C++ UrhoXRuntime 会处理此事件，使用保存的 gameScriptPath_ 切换脚本
    SendEvent("RequestSwitchToGameScript", VariantMap())
end

-- 服务器进度更新处理
local function OnServerProgress(eventType, eventData)
    local progress = eventData["Progress"]:GetFloat()
    local status = eventData["Status"]:GetString()
    local progressPercent = math.floor(progress * 100)

    print(string.format("[Lobby] Server progress: %d%% - %s", progressPercent, status))

    -- 更新 UI 显示服务器加载进度
    LobbyUI.UpdateServerProgress(progress, status)
end

-- 连接成功处理
local function OnServerConnected()
    print("[Lobby] Connected to game server, waiting for server ready...")
    isConnecting_ = false
    isServerConnected_ = true

    -- 切换到服务器进度显示视图
    LobbyUI.SwitchToServerProgressView()

    -- 注意：不在这里切换脚本，等待 ServerReady 事件
    -- 服务器可能还在下载资源，需要等待服务器准备就绪
end

-- 连接失败处理
local function OnConnectFailed()
    print("[Lobby] Failed to connect to game server!")
    isConnecting_ = false
    isServerConnected_ = false

    LobbyUI.ShowError("Failed to connect to game server. Please try again.")
end

-- 连接到服务器
local function ConnectToServer()
    if isConnecting_ then
        print("[Lobby] Already connecting, ignore duplicate callback")
        return
    end

    isConnecting_ = true

    -- 连接到游戏服务器
    local lobbyMgr = LobbyUI.GetLobbyManager()
    if lobbyMgr then
        print("[Lobby] Connecting to game server...")
        local success = lobbyMgr:ConnectToGame()
        if not success then
            print("[Lobby] Failed to initiate connection")
            isConnecting_ = false
            LobbyUI.ShowError("Failed to initiate connection to game server.")
        end
    else
        print("[Lobby] LobbyManager not available!")
        isConnecting_ = false
    end
end

-- 服务器断线处理
local function HandleServerDisconnected()
    print("[Lobby] Server disconnected!")
    isServerConnected_ = false
    isConnecting_ = false

    -- 主动返回大厅时不重连（ReturnToLobby 触发的断线是预期行为）
    if LobbyUI.isReturningToLobby_ then
        print("[Lobby] Disconnected due to ReturnToLobby, skip reconnect")
        LobbyUI.isReturningToLobby_ = false
        return
    end

    -- 显示断线提示
    LobbyUI.ShowError("Disconnected from server. Reconnecting...")

    -- 标记需要重连，下一帧在 Update 中执行
    pendingReconnect_ = true
end

-- 游戏开始回调（收到服务器信息后触发）
local function OnGameStart(serverInfo)
    print(string.format("[Lobby] Game start! Server: %s:%d", serverInfo.ip, serverInfo.port))

    ConnectToServer()
end

-- 启动多开调试模式
local function tryStartMultiDebugMode()
    local lobbyMgr = LobbyUI.GetLobbyManager()
    local multiDebugNum = lobbyMgr:GetMultiDebugNum()
    if multiDebugNum <= 0 then
        return false
    end

    print(string.format("[Lobby] Multi-debug mode detected! playerCount=%d", multiDebugNum))
    isMultiDebugMode_ = true

    -- 隐藏 UI
    LobbyUI.SetEnabled(false)

    -- 清空 LobbyUI 设置的 onMatchFound 回调（多开调试不是匹配模式）
    lobbyMgr:OnMatchFound(nil)

    -- 设置游戏开始回调，收到 NotifyGameStart 时连接游戏
    lobbyMgr:OnGameStarted(function(serverInfo)
        print("[Lobby] Multi-debug: NotifyGameStart received, connecting to game...")
        ConnectToServer()
    end)

    -- 使用 project_id 作为 mapName
    local mapName = lobbyMgr:GetProjectId()
    if not mapName or mapName == "" then
        mapName = "DefaultMap"
    end

    print(string.format("[Lobby] Multi-debug: creating game with mapName=%s, playerCount=%d", mapName, multiDebugNum))

    -- 创建多开调试游戏（会自动通知 JS 打开调试窗口）
    lobbyMgr:CreateMultiDebugGame({
        mapName = mapName,
        playerCount = multiDebugNum,
        tag = "test",
        onSuccess = function(debugConnectInfo)
            print("[Lobby] Multi-debug: game created, debug clients can connect")
        end,
        onError = function(errorCode)
            print("[Lobby] Multi-debug: create game failed with error: " .. tostring(errorCode))
        end
    })

    -- 不立即切换脚本，等 NotifyGameStart → ConnectToServer() → ServerReady 后再切换
    print("[Lobby] Multi-debug mode started, waiting for NotifyGameStart...")
    return true
end

function Start()
    print("==============================================")
    print("  Lobby Main Script")
    print("==============================================")

    -- 初始化协议解析模块（用于在 Lua 端解析 protobuf 协议）
    -- local LobbyProto = require("urhox-libs.Lobby.LobbyProto")
    -- LobbyProto.Init()
    -- LobbyProto.RegisterHandler(0x3040, function(messageId, msg)
    --     -- 处理 ResponseUserCurrentStatus
    -- end)

    -- 注册远端事件（允许从服务器接收事件）
    local network = GetNetwork()
    if network then
        network:RegisterRemoteEvent("ServerProgress")
        network:RegisterRemoteEvent("ServerReady")
        network:RegisterRemoteEvent("IdentityUpdated")
        print("[Lobby] Registered remote events: ServerProgress, ServerReady")
    else
        print("[Lobby] Warning: Network subsystem not available")
    end

    -- 订阅网络连接事件
    SubscribeToEvent("ServerConnected", function()
        -- 发送认证协议
        if not NETWORK_AUTO_SEND_IDENTITY then
            local network = GetNetwork()
            if network then
                local serverConnection = network:GetServerConnection()
                if serverConnection then
                    local msg = VectorBuffer()
                    msg:WriteVariantMap(serverConnection:GetIdentity())
                    serverConnection:SendMessage(135, true, true, msg)
                end
            end
        end

        OnServerConnected()
    end)

    SubscribeToEvent("ConnectFailed", function()
        OnConnectFailed()
    end)

    SubscribeToEvent("ServerDisconnected", function()
        HandleServerDisconnected()
    end)

    -- 订阅服务器进度事件（远端事件）
    SubscribeToEvent("ServerProgress", function(eventType, eventData)
        OnServerProgress(eventType, eventData)
    end)

    -- 订阅服务器准备就绪事件（远端事件）
    SubscribeToEvent("ServerReady", function()
        OnServerReady()
    end)

    -- 订阅身份信息更新事件（服务端发送，同步 nick_name 到客户端 identity）
    SubscribeToEvent("IdentityUpdated", function(eventType, eventData)
        local network = GetNetwork()
        if network then
            local serverConnection = network:GetServerConnection()
            if serverConnection then
                local identity = serverConnection:GetIdentity()
                local nickName = eventData:GetString("nick_name") or ""
                identity:SetString("nick_name", nickName)
                print(string.format("[Lobby] Identity updated from server: nick_name=%s", nickName))
            end
        end
    end)

    -- 读取 settings.json 获取配置
    local matchInfo = nil
    local backgroundMatch = false
    local cache = GetCache()
    if cache then
        local file = cache:GetFile("settings.json")
        if file then
            local content = file:ReadString()
            file:Close()

            if content and content ~= "" then
                local success, settings = pcall(cjson.decode, content)
                if success and settings then
                    local multiplayer = settings.multiplayer
                    if multiplayer then
                        print("[Lobby] multiplayer config: " .. cjson.encode(multiplayer))
                        matchInfo = multiplayer.match_info
                        backgroundMatch = multiplayer.background_match == true
                    end
                else
                    print("[Lobby] Failed to parse settings.json")
                end
            end
        else
            print("[Lobby] settings.json not found")
        end
    end

    -- 显示 Lobby UI
    LobbyUI.Show({
        debugMode = true,
        theme = "dark",

        -- 功能开关
        allowCreateRoom = true,
        allowQuickMatch = true,
        allowBrowseRooms = true,

        -- 匹配配置（从 settings.json 读取）
        matchInfo = matchInfo,
        backgroundMatch = backgroundMatch,

        -- 游戏开始回调
        onGameStart = OnGameStart
    })

    print("[Lobby] Lobby UI initialized")

    -- 创建事件订阅用的 ScriptObject（避免全局订阅覆盖）
    eventNode_ = Node()
    eventScriptObject_ = eventNode_:CreateScriptObject("LuaScriptObject")
    eventScriptObject_:SubscribeToEvent("Update", function(self, eventType, eventData)
        if pendingReconnect_ then
            pendingReconnect_ = false
            ConnectToServer()
        end
    end)

    -- 后台匹配模式
    if backgroundMatch then
        print("[Lobby] Background match mode enabled!")
        isBackgroundMatch_ = true

        -- 立即开始匹配
        LobbyUI.StartQuickMatch()

        -- 禁用 UI（后台匹配，不显示界面）
        LobbyUI.SetEnabled(false)

        -- 立即切换到游戏脚本（游戏先运行，匹配在后台进行）
        SendEvent("RequestSwitchToGameScript", VariantMap())

        print("[Lobby] Background match started, switched to game script")
    end

    -- 多开调试模式（?multiDebugNum=N）
    tryStartMultiDebugMode()
end

function Stop()
    print("[Lobby] Stopping...")

    -- 清理事件订阅 Node
    if eventNode_ then
        eventNode_:Remove()
        eventNode_ = nil
        eventScriptObject_ = nil
    end

    -- 隐藏 UI
    LobbyUI.Hide()
end
