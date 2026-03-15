-- Gomoku (Five-in-a-Row) Game using Urho3D Lua
-- Main Application Entry Point

-- Game constants
local BOARD_SIZE = 15
local CELL_SIZE = 40

-- Network constants
local SERVER_PORT = 54654

-- Game state
local isHost = false
local isClient = false
local isMyTurn = false
local myColor = 1  -- 1 = black, 2 = white
local currentPlayer = 1
local board = {}
local gameStarted = false
local gameOver = false
local winner = 0

-- UI elements
---@type UIElement
local menuPanel = nil
---@type Button
local hostButton = nil
---@type Button
local joinButton = nil
---@type LineEdit
local ipInput = nil
---@type Text
local statusText = nil
---@type Text
local turnText = nil
---@type Text
local resultText = nil

-- Subsystems
---@type Scene
local scene_ = nil
---@type Network
local network = nil

-- Entry point
function Start()
    -- Initialize board
    for i = 1, BOARD_SIZE do
        board[i] = {}
        for j = 1, BOARD_SIZE do
            board[i][j] = 0
        end
    end

    -- Enable OS cursor (required for UI interaction)
    local input = GetInput()
    input.mouseVisible = true

    -- Create the scene content
    CreateScene()

    -- Create the UI content
    CreateUI()

    -- Setup viewport
    SetupViewport()

    -- Subscribe to necessary events
    SubscribeToEvents()
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- Create camera
    local cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(0, 0, -10)
    local camera = cameraNode:CreateComponent("Camera")
    camera.orthographic = true
    camera.orthoSize = 600

    -- Create light
    local lightNode = scene_:CreateChild("Light")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(0.5, 0.5, 0.5)

    -- Setup network
    network = GetNetwork()
end

function CreateUI()
    local ui = GetUI()

    -- Create root UI element
    local uiRoot = ui.root
    local graphics = GetGraphics()

    -- 设置默认style
    local style = cache:GetResource("XMLFile", "UI/TestStyle.xml")
    ui.root.defaultStyle = style

    -- Create menu panel (initially visible)
    menuPanel = uiRoot:CreateChild("UIElement")
    menuPanel:SetSize(400, 300)
    menuPanel:SetPosition((graphics.width - 400) / 2, (graphics.height - 300) / 2)
    menuPanel:SetStyleAuto()

    -- Title
    local title = menuPanel:CreateChild("Text")
    title:SetText("Gomoku - Five in a Row")
    title:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 30)
    title:SetAlignment(HA_CENTER, VA_TOP)
    title:SetPosition(0, 20)
    title.textEffect = TE_SHADOW
    title:SetColor(Color(1, 1, 1))

    -- Host button (使用新的内置Text功能)
    hostButton = menuPanel:CreateChild("Button")
    hostButton:SetStyleAuto()  -- 样式会自动应用到内置Text
    hostButton:SetSize(200, 40)
    hostButton:SetPosition(100, 80)
    hostButton.text = "Host Game"  -- 直接设置文本！

    -- Join button (使用新的内置Text功能)
    joinButton = menuPanel:CreateChild("Button")
    joinButton:SetStyleAuto()
    joinButton:SetSize(200, 40)
    joinButton:SetPosition(100, 130)
    joinButton.text = "Join Game"  -- 直接设置文本！

    -- Server IP input (for join)
    ipInput = menuPanel:CreateChild("LineEdit")
    ipInput:SetStyleAuto()
    ipInput:SetSize(200, 30)
    ipInput:SetPosition(100, 180)
    ipInput.text = "localhost"


    -- Status text
    statusText = uiRoot:CreateChild("Text")
    statusText:SetText("Waiting for connection...")
    statusText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 16)
    statusText:SetAlignment(HA_CENTER, VA_TOP)
    statusText:SetPosition(0, 20)
    statusText.visible = false
    statusText.textEffect = TE_SHADOW

    -- Turn indicator
    turnText = uiRoot:CreateChild("Text")
    turnText:SetText("")
    turnText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 20)
    turnText:SetAlignment(HA_CENTER, VA_TOP)
    turnText:SetPosition(0, 50)
    turnText.visible = false
    turnText.textEffect = TE_SHADOW

    -- Game result text
    resultText = uiRoot:CreateChild("Text")
    resultText:SetText("")
    resultText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 30)
    resultText:SetAlignment(HA_CENTER, VA_CENTER)
    resultText:SetPosition(0, 0)
    resultText.visible = false
    resultText.textEffect = TE_SHADOW
