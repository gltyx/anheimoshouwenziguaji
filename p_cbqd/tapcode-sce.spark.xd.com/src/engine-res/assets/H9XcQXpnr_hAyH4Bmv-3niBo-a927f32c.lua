-- Scene network replication example with multiple transport support.
-- This sample demonstrates:
--     - Creating a scene in which network clients can join
--     - Supporting three transport types: RakNet (UDP), WebSocket, and KCP
--     - Giving each client an object to control and sending the controls from the clients to the server,
--       where the authoritative simulation happens
--     - Controlling a physics object's movement by applying forces

require "LuaScripts/Utilities/Sample"

-- UDP port we will use
local SERVER_PORT = 2345

-- Control bits we define
local CTRL_FORWARD = 1
local CTRL_BACK = 2
local CTRL_LEFT = 4
local CTRL_RIGHT = 8

-- Transport protocol options
local TRANSPORT_NAMES = {
    [TRANSPORT_SLIKENET] = "RakNet (UDP)",
    [TRANSPORT_WEBSOCKET] = "WebSocket",
    [TRANSPORT_KCP] = "KCP"
}

---@type Text
local instructionsText = nil
---@type UIElement
local buttonContainer = nil
---@type LineEdit
local textEdit = nil
---@type Button
local connectButton = nil
---@type Button
local disconnectButton = nil
---@type Button
local startServerButton = nil
---@type DropDownList
local transportDropDown = nil
---@type Text
local statusText = nil
local clients = {}
local clientObjectID = 0

-- Current selected transport protocol
local selectedTransport = TRANSPORT_SLIKENET

-- 连接状态跟踪
local isConnecting = false
local isDisconnecting = false

function Start()
    -- Execute the common startup for samples
    SampleStart()

    -- Create the scene content
    CreateScene()

    -- Create the UI content
    CreateUI()

    -- Setup the viewport for displaying the scene
    SetupViewport()

    -- Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_FREE)

    -- Hook up to necessary events
    SubscribeToEvents()
end

function CreateScene()
    scene_ = Scene()

    -- Create octree and physics world with default settings. Create them as local so that they are not needlessly replicated
    -- when a client connects
    scene_:CreateComponent("Octree", LOCAL)
    scene_:CreateComponent("PhysicsWorld", LOCAL)

    -- All static scene content and the camera are also created as local, so that they are unaffected by scene replication and are
    -- not removed from the client upon connection. Create a Zone component first for ambient lighting & fog control.
    local zoneNode = scene_:CreateChild("Zone", LOCAL)
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.1, 0.1, 0.1)
    zone.fogStart = 100.0
    zone.fogEnd = 300.0

    -- Create a directional light without shadows
    local lightNode = scene_:CreateChild("DirectionalLight", LOCAL)
    lightNode.direction = Vector3(0.5, -1.0, 0.5)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(0.2, 0.2, 0.2)
    light.specularIntensity = 1.0

    -- Create a "floor" consisting of several tiles. Make the tiles physical but leave small cracks between them
    for y = -20, 20 do
        for x = -20, 20 do
            local floorNode = scene_:CreateChild("FloorTile", LOCAL)
            floorNode.position = Vector3(x * 20.2, -0.5, y * 20.2)
            floorNode.scale = Vector3(20.0, 1.0, 20.0)
            local floorObject = floorNode:CreateComponent("StaticModel")
            floorObject.model = cache:GetResource("Model", "Models/Box.mdl")
            floorObject.material = cache:GetResource("Material", "Materials/Stone.xml")

            local body = floorNode:CreateComponent("RigidBody")
            body.friction = 1.0
            local shape = floorNode:CreateComponent("CollisionShape")
            shape:SetBox(Vector3(1.0, 1.0, 1.0))
        end
    end

    -- Create the camera. Limit far clip distance to match the fog
    -- The camera needs to be created into a local node so that each client can retain its own camera, that is unaffected by
    -- network messages. Furthermore, because the client removes all replicated scene nodes when connecting to a server scene,
    -- the screen would become blank if the camera node was replicated (as only the locally created camera is assigned to a
    -- viewport in SetupViewports() below)
    cameraNode = scene_:CreateChild("Camera", LOCAL)
    local camera = cameraNode:CreateComponent("Camera")
    camera.farClip = 300.0

    -- Set an initial position for the camera scene node above the plane
    cameraNode.position = Vector3(0.0, 5.0, 0.0)
