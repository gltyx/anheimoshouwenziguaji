-- TransportTest.lua
-- Test script for multi-protocol network support
-- This demonstrates how to use different transport protocols via the standard Network API

require "LuaScripts/Utilities/Sample"

-- Global variables
local isServer = false
local currentProtocol = TRANSPORT_SLIKENET
local messageLog = {}

-- UI elements
local mainWindow = nil
local logText = nil
local statusText = nil
local hostInput = nil
local portInput = nil

function Start()
    -- Setup the sample defaults
    SampleStart()

    -- Enable mouse cursor
    input.mouseVisible = true

    -- Create UI
    CreateUI()

    -- Print usage to console
    PrintUsage()

    -- Subscribe to events
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("ServerConnected", "HandleServerConnected")
    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
    SubscribeToEvent("ConnectFailed", "HandleConnectFailed")
    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent("NetworkMessage", "HandleNetworkMessage")
end

function CreateUI()
    local uiStyle = cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
    ui.root.defaultStyle = uiStyle

    -- Create main window
    mainWindow = ui.root:CreateChild("Window")
    mainWindow:SetStyleAuto()
    mainWindow:SetMinSize(700, 500)
    mainWindow:SetLayout(LM_VERTICAL, 6, IntRect(6, 6, 6, 6))
    mainWindow:SetAlignment(HA_CENTER, VA_CENTER)
    mainWindow:SetName("MainWindow")

    -- Title bar
    CreateTitleBar()

    -- Status section
    CreateStatusSection()

    -- Server controls section
    CreateServerSection()

    -- Client controls section
    CreateClientSection()

    -- Message controls section
    CreateMessageSection()

    -- Log section
    CreateLogSection()

    -- Initial status
    UpdateStatus()
    AddLogMessage("Transport Test Ready")
    AddLogMessage("Select a protocol and start server or connect as client")
end

function CreateTitleBar()
    local titleBar = mainWindow:CreateChild("UIElement")
    titleBar:SetMinSize(0, 30)
    titleBar:SetLayoutMode(LM_HORIZONTAL)
    titleBar.layoutSpacing = 10

    local windowTitle = titleBar:CreateChild("Text")
    windowTitle:SetText("Multi-Protocol Network Test")
    windowTitle:SetStyleAuto()
    windowTitle:SetFontSize(16)

    -- Close button
    local closeButton = titleBar:CreateChild("Button")
    closeButton:SetStyle("CloseButton")
    closeButton:SetAlignment(HA_RIGHT, VA_CENTER)
    SubscribeToEvent(closeButton, "Released", function()
        network:Disconnect(100)
        network:StopServer()
        engine:Exit()
    end)
end

function CreateStatusSection()
    local section = mainWindow:CreateChild("UIElement")
    section:SetMinSize(0, 40)
    section:SetLayoutMode(LM_HORIZONTAL)
    section.layoutSpacing = 20

    -- Status label
    local label = section:CreateChild("Text")
    label:SetText("Status:")
    label:SetStyleAuto()

    -- Status text
    statusText = section:CreateChild("Text")
    statusText:SetName("StatusText")
    statusText:SetStyleAuto()
    statusText.color = Color(0.0, 1.0, 0.0)
end

function CreateServerSection()
    -- Section container with border
    local sectionBorder = mainWindow:CreateChild("BorderImage")
    sectionBorder:SetStyle("EditorDarkBorder")
    sectionBorder:SetMinSize(0, 100)
    sectionBorder:SetLayout(LM_VERTICAL, 4, IntRect(8, 8, 8, 8))

    -- Section title
    local title = sectionBorder:CreateChild("Text")
    title:SetText("Server Controls")
    title:SetStyleAuto()
    title:SetFontSize(14)

    -- Protocol buttons row
    local protocolRow = sectionBorder:CreateChild("UIElement")
    protocolRow:SetMinSize(0, 30)
    protocolRow:SetLayoutMode(LM_HORIZONTAL)
    protocolRow.layoutSpacing = 10

    local protocolLabel = protocolRow:CreateChild("Text")
    protocolLabel:SetText("Start Server:")
    protocolLabel:SetStyleAuto()

    -- UDP Server button
    local udpButton = CreateStyledButton(protocolRow, "UDP (12345)", 120)
    SubscribeToEvent(udpButton, "Released", function()
        StartServer(TRANSPORT_SLIKENET, 12345)
    end)

    -- WebSocket Server button
    local wsButton = CreateStyledButton(protocolRow, "WebSocket (8080)", 140)
    SubscribeToEvent(wsButton, "Released", function()
        StartServer(TRANSPORT_WEBSOCKET, 8080)
    end)

    -- KCP Server button
    local kcpButton = CreateStyledButton(protocolRow, "KCP (9999)", 120)
    SubscribeToEvent(kcpButton, "Released", function()
        StartServer(TRANSPORT_KCP, 9999)
    end)

    -- Stop server button
    local stopRow = sectionBorder:CreateChild("UIElement")
    stopRow:SetMinSize(0, 30)
    stopRow:SetLayoutMode(LM_HORIZONTAL)
    stopRow.layoutSpacing = 10

    local stopButton = CreateStyledButton(stopRow, "Stop Server", 120)
    stopButton.color = Color(0.8, 0.3, 0.3)
    SubscribeToEvent(stopButton, "Released", function()
        StopServer()
    end)