end

function SetupViewport()
    local renderer = GetRenderer()
    local viewport = Viewport:new(scene_, scene_:GetChild("Camera"):GetComponent("Camera"))
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    -- Subscribe to button clicks
    SubscribeToEvent(hostButton, "Released", "HandleHostGame")
    SubscribeToEvent(joinButton, "Released", "HandleJoinGame")

    -- Subscribe to mouse click
    SubscribeToEvent("MouseButtonDown", "HandleMouseClick")

    -- Subscribe to network events
    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent("ServerConnected", "HandleServerConnected")
    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
    SubscribeToEvent("NetworkMessage", "HandleNetworkMessage")
end

function HandleHostGame()
    local success = network:StartServer(SERVER_PORT)
    if success then
        isHost = true
        myColor = 1  -- Host plays black
        isMyTurn = true
        currentPlayer = 1
        menuPanel.visible = false
        statusText.visible = true
        statusText:SetText("Waiting for opponent...")
        DrawBoard()
    else
        print("Failed to start server")
    end
end

function HandleJoinGame()
    local serverIP = ipInput.text
    local success = network:Connect(serverIP, SERVER_PORT, scene_)
    if success then
        isClient = true
        myColor = 2  -- Client plays white
        isMyTurn = false
        currentPlayer = 1
        menuPanel.visible = false
        statusText.visible = true
        statusText:SetText("Connecting...")
    else
        print("Failed to connect to server")
    end
end

function HandleClientConnected(eventType, eventData)
    if isHost then
        gameStarted = true
        statusText:SetText("Game Started!")
        turnText.visible = true
        UpdateTurnDisplay()

        -- Send current board state to client
        SendGameState()
    end
end

function HandleClientDisconnected(eventType, eventData)
    statusText:SetText("Opponent disconnected")
    gameStarted = false
end

function HandleServerConnected(eventType, eventData)
    if isClient then
        statusText:SetText("Connected to server")
    end
end

function HandleServerDisconnected(eventType, eventData)
    statusText:SetText("Disconnected from server")
    gameStarted = false
end

function HandleNetworkMessage(eventType, eventData) ---@cast eventData NetworkMessageEventData
    local msgID = eventData:GetInt("MessageID")

    if msgID == 100 then  -- Game state message
        ReceiveGameState(eventData)
    elseif msgID == 101 then  -- Move message
        ReceiveMove(eventData)
    elseif msgID == 102 then  -- Game over message
        ReceiveGameOver(eventData)
    end
end

function SendGameState()
    if not isHost then return end

    local msg = VectorBuffer()
    msg:WriteInt(100)  -- Message ID
    msg:WriteInt(currentPlayer)
    msg:WriteBool(gameStarted)

    -- Send board state
    for i = 1, BOARD_SIZE do
        for j = 1, BOARD_SIZE do
            msg:WriteInt(board[i][j])
        end
    end

    network:BroadcastMessage(100, true, true, msg)
end

function ReceiveGameState(eventData)
    if not isClient then return end

    local msg = eventData:GetBuffer()
    msg:ReadInt()  -- Skip message ID
    currentPlayer = msg:ReadInt()
    gameStarted = msg:ReadBool()

    -- Receive board state
    for i = 1, BOARD_SIZE do
        for j = 1, BOARD_SIZE do
            board[i][j] = msg:ReadInt()
        end
    end

    DrawBoard()
    turnText.visible = true
    UpdateTurnDisplay()
end

