-- Physics Stress Test v2.0：动态 N×N 分区掉落（总量配置 + 自动均摊）
-- 配置总的初始盒子数、总的每波掉落数、总掉落半径、网格边长，自动均摊到各子区域
-- 格子大小 = 场景大小 / 格子边长数（场景固定 200×200）
-- 掉落半径 = 总掉落半径 / 格子边长数（控制每个格子内方块掉落的范围）

require "LuaScripts/Utilities/Sample"

-- ========================================
-- 核心配置（总量）
-- ========================================
local TOTAL_INITIAL_BOXES = 500      -- 总初始盒子数（均摊到所有区域）
local TOTAL_BOXES_PER_WAVE = 50      -- 总每波掉落数（均摊到所有区域）
local TOTAL_DROP_RADIUS = 80         -- 总掉落半径（所有格子的掉落区域总范围）
local GRID_SIZE = 6                  -- 网格边长（N×N，例如 3 = 3×3 = 9 个区域）

-- 场景配置（固定）
local SCENE_SIZE = 200               -- 场景大小（地面和墙壁的尺寸，固定不变）
local WAVE_INTERVAL = 3.0            -- 每波间隔（秒）
local BOX_SIZE = 1.5                 -- 方块大小
local DROP_HEIGHT = 25.0             -- 投放高度
local FPS_THRESHOLD = 30             -- FPS 低于此值时停止测试
local MAX_WAVES = 0                  -- 最大波次（0 = 无限制）

-- ========================================
-- 自动计算的派生配置
-- ========================================
local TOTAL_ZONES = GRID_SIZE * GRID_SIZE
local BOXES_PER_ZONE_INITIAL = math.floor(TOTAL_INITIAL_BOXES / TOTAL_ZONES)
local BOXES_PER_ZONE_WAVE = math.floor(TOTAL_BOXES_PER_WAVE / TOTAL_ZONES)
local ZONE_SPACING = SCENE_SIZE / GRID_SIZE                         -- 格子间距（格子边长）= 场景大小 / 格子边长数
local ZONE_RADIUS = TOTAL_DROP_RADIUS / GRID_SIZE / GRID_SIZE       -- 单个格子的掉落半径 = 总掉落半径 / 格子边长数

-- 测试状态
local currentWave = 0
local totalBoxes = 0
local initialBoxes = 0
local waveTimer = 0
local testRunning = true
local manualMode = false
local fpsHistory = {}
local FPS_HISTORY_SIZE = 60
local waveStats = {}

-- 动态生成的区域位置
local zonePositions = {}

function Start()
    Print("========================================")
    Print("Physics Stress Test v2.0 Starting...")
    Print("========================================")
    
    SampleStart()
    Print("SampleStart() complete")
    
    InitializeZonePositions()
    Print("Zones initialized: " .. TOTAL_ZONES .. " zones")
    
    CreateScene()
    Print("Scene created")
    
    CreateInstructions()
    Print("UI created")
    
    SetupViewport()
    Print("Viewport setup")
    
    SubscribeToEvents()
    Print("Events subscribed")
    
    -- 强制显示鼠标
    input.mouseVisible = true
    input.mouseMode = MM_FREE
    
    Print("========================================")
    Print("Physics Stress Test v2.0 - " .. GRID_SIZE .. "×" .. GRID_SIZE .. " Dynamic Grid")
    Print("========================================")
    Print("Configuration (TOTAL):")
    Print("  Total initial boxes: " .. TOTAL_INITIAL_BOXES)
    Print("  Total boxes per wave: " .. TOTAL_BOXES_PER_WAVE)
    Print("  Total drop radius: " .. TOTAL_DROP_RADIUS .. " units")
    Print("  Grid size: " .. GRID_SIZE .. "×" .. GRID_SIZE .. " = " .. TOTAL_ZONES .. " zones")
    Print("")
    Print("Configuration (PER ZONE):")
    Print("  Initial boxes/zone: " .. BOXES_PER_ZONE_INITIAL)
    Print("  Boxes per wave/zone: " .. BOXES_PER_ZONE_WAVE)
    Print("  Zone spacing (grid cell size): " .. string.format("%.1f", ZONE_SPACING) .. " units")
    Print("  Zone drop radius: " .. string.format("%.1f", ZONE_RADIUS) .. " units")
    Print("")
    Print("Scene:")
    Print("  Scene size (fixed): " .. SCENE_SIZE .. " units")
    Print("  Wave interval: " .. WAVE_INTERVAL .. "s")
    Print("  FPS threshold: " .. FPS_THRESHOLD)
    Print("========================================")
    Print("")
    Print("Spawning initial " .. TOTAL_INITIAL_BOXES .. " boxes across all zones...")
    
    -- 预先生成初始方块（分散到各个区域）
    SpawnInitialBoxes()
    
    Print("Initial spawn complete! Starting wave test...")
    Print("Each wave spawns in ALL " .. TOTAL_ZONES .. " zones simultaneously!")
    Print("========================================")
