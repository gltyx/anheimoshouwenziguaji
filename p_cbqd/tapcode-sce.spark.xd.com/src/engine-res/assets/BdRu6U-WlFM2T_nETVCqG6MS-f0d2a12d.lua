-- Lobby API Test Suite
-- 测试大厅Lua API的功能
-- 包含: 用户信息、房间操作、游戏开始、匹配等功能测试

-- ============================================================================
-- 全局状态
-- ============================================================================
local testResults = {}
local currentRoomId = nil
local statusText = nil
local logText = nil
local logLines = {}
local MAX_LOG_LINES = 20
local gameScene = nil  -- 用于网络连接的 Scene

-- ============================================================================
-- 辅助函数
-- ============================================================================

local function Log(message, color)
    color = color or "white"
    local timestamp = os.date("%H:%M:%S")
    local line = string.format("[%s] %s", timestamp, message)
    print(line)
    
    -- 添加到日志显示
    table.insert(logLines, { text = line, color = color })
    if #logLines > MAX_LOG_LINES then
        table.remove(logLines, 1)
    end
    
    -- 更新日志显示
    if logText then
        local displayText = ""
        for i, l in ipairs(logLines) do
            displayText = displayText .. l.text .. "\n"
        end
        logText.text = displayText
    end
end

local function LogSuccess(message)
    Log("✓ " .. message, "green")
end

local function LogError(message)
    Log("✗ " .. message, "red")
end

local function LogInfo(message)
    Log("→ " .. message, "yellow")
end

local function UpdateStatus(text)
    if statusText then
        statusText.text = "状态: " .. text
    end
end

local function CheckLobby()
    if not lobby then
        LogError("lobby 全局对象不存在!")
        return false
    end
    return true
end

-- ============================================================================
-- 测试函数
-- ============================================================================

-- 测试1: 检查lobby对象是否存在
local function TestLobbyExists()
    LogInfo("测试: 检查lobby对象...")
    if lobby then
        LogSuccess("lobby 对象存在")
        return true
    else
        LogError("lobby 对象不存在")
        return false
    end
end

-- 测试2: 获取用户ID
local function TestGetMyUserId()
    if not CheckLobby() then return false end
    
    LogInfo("测试: GetMyUserId()")
    local userId = lobby:GetMyUserId()
    if userId then
        LogSuccess("用户ID: " .. tostring(userId))
        return true
    else
        LogError("获取用户ID失败")
        return false
    end
end

-- 测试3: 检查在线状态
local function TestIsOnline()
    if not CheckLobby() then return false end
    
    LogInfo("测试: IsOnline()")
    local online = lobby:IsOnline()
    if online then
        LogSuccess("已连接到服务器")
    else
        LogInfo("未连接到服务器 (这可能是正常的)")
    end
    return true
end

-- 测试4: 检查大厅状态
local function TestIsInLobby()
    if not CheckLobby() then return false end
    
    LogInfo("测试: IsInLobby()")
    local inLobby = lobby:IsInLobby()
    Log("在大厅中: " .. tostring(inLobby))
    return true
end

-- 测试5: 检查游戏状态
local function TestIsInGame()
    if not CheckLobby() then return false end
    
    LogInfo("测试: IsInGame()")
    local inGame = lobby:IsInGame()
    Log("在游戏中: " .. tostring(inGame))
    return true
end

-- 测试6: 检查游客状态
local function TestIsGuestUser()
    if not CheckLobby() then return false end
    
    LogInfo("测试: IsGuestUser()")
    local isGuest = lobby:IsGuestUser()
    Log("是游客: " .. tostring(isGuest))
    return true
end