end

function CreateClientSection()
    -- Section container with border
    local sectionBorder = mainWindow:CreateChild("BorderImage")
    sectionBorder:SetStyle("EditorDarkBorder")
    sectionBorder:SetMinSize(0, 120)
    sectionBorder:SetLayout(LM_VERTICAL, 4, IntRect(8, 8, 8, 8))

    -- Section title
    local title = sectionBorder:CreateChild("Text")
    title:SetText("Client Controls")
    title:SetStyleAuto()
    title:SetFontSize(14)

    -- Host/Port input row
    local inputRow = sectionBorder:CreateChild("UIElement")
    inputRow:SetMinSize(0, 30)
    inputRow:SetLayoutMode(LM_HORIZONTAL)
    inputRow.layoutSpacing = 10

    local hostLabel = inputRow:CreateChild("Text")
    hostLabel:SetText("Host:")
    hostLabel:SetStyleAuto()

    hostInput = inputRow:CreateChild("LineEdit")
    hostInput:SetStyleAuto()
    hostInput:SetMinSize(150, 24)
    hostInput:SetText("127.0.0.1")

    local portLabel = inputRow:CreateChild("Text")
    portLabel:SetText("Port:")
    portLabel:SetStyleAuto()

    portInput = inputRow:CreateChild("LineEdit")
    portInput:SetStyleAuto()
    portInput:SetMinSize(80, 24)
    portInput:SetText("12345")

    -- Connect buttons row
    local connectRow = sectionBorder:CreateChild("UIElement")
    connectRow:SetMinSize(0, 30)
    connectRow:SetLayoutMode(LM_HORIZONTAL)
    connectRow.layoutSpacing = 10

    local connectLabel = connectRow:CreateChild("Text")
    connectLabel:SetText("Connect via:")
    connectLabel:SetStyleAuto()

    -- UDP Connect button
    local udpConnectBtn = CreateStyledButton(connectRow, "UDP", 80)
    SubscribeToEvent(udpConnectBtn, "Released", function()
        ConnectToServerWithProtocol(TRANSPORT_SLIKENET)
    end)

    -- WebSocket Connect button
    local wsConnectBtn = CreateStyledButton(connectRow, "WebSocket", 100)
    SubscribeToEvent(wsConnectBtn, "Released", function()
        ConnectToServerWithProtocol(TRANSPORT_WEBSOCKET)
    end)

    -- KCP Connect button
    local kcpConnectBtn = CreateStyledButton(connectRow, "KCP", 80)
    SubscribeToEvent(kcpConnectBtn, "Released", function()
        ConnectToServerWithProtocol(TRANSPORT_KCP)
    end)

    -- Disconnect button
    local disconnectBtn = CreateStyledButton(connectRow, "Disconnect", 100)
    disconnectBtn.color = Color(0.8, 0.3, 0.3)
    SubscribeToEvent(disconnectBtn, "Released", function()
        Disconnect()
    end)
end

function CreateMessageSection()
    -- Section container with border
    local sectionBorder = mainWindow:CreateChild("BorderImage")
    sectionBorder:SetStyle("EditorDarkBorder")
    sectionBorder:SetMinSize(0, 60)
    sectionBorder:SetLayout(LM_VERTICAL, 4, IntRect(8, 8, 8, 8))

    -- Section title
    local title = sectionBorder:CreateChild("Text")
    title:SetText("Message")
    title:SetStyleAuto()
    title:SetFontSize(14)

    -- Message row
    local msgRow = sectionBorder:CreateChild("UIElement")
    msgRow:SetMinSize(0, 30)
    msgRow:SetLayoutMode(LM_HORIZONTAL)
    msgRow.layoutSpacing = 10

    -- Send button (to first client or server)
    local sendButton = CreateStyledButton(msgRow, "Send to First", 120)
    sendButton.color = Color(0.3, 0.6, 0.8)
    SubscribeToEvent(sendButton, "Released", function()
        SendTestMessage()
    end)

    -- Broadcast button (server only, to all clients)
    local broadcastButton = CreateStyledButton(msgRow, "Broadcast All", 120)
    broadcastButton.color = Color(0.6, 0.3, 0.8)
    SubscribeToEvent(broadcastButton, "Released", function()
        BroadcastTestMessage()
    end)

    -- Clear log button
    local clearButton = CreateStyledButton(msgRow, "Clear Log", 100)
    SubscribeToEvent(clearButton, "Released", function()
        messageLog = {}
        UpdateLogDisplay()
    end)