end

function InitializeZonePositions()
    -- 动态初始化 N×N 网格的中心坐标
    zonePositions = {}
    local index = 1
    
    -- 计算起始偏移（使网格居中）
    local startOffset = -ZONE_SPACING * (GRID_SIZE - 1) / 2
    
    for row = 0, GRID_SIZE - 1 do
        for col = 0, GRID_SIZE - 1 do
            local x = startOffset + col * ZONE_SPACING
            local z = startOffset + row * ZONE_SPACING
            zonePositions[index] = Vector3(x, 0, z)
            Print("  Zone " .. index .. ": (" .. string.format("%.1f", x) .. ", " .. string.format("%.1f", z) .. ")")
            index = index + 1
        end
    end
end

function CreateScene()
    Print("Creating scene...")
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    
    local physicsWorld = scene_:CreateComponent("PhysicsWorld")
    physicsWorld.fps = 60
    physicsWorld.maxSubSteps = 10
    
    -- 调试信息
    Print("Physics World Configuration:")
    Print("  FPS: " .. physicsWorld.fps)
    Print("  MaxSubSteps: " .. physicsWorld.maxSubSteps)
    Print("  Fixed TimeStep: " .. (1.0 / physicsWorld.fps) .. " seconds")
    Print("")
    
    -- 光照
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-2000.0, 2000.0)
    zone.ambientColor = Color(0.7, 0.7, 0.75)  -- 环境光更亮（从 0.5 增加到 0.7）
    zone.fogColor = Color(0.2, 0.2, 0.3)       -- 深色雾
    zone.fogStart = SCENE_SIZE * 0.8
    zone.fogEnd = SCENE_SIZE * 1.5
    
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(1.0, 1.0, 0.95)        -- 主光颜色（略带暖色）
    light.brightness = 1.2                      -- 主光亮度增加
    light.castShadows = true
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(20.0, 80.0, 300.0, 0.0, 0.8)
    light.specularIntensity = 0.7              -- 镜面反射强度增加（从 0.5 到 0.7）
    
    -- 相机（固定位置，基于场景大小）
    cameraNode = scene_:CreateChild("Camera")
    local cameraHeight = SCENE_SIZE * 0.67   -- 100 (当 SCENE_SIZE = 150)
    local cameraDistance = SCENE_SIZE * 0.67  -- 100 (当 SCENE_SIZE = 150)
    cameraNode.position = Vector3(0, cameraHeight, -cameraDistance)
    cameraNode:LookAt(Vector3(0, 0, 0))
    local camera = cameraNode:CreateComponent("Camera")
    camera.farClip = SCENE_SIZE * 3
    
    Print("Camera: height=" .. cameraHeight .. ", distance=" .. cameraDistance)
    
    -- 超大地面
    local groundNode = scene_:CreateChild("Ground")
    groundNode.position = Vector3(0, -0.5, 0)
    groundNode.scale = Vector3(SCENE_SIZE, 1, SCENE_SIZE)
    
    local groundObject = groundNode:CreateComponent("StaticModel")
    groundObject.model = cache:GetResource("Model", "Models/Box.mdl")
    groundObject.material = cache:GetResource("Material", "Materials/Stone.xml")
    
    local groundBody = groundNode:CreateComponent("RigidBody")
    groundBody.collisionLayer = 1
    
    local groundShape = groundNode:CreateComponent("CollisionShape")
    groundShape:SetBox(Vector3.ONE)
    
    Print("Ground: " .. SCENE_SIZE .. "×" .. SCENE_SIZE)
    
    -- 墙壁
    Print("Creating walls...")
    local wallHeight = 15
    local wallHalfSize = SCENE_SIZE / 2
    CreateWall(Vector3(0, wallHeight/2, wallHalfSize), Vector3(SCENE_SIZE, wallHeight, 1))   -- 后墙
    CreateWall(Vector3(0, wallHeight/2, -wallHalfSize), Vector3(SCENE_SIZE, wallHeight, 1))  -- 前墙
    CreateWall(Vector3(wallHalfSize, wallHeight/2, 0), Vector3(1, wallHeight, SCENE_SIZE))   -- 右墙
    CreateWall(Vector3(-wallHalfSize, wallHeight/2, 0), Vector3(1, wallHeight, SCENE_SIZE))  -- 左墙
    Print("Walls created")
    
    -- 创建网格线（视觉辅助）
    Print("Creating grid lines...")
    CreateGridLines()
    
    Print("Scene creation complete!")
