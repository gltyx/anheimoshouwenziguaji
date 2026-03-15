-- ============================================================================
-- UrhoX 3D Scene Scaffold (3D 场景展示脚手架)
-- 版本: 1.1
-- 用途: 3D 场景展示、可视化、自由相机漫游（不含角色控制）
-- 分辨率缩放: UI.Scale.DEFAULT (DPR + 小屏密度自适应)
--             尺寸遵循 CSS/Web 常识: 按钮 40-48px, 字体 14-16px, 间距 8/16/24px
-- 
-- ⚠️ 注意：如果你要做角色游戏（如 Fall Guys、Roblox、马里奥3D），
--          请使用 scaffold-3d-character.lua 而不是这个文件！
-- 
-- 适用场景：
--   ✅ 建筑漫游、3D 可视化
--   ✅ 产品展示、教育展示
--   ✅ 静态场景、自由视角游戏
--   ❌ 不适合需要角色控制的游戏（请用 scaffold-3d-character.lua）
--
-- 📖 必读文档（做3D游戏前必须阅读）：
--   1. recipes/materials.md - PBR材质参数详解
--   2. recipes/rendering.md - 光照配置和LightGroup预设
--   3. built-in-models.md - 内置模型尺寸参考
-- ============================================================================

-- 引入 UI 系统 (Yoga Flexbox + NanoVG, 40+ 内置控件)
local UI = require("urhox-libs/UI")

-- ============================================================================
-- 1. 全局变量声明 (Global Variables)
-- ============================================================================
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
local yaw_ = 0.0
local pitch_ = 0.0
local debugDraw_ = false

-- 游戏配置
local CONFIG = {
    Title = "AI Generated 3D Game",
    Width = 1280,
    Height = 720,
    CameraSpeed = 20.0,      -- 相机移动速度
    MouseSensitivity = 0.1,  -- 鼠标灵敏度
    CameraNearClip = 0.1,    -- 近裁剪面
    CameraFarClip = 1000.0,  -- 远裁剪面
}

-- ============================================================================
-- 2. 生命周期函数 (Lifecycle Functions)
-- ============================================================================

function Start()
    -- 设置窗口标题
    graphics.windowTitle = CONFIG.Title
    
    -- 1. 初始化 UI 系统 (自动处理 NanoVG、事件订阅和渲染)
    InitUI()
    
    -- 2. 创建场景
    CreateScene()
    
    -- 3. 设置摄像机和视口
    SetupCameraAndViewport()
    
    -- 4. 创建游戏内容 (AI 在这里填充)
    CreateGameContent()
    
    -- 5. 创建 UI (使用 urhox-libs/UI 控件库)
    CreateUI()
    
    -- 6. 订阅事件
    SubscribeToEvents()
    
    print("=== 3D Game Started: " .. CONFIG.Title .. " ===")
end

function Stop()
    -- 清理 UI 系统 (自动清理 NanoVG 上下文和所有控件)
    UI.Shutdown()
end

-- ============================================================================
-- 3. 初始化辅助函数 (Initialization Helpers)
-- ============================================================================

function CreateScene()
    scene_ = Scene()
    
    -- 创建八叉树 (用于渲染优化)
    scene_:CreateComponent("Octree")
    
    -- 创建调试渲染器 (用于调试可视化)
    scene_:CreateComponent("DebugRenderer")
    
    -- ✅ 最佳实践：使用 LightGroup 加载预设光照环境
    -- LightGroup 包含完整的光照配置（定向光、环境光、雾效等）
    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())
    
    -- 可选：如果需要物理系统，取消下面的注释
    -- local physicsWorld = scene_:CreateComponent("PhysicsWorld")
    -- physicsWorld:SetGravity(Vector3(0, -9.81, 0))
end

function SetupCameraAndViewport()
    -- 创建摄像机节点
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 2, -10)  -- 初始位置
    
    -- 添加摄像机组件
    local camera = cameraNode_:CreateComponent("Camera")
    camera.nearClip = CONFIG.CameraNearClip
    camera.farClip = CONFIG.CameraFarClip
    camera.fov = 75.0  -- 视野角度
    
    -- 设置视口
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
    
    -- ✅ 最佳实践：开启 HDR 渲染（用于 PBR 材质）
    renderer.hdrRendering = true
    
    -- 初始化相机朝向
    yaw_ = 0.0
    pitch_ = 0.0
