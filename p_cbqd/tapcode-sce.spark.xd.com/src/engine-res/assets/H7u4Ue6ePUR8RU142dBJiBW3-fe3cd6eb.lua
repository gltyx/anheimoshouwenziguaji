--[[
    CEParticle Viewer Sample

    功能：
    1. 扫描资源目录下的 .effect 文件
    2. 使用 VirtualList 展示
    3. 双击播放粒子效果

    使用 urhox-libs/UI 制作界面
]]

local UI = require("urhox-libs/UI")

-- ============ 配置 ============
local CONFIG = {
    ITEM_HEIGHT = 40,
    ITEM_GAP = 2,
    LIST_WIDTH = 350,
}

-- ============ 全局变量 ============
local scene = nil
local cameraNode = nil
local currentParticleNode = nil
local effectFiles = {}
local virtualList = nil
local statusLabel = nil
local convertedEffects = {}  -- 记录已转换的资源路径

-- ============ 场景初始化 ============
local function SetupScene()
    local cache = GetCache()

    scene = Scene()
    scene:CreateComponent("Octree")

    -- 创建 Zone 组件设置环境光和背景色
    local zoneNode = scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.3, 0.3, 0.3)
    zone.fogColor = Color(0.0, 0.0, 0.0)
    zone.fogStart = 100.0
    zone.fogEnd = 300.0

    -- 创建摄像机
    cameraNode = scene:CreateChild("Camera")
    local camera = cameraNode:CreateComponent("Camera")
    camera.farClip = 1000.0
    cameraNode:SetPosition(Vector3(0, 2, -5))
    cameraNode:LookAt(Vector3(0, 0, 0))

    -- 设置视口
    local renderer = GetRenderer()
    local viewport = Viewport(scene, camera)
    renderer:SetViewport(0, viewport)

    -- 创建光源
    local lightNode = scene:CreateChild("Light")
    lightNode:SetDirection(Vector3(0.5, -1.0, 0.5))
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(1.0, 1.0, 1.0)

    -- 创建地面参考平面
    local floorNode = scene:CreateChild("Floor")
    floorNode:SetPosition(Vector3(0.0, -1.0, 0.0))
    floorNode:SetScale(Vector3(20.0, 0.01, 20.0))
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel.model = cache:GetResource("Model", "Models/Box.mdl")
    floorModel.material = cache:GetResource("Material", "Materials/Stone.xml")

    -- 测试立方体（确认场景可见）

end

-- ============ 粒子播放 ============
local function PlayParticle(effectPath)
    print("[CEParticleViewer] === PlayParticle called ===")
    print("[CEParticleViewer] Path: " .. tostring(effectPath))

    -- 清除之前的粒子
    if currentParticleNode then
        currentParticleNode:Remove()
        currentParticleNode = nil
    end

    local cache = GetCache()

    -- 加载粒子系统
    local particleSystem = cache:GetResource("CEParticleSystem", effectPath, false)
    if not particleSystem then
        local msg = "Failed to load: " .. effectPath
        if statusLabel then
            statusLabel:SetText(msg)
        end
        print("[CEParticleViewer] " .. msg)
        return false
    end

    print("[CEParticleViewer] Resource loaded OK")
    print("[CEParticleViewer] Effect count: " .. tostring(particleSystem:GetEffectNum()))

    -- 第一次加载时转换粒子系统（坐标系 Z-up -> Y-up，单位 cm -> m）
    if not convertedEffects[effectPath] then
        -- scale=0.01 (cm->m), convertAxis=true (X->Z, Y->X, Z->Y)
        CEParticleConverter:ConvertSystem(particleSystem, 0.01, true)
        convertedEffects[effectPath] = true
        print("[CEParticleViewer] Converted particle system in memory")
    else
        print("[CEParticleViewer] Already converted, skip")
    end

    -- 使用 CreateInstance 创建粒子实例
    currentParticleNode = particleSystem:CreateInstance(false)
    if not currentParticleNode then
        local msg = "Failed to create instance: " .. effectPath
        if statusLabel then
            statusLabel:SetText(msg)
        end
        print("[CEParticleViewer] " .. msg)
        return false
    end

    -- 添加到场景（无需运行时旋转和缩放，数据已在内存中转换）
    scene:AddChild(currentParticleNode)
    currentParticleNode:SetPosition(Vector3(0, 0, 0))

    print("[CEParticleViewer] Node created, children: " .. tostring(currentParticleNode:GetNumChildren()))

    -- 获取所有 emitter 并调用 Reset() 开始播放
    -- emitter 组件直接在节点本身上，不是子节点
    local emitterTypes = {
        "CEParticleEmitter",
        "CEParticleMeshEmitter",
        "CEParticleRibbonEmitter",
        "CEParticleBeamEmitter",
    }
    for _, emitterType in ipairs(emitterTypes) do
        local emitters = currentParticleNode:GetComponents(emitterType)
        for i = 1, #emitters do
            emitters[i]:Reset()
            print("[CEParticleViewer] Reset emitter: " .. emitterType)
        end
    end

    if statusLabel then
        statusLabel:SetText("Playing: " .. effectPath)
    end
    return true