function SendMove(row, col)
    local msg = VectorBuffer()
    msg:WriteInt(101)  -- Message ID
    msg:WriteInt(row)
    msg:WriteInt(col)
    msg:WriteInt(myColor)

    if isHost then
        network:BroadcastMessage(101, true, true, msg)
    else
        network:GetServerConnection():SendMessage(101, true, true, msg)
    end
end

function ReceiveMove(eventData)
    local msg = eventData:GetBuffer()
    msg:ReadInt()  -- Skip message ID
    local row = msg:ReadInt()
    local col = msg:ReadInt()
    local color = msg:ReadInt()

    board[row][col] = color
    DrawBoard()

    -- Check for winner
    if CheckWinner(row, col, color) then
        GameOver(color)
    else
        -- Switch turns
        currentPlayer = 3 - currentPlayer  -- Toggle between 1 and 2
        isMyTurn = (currentPlayer == myColor)
        UpdateTurnDisplay()
    end
end

function SendGameOver(winnerColor)
    local msg = VectorBuffer()
    msg:WriteInt(102)  -- Message ID
    msg:WriteInt(winnerColor)

    if isHost then
        network:BroadcastMessage(102, true, true, msg)
    else
        network:GetServerConnection():SendMessage(102, true, true, msg)
    end
end

function ReceiveGameOver(eventData)
    local msg = eventData:GetBuffer()
    msg:ReadInt()  -- Skip message ID
    local winnerColor = msg:ReadInt()

    GameOver(winnerColor)
end

function HandleMouseClick(eventType, eventData)
    if not gameStarted or gameOver or not isMyTurn then
        return
    end

    local button = eventData:GetInt("Button")
    if button == MOUSEB_LEFT then
        local ui = GetUI()
        local x = eventData:GetInt("X")
        local y = eventData:GetInt("Y")

        -- Convert screen coordinates to board coordinates
        local graphics = GetGraphics()
        local boardX = x - (graphics.width - BOARD_SIZE * CELL_SIZE) / 2
        local boardY = y - (graphics.height - BOARD_SIZE * CELL_SIZE) / 2

        if boardX >= 0 and boardY >= 0 then
            local col = math.floor(boardX / CELL_SIZE) + 1
            local row = math.floor(boardY / CELL_SIZE) + 1

            if row >= 1 and row <= BOARD_SIZE and col >= 1 and col <= BOARD_SIZE then
                if board[row][col] == 0 then
                    -- Valid move
                    board[row][col] = myColor
                    DrawBoard()

                    -- Send move to opponent
                    SendMove(row, col)

                    -- Check for winner
                    if CheckWinner(row, col, myColor) then
                        GameOver(myColor)
                    else
                        -- Switch turns
                        currentPlayer = 3 - currentPlayer
                        isMyTurn = false
                        UpdateTurnDisplay()
                    end
                end
            end
        end
    end
end