end

function CreateUI()
    local uiStyle = cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
    -- Set style to the UI root so that elements will inherit it
    ui.root.defaultStyle = uiStyle

    -- Create a Cursor UI element because we want to be able to hide and show it at will. When hidden, the mouse cursor will
    -- control the camera, and when visible, it will point the raycast target
    local cursor = ui.root:CreateChild("Cursor")
    cursor:SetStyleAuto(uiStyle)
    ui.cursor = cursor
    -- Set starting position of the cursor at the rendering window center
    cursor:SetPosition(graphics.width / 2, graphics.height / 2)

    -- Construct the instructions text element
    instructionsText = ui.root:CreateChild("Text")
    instructionsText:SetText("Use WASD keys to move and RMB to rotate view")
    instructionsText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 15)
    -- Position the text relative to the screen center
    instructionsText.horizontalAlignment = HA_CENTER
    instructionsText.verticalAlignment = VA_CENTER
    instructionsText:SetPosition(0, graphics.height / 4)
    -- Hide until connected
    instructionsText.visible = false

    -- Create main button container
    buttonContainer = ui.root:CreateChild("UIElement")
    buttonContainer:SetFixedSize(700, 20)
    buttonContainer:SetPosition(20, 20)
    buttonContainer.layoutMode = LM_HORIZONTAL
    buttonContainer.layoutSpacing = 5

    -- Address text edit
    textEdit = buttonContainer:CreateChild("LineEdit")
    textEdit:SetStyleAuto()
    textEdit:SetFixedWidth(150)

    -- Transport selector dropdown
    transportDropDown = CreateTransportDropDown()

    -- Buttons
    connectButton = CreateButton("Connect", 90)
    disconnectButton = CreateButton("Disconnect", 100)
    startServerButton = CreateButton("Start Server", 110)

    -- Status text
    statusText = ui.root:CreateChild("Text")
    statusText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 12)
    statusText:SetPosition(20, 50)
    statusText:SetColor(Color(0.0, 1.0, 0.0))
    UpdateStatusText()

    UpdateButtons()
end

function CreateTransportDropDown()
    local font = cache:GetResource("Font", "Fonts/Anonymous Pro.ttf")

    local dropDown = buttonContainer:CreateChild("DropDownList")
    dropDown:SetStyleAuto()
    dropDown:SetFixedSize(120, 20)

    -- Add transport options
    local transportOptions = {
        { protocol = TRANSPORT_SLIKENET, name = "RakNet" },
        { protocol = TRANSPORT_WEBSOCKET, name = "WebSocket" },
        { protocol = TRANSPORT_KCP, name = "KCP" }
    }

    for i, option in ipairs(transportOptions) do
        local item = dropDown:CreateChild("Text")
        item:SetStyleAuto()
        item:SetFont(font, 11)
        item:SetText(option.name)
        item.minHeight = 18
        dropDown:AddItem(item)
    end

    dropDown.selection = 0  -- Default to RakNet (UDP)
    selectedTransport = TRANSPORT_SLIKENET

    return dropDown
end

function CreateButton(text, width)
    local font = cache:GetResource("Font", "Fonts/Anonymous Pro.ttf")

    local button = buttonContainer:CreateChild("Button")
    button:SetStyleAuto()
    button:SetFixedWidth(width)
    button.text = text
    button.textElement:SetFont(font, 12)

    return button
end