end

function CreateWall(position, scale)
    local wallNode = scene_:CreateChild("Wall")
    wallNode.position = position
    wallNode.scale = scale
    
    local wallObject = wallNode:CreateComponent("StaticModel")
    wallObject.model = cache:GetResource("Model", "Models/Box.mdl")
    wallObject.material = cache:GetResource("Material", "Materials/Stone.xml")
    
    local wallBody = wallNode:CreateComponent("RigidBody")
    wallBody.collisionLayer = 1
    
    local wallShape = wallNode:CreateComponent("CollisionShape")
    wallShape:SetBox(Vector3.ONE)
end

function CreateGridLines()
    -- 在地面上创建网格线（用平板表示）
    local lineHeight = 0.1
    local lineThickness = 0.5
    
    -- 横向线（GRID_SIZE - 1 条）
    for i = 1, GRID_SIZE - 1 do
        local startOffset = -ZONE_SPACING * (GRID_SIZE - 1) / 2
        local z = startOffset + (i - 0.5) * ZONE_SPACING
        local lineNode = scene_:CreateChild("GridLine")
        lineNode.position = Vector3(0, lineHeight, z)
        lineNode.scale = Vector3(SCENE_SIZE, lineHeight, lineThickness)
        
        local lineObject = lineNode:CreateComponent("StaticModel")
        lineObject.model = cache:GetResource("Model", "Models/Box.mdl")
        lineObject.material = cache:GetResource("Material", "Materials/Stone.xml")
    end
    
    -- 纵向线（GRID_SIZE - 1 条）
    for i = 1, GRID_SIZE - 1 do
        local startOffset = -ZONE_SPACING * (GRID_SIZE - 1) / 2
        local x = startOffset + (i - 0.5) * ZONE_SPACING
        local lineNode = scene_:CreateChild("GridLine")
        lineNode.position = Vector3(x, lineHeight, 0)
        lineNode.scale = Vector3(lineThickness, lineHeight, SCENE_SIZE)
        
        local lineObject = lineNode:CreateComponent("StaticModel")
        lineObject.model = cache:GetResource("Model", "Models/Box.mdl")
        lineObject.material = cache:GetResource("Material", "Materials/Stone.xml")
    end
    
    Print("Grid lines created: " .. (GRID_SIZE - 1) * 2 .. " lines for " .. GRID_SIZE .. "×" .. GRID_SIZE .. " grid")
end

function SpawnInitialBoxes()
    -- 均匀分配到所有区域
    local boxesSpawned = 0
    
    for zoneIdx = 1, TOTAL_ZONES do
        for i = 1, BOXES_PER_ZONE_INITIAL do
            SpawnBoxInZone(zoneIdx, math.random(2, 10))  -- 初始高度随机 2-10
            boxesSpawned = boxesSpawned + 1
        end
    end
    
    -- 处理余数（如果总数不能被区域数整除）
    local remainder = TOTAL_INITIAL_BOXES - boxesSpawned
    for i = 1, remainder do
        local randomZone = math.random(1, TOTAL_ZONES)
        SpawnBoxInZone(randomZone, math.random(2, 10))
    end
    
    Print("Initial boxes distributed: " .. totalBoxes .. " across " .. TOTAL_ZONES .. " zones")
end