end

-- ============ 原始粒子播放（不转换）============
local function PlayParticleRaw(effectPath)
    print("[CEParticleViewer] === PlayParticleRaw called (no conversion) ===")
    print("[CEParticleViewer] Path: " .. tostring(effectPath))

    -- 清除之前的粒子
    if currentParticleNode then
        currentParticleNode:Remove()
        currentParticleNode = nil
    end

    local cache = GetCache()

    -- 加载粒子系统
    local particleSystem = cache:GetResource("CEParticleSystem", effectPath, false)
    if not particleSystem then
        local msg = "Failed to load: " .. effectPath
        if statusLabel then
            statusLabel:SetText(msg)
        end
        print("[CEParticleViewer] " .. msg)
        return false
    end

    print("[CEParticleViewer] Resource loaded OK (raw, no conversion)")
    print("[CEParticleViewer] Effect count: " .. tostring(particleSystem:GetEffectNum()))

    -- 不做任何转换，直接使用原始数据

    -- 使用 CreateInstance 创建粒子实例
    currentParticleNode = particleSystem:CreateInstance(false)
    if not currentParticleNode then
        local msg = "Failed to create instance: " .. effectPath
        if statusLabel then
            statusLabel:SetText(msg)
        end
        print("[CEParticleViewer] " .. msg)
        return false
    end

    -- 添加到场景
    scene:AddChild(currentParticleNode)
    currentParticleNode:SetPosition(Vector3(0, 0, 0))

    print("[CEParticleViewer] Node created (raw), children: " .. tostring(currentParticleNode:GetNumChildren()))

    -- 获取所有 emitter 并调用 Reset() 开始播放
    local emitterTypes = {
        "CEParticleEmitter",
        "CEParticleMeshEmitter",
        "CEParticleRibbonEmitter",
        "CEParticleBeamEmitter",
    }
    for _, emitterType in ipairs(emitterTypes) do
        local emitters = currentParticleNode:GetComponents(emitterType)
        for i = 1, #emitters do
            emitters[i]:Reset()
            print("[CEParticleViewer] Reset emitter: " .. emitterType)
        end
    end

    if statusLabel then
        statusLabel:SetText("Playing (Raw): " .. effectPath)
    end
    return true
end

-- ============ 扫描目录 ============
local function ScanEffectFiles()
    local cache = GetCache()
    local fileSystem = GetFileSystem()
    local result = {}

    -- 获取所有资源目录
    local dirs = cache:GetResourceDirs()
    if dirs then
        for i = 1, #dirs do
            local basePath = dirs[i]
            -- 扫描 .effect 文件（递归）
            local files = fileSystem:ScanDir(basePath, "*.effect", SCAN_FILES, true) or {}
            for j = 1, #files do
                table.insert(result, {
                    path = files[j],
                    name = files[j]:match("([^/\\]+)$") or files[j]
                })
            end
        end
    end

    return result
end

-- ============ VirtualList Item 创建 ============
local function CreateItemWidget()
    local item = UI.Panel {
        width = CONFIG.LIST_WIDTH - 20,
        height = CONFIG.ITEM_HEIGHT,
        flexDirection = "row",
        alignItems = "center",
        padding = 8,
        gap = 8,
        backgroundColor = { 40, 45, 55, 255 },
        borderRadius = 4,
    }

    local nameLabel = UI.Label {
        id = "name",
        text = "effect.effect",
        fontSize = 13,
        fontColor = { 220, 220, 220, 255 },
        maxLines = 1,
    }
    item:AddChild(nameLabel)

    item._nameLabel = nameLabel

    return item
