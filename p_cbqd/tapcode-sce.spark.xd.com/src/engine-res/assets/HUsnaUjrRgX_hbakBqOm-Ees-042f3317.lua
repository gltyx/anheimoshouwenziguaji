-- ============================================================================
-- UrhoX 2D Physics Scaffold (2D 物理游戏开发脚手架)
-- 版本: 2.1
-- 用途: 包含 Box2D 物理系统的 2D 游戏起点
-- UI 系统: urhox-libs/UI (Yoga Flexbox + NanoVG, 40+ 内置控件)
-- 渲染方式: Scene/Viewport (Box2D 物理需要场景) + UI 叠加层
-- 分辨率缩放: UI.Scale.DEFAULT (DPR + 小屏密度自适应)
--             尺寸遵循 CSS/Web 常识: 按钮 40-48px, 字体 14-16px, 间距 8/16/24px
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
local uiRoot_ = nil   -- UI 根控件引用
local debugDraw_ = false

-- 游戏配置
local CONFIG = {
    Title = "AI Generated Physics Game",
    Width = 1280,
    Height = 720,
    Gravity = 9.81,
    PixelPerUnit = 100.0 -- 2D 游戏常用：1 物理单位 = 100 像素
}

-- ============================================================================
-- 2. 生命周期函数 (Lifecycle Functions)
-- ============================================================================

function Start()
    -- 设置窗口标题
    graphics.windowTitle = CONFIG.Title
    
    -- 1. 初始化 UI 系统 (自动处理 NanoVG、事件订阅和渲染)
    InitUI()
    
    -- 2. 创建场景和物理世界 (Box2D 需要 Scene)
    CreateScene()
    
    -- 3. 设置视口和摄像机 (Box2D 精灵需要 Viewport 渲染)
    SetupViewport()
    
    -- 4. 创建游戏内容 (AI 在这里填充)
    CreateGameContent()
    
    -- 5. 创建 UI (使用 urhox-libs/UI 控件库)
    CreateUI()
    
    -- 6. 订阅事件
    SubscribeToEvents()
    
    print("=== Physics Game Started: " .. CONFIG.Title .. " ===")
end

function Stop()
    -- 清理 UI 系统 (自动清理 NanoVG 上下文和所有控件)
    UI.Shutdown()
end

-- ============================================================================
-- 3. 初始化辅助函数 (Initialization Helpers)
-- ============================================================================

function InitUI()
    -- ⚠️ 关键: UI.Init 替代了手动 nvgCreate / nvgCreateFont
    -- autoEvents 默认开启，自动处理 input + update + render，无需手动订阅 NanoVGRender
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

function CreateScene()
    scene_ = Scene()
    
    -- 创建八叉树 (用于渲染查询)
    scene_:CreateComponent("Octree")
    
    -- 创建调试渲染器 (用于物理调试)
    scene_:CreateComponent("DebugRenderer")
    
    -- 创建物理世界
    local physicsWorld = scene_:CreateComponent("PhysicsWorld2D")
    physicsWorld.gravity = Vector2(0, -CONFIG.Gravity)
    physicsWorld.drawShape = true -- 允许调试绘制
end

function SetupViewport()
    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    
    -- 2D 游戏通常使用正交投影
    camera.orthographic = true
    camera.orthoSize = CONFIG.Height / CONFIG.PixelPerUnit
    
    -- 设置相机位置 (Z = -10 保证能看到 Z=0 的物体)
    cameraNode_.position = Vector3(0, 0, -10)
    
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    -- 核心更新循环
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    
    -- 输入事件
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    
    -- 物理碰撞事件 (Box2D)
    SubscribeToEvent("PhysicsBeginContact2D", "HandleCollisionBegin")
    
    -- ⚠️ 注意: 不需要手动订阅 NanoVGRender
    -- UI 系统通过 autoEvents 自动处理渲染周期
end

-- ============================================================================
-- 4. 游戏逻辑 (Game Logic) - AI 填充区域
-- ============================================================================

function CreateGameContent()
    -- [AI TODO]: 在这里创建游戏对象、角色、地图等
    print("Creating physics game content...")
    
    -- 示例：创建一个地面
    -- local ground = scene_:CreateChild("Ground")
    -- local body = ground:CreateComponent("RigidBody2D")
    -- local shape = ground:CreateComponent("CollisionBox2D")
end