function SpawnBoxInZone(zoneIdx, heightOverride)
    if zoneIdx < 1 or zoneIdx > TOTAL_ZONES then
        Print("Error: Invalid zone index " .. zoneIdx)
        return
    end
    
    local zoneCenter = zonePositions[zoneIdx]
    local spawnHeight = heightOverride or DROP_HEIGHT
    
    -- 在区域内随机位置
    local angle = math.random() * 2 * 3.14159
    local radius = math.random() * ZONE_RADIUS
    local offsetX = radius * math.cos(angle)
    local offsetZ = radius * math.sin(angle)
    
    local boxNode = scene_:CreateChild("Box")
    boxNode.position = Vector3(
        zoneCenter.x + offsetX,
        spawnHeight,
        zoneCenter.z + offsetZ
    )
    boxNode.scale = Vector3(BOX_SIZE, BOX_SIZE, BOX_SIZE)
    
    local boxObject = boxNode:CreateComponent("StaticModel")
    boxObject.model = cache:GetResource("Model", "Models/Box.mdl")
    boxObject.material = cache:GetResource("Material", "Materials/StoneSmall.xml")
    boxObject.castShadows = true
    
    local boxBody = boxNode:CreateComponent("RigidBody")
    boxBody.mass = 1.0
    boxBody.friction = 0.75
    boxBody.restitution = 0.2
    boxBody.collisionLayer = 2
    
    local boxShape = boxNode:CreateComponent("CollisionShape")
    boxShape:SetBox(Vector3.ONE)
    
    totalBoxes = totalBoxes + 1
    if heightOverride and heightOverride < DROP_HEIGHT then
        initialBoxes = initialBoxes + 1
    end
end

function SpawnWave()
    if not testRunning and not manualMode then
        return
    end
    
    currentWave = currentWave + 1
    
    Print("Wave " .. currentWave .. " → Spawning in ALL " .. TOTAL_ZONES .. " zones simultaneously!")
    
    -- 在所有区域同时投放方块
    local boxesSpawned = 0
    for zoneIdx = 1, TOTAL_ZONES do
        for i = 1, BOXES_PER_ZONE_WAVE do
            SpawnBoxInZone(zoneIdx, DROP_HEIGHT)
            boxesSpawned = boxesSpawned + 1
        end
    end
    
    -- 处理余数
    local remainder = TOTAL_BOXES_PER_WAVE - boxesSpawned
    for i = 1, remainder do
        local randomZone = math.random(1, TOTAL_ZONES)
        SpawnBoxInZone(randomZone, DROP_HEIGHT)
    end
    
    Print("  -> Spawned " .. TOTAL_BOXES_PER_WAVE .. " boxes total (" .. TOTAL_ZONES .. " zones × " .. BOXES_PER_ZONE_WAVE .. " + " .. remainder .. " remainder)")
    
    -- 记录统计
    local avgFps = CalculateAverageFPS()
    table.insert(waveStats, {
        wave = currentWave,
        boxes = totalBoxes,
        fps = avgFps
    })
    
    -- 检查 FPS 是否低于阈值
    if avgFps < FPS_THRESHOLD then
        testRunning = false
        Print("")
        Print("========================================")
        Print("FPS dropped below " .. FPS_THRESHOLD .. "!")
        Print("Test stopped at Wave " .. currentWave)
        Print("Total boxes: " .. totalBoxes)
        Print("========================================")
        
        -- 显示手动模式按钮
        local manualButton = ui.root:GetChild("ManualButton", true)
        if manualButton then
            manualButton.visible = true
        end
    end
end

function CreateInstructions()
    local instructionText = ui.root:CreateChild("Text")
    instructionText.name = "Instructions"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 14)
    instructionText.textAlignment = HA_LEFT
    instructionText.horizontalAlignment = HA_LEFT
    instructionText.verticalAlignment = VA_TOP
    instructionText:SetPosition(10, 10)
    instructionText:SetColor(Color(1, 1, 0))
    instructionText.text = "Loading..."
    
    -- 按钮容器
    local buttonContainer = ui.root:CreateChild("UIElement")
    buttonContainer.name = "ButtonContainer"
    buttonContainer:SetAlignment(HA_CENTER, VA_BOTTOM)
    buttonContainer:SetPosition(0, -100)
    buttonContainer:SetSize(400, 200)
    
    -- 切换到手动模式按钮
    local manualButton = buttonContainer:CreateChild("Button")
    manualButton.name = "ManualButton"
    manualButton:SetAlignment(HA_CENTER, VA_TOP)
    manualButton:SetSize(350, 60)
    manualButton:SetPosition(0, 0)
    manualButton.visible = false
    
    manualButton:SetStyle("Button", cache:GetResource("XMLFile", "UI/DefaultStyle.xml"))
    manualButton:SetColor(Color(1.0, 0.5, 0.0, 0.9))
    
    local manualButtonText = manualButton:CreateChild("Text")
    manualButtonText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 22)
    manualButtonText.textAlignment = HA_CENTER
    manualButtonText:SetAlignment(HA_CENTER, VA_CENTER)
    manualButtonText.text = "SWITCH TO MANUAL MODE"
    manualButtonText:SetColor(Color(1, 1, 1))
    
    SubscribeToEvent(manualButton, "Released", "HandleManualButtonClick")
    
    -- 投放下一波按钮
    local spawnButton = buttonContainer:CreateChild("Button")
    spawnButton.name = "SpawnButton"
    spawnButton:SetAlignment(HA_CENTER, VA_TOP)
    spawnButton:SetSize(350, 60)
    spawnButton:SetPosition(0, 70)
    spawnButton.visible = false
    
    spawnButton:SetStyle("Button", cache:GetResource("XMLFile", "UI/DefaultStyle.xml"))
    spawnButton:SetColor(Color(0.0, 1.0, 0.5, 0.9))
    
    local spawnButtonText = spawnButton:CreateChild("Text")
    spawnButtonText.name = "ButtonText"
    spawnButtonText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 22)
    spawnButtonText.textAlignment = HA_CENTER
    spawnButtonText:SetAlignment(HA_CENTER, VA_CENTER)
    spawnButtonText.text = "SPAWN NEXT WAVE (ALL " .. TOTAL_ZONES .. " ZONES)"
    spawnButtonText:SetColor(Color(1, 1, 1))
    
    SubscribeToEvent(spawnButton, "Released", "HandleSpawnButtonClick")