end

local function BindItemWidget(widget, data, index)
    widget._nameLabel:SetText(data.path)
end

-- ============ UI 创建 ============
local function CreateUI()
    local root = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = { 0, 0, 0, 0 },
        flexDirection = "column",  -- 改为纵向布局
    }

    -- 顶部输入栏
    local topBar = UI.Panel {
        width = "100%",
        height = 50,
        flexShrink = 0,
        backgroundColor = { 30, 30, 40, 240 },
        flexDirection = "row",
        alignItems = "center",
        padding = 10,
        gap = 10,
    }
    root:AddChild(topBar)

    -- 标题
    topBar:AddChild(UI.Label {
        text = "CEParticle Viewer",
        fontSize = 14,
        fontColor = { 255, 255, 255, 255 },
        flexShrink = 0,
    })

    -- 输入框
    local pathInput = UI.TextField {
        flexGrow = 1,
        height = 32,
        placeholder = "effect/xxx/yyy.effect",
        fontSize = 12,
        onSubmit = function(widget, value)
            if value and #value > 0 then
                PlayParticle(value)
            end
        end,
    }
    topBar:AddChild(pathInput)

    -- 粘贴按钮
    local pasteButton = UI.Button {
        width = 50,
        height = 32,
        text = "Paste",
        fontSize = 12,
        flexShrink = 0,
        onClick = function()
            local clipboardText = ui:GetClipboardText()
            if clipboardText and #clipboardText > 0 then
                pathInput:SetValue(clipboardText)
            end
        end,
    }
    topBar:AddChild(pasteButton)

    -- 执行按钮
    local playButton = UI.Button {
        width = 50,
        height = 32,
        text = "Play",
        fontSize = 12,
        flexShrink = 0,
        onClick = function()
            local path = pathInput:GetValue()
            if path and #path > 0 then
                PlayParticle(path)
            end
        end,
    }
    topBar:AddChild(playButton)

    -- 第二个输入栏（原始播放，不转换）
    local rawBar = UI.Panel {
        width = "100%",
        height = 50,
        flexShrink = 0,
        backgroundColor = { 40, 35, 30, 240 },  -- 略带橙色，区分于上方
        flexDirection = "row",
        alignItems = "center",
        padding = 10,
        gap = 10,
    }
    root:AddChild(rawBar)

    -- 标题
    rawBar:AddChild(UI.Label {
        text = "Raw (No Convert)",
        fontSize = 14,
        fontColor = { 255, 200, 150, 255 },
        flexShrink = 0,
    })

    -- 输入框
    local rawPathInput = UI.TextField {
        flexGrow = 1,
        height = 32,
        placeholder = "effect/xxx/yyy.effect (already converted)",
        fontSize = 12,
        onSubmit = function(widget, value)
            if value and #value > 0 then
                PlayParticleRaw(value)
            end
        end,
    }
    rawBar:AddChild(rawPathInput)

    -- 粘贴按钮
    local rawPasteButton = UI.Button {
        width = 50,
        height = 32,
        text = "Paste",
        fontSize = 12,
        flexShrink = 0,
        onClick = function()
            local clipboardText = ui:GetClipboardText()
            if clipboardText and #clipboardText > 0 then
                rawPathInput:SetValue(clipboardText)
            end
        end,
    }
    rawBar:AddChild(rawPasteButton)

    -- 执行按钮
    local rawPlayButton = UI.Button {
        width = 50,
        height = 32,
        text = "Play",
        fontSize = 12,
        flexShrink = 0,
        backgroundColor = { 180, 120, 60, 255 },  -- 橙色按钮
        onClick = function()
            local path = rawPathInput:GetValue()
            if path and #path > 0 then
                PlayParticleRaw(path)
            end
        end,
    }
    rawBar:AddChild(rawPlayButton)

    -- 下方内容区域
    local contentArea = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexDirection = "row",
    }
    root:AddChild(contentArea)

    -- 左侧面板
    local leftPanel = UI.Panel {
        width = CONFIG.LIST_WIDTH,
        height = "100%",
        backgroundColor = { 30, 30, 40, 240 },
        flexDirection = "column",
        padding = 12,
        gap = 8,
    }
    contentArea:AddChild(leftPanel)

    -- 文件数量
    leftPanel:AddChild(UI.Label {
        text = #effectFiles .. " effect files",
        fontSize = 12,
        fontColor = { 150, 150, 150, 255 },
    })

    -- VirtualList 容器
    local listContainer = UI.Panel {
        width = "100%",
        flexGrow = 1,
        backgroundColor = { 20, 20, 30, 200 },
        borderRadius = 4,
        overflow = "hidden",
    }
    leftPanel:AddChild(listContainer)

    -- VirtualList
    virtualList = UI.VirtualList {
        width = "100%",
        height = "100%",
        data = effectFiles,
        itemHeight = CONFIG.ITEM_HEIGHT,
        itemGap = CONFIG.ITEM_GAP,
        poolBuffer = 3,
        createItem = CreateItemWidget,
        bindItem = BindItemWidget,
        onItemClick = function(data, index, widget)
            PlayParticle(data.path)
        end,
    }
    listContainer:AddChild(virtualList)

    -- 状态栏
    local statusBar = UI.Panel {
        width = "100%",
        height = 30,
        flexShrink = 0,  -- 防止被压缩
        backgroundColor = { 20, 20, 30, 200 },
        borderRadius = 4,
        padding = 8,
        justifyContent = "center",
        marginTop = 8,
    }
    leftPanel:AddChild(statusBar)

    statusLabel = UI.Label {
        text = "Ready",
        fontSize = 12,
        fontColor = { 150, 150, 150, 255 },
    }
    statusBar:AddChild(statusLabel)

    return root