function GetSelectedTransport()
    local selection = transportDropDown.selection
    if selection == 0 then
        return TRANSPORT_SLIKENET
    elseif selection == 1 then
        return TRANSPORT_WEBSOCKET
    elseif selection == 2 then
        return TRANSPORT_KCP
    end
    return TRANSPORT_SLIKENET
end

function GetTransportName(protocol)
    if TRANSPORT_NAMES[protocol] then
        return TRANSPORT_NAMES[protocol]
    end
    return "Unknown"
end

function UpdateStatusText()
    local status = ""
    local serverConnection = network:GetServerConnection()
    local serverRunning = network.serverRunning

    if isDisconnecting then
        status = "Disconnecting..."
        statusText:SetColor(Color(1.0, 0.5, 0.0)) -- 橙色表示正在断开
    elseif isConnecting then
        status = "Connecting..."
        statusText:SetColor(Color(1.0, 0.8, 0.0)) -- 黄橙色表示正在连接
    elseif serverRunning then
        status = "Server running on port " .. SERVER_PORT .. " via " .. GetTransportName(selectedTransport)
        statusText:SetColor(Color(0.0, 1.0, 0.5))
    elseif serverConnection ~= nil and serverConnection.connected then
        status = "Connected to server via " .. GetTransportName(selectedTransport)
        statusText:SetColor(Color(0.5, 1.0, 0.0))
    else
        status = "Disconnected - Select transport and connect/start server"
        statusText:SetColor(Color(1.0, 1.0, 0.0))
    end

    statusText:SetText(status)
end

function UpdateButtons()
    local serverConnection = network:GetServerConnection()
    local serverRunning = network.serverRunning

    -- Show and hide buttons so that eg. Connect and Disconnect are never shown at the same time
    -- 检查 Connection 是否真正连接（不仅仅是存在）
    local isConnected = serverConnection ~= nil and serverConnection.connected
    local isPending = serverConnection ~= nil and serverConnection.connectPending
    local canConnect = not isConnected and not isPending and not serverRunning and not isConnecting and not isDisconnecting
    
    connectButton.visible = canConnect
    disconnectButton.visible = (isConnected or isPending or serverRunning or isConnecting) and not isDisconnecting
    startServerButton.visible = canConnect
    textEdit.visible = canConnect
    transportDropDown.visible = canConnect
    
    -- 显示正在断开状态
    if isDisconnecting then
        statusText:SetText("Disconnecting...")
        statusText:SetColor(Color(1.0, 0.5, 0.0))  -- 橙色
    end

    UpdateStatusText()
end

function SetupViewport()
    -- Set up a viewport to the Renderer subsystem so that the 3D scene can be seen
    local viewport = Viewport:new(scene_, cameraNode:GetComponent("Camera"))
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    -- Subscribe to fixed timestep physics updates for setting or applying controls
    SubscribeToEvent("PhysicsPreStep", "HandlePhysicsPreStep")

    -- Subscribe HandlePostUpdate() method for processing update events. Subscribe to PostUpdate instead
    -- of the usual Update so that physics simulation has already proceeded for the frame, and can
    -- accurately follow the object with the camera
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")

    -- Subscribe to button actions
    SubscribeToEvent(connectButton, "Released", "HandleConnect")
    SubscribeToEvent(disconnectButton, "Released", "HandleDisconnect")
    SubscribeToEvent(startServerButton, "Released", "HandleStartServer")

    -- Subscribe to network events
    SubscribeToEvent("ServerConnected", "HandleConnectionStatus")
    SubscribeToEvent("ServerDisconnected", "HandleConnectionStatus")
    SubscribeToEvent("ConnectFailed", "HandleConnectionFailed")
    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    -- This is a custom event, sent from the server to the client. It tells the node ID of the object the client should control
    SubscribeToEvent("ClientObjectID", "HandleClientObjectID")
    -- Events sent between client & server (remote events) must be explicitly registered or else they are not allowed to be received
    network:RegisterRemoteEvent("ClientObjectID")