end

function CreateLogSection()
    -- Log container
    local logContainer = mainWindow:CreateChild("BorderImage")
    logContainer:SetStyle("EditorDarkBorder")
    logContainer:SetMinSize(0, 150)
    logContainer:SetLayout(LM_VERTICAL, 2, IntRect(4, 4, 4, 4))

    -- Log title
    local logTitle = logContainer:CreateChild("Text")
    logTitle:SetText("Log:")
    logTitle:SetStyleAuto()

    -- Scrollable log area
    local scrollView = logContainer:CreateChild("ScrollView")
    scrollView:SetStyleAuto()
    scrollView:SetMinSize(0, 120)

    -- Log text
    logText = scrollView:CreateChild("Text")
    logText:SetName("LogText")
    logText:SetStyleAuto()
    logText:SetWordwrap(true)
    logText:SetMinWidth(650)

    scrollView:SetContentElement(logText)
end

function CreateStyledButton(parent, text, width)
    local button = parent:CreateChild("Button")
    button:SetStyleAuto()
    button:SetMinSize(width, 26)

    local buttonText = button:CreateChild("Text")
    buttonText:SetText(text)
    buttonText:SetStyleAuto()
    buttonText:SetAlignment(HA_CENTER, VA_CENTER)

    return button
end

function UpdateStatus()
    local status = ""
    local statusColor = Color(0.5, 0.5, 0.5)

    if network.serverRunning then
        status = "Server Running (" .. GetProtocolName(currentProtocol) .. ")"
        statusColor = Color(0.0, 1.0, 0.0)
    elseif network.serverConnection then
        status = "Connected to Server (" .. GetProtocolName(currentProtocol) .. ")"
        statusColor = Color(0.0, 0.8, 1.0)
    else
        status = "Idle"
        statusColor = Color(0.7, 0.7, 0.7)
    end

    if statusText then
        statusText:SetText(status)
        statusText.color = statusColor
    end
end

function PrintUsage()
    print("=== Multi-Protocol Network Test ===")
    print("Use the UI buttons to control the network")
    print("Or use keyboard shortcuts:")
    print("1 - Start UDP server on port 12345")
    print("2 - Start WebSocket server on port 8080")
    print("3 - Start KCP server on port 9999")
    print("ESC - Exit")
end

function AddLogMessage(msg)
    table.insert(messageLog, os.date("%H:%M:%S") .. " " .. msg)

    -- Keep only last 30 messages
    while #messageLog > 30 do
        table.remove(messageLog, 1)
    end

    UpdateLogDisplay()
    print(msg)
end

function UpdateLogDisplay()
    if logText then
        logText:SetText(table.concat(messageLog, "\n"))
    end
end

function GetProtocolName(protocol)
    if protocol == TRANSPORT_SLIKENET then
        return "UDP"
    elseif protocol == TRANSPORT_WEBSOCKET then
        return "WebSocket"
    elseif protocol == TRANSPORT_KCP then
        return "KCP"
    else
        return "Unknown"
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_ESCAPE then
        network:Disconnect(100)
        network:StopServer()
        engine:Exit()
        return
    end

    if key == KEY_1 then
        StartServer(TRANSPORT_SLIKENET, 12345)
    elseif key == KEY_2 then
        StartServer(TRANSPORT_WEBSOCKET, 8080)
    elseif key == KEY_3 then
        StartServer(TRANSPORT_KCP, 9999)
    end
end

function StartServer(protocol, port)
    -- Stop any existing server
    if network.serverRunning then
        network:StopServer()
    end

    -- Disconnect if connected as client
    if network.serverConnection then
        network:Disconnect(100)
    end

    -- Check if protocol is supported
    if not TransportIsSupported(protocol) then
        AddLogMessage("ERROR: " .. GetProtocolName(protocol) .. " not supported on this platform")
        return
    end

    currentProtocol = protocol
    local protocolName = GetProtocolName(protocol)

    -- Start server with specified transport
    local success = false
    if protocol == TRANSPORT_SLIKENET then
        -- Use default UDP (SLikeNet)
        success = network:StartServer(port)
    else
        -- Use Transport layer for WebSocket/KCP
        success = network:StartServerWithTransport(port, protocol)
    end

    if success then
        isServer = true
        AddLogMessage("Server started: " .. protocolName .. " on port " .. port)
        -- Note: KCP server uses built-in KCPTransport (not ACGame::KCPNetwork)
        if protocol == TRANSPORT_KCP then
            AddLogMessage("(Using built-in KCPTransport)")
        end
    else
        AddLogMessage("ERROR: Failed to start " .. protocolName .. " server")
    end

    UpdateStatus()