function CreateUI()
    -- ⚠️ 关键三步: UI.Init() → 构建控件树 → UI.SetRoot()
    -- 忘记调用 UI.SetRoot() 是最常见的错误！
    
    uiRoot_ = UI.Panel {
        id = "gameUI",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",  -- SetRoot 会自动设置，这里显式写出便于理解
        children = {
            -- [AI TODO]: 在这里添加游戏 HUD
            -- 例如: CreateHUDPanel(),
            -- 💡 适配手机刘海屏: UI.SafeAreaView { width = "100%", height = "100%", children = { ... } }
            
            -- 脚手架占位卡片 (开发时可见，正式开发时删除)
            CreatePlaceholderCard(),
            
            -- 调试信息面板 (按 Z 键切换)
            CreateDebugPanel(),
            
            -- 底部提示文字
            UI.Label {
                id = "instructionLabel",
                text = "Press 'Z' to toggle physics debug",
                fontSize = 12,
                fontColor = { 255, 255, 255, 200 },
                position = "absolute",
                bottom = 20,
                left = 0,
                right = 0,
                textAlign = "center",
            },
        }
    }
    
    -- ⚠️ 必须调用 SetRoot，否则 UI 不会渲染！
    UI.SetRoot(uiRoot_)
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    
    -- [AI TODO]: 更新游戏逻辑
    
    -- 物理调试绘制 (每帧调用，DebugRenderer 只保留一帧)
    if debugDraw_ then
        local physicsWorld = scene_:GetComponent("PhysicsWorld2D")
        if physicsWorld then
            physicsWorld:DrawDebugGeometry()
        end
    end
end

---@param eventType string
---@param eventData PostUpdateEventData
function HandlePostUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    
    -- 相机跟随逻辑通常放在这里
    -- if scene_:GetChild("Player", true) then
    --     local player = scene_:GetChild("Player", true)
    --     cameraNode_.position2D = player.position2D
    -- end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    if key == KEY_Z then
        debugDraw_ = not debugDraw_
        local debugPanel = uiRoot_:FindById("debugPanel")
        if debugPanel then
            debugPanel:SetVisible(debugDraw_)
        end
        print("Physics Debug: " .. (debugDraw_ and "ON" or "OFF"))
    end
    
    -- [AI TODO]: 处理其他按键
end

---@param eventType string
---@param eventData PhysicsBeginContact2DEventData
function HandleCollisionBegin(eventType, eventData)
    -- [AI TODO]: 处理物理碰撞
    local nodeA = eventData["NodeA"]:GetPtr("Node")
    local nodeB = eventData["NodeB"]:GetPtr("Node")
end

-- ============================================================================
-- 5. UI 构建辅助函数 (UI Builder Helpers)
-- ============================================================================

--- 脚手架占位卡片 (展示 UI 系统已就绪，正式开发时删除此函数)
function CreatePlaceholderCard()
    return UI.Panel {
        id = "placeholderCard",
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                width = "90%",
                maxWidth = 360,  -- 大屏限制最大宽度，小屏自适应
                padding = 32,
                gap = 12,
                backgroundColor = { 30, 35, 50, 230 },
                borderRadius = 16,
                borderWidth = 1,
                borderColor = { 80, 90, 120, 100 },
                alignItems = "center",
                overflow = "hidden",
                pointerEvents = "auto",
                children = {
                    UI.Label {
                        text = CONFIG.Title,
                        fontSize = 20,
                        fontColor = { 255, 255, 255, 255 },
                    },
                    UI.Label {
                        text = "Scaffold Ready",
                        fontSize = 12,
                        fontColor = { 140, 160, 200, 180 },
                    },
                    UI.Button {
                        text = "OK",
                        variant = "primary",
                        marginTop = 4,
                        onClick = function(self)
                            local card = uiRoot_:FindById("placeholderCard")
                            if card then card:Hide() end
                        end,
                    },
                }
            }
        }
    }
end

--- 创建调试信息面板
function CreateDebugPanel()
    return UI.Panel {
        id = "debugPanel",
        visible = false,  -- 默认隐藏，按 Z 键切换
        position = "absolute",
        top = 10,
        left = 10,
        padding = 8,
        backgroundColor = { 0, 0, 0, 160 },
        borderRadius = 4,
        pointerEvents = "none",  -- 调试面板不拦截输入
        children = {
            UI.Label {
                id = "debugLabel",
                text = "Physics Debug: ON",
                fontSize = 12,
                fontColor = { 255, 255, 255, 255 },
            },
        }
    }
end

--- 创建 HUD 面板示例 (生命值、分数等)
--- [AI TODO]: 根据游戏需求定制，取消注释并加入 CreateUI 的 children 中
function CreateHUDPanel()
    return UI.Panel {
        id = "hud",
        position = "absolute",
        top = 16,
        right = 16,
        padding = 12,
        gap = 8,
        backgroundColor = { 0, 0, 0, 160 },
        borderRadius = 8,
        pointerEvents = "none",  -- HUD 不拦截输入
        children = {
            UI.Label {
                id = "scoreLabel",
                text = "Score: 0",
                fontSize = 16,
                fontColor = { 255, 255, 255, 255 },
            },
        }
    }
end

--- 更新分数显示示例
function UpdateScoreDisplay(score)
    local label = uiRoot_:FindById("scoreLabel")
    if label then
        label:SetText("Score: " .. tostring(score))
    end
end