function DrawBoard()
    local ui = GetUI()
    local uiRoot = ui.root
    local graphics = GetGraphics()

    -- Remove old board if exists
    local oldBoard = uiRoot:GetChild("Board", false)
    if oldBoard then
        oldBoard:Remove()
    end

    -- Create board container
    local boardElement = uiRoot:CreateChild("UIElement", "Board")
    boardElement:SetSize(BOARD_SIZE * CELL_SIZE + 20, BOARD_SIZE * CELL_SIZE + 20)
    boardElement:SetPosition((graphics.width - BOARD_SIZE * CELL_SIZE - 20) / 2,
                             (graphics.height - BOARD_SIZE * CELL_SIZE - 20) / 2)

    -- Draw grid lines
    for i = 0, BOARD_SIZE do
        -- Horizontal line
        local hLine = boardElement:CreateChild("BorderImage")
        hLine:SetSize(BOARD_SIZE * CELL_SIZE, 1)
        hLine:SetPosition(10, 10 + i * CELL_SIZE)
        hLine:SetColor(Color(0.3, 0.3, 0.3))

        -- Vertical line
        local vLine = boardElement:CreateChild("BorderImage")
        vLine:SetSize(1, BOARD_SIZE * CELL_SIZE)
        vLine:SetPosition(10 + i * CELL_SIZE, 10)
        vLine:SetColor(Color(0.3, 0.3, 0.3))
    end

    -- Draw stones
    for i = 1, BOARD_SIZE do
        for j = 1, BOARD_SIZE do
            if board[i][j] ~= 0 then
                local stone = boardElement:CreateChild("BorderImage")
                stone:SetSize(CELL_SIZE - 6, CELL_SIZE - 6)
                stone:SetPosition(10 + (j - 1) * CELL_SIZE - (CELL_SIZE - 6) / 2 + CELL_SIZE / 2,
                                 10 + (i - 1) * CELL_SIZE - (CELL_SIZE - 6) / 2 + CELL_SIZE / 2)

                if board[i][j] == 1 then
                    -- Black stone
                    stone:SetColor(Color(0.1, 0.1, 0.1))
                else
                    -- White stone
                    stone:SetColor(Color(0.95, 0.95, 0.95))
                end

                -- Make it circular by using texture
                stone.texture = cache:GetResource("Texture2D", "Textures/UI.png")
                stone.imageRect = IntRect(64, 0, 80, 16)
            end
        end
    end
end

function UpdateTurnDisplay()
    if isMyTurn then
        if myColor == 1 then
            turnText:SetText("Your turn - Black")
            turnText:SetColor(Color(0.2, 0.2, 0.2))
        else
            turnText:SetText("Your turn - White")
            turnText:SetColor(Color(0.9, 0.9, 0.9))
        end
    else
        turnText:SetText("Opponent's turn")
        turnText:SetColor(Color(0.7, 0.7, 0.7))
    end
end

function CheckWinner(row, col, color)
    -- Check horizontal
    local count = 1
    for i = col - 1, 1, -1 do
        if board[row][i] == color then
            count = count + 1
        else
            break
        end
    end
    for i = col + 1, BOARD_SIZE do
        if board[row][i] == color then
            count = count + 1
        else
            break
        end
    end
    if count >= 5 then return true end

    -- Check vertical
    count = 1
    for i = row - 1, 1, -1 do
        if board[i][col] == color then
            count = count + 1
        else
            break
        end
    end
    for i = row + 1, BOARD_SIZE do
        if board[i][col] == color then
            count = count + 1
        else
            break
        end
    end
    if count >= 5 then return true end

    -- Check diagonal (top-left to bottom-right)
    count = 1
    local r, c = row - 1, col - 1
    while r >= 1 and c >= 1 do
        if board[r][c] == color then
            count = count + 1
            r = r - 1
            c = c - 1
        else
            break
        end
    end
    r, c = row + 1, col + 1
    while r <= BOARD_SIZE and c <= BOARD_SIZE do
        if board[r][c] == color then
            count = count + 1
            r = r + 1
            c = c + 1
        else
            break
        end
    end
    if count >= 5 then return true end

    -- Check diagonal (top-right to bottom-left)
    count = 1
    r, c = row - 1, col + 1
    while r >= 1 and c <= BOARD_SIZE do
        if board[r][c] == color then
            count = count + 1
            r = r - 1
            c = c + 1
        else
            break
        end
    end
    r, c = row + 1, col - 1
    while r <= BOARD_SIZE and c >= 1 do
        if board[r][c] == color then
            count = count + 1
            r = r + 1
            c = c - 1
        else
            break
        end
    end
    if count >= 5 then return true end

    return false
end

function GameOver(winnerColor)
    gameOver = true
    winner = winnerColor
    turnText.visible = false

    if winnerColor == myColor then
        resultText:SetText("You Win!")
        resultText:SetColor(Color(0, 1, 0))
    else
        resultText:SetText("You Lose!")
        resultText:SetColor(Color(1, 0, 0))
    end
    resultText.visible = true

    -- Send game over message
    SendGameOver(winnerColor)
end