end

function ConnectToServerWithProtocol(protocol)
    local host = "127.0.0.1"
    local port = 12345

    -- Get host from input
    if hostInput and hostInput:GetText() ~= "" then
        host = hostInput:GetText()
    end

    -- Get port from input
    if portInput and portInput:GetText() ~= "" then
        port = tonumber(portInput:GetText()) or 12345
    end

    -- Check if protocol is supported
    if not TransportIsSupported(protocol) then
        AddLogMessage("ERROR: " .. GetProtocolName(protocol) .. " not supported")
        return
    end

    currentProtocol = protocol
    local protocolName = GetProtocolName(protocol)

    -- Connect with specified transport
    local success = false
    if protocol == TRANSPORT_SLIKENET then
        -- Use default UDP (SLikeNet)
        success = network:Connect(host, port, nil)
    else
        -- Use Transport layer for WebSocket/KCP
        success = network:ConnectWithTransport(host, port, nil, protocol)
    end

    if success then
        isServer = false
        AddLogMessage("Connecting to " .. host .. ":" .. port .. " via " .. protocolName .. "...")
    else
        AddLogMessage("ERROR: Failed to connect via " .. protocolName)
    end

    UpdateStatus()
end

-- Keep old function for backward compatibility
function ConnectToServer()
    ConnectToServerWithProtocol(currentProtocol)
end

function SendTestMessage()
    local connection = nil

    if isServer then
        -- Get first client connection
        local clients = network:GetClientConnections()
        if clients and #clients > 0 then
            connection = clients[1]
        else
            AddLogMessage("ERROR: No clients connected")
            return
        end
    else
        -- Get server connection
        connection = network.serverConnection
        if not connection then
            AddLogMessage("ERROR: Not connected to server")
            return
        end
    end

    -- Send a test message (ID_USER_PACKET_ENUM = 134, use a value >= 134 for user messages)
    local MSG_USER_TEST = 200
    local message = VectorBuffer()
    message:WriteString("Hello from Lua! Time: " .. os.time())
    connection:SendMessage(MSG_USER_TEST, true, true, message)

    AddLogMessage("Sent test message")
end

function BroadcastTestMessage()
    if not isServer then
        AddLogMessage("ERROR: Broadcast is only available on server")
        return
    end

    local clients = network:GetClientConnections()
    if not clients or #clients == 0 then
        AddLogMessage("ERROR: No clients connected")
        return
    end

    -- Send to all clients using BroadcastMessage
    local MSG_USER_TEST = 200
    local message = VectorBuffer()
    message:WriteString("Broadcast from server! Time: " .. os.time())

    -- Use network:BroadcastMessage to send to all clients
    network:BroadcastMessage(MSG_USER_TEST, true, true, message)

    AddLogMessage("Broadcast sent to " .. #clients .. " clients")
end

function Disconnect()
    if network.serverConnection then
        network:Disconnect(100)
        AddLogMessage("Disconnecting from server...")
    else
        AddLogMessage("Not connected to server")
    end
    UpdateStatus()
end

function StopServer()
    if network.serverRunning then
        network:StopServer()
        isServer = false
        AddLogMessage("Server stopped")
    else
        AddLogMessage("Server not running")
    end
    UpdateStatus()
end

-- Event handlers
function HandleServerConnected(eventType, eventData)
    AddLogMessage("Connected to server!")
    UpdateStatus()
end

function HandleServerDisconnected(eventType, eventData)
    AddLogMessage("Disconnected from server")
    UpdateStatus()
end

function HandleConnectFailed(eventType, eventData)
    AddLogMessage("ERROR: Connection failed")
    UpdateStatus()
end

function HandleClientConnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    if connection then
        AddLogMessage("Client connected: " .. connection:ToString())
    end
    UpdateStatus()
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    if connection then
        AddLogMessage("Client disconnected: " .. connection:ToString())
    end
    UpdateStatus()
end

function HandleNetworkMessage(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local msgID = eventData["MessageID"]:GetInt()
    local data = eventData["Data"]:GetBuffer()

    -- data is already a VectorBuffer, read directly from it
    local message = data:ReadString()

    AddLogMessage("Received [" .. msgID .. "]: " .. message)
end

function Stop()
    network:Disconnect(100)
    network:StopServer()
end

-- Entry point
Start()