end

-- ============ 主入口 ============
function Start()
    -- 设置窗口标题
    graphics.windowTitle = "CEParticle Viewer"

    -- 启用系统剪切板
    ui:SetUseSystemClipboard(true)

    -- 初始化场景
    SetupScene()

    -- 扫描 .effect 文件（暂时关闭，使用输入框加载）
    -- effectFiles = ScanEffectFiles()
    -- print("[CEParticleViewer] Found " .. #effectFiles .. " effect files")

    -- 初始化 UI
    UI.Init({
        fonts = {
            { name = "sans", path = "Fonts/MiSans-Regular.ttf" },
        },
        autoEvents = true,
        designSize = 1080,
    })

    UI.SetRoot(CreateUI())

    print("[CEParticleViewer] Started")
end

function Stop()
    UI.Shutdown()
end

-- ============ 相机控制 ============
local yaw = 0
local pitch = 0
local MOVE_SPEED = 10.0
local MOUSE_SENSITIVITY = 0.1

SubscribeToEvent("Update", function(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- 鼠标在 UI 区域外（x > 350）才控制相机
    local mousePos = input.mousePosition
    local inViewport = mousePos.x > CONFIG.LIST_WIDTH

    -- 右键按住时旋转相机
    if inViewport and input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local mouseMove = input.mouseMove
        yaw = yaw + MOUSE_SENSITIVITY * mouseMove.x
        pitch = pitch + MOUSE_SENSITIVITY * mouseMove.y
        pitch = Clamp(pitch, -90.0, 90.0)
        cameraNode.rotation = Quaternion(pitch, yaw, 0.0)
    end

    -- WASD 移动（任何时候都可以）
    if cameraNode then
        local speed = MOVE_SPEED * timeStep
        if input:GetKeyDown(KEY_W) then
            cameraNode:Translate(Vector3(0, 0, 1) * speed)
        end
        if input:GetKeyDown(KEY_S) then
            cameraNode:Translate(Vector3(0, 0, -1) * speed)
        end
        if input:GetKeyDown(KEY_A) then
            cameraNode:Translate(Vector3(-1, 0, 0) * speed)
        end
        if input:GetKeyDown(KEY_D) then
            cameraNode:Translate(Vector3(1, 0, 0) * speed)
        end
        if input:GetKeyDown(KEY_Q) then
            cameraNode:Translate(Vector3(0, -1, 0) * speed)
        end
        if input:GetKeyDown(KEY_E) then
            cameraNode:Translate(Vector3(0, 1, 0) * speed)
        end
    end
end)