end

-- ============================================================================
-- 4. 游戏内容创建 (Game Content - AI 填充区域)
-- ============================================================================

function CreateGameContent()
    -- ⚠️ AI 提示: 在这里创建游戏对象
    -- 
    -- ✅ 最佳实践：使用 PBR 材质系统
    -- PBR (Physically Based Rendering) 材质提供真实的光照效果
    -- 
    -- 示例 1: 创建带 PBR 材质的方块
    -- local boxNode = scene_:CreateChild("Box")
    -- boxNode.position = Vector3(0, 0, 0)
    -- local boxModel = boxNode:CreateComponent("StaticModel")
    -- boxModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    -- 
    -- -- 创建 PBR 材质 (使用 PBRNoTexture)
    -- local material = Material:new()
    -- material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    -- material:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.6, 0.4, 1.0)))  -- 漫反射颜色
    -- material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))  -- 高光颜色
    -- material:SetShaderParameter("Metallic", Variant(0.5))    -- 金属度 (0=非金属, 1=金属)
    -- material:SetShaderParameter("Roughness", Variant(0.5))   -- 粗糙度 (0=光滑, 1=粗糙)
    -- boxModel:SetMaterial(material)
    -- boxModel.castShadows = true
    --
    -- 示例 2: 常见材质类型
    -- 金属：   Metallic = 0.9,  Roughness = 0.2  (光滑金属)
    -- 塑料：   Metallic = 0.0,  Roughness = 0.5  (塑料感)
    -- 橡胶：   Metallic = 0.0,  Roughness = 0.8  (粗糙橡胶)
    -- 木头：   Metallic = 0.0,  Roughness = 0.7  (木质感)
    -- 发光：   额外设置 MatEmissiveColor 参数
    
    -- ============================================================
    -- 下面是示例代码（可删除）
    -- ============================================================
    
    -- 1. 创建地面（粗糙的深灰色）
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = Vector3(0, -0.5, 0)
    floorNode.scale = Vector3(100, 1, 100)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.2, 0.25, 1.0)))
    floorMat:SetShaderParameter("MatSpecColor", Variant(Color(0.3, 0.3, 0.3, 1.0)))
    floorMat:SetShaderParameter("Metallic", Variant(0.0))
    floorMat:SetShaderParameter("Roughness", Variant(0.9))
    floorModel:SetMaterial(floorMat)
    floorModel.castShadows = false
    
    -- 2. 创建示例方块（不同材质）
    CreateSampleBox(Vector3(-3, 0.5, 0), Color(0.8, 0.3, 0.2), 0.1, 0.6, "Box1")  -- 塑料质感
    CreateSampleBox(Vector3(0, 0.5, 0), Color(0.9, 0.7, 0.3), 0.95, 0.1, "Box2")  -- 金属质感
    CreateSampleBox(Vector3(3, 0.5, 0), Color(0.3, 0.6, 0.9), 0.0, 0.8, "Box3")   -- 橡胶质感
    
    -- 3. 创建示例球体（光滑金属）
    local sphereNode = scene_:CreateChild("Sphere")
    sphereNode.position = Vector3(0, 2, 5)
    local sphereModel = sphereNode:CreateComponent("StaticModel")
    sphereModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    
    local sphereMat = Material:new()
    sphereMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    sphereMat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.6, 0.2, 1.0)))
    sphereMat:SetShaderParameter("MatSpecColor", Variant(Color(0.8, 0.8, 0.8, 1.0)))
    sphereMat:SetShaderParameter("Metallic", Variant(0.9))
    sphereMat:SetShaderParameter("Roughness", Variant(0.2))
    sphereModel:SetMaterial(sphereMat)
    sphereModel.castShadows = true
    
    print("✅ Scene created with PBR materials and lighting")
end

-- 辅助函数：创建带 PBR 材质的方块
function CreateSampleBox(position, color, metallic, roughness, name)
    local boxNode = scene_:CreateChild(name)
    boxNode.position = position
    local boxModel = boxNode:CreateComponent("StaticModel")
    boxModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(color))
    material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    boxModel:SetMaterial(material)
    boxModel.castShadows = true