end

function CreateControllableObject()
    -- Create the scene node & visual representation. This will be a replicated object
    local ballNode = scene_:CreateChild("Ball")
    ballNode.position = Vector3(Random(40.0) - 20.0, 5.0, Random(40.0) - 20.0)
    ballNode:SetScale(0.5)
    local ballObject = ballNode:CreateComponent("StaticModel")
    ballObject.model = cache:GetResource("Model", "Models/Sphere.mdl")
    ballObject.material = cache:GetResource("Material", "Materials/StoneSmall.xml")

    -- Create the physics components
    local body = ballNode:CreateComponent("RigidBody")
    body.mass = 1.0
    body.friction = 1.0
    -- In addition to friction, use motion damping so that the ball can not accelerate limitlessly
    body.linearDamping = 0.5
    body.angularDamping = 0.5
    local shape = ballNode:CreateComponent("CollisionShape")
    shape:SetSphere(1.0)

    -- Create a random colored point light at the ball so that can see better where is going
    local light = ballNode:CreateComponent("Light")
    light.range = 3.0
    light.color = Color(0.5 + RandomInt(2) * 0.5, 0.5 + RandomInt(2) * 0.5, 0.5 + RandomInt(2) * 0.5)

    return ballNode
end

function MoveCamera()
    input.mouseVisible = input.mouseMode ~= MM_RELATIVE
    mouseDown = input:GetMouseButtonDown(MOUSEB_RIGHT)

    -- Override the MM_RELATIVE mouse grabbed settings, to allow interaction with UI
    input.mouseGrabbed = mouseDown

    -- Right mouse button controls mouse cursor visibility: hide when pressed
    ui.cursor.visible = not mouseDown

    -- Mouse sensitivity as degrees per pixel
    local MOUSE_SENSITIVITY = 0.1

    -- Use this frame's mouse motion to adjust camera node yaw and pitch. Clamp the pitch and only move the camera
    -- when the cursor is hidden
    if not ui.cursor.visible then
        local mouseMove = input.mouseMove
        yaw = yaw + MOUSE_SENSITIVITY * mouseMove.x
        pitch = pitch + MOUSE_SENSITIVITY * mouseMove.y
        pitch = Clamp(pitch, 1.0, 90.0)
    end

    -- Construct new orientation for the camera scene node from yaw and pitch. Roll is fixed to zero
    cameraNode.rotation = Quaternion(pitch, yaw, 0.0)

    -- Only move the camera / show instructions if we have a controllable object
    local showInstructions = false
    if clientObjectID ~= 0 then
        local ballNode = scene_:GetNode(clientObjectID)
        if ballNode ~= nil then
            local CAMERA_DISTANCE = 5.0

            -- Move camera some distance away from the ball
            cameraNode.position = ballNode.position + cameraNode.rotation * Vector3(0.0, 0.0, -1.0) * CAMERA_DISTANCE
            showInstructions = true
        end
    end

    instructionsText.visible = showInstructions
end

function HandlePostUpdate(eventType, eventData)

    -- We only rotate the camera according to mouse movement since last frame, so do not need the time step
    MoveCamera()
end