-- 测试7: 创建房间
local function TestCreateRoom()
    if not CheckLobby() then return false end
    
    LogInfo("测试: CreateRoom()")
    
    -- 使用options table方式
    -- 注意: roomData 必须是 MsgPack 编码的二进制数据，包含 map_name 和 mode_id 字段
    local roomDataTable = {
        map_name = "p_ogma",
        mode_id = "pvp"  -- 注意是 mode_id 不是 mode
    }
    local roomDataPacked = cmsg_pack.pack(roomDataTable)
    LogInfo("roomData (MsgPack): " .. #roomDataPacked .. " bytes")
    
    local requestId = lobby:CreateRoom({
        maxPlayers = 4,
        roomData = roomDataPacked,
        isPrivate = false,
        password = ""
    })
    
    if requestId and requestId > 0 then
        LogSuccess("创建房间请求已发送, requestId: " .. tostring(requestId))
        return true
    else
        LogError("创建房间请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试8: 创建房间(简化调用) - 注意：简化调用不包含 map_name，可能会失败
local function TestCreateRoomSimple()
    if not CheckLobby() then return false end
    
    LogInfo("测试: CreateRoom(4) - 简化调用（可能失败，因为缺少 map_name）")
    
    local requestId = lobby:CreateRoom(4)
    
    if requestId and requestId > 0 then
        LogSuccess("创建房间请求已发送, requestId: " .. tostring(requestId))
        return true
    else
        LogError("创建房间请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试9: 获取房间列表
local function TestGetRoomList()
    if not CheckLobby() then return false end
    
    LogInfo("测试: GetRoomList()")
    
    local requestId = lobby:GetRoomList({
        limit = 10,
        includePrivate = false
    })
    
    if requestId and requestId > 0 then
        LogSuccess("获取房间列表请求已发送, requestId: " .. tostring(requestId))
        return true
    else
        LogError("获取房间列表请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试10: 加入房间
local function TestJoinRoom()
    if not CheckLobby() then return false end
    
    LogInfo("测试: JoinRoom()")
    
    -- 尝试加入一个测试房间ID
    local requestId = lobby:JoinRoom({
        roomId = 12345,
        ownerId = 0
    })
    
    if requestId and requestId > 0 then
        LogSuccess("加入房间请求已发送, requestId: " .. tostring(requestId))
        return true
    else
        LogError("加入房间请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试11: 离开房间
local function TestLeaveRoom()
    if not CheckLobby() then return false end
    
    LogInfo("测试: LeaveRoom()")
    
    local requestId = lobby:LeaveRoom()
    
    if requestId and requestId > 0 then
        LogSuccess("离开房间请求已发送, requestId: " .. tostring(requestId))
        return true
    else
        LogError("离开房间请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试12: 开始游戏 (使用 RequestMatchStart 协议)
local function TestStartGame()
    if not CheckLobby() then return false end
    
    LogInfo("测试: StartGame() - 使用 RequestMatchStart 协议")
    
    -- matchInfo 必须是 JSON 字符串格式！（不是 MsgPack）
    local matchInfoJson = '{"mode":"pvp","immediately_start":true}'
    
    local requestId = lobby:StartGame({
        mapName = "p_ogma",
        matchInfo = matchInfoJson,  -- JSON 字符串
        modeArgs = '{"test":true}',
        regions = {"cn-east"}
    })
    
    if requestId and requestId > 0 then
        LogSuccess("开始游戏请求已发送 (RequestMatchStart), requestId: " .. tostring(requestId))
        return true
    else
        LogError("开始游戏请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试13: 开始游戏(简化调用)
local function TestStartGameSimple()
    if not CheckLobby() then return false end
    
    LogInfo("测试: StartGame('p_ogma') - 简化调用")
    
    local requestId = lobby:StartGame("p_ogma")
    
    if requestId and requestId > 0 then
        LogSuccess("开始游戏请求已发送 (RequestMatchStart), requestId: " .. tostring(requestId))
        return true
    else
        LogError("开始游戏请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试14: 开始匹配
local function TestFindMatch()
    if not CheckLobby() then return false end
    
    LogInfo("测试: FindMatch()")
    
    local requestId = lobby:FindMatch({
        mapName = "MatchMap",
        matchInfo = '{"skill":1000}',
        regions = {"cn-east"}
    })
    
    if requestId and requestId > 0 then
        LogSuccess("开始匹配请求已发送, requestId: " .. tostring(requestId))
        return true
    else
        LogError("开始匹配请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 测试15: 取消匹配
local function TestCancelMatch()
    if not CheckLobby() then return false end
    
    LogInfo("测试: CancelMatch()")
    
    local requestId = lobby:CancelMatch()
    
    if requestId and requestId > 0 then
        LogSuccess("取消匹配请求已发送, requestId: " .. tostring(requestId))
        return true
    else
        LogError("取消匹配请求失败, requestId: " .. tostring(requestId))
        return false
    end
end

-- 运行所有基础测试
local function RunAllBasicTests()
    Log("")
    Log("========================================")
    Log("运行所有基础测试...")
    Log("========================================")
    
    local tests = {
        { name = "lobby对象存在", fn = TestLobbyExists },
        { name = "获取用户ID", fn = TestGetMyUserId },
        { name = "检查在线状态", fn = TestIsOnline },
        { name = "检查大厅状态", fn = TestIsInLobby },
        { name = "检查游戏状态", fn = TestIsInGame },
        { name = "检查游客状态", fn = TestIsGuestUser },
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local success = test.fn()
        testResults[test.name] = success
        if success then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end
    
    Log("========================================")
    Log(string.format("测试完成: %d 通过, %d 失败", passed, failed))
    Log("========================================")
    
    UpdateStatus(string.format("基础测试: %d/%d 通过", passed, passed + failed))
end

-- ============================================================================
-- UI 创建
-- ============================================================================

local function CreateUI()
    local ui = GetUI()
    if not ui then
        print("ERROR: Cannot get UI")
        return
    end
    
    -- 显示鼠标
    local input = GetInput()
    if input then
        input.mouseVisible = true
    end
    
    local root = ui.root
    local cache = GetCache()
    local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")
    if not font then
        font = cache:GetResource("Font", "Fonts/Anonymous Pro.ttf")
    end
    
    local graphics = GetGraphics()
    local screenWidth = graphics.width
    local screenHeight = graphics.height
    
    -- 创建主容器
    local container = root:CreateChild("Window")
    container.name = "LobbyTestContainer"
    container:SetStyleAuto()
    local panelWidth = 900
    local panelHeight = 700
    container:SetSize(panelWidth, panelHeight)
    container:SetPosition((screenWidth - panelWidth) / 2, (screenHeight - panelHeight) / 2)
    container.opacity = 0.95
    container:SetMovable(true)
    container:SetColor(Color(0.12, 0.12, 0.15, 1.0))
    
    -- 标题
    local title = container:CreateChild("Text")
    title:SetFont(font, 22)
    title.text = "🎮 Lobby API 测试套件"
    title:SetPosition(30, 15)
    title:SetColor(Color(0.3, 0.8, 1.0))
    
    -- 状态显示
    statusText = container:CreateChild("Text")
    statusText:SetFont(font, 14)
    statusText.text = "状态: 就绪"
    statusText:SetPosition(30, 50)
    statusText:SetColor(Color(0.8, 0.8, 0.8))
    
    -- 分隔线
    local divider = container:CreateChild("Text")
    divider:SetFont(font, 12)
    divider.text = string.rep("─", 100)
    divider:SetPosition(30, 75)
    divider:SetColor(Color(0.4, 0.4, 0.4))
    
    -- 按钮样式
    local buttonWidth = 180
    local buttonHeight = 32
    local buttonSpacing = 10
    local startX = 30
    local startY = 100
    
    local function CreateButton(text, x, y, onClick)
        local btn = container:CreateChild("Button")
        btn:SetStyleAuto()
        btn:SetSize(buttonWidth, buttonHeight)
        btn:SetPosition(x, y)
        btn:SetColor(Color(0.2, 0.4, 0.6, 1.0))
        
        local btnText = btn:CreateChild("Text")
        btnText:SetFont(font, 12)
        btnText.text = text
        btnText:SetAlignment(HA_CENTER, VA_CENTER)
        btnText:SetColor(Color(1, 1, 1))
        
        SubscribeToEvent(btn, "Released", onClick)
        return btn
    end
    
    -- 第一行: 基础信息测试
    local row1Y = startY
    CreateButton("运行基础测试", startX, row1Y, function() RunAllBasicTests() end)
    CreateButton("获取用户ID", startX + buttonWidth + buttonSpacing, row1Y, function() TestGetMyUserId() end)
    CreateButton("检查在线状态", startX + (buttonWidth + buttonSpacing) * 2, row1Y, function() TestIsOnline() end)
    CreateButton("检查状态", startX + (buttonWidth + buttonSpacing) * 3, row1Y, function() 
        TestIsInLobby()
        TestIsInGame()
    end)
    
    -- 第二行: 房间操作
    local row2Y = startY + buttonHeight + buttonSpacing
    local sectionLabel1 = container:CreateChild("Text")
    sectionLabel1:SetFont(font, 14)
    sectionLabel1.text = "房间操作:"
    sectionLabel1:SetPosition(startX, row2Y + 8)
    sectionLabel1:SetColor(Color(1, 0.8, 0.3))
    
    local row2BtnY = row2Y + 30
    CreateButton("创建房间", startX, row2BtnY, function() TestCreateRoom() end)
    CreateButton("创建房间(简化)", startX + buttonWidth + buttonSpacing, row2BtnY, function() TestCreateRoomSimple() end)
    CreateButton("获取房间列表", startX + (buttonWidth + buttonSpacing) * 2, row2BtnY, function() TestGetRoomList() end)
    CreateButton("离开房间", startX + (buttonWidth + buttonSpacing) * 3, row2BtnY, function() TestLeaveRoom() end)
    
    -- 第三行: 加入房间
    local row3Y = row2BtnY + buttonHeight + buttonSpacing
    CreateButton("加入房间(12345)", startX, row3Y, function() TestJoinRoom() end)
    
    -- 第四行: 游戏操作
    local row4Y = row3Y + buttonHeight + buttonSpacing + 10
    local sectionLabel2 = container:CreateChild("Text")
    sectionLabel2:SetFont(font, 14)
    sectionLabel2.text = "游戏操作:"
    sectionLabel2:SetPosition(startX, row4Y + 8)
    sectionLabel2:SetColor(Color(1, 0.8, 0.3))
    
    local row4BtnY = row4Y + 30
    CreateButton("开始游戏", startX, row4BtnY, function() TestStartGame() end)
    CreateButton("开始游戏(简化)", startX + buttonWidth + buttonSpacing, row4BtnY, function() TestStartGameSimple() end)
    
    -- 第五行: 匹配操作
    local row5Y = row4BtnY + buttonHeight + buttonSpacing + 10
    local sectionLabel3 = container:CreateChild("Text")
    sectionLabel3:SetFont(font, 14)
    sectionLabel3.text = "匹配操作:"
    sectionLabel3:SetPosition(startX, row5Y + 8)
    sectionLabel3:SetColor(Color(1, 0.8, 0.3))
    
    local row5BtnY = row5Y + 30
    CreateButton("开始匹配", startX, row5BtnY, function() TestFindMatch() end)
    CreateButton("取消匹配", startX + buttonWidth + buttonSpacing, row5BtnY, function() TestCancelMatch() end)
    
    -- 日志区域
    local logY = row5BtnY + buttonHeight + buttonSpacing + 20
    local logLabel = container:CreateChild("Text")
    logLabel:SetFont(font, 14)
    logLabel.text = "日志输出:"
    logLabel:SetPosition(startX, logY)
    logLabel:SetColor(Color(0.6, 0.9, 0.6))
    
    -- 日志背景
    local logBg = container:CreateChild("Window")
    logBg:SetStyleAuto()
    logBg:SetSize(panelWidth - 60, 200)
    logBg:SetPosition(startX, logY + 25)
    logBg:SetColor(Color(0.08, 0.08, 0.1, 1.0))
    
    -- 日志文本
    logText = logBg:CreateChild("Text")
    logText:SetFont(font, 11)
    logText.text = ""
    logText:SetPosition(10, 10)
    logText:SetColor(Color(0.8, 0.8, 0.8))
    
    -- 关闭按钮
    local closeBtn = container:CreateChild("Button")
    closeBtn:SetStyleAuto()
    closeBtn:SetSize(80, 28)
    closeBtn:SetPosition(panelWidth - 100, 15)
    closeBtn:SetColor(Color(0.6, 0.2, 0.2, 1.0))
    
    local closeText = closeBtn:CreateChild("Text")
    closeText:SetFont(font, 12)
    closeText.text = "关闭"
    closeText:SetAlignment(HA_CENTER, VA_CENTER)
    closeText:SetColor(Color(1, 1, 1))
    
    SubscribeToEvent(closeBtn, "Released", function()
        engine:Exit()
    end)
end

-- ============================================================================
-- 事件响应处理
-- ============================================================================

-- 响应类型常量（与 C++ LobbyResponseType 对应）
local LobbyResponseType = {
    CREATE_ROOM = 1,
    JOIN_ROOM = 2,
    LEAVE_ROOM = 3,
    START_GAME = 4,
    ROOM_LIST = 5,
}

-- 响应类型名称映射
local ResponseTypeNames = {
    [1] = "CreateRoom",
    [2] = "JoinRoom",
    [3] = "LeaveRoom",
    [4] = "StartGame",
    [5] = "RoomList",
}

-- 处理 Lobby 响应事件
function HandleLobbyResponse(eventType, eventData)
    local respType = eventData["Type"]:GetInt()
    local requestId = eventData["RequestId"]:GetInt()
    local success = eventData["Success"]:GetBool()
    local errorCode = eventData["ErrorCode"]:GetInt()
    local data = eventData["Data"]:GetString()
    
    local typeName = ResponseTypeNames[respType] or ("Unknown(" .. respType .. ")")
    
    if success then
        LogSuccess(string.format("[服务器响应] %s 成功! RequestId: %d, Data: %s", 
            typeName, requestId, data))
        UpdateStatus(typeName .. " 成功!", Color(0, 1, 0))
        
        -- 特殊处理：如果是创建房间成功，保存房间ID
        if respType == LobbyResponseType.CREATE_ROOM and data ~= "" then
            currentRoomId = tonumber(data)
            LogInfo("房间ID已保存: " .. tostring(currentRoomId))
        end
    else
        LogError(string.format("[服务器响应] %s 失败! RequestId: %d, ErrorCode: %d", 
            typeName, requestId, errorCode))
        UpdateStatus(typeName .. " 失败! 错误码: " .. errorCode, Color(1, 0, 0))
    end
end

-- 处理游戏开始通知事件
function HandleNotifyGameStart(eventType, eventData)
    local success = eventData["Success"]:GetBool()
    local errorCode = eventData["ErrorCode"]:GetInt()
    local serverIP = eventData["ServerIP"]:GetString()
    local serverPort = eventData["ServerPort"]:GetInt()  -- KCP/UDP 端口 (Native 客户端)
    local wsPort = eventData["WSPort"]:GetInt()          -- WebSocket 端口 (Web 客户端)
    local authKey = eventData["AuthKey"]:GetString()
    local sessionId = eventData["SessionId"]:GetInt64()
    local mapName = eventData["MapName"]:GetString()
    local middleKey = eventData["MiddleKeyFull"]:GetString()
    local isQuickStart = eventData["IsQuickStart"]:GetBool()
    local useEntrance = eventData["UseEntranceConnection"]:GetBool()
    
    if success then
        LogSuccess(string.format("[游戏开始通知] 服务器: %s, port=%d, ws_port=%d, SessionId: %d", 
            serverIP, serverPort, wsPort, sessionId))
        LogInfo(string.format("  AuthKey: %s, MapName: %s", authKey, mapName))
        
        -- 自动连接游戏服务器
        -- 使用全局 'lobby' 对象和 'gameScene'
        if lobby and gameScene then
            LogInfo("正在连接游戏服务器...")
            UpdateStatus("正在连接: " .. serverIP .. ":" .. tostring(serverPort), Color(1, 1, 0))
            
            -- 使用 lobby:ConnectToGameServer(scene) 自动选择协议和端口
            -- Native: KCP + server_port
            -- Web: WebSocket + ws_port (回退到 server_port)
            local connected = lobby:ConnectToGameServer(gameScene)
            if connected then
                LogInfo("连接请求已发送，等待服务器响应...")
            else
                LogError("发起连接失败! 请检查服务器信息")
                UpdateStatus("连接失败", Color(1, 0, 0))
            end
        else
            if not lobby then
                LogError("lobby 对象不可用")
            end
            if not gameScene then
                LogError("gameScene 未创建")
            end
            UpdateStatus("游戏开始! 服务器: " .. serverIP .. ":" .. tostring(serverPort), Color(0, 1, 0))
        end
    else
        LogError(string.format("[游戏开始通知] 失败! 错误码: %d", errorCode))
        UpdateStatus("游戏开始失败! 错误码: " .. errorCode, Color(1, 0, 0))
    end
end

-- ============================================================================
-- 主入口
-- ============================================================================

function Start()
    print("")
    print("========================================")
    print("  Lobby API 测试套件")
    print("========================================")
    print("")
    
    -- 创建用于网络连接的 Scene
    gameScene = Scene()
    gameScene.name = "GameScene"
    
    -- 创建UI
    CreateUI()
    
    -- 订阅 Lobby 响应事件
    SubscribeToEvent("LobbyResponse", "HandleLobbyResponse")
    
    -- 订阅游戏开始通知事件
    SubscribeToEvent("NotifyGameStartEvent", "HandleNotifyGameStart")
    
    -- 订阅网络事件
    SubscribeToEvent("ServerConnected", "HandleServerConnected")
    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
    SubscribeToEvent("ConnectFailed", "HandleConnectFailed")
    
    -- 初始化日志
    Log("Lobby API 测试套件已启动")
    Log("已订阅 LobbyResponse 和 NotifyGameStartEvent 事件")
    Log("点击按钮开始测试")
    
    -- 自动运行基础测试
    RunAllBasicTests()
end

-- ============================================================================
-- 网络事件处理
-- ============================================================================

function HandleServerConnected(eventType, eventData)
    LogSuccess("[网络] 已连接到游戏服务器!")
    UpdateStatus("已连接到游戏服务器", Color(0, 1, 0))
end

function HandleServerDisconnected(eventType, eventData)
    LogInfo("[网络] 与游戏服务器断开连接")
    UpdateStatus("已断开连接", Color(1, 1, 0))
end

function HandleConnectFailed(eventType, eventData)
    LogError("[网络] 连接游戏服务器失败!")
    UpdateStatus("连接失败", Color(1, 0, 0))
end