end

-- ============================================================================
-- 5. UI 创建 (UI Creation)
-- ============================================================================

local uiRoot_ = nil  -- UI 根控件引用

function InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
                -- bold = "Fonts/MiSans-Bold.ttf",  -- 取消注释后可在 Label 中使用 fontWeight = "bold"
            } }
        },
        -- 推荐! DPR 缩放 + 小屏密度自适应（见 ui.md §10）
        -- 1 基准像素 ≈ 1 CSS 像素，尺寸遵循 CSS/Web 常识
        scale = UI.Scale.DEFAULT,
    })
end

function CreateUI()
    -- ⚠️ 关键三步: UI.Init() → 构建控件树 → UI.SetRoot()
    uiRoot_ = UI.Panel {
        id = "gameUI",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",  -- SetRoot 会自动设置，这里显式写出便于理解
        children = {
            -- 顶部操作提示
            UI.Label {
                text = "WASD: Move | Mouse Right: Look | Space: Up | C: Down | Tab: Debug",
                fontSize = 12,
                fontColor = { 255, 255, 200, 200 },
                position = "absolute",
                top = 10,
                left = 0,
                right = 0,
                textAlign = "center",
            },
        }
    }
    
    UI.SetRoot(uiRoot_)
end

-- ============================================================================
-- 6. 事件处理 (Event Handlers)
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    -- 相机控制
    HandleCameraMovement(dt)
    
    -- 游戏逻辑更新 (AI 填充)
    UpdateGameLogic(dt)
    
    -- 调试开关
    if input:GetKeyPress(KEY_TAB) then
        debugDraw_ = not debugDraw_
    end
end

---@param eventType string
---@param eventData PostRenderUpdateEventData
function HandlePostRenderUpdate(eventType, eventData)
    if debugDraw_ then
        -- 绘制调试信息
        local debugRenderer = scene_:GetComponent("DebugRenderer")
        if debugRenderer ~= nil then
            -- 绘制八叉树边界
            debugRenderer:AddBoundingBox(
                BoundingBox(Vector3(-50, -50, -50), Vector3(50, 50, 50)),
                Color(0, 1, 0),
                false
            )
            
            -- 绘制坐标轴
            debugRenderer:AddLine(
                Vector3(0, 0, 0),
                Vector3(5, 0, 0),
                Color(1, 0, 0),  -- X轴 红色
                false
            )
            debugRenderer:AddLine(
                Vector3(0, 0, 0),
                Vector3(0, 5, 0),
                Color(0, 1, 0),  -- Y轴 绿色
                false
            )
            debugRenderer:AddLine(
                Vector3(0, 0, 0),
                Vector3(0, 0, 5),
                Color(0, 0, 1),  -- Z轴 蓝色
                false
            )
        end
    end
end

-- ============================================================================
-- 7. 游戏逻辑 (Game Logic - AI 填充区域)
-- ============================================================================

function UpdateGameLogic(dt)
    -- 示例: 让球体缓慢旋转
    local sphereNode = scene_:GetChild("Sphere")
    if sphereNode ~= nil then
        sphereNode:Rotate(Quaternion(0, 30 * dt, 0))  -- 每秒旋转30度
    end
    
    -- ⚠️ AI 提示: 在这里添加更多游戏逻辑
end

-- ============================================================================
-- 8. 相机控制 (Camera Control)
-- ============================================================================