function HandlePhysicsPreStep(eventType, eventData)

    -- This function is different on the client and server. The client collects controls (WASD controls + yaw angle)
    -- and sets them to its server connection object, so that they will be sent to the server automatically at a
    -- fixed rate, by default 30 FPS. The server will actually apply the controls (authoritative simulation.)
    local serverConnection = network:GetServerConnection()

    -- Client: collect controls
    if serverConnection ~= nil then
        local controls = Controls()

        -- Copy mouse yaw
        controls.yaw = yaw

        -- Only apply WASD controls if there is no focused UI element
        if ui.focusElement == nil then
            controls:Set(CTRL_FORWARD, input:GetKeyDown(KEY_W))
            controls:Set(CTRL_BACK, input:GetKeyDown(KEY_S))
            controls:Set(CTRL_LEFT, input:GetKeyDown(KEY_A))
            controls:Set(CTRL_RIGHT, input:GetKeyDown(KEY_D))
        end

        serverConnection.controls = controls
        -- In case the server wants to do position-based interest management using the NetworkPriority components, we should also
        -- tell it our observer (camera) position. In this sample it is not in use, but eg. the NinjaSnowWar game uses it
        serverConnection.position = cameraNode.position
    -- Server: apply controls to client objects
    elseif network.serverRunning then
        for i, v in ipairs(clients) do
            local connection = v.connection
            
            -- 防御性检查：connection 可能已断开但还在列表中
            if connection == nil then
                goto continue
            end
            
            -- 检查 connection 是否真的是 Connection 类型（防止被 GC 后内存复用）
            local connStr = tostring(connection)
            if not connStr:find("Connection") then
                v.connection = nil  -- 标记为无效
                goto continue
            end
            
            -- 检查 controls 是否有效
            local controls = connection.controls
            if controls == nil then
                goto continue
            end
            
            -- Get the object this connection is controlling
            local ballNode = v.object

            local body = ballNode:GetComponent("RigidBody")

            -- Torque is relative to the forward vector
            local rotation = Quaternion(0.0, controls.yaw, 0.0)

            local MOVE_TORQUE = 3.0

            -- Movement torque is applied before each simulation step, which happen at 60 FPS. This makes the simulation
            -- independent from rendering framerate. We could also apply forces (which would enable in-air control),
            -- but want to emphasize that it's a ball which should only control its motion by rolling along the ground
            if controls:IsDown(CTRL_FORWARD) then
                body:ApplyTorque(rotation * Vector3(1.0, 0.0, 0.0) * MOVE_TORQUE)
            end
            if controls:IsDown(CTRL_BACK) then
                body:ApplyTorque(rotation * Vector3(-1.0, 0.0, 0.0) * MOVE_TORQUE)
            end
            if controls:IsDown(CTRL_LEFT) then
                body:ApplyTorque(rotation * Vector3(0.0, 0.0, 1.0) * MOVE_TORQUE)
            end
            if controls:IsDown(CTRL_RIGHT) then
                body:ApplyTorque(rotation * Vector3(0.0, 0.0, -1.0) * MOVE_TORQUE)
            end
            
            ::continue::
        end
    end
end

function HandleConnect(eventType, eventData)
    local address = textEdit.text
    if address == "" then
        address = "localhost" -- Use localhost to connect if nothing else specified
    end

    -- Get selected transport protocol
    selectedTransport = GetSelectedTransport()

    -- Connect to server, specify scene to use as a client for replication
    clientObjectID = 0 -- Reset own object ID from possible previous connection

    -- Use the transport-aware connect function
    local success = network:ConnectWithTransport(address, SERVER_PORT, scene_, selectedTransport)

    if not success then
        log:Write(LOG_ERROR, "Failed to connect using " .. GetTransportName(selectedTransport))
        statusText:SetText("Connection failed - " .. GetTransportName(selectedTransport) .. " may not be supported")
        statusText:SetColor(Color(1.0, 0.0, 0.0))
        isConnecting = false
    else
        log:Write(LOG_INFO, "Connecting via " .. GetTransportName(selectedTransport) .. " to " .. address .. ":" .. SERVER_PORT)
        isConnecting = true  -- 标记正在连接
    end

    UpdateButtons()
end