end

function HandleManualButtonClick()
    Print("")
    Print("========================================")
    Print("Switching to MANUAL MODE")
    Print("========================================")
    manualMode = true
    testRunning = false
    
    local manualButton = ui.root:GetChild("ManualButton", true)
    if manualButton then
        manualButton.visible = false
    end
    
    local spawnButton = ui.root:GetChild("SpawnButton", true)
    if spawnButton then
        spawnButton.visible = true
    end
end

function HandleSpawnButtonClick()
    if manualMode then
        Print("")
        Print("Manual spawn triggered...")
        SpawnWave()
    end
end

function UpdateInstructions()
    local instructionText = ui.root:GetChild("Instructions", true)
    if not instructionText then
        return
    end
    
    local avgFps = CalculateAverageFPS()
    local lastWaveFps = "N/A"
    if #waveStats > 0 then
        lastWaveFps = string.format("%.1f", waveStats[#waveStats].fps)
    end
    
    -- 获取当前瞬时 FPS
    local currentFps = #fpsHistory > 0 and fpsHistory[#fpsHistory] or 60.0
    
    -- 更新按钮可见性
    local buttonContainer = ui.root:GetChild("ButtonContainer", true)
    if buttonContainer then
        local manualButton = buttonContainer:GetChild("ManualButton", true)
        local spawnButton = buttonContainer:GetChild("SpawnButton", true)
        
        if manualMode then
            if manualButton then manualButton.visible = false end
            if spawnButton then spawnButton.visible = true end
        elseif not testRunning then
            if manualButton then manualButton.visible = true end
            if spawnButton then spawnButton.visible = false end
        else
            if manualButton then manualButton.visible = false end
            if spawnButton then spawnButton.visible = false end
        end
    end
    
    -- 手动模式 UI
    if manualMode then
        instructionText.text = string.format(
            "╔═══════════════════════════════════════════╗\n" ..
            "║  PHYSICS STRESS TEST v2.0 - MANUAL MODE  ║\n" ..
            "╠═══════════════════════════════════════════╣\n" ..
            "║                                           ║\n" ..
            "║ Current Wave: %-5d                       ║\n" ..
            "║ Total Boxes:  %-5d (%-4d + %-4d)         ║\n" ..
            "║ Per wave:     %-3d boxes (%d×%d zones)    ║\n" ..
            "║                                           ║\n" ..
            "║ Real-time FPS: %-6.1f (LIVE)             ║\n" ..
            "║ Average FPS:   %-6.1f                     ║\n" ..
            "║ Last Wave:     %-6s                      ║\n" ..
            "║                                           ║\n" ..
            "╠═══════════════════════════════════════════╣\n" ..
            "║ CLICK button below to spawn next wave    ║\n" ..
            "║ (Spawns in ALL %d zones simultaneously)  ║\n" ..
            "╚═══════════════════════════════════════════╝",
            currentWave,
            totalBoxes, initialBoxes, totalBoxes - initialBoxes,
            TOTAL_BOXES_PER_WAVE, BOXES_PER_ZONE_WAVE, TOTAL_ZONES,
            currentFps,
            avgFps,
            lastWaveFps,
            TOTAL_ZONES
        )
        return
    end
    
    -- 自动模式 UI
    local statusText = testRunning and "AUTO RUN" or "STOPPED"
    local statusColor = testRunning and "[YELLOW]" or "[RED]"
    
    if not testRunning then
        instructionText.text = string.format(
            "╔═══════════════════════════════════════════╗\n" ..
            "║  PHYSICS STRESS TEST v2.0 - STOPPED      ║\n" ..
            "╠═══════════════════════════════════════════╣\n" ..
            "║                                           ║\n" ..
            "║ Current Wave: %-5d                       ║\n" ..
            "║ Total Boxes:  %-5d (%d+%d×%-2d)          ║\n" ..
            "║                                           ║\n" ..
            "║ Real-time FPS: %-6.1f (LIVE)             ║\n" ..
            "║ Average FPS:   %-6.1f                     ║\n" ..
            "║                                           ║\n" ..
            "╠═══════════════════════════════════════════╣\n" ..
            "║ Auto-spawn stopped (FPS < %d)            ║\n" ..
            "║                                           ║\n" ..
            "║ Click button below to continue            ║\n" ..
            "╚═══════════════════════════════════════════╝",
            currentWave,
            totalBoxes, initialBoxes, TOTAL_BOXES_PER_WAVE, currentWave,
            currentFps,
            avgFps,
            FPS_THRESHOLD
        )
    else
        instructionText.text = string.format(
            "╔═══════════════════════════════════════════╗\n" ..
            "║ PHYSICS STRESS TEST v2.0 - %d×%d Grid (%dZ)║\n" ..
            "╠═══════════════════════════════════════════╣\n" ..
            "║ Status: %s%-8s[RESET]                      ║\n" ..
            "║                                           ║\n" ..
            "║ Current Wave: %-5d                       ║\n" ..
            "║ Total Boxes:  %-5d (%d+%d×%-2d)          ║\n" ..
            "║ Next wave in: %-4.1fs (+%-3d boxes)       ║\n" ..
            "║                                           ║\n" ..
            "║ Real-time FPS: %-6.1f (LIVE)             ║\n" ..
            "║ Average FPS:   %-6.1f                     ║\n" ..
            "║ Last Wave:     %-6s                      ║\n" ..
            "║                                           ║\n" ..
            "║ Threshold:     %-6d FPS                  ║\n" ..
            "╚═══════════════════════════════════════════╝",
            GRID_SIZE, GRID_SIZE, TOTAL_ZONES,
            statusColor, statusText,
            currentWave,
            totalBoxes, initialBoxes, TOTAL_BOXES_PER_WAVE, currentWave,
            math.max(0, WAVE_INTERVAL - waveTimer),
            TOTAL_BOXES_PER_WAVE,
            currentFps,
            avgFps,
            lastWaveFps,
            FPS_THRESHOLD
        )
    end
end

function CalculateAverageFPS()
    if #fpsHistory == 0 then
        return 60
    end
    
    local sum = 0
    for i = 1, #fpsHistory do
        sum = sum + fpsHistory[i]
    end
    return sum / #fpsHistory
end

function SetupViewport()
    local viewport = Viewport:new(scene_, cameraNode:GetComponent("Camera"))
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    
    -- 更新 FPS 历史
    local fps = 1.0 / timeStep
    table.insert(fpsHistory, fps)
    if #fpsHistory > FPS_HISTORY_SIZE then
        table.remove(fpsHistory, 1)
    end
    
    -- 手动模式
    if manualMode then
        UpdateInstructions()
        return
    end
    
    -- 自动模式
    if not testRunning then
        UpdateInstructions()
        return
    end
    
    -- 更新波次计时器
    waveTimer = waveTimer + timeStep
    
    -- 检查是否到达波次间隔
    if waveTimer >= WAVE_INTERVAL then
        waveTimer = 0
        SpawnWave()
        
        -- 检查停止条件
        local avgFps = CalculateAverageFPS()
        
        if avgFps < FPS_THRESHOLD and currentWave > 3 then
            testRunning = false
            Print("")
            Print("========================================")
            Print("Auto-spawn stopped! FPS dropped below " .. FPS_THRESHOLD)
            Print("Final wave: " .. currentWave)
            Print("Total boxes: " .. totalBoxes)
            Print("Average FPS: " .. string.format("%.1f", avgFps))
            Print("========================================")
        end
    end
    
    UpdateInstructions()
end

function Print(message)
    print(message)
end