function HandleCameraMovement(dt)
    -- 鼠标控制视角（右键按下时）
    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local mouseMoveX = input.mouseMoveX
        local mouseMoveY = input.mouseMoveY
        
        yaw_ = yaw_ + mouseMoveX * CONFIG.MouseSensitivity
        pitch_ = pitch_ + mouseMoveY * CONFIG.MouseSensitivity
        pitch_ = Clamp(pitch_, -90.0, 90.0)
        
        cameraNode_.rotation = Quaternion(pitch_, yaw_, 0)
    end
    
    -- 键盘控制移动
    local moveSpeed = CONFIG.CameraSpeed
    if input:GetKeyDown(KEY_SHIFT) then
        moveSpeed = moveSpeed * 2.0  -- 加速
    end
    
    if input:GetKeyDown(KEY_W) then
        cameraNode_:Translate(Vector3(0, 0, 1) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_S) then
        cameraNode_:Translate(Vector3(0, 0, -1) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_A) then
        cameraNode_:Translate(Vector3(-1, 0, 0) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_D) then
        cameraNode_:Translate(Vector3(1, 0, 0) * dt * moveSpeed)
    end
    if input:GetKeyDown(KEY_SPACE) then
        cameraNode_:Translate(Vector3(0, 1, 0) * dt * moveSpeed, TS_WORLD)
    end
    if input:GetKeyDown(KEY_C) then
        cameraNode_:Translate(Vector3(0, -1, 0) * dt * moveSpeed, TS_WORLD)
    end
end

-- ============================================================================
-- 9. 辅助函数 (Utility Functions)
-- ============================================================================

function Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- ============================================================================
-- 使用说明 (Usage Instructions)
-- ============================================================================
--[[
    这个脚手架提供了 3D 游戏开发的基础框架，包括：
    
    ✅ 场景管理 (Scene)
    ✅ 摄像机控制 (WASD移动 + 鼠标视角)
    ✅ PBR 材质系统 (物理真实感渲染)
    ✅ HDR 渲染
    ✅ 专业光照环境 (LightGroup)
    ✅ 调试渲染 (按Tab切换)
    ✅ UI 系统
    ✅ 事件系统
    
    AI 需要填充的区域：
    1. CreateGameContent() - 创建游戏对象、材质等
    2. UpdateGameLogic() - 更新游戏逻辑
    
    ============================================================
    PBR 材质系统使用指南 (⭐ PBRNoTexture)
    ============================================================
    
    基本用法：
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", 
        "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(R, G, B, 1.0)))
    material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    model:SetMaterial(material)
    
    PBR 参数说明：
    - MatDiffColor: 漫反射颜色 Color(R, G, B, A)
    - MatSpecColor: 高光颜色 Color(R, G, B, A)（通常 0.5 左右）
    - Metallic: 金属度 (0.0 = 非金属, 1.0 = 金属)
    - Roughness: 粗糙度 (0.0 = 光滑镜面, 1.0 = 完全粗糙)
    
    常见材质配置：
    - 光滑金属: Metallic=0.95, Roughness=0.1
    - 粗糙金属: Metallic=0.9,  Roughness=0.5
    - 塑料:     Metallic=0.0,  Roughness=0.5
    - 橡胶:     Metallic=0.0,  Roughness=0.8
    - 木头:     Metallic=0.0,  Roughness=0.7
    - 玻璃:     Metallic=0.0,  Roughness=0.0
    
    发光材质（额外参数）：
    material:SetShaderParameter("MatEmissiveColor", Variant(Color(R, G, B)))  -- 自发光颜色
    
    ============================================================
    常用资源路径
    ============================================================
    
    Models（内置模型）：
    - "Models/Box.mdl"       (方块)
    - "Models/Sphere.mdl"    (球体)
    - "Models/Cylinder.mdl"  (圆柱)
    - "Models/Cone.mdl"      (圆锥)
    - "Models/Plane.mdl"     (平面)
    - "Models/Torus.mdl"     (圆环)
    
    LightGroup（光照预设）：
    - "LightGroup/Daytime.xml"   (白天)
    - "LightGroup/Night.xml"     (夜晚)
    - "LightGroup/Dusk.xml"    (黄昏)
    
    Fonts（字体）：
    - "Fonts/MiSans-Regular.ttf"
    
    ⚠️ 重要：获取模型尺寸
    方法1: 使用 model.boundingBox.size 动态获取（推荐）
    方法2: 查文档 ai-dev-kit/built-in-models.md
    
    绝不要假设所有模型都是 1×1×1！
    
    ============================================================
    控制说明
    ============================================================
    - WASD: 移动摄像机
    - 鼠标右键拖动: 旋转视角
    - Space: 上升
    - C: 下降
    - Shift: 加速移动
    - Tab: 切换调试渲染
    - ESC: 退出 (Sample工具库提供)
]]