function HandleDisconnect(eventType, eventData)
    -- 设置正在断开状态，立即更新 UI
    isDisconnecting = true
    isConnecting = false
    UpdateButtons()
    
    local serverConnection = network.serverConnection
    -- If we were connected to server, disconnect. Or if we were running a server, stop it. In both cases clear the
    -- scene of all replicated content, but let the local nodes & components (the static world + camera) stay
    if serverConnection ~= nil then
        -- NOTE: 客户端断开服务器必须使用 network:Disconnect()
        -- 不要使用 serverConnection:Disconnect()，因为：
        -- 1. network:Disconnect() 会触发 ServerDisconnected 事件，用于状态管理
        -- 2. serverConnection:Disconnect() 只断开底层传输，不触发事件
        -- serverConnection:Disconnect() 仅用于服务器端踢出客户端的场景
        network:Disconnect(100)
        scene_:Clear(true, false)
        clientObjectID = 0
    elseif network.serverRunning then
        network:StopServer()
        scene_:Clear(true, false)
        clients = {}  -- 清理 clients 列表
        -- 服务器停止是同步操作，立即重置状态
        isDisconnecting = false
        UpdateButtons()
    else
        -- 没有需要断开的，直接恢复状态
        isDisconnecting = false
    end
    
    UpdateButtons()
end

function HandleStartServer(eventType, eventData)
    -- Get selected transport protocol
    selectedTransport = GetSelectedTransport()

    -- Start server with the selected transport
    local success = network:StartServerWithTransport(SERVER_PORT, selectedTransport)

    if not success then
        log:Write(LOG_ERROR, "Failed to start server using " .. GetTransportName(selectedTransport))
        statusText:SetText("Server start failed - " .. GetTransportName(selectedTransport) .. " may not be supported")
        statusText:SetColor(Color(1.0, 0.0, 0.0))
    else
        log:Write(LOG_INFO, "Server started on port " .. SERVER_PORT .. " via " .. GetTransportName(selectedTransport))
    end

    UpdateButtons()
end

function HandleConnectionStatus(eventType, eventData)
    isConnecting = false
    isDisconnecting = false
    UpdateButtons()
end

function HandleConnectionFailed(eventType, eventData)
    statusText:SetText("Connection failed!")
    statusText:SetColor(Color(1.0, 0.0, 0.0))
    isConnecting = false
    isDisconnecting = false
    UpdateButtons()
end

function HandleClientConnected(eventType, eventData)
    -- When a client connects, assign to scene to begin scene replication
    local newConnection = eventData["Connection"]:GetPtr("Connection")
    
    -- 验证 connection 对象类型（防止无效对象）
    local connStr = tostring(newConnection)
    if not connStr:find("Connection") then
        return
    end
    
    newConnection.scene = scene_

    -- Then create a controllable object for that client
    local newObject = CreateControllableObject()
    local newClient = {}
    newClient.connection = newConnection
    newClient.object = newObject
    table.insert(clients, newClient)

    -- Finally send the object's node ID using a remote event
    local remoteEventData = VariantMap()
    remoteEventData["ID"] = newObject.ID
    newConnection:SendRemoteEvent("ClientObjectID", true, remoteEventData)
end

function HandleClientDisconnected(eventType, eventData)
    -- When a client disconnects, remove the controlled object
    local connection = eventData["Connection"]:GetPtr("Connection")
    
    for i, v in ipairs(clients) do
        if v.connection == connection then
            if v.object then
                v.object:Remove()
            end
            table.remove(clients, i)
            return
        end
    end
    
    -- 如果没找到匹配的客户端，清理所有无效的 clients（可能被 GC 复用了内存）
    local toRemove = {}
    for i, v in ipairs(clients) do
        local vConnStr = tostring(v.connection)
        if not vConnStr:find("Connection") then
            table.insert(toRemove, i)
        end
    end
    -- 从后往前删除，避免索引问题
    for j = #toRemove, 1, -1 do
        local idx = toRemove[j]
        if clients[idx].object then
            clients[idx].object:Remove()
        end
        table.remove(clients, idx)
    end
end

function HandleClientObjectID(eventType, eventData)
    clientObjectID = eventData["ID"]:GetUInt()
end

-- Create XML patch instructions for screen joystick layout specific to this sample app
function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end

