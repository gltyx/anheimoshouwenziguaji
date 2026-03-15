-- ============================================================================
-- UrhoX 3D Third-Person Character Scaffold (第三人称角色游戏脚手架)
-- 版本: 3.1
-- 用途: 第三人称角色游戏（Fall Guys、Roblox、马里奥3D风格）+ 第三人称射击游戏
-- 参考: 83_CharacterDemo2.lua
--
-- v3.1 更新:
--   - 新增 AimOffset 组件（程序化上半身瞄准）
--   - 越肩视角相机（持枪/瞄准时自动切换）
--   - 战斗模式：角色面向相机方向，支持移动+射击
--   - 探索模式：角色面向移动方向
--   - 平滑相机过渡（距离、偏移、FOV）
--
-- v3.0 更新:
--   - 采用双 FSM 架构（Normal + Armed），类似 Unity 的多 Animator Controller
--   - Normal FSM: 单层全身动画（Locomotion + Jump）
--   - Armed FSM: 3 层架构
--     * Layer 0 (Base): RifleLocomotion BlendSpace（全身）
--     * Layer 1 (LowerBody): 跳跃动画，使用 LowerBody BoneMask
--     * Layer 2 (UpperBody): 射击/换弹动画，使用 UpperBody BoneMask
--   - Q 键切换 FSM，平滑过渡
--
-- v2.2 更新:
--   - 实现上下半身动画分离（Animation Layering + Bone Mask）
--   - 持枪行走时：下半身播放走路动画，上半身播放持枪动画
--   - 支持 SetStartBone() 骨骼遮罩
--   - 新增 DebugPrintSkeleton() 调试函数
--
-- v2.1 更新:
--   - 新增持枪状态切换（Q键）
--   - 新增射击动画（鼠标左键）
--   - 新增换弹动画（R键）
--   - 完整的 Rifle 动画状态机支持
--
-- v2.0 更新:
--   - 支持预制体加载（推荐）+ 手动配置回退
--   - AnimationStateMachine + BlendSpace1D 动画混合
--   - CharacterComponent 只处理物理，动画参数在 Lua 脚本中设置
--   - 步行/跑步模式（默认步行，Shift 跑步）
--
-- 必读文档（做3D角色游戏前必须阅读）：
--   1. recipes/materials.md - PBR材质参数详解
--   2. recipes/rendering.md - 光照配置和LightGroup预设
--   3. built-in-models.md - 内置模型尺寸参考
--   4. docs/CharacterComponent_Air_Control_System.md - 空中控制详解
--   5. templates/README.md - 完整脚手架对比
--
-- 游戏 HUD：
--   - GameHUD.Create() - 统一 HUD 创建（摇杆 + 跳跃 + 可选跑步 + 可选射击系统）
--   - GameHUD.SetControls() - 摇杆自动绑定角色控制，支持切换角色
--   - Touch.lua - 视角控制 + 双指缩放
-- ============================================================================

-- 引入工具库
require "LuaScripts/Utilities/Sample"    -- 引擎基础初始化 (触摸/鼠标模式，GameHUD 依赖)
require "LuaScripts/Utilities/Touch"     -- 触摸控制 (双指缩放等)
require "urhox-libs.UI.GameHUD"          -- 游戏 HUD (摇杆 + 按钮)
require "urhox-libs.Camera.ThirdPersonCamera"
local UI = require("urhox-libs/UI")      -- UI 系统 (Yoga Flexbox + NanoVG)

-- ============================================================================
-- 1. 全局变量声明 (Global Variables)
-- ============================================================================

---@type Scene
local scene_ = nil
---@type ThirdPersonCameraInstance
local tpCamera_ = nil
---@type CharacterComponent
local character_ = nil
---@type AnimationStateMachine
local stateMachine_ = nil
---@type JSONFile
local normalFSMFile_ = nil
---@type JSONFile
local armedFSMFile_ = nil
-- 当前状态机类型: "normal" or "armed"
local currentFSMType_ = "normal"
---@type AimOffset
local aimOffset_ = nil
-- 持枪状态
local isArmed_ = false
-- 瞄准状态（鼠标右键按住）
local isAiming_ = false

-- 游戏配置
local CONFIG = {
    Title = "Third Person Game Template",

    -- 角色配置
    CharacterStartPos = Vector3(0, 2, 0),

    -- 角色模型配置（二选一）
    -- 方式1: 使用预制体（推荐，包含完整模型+材质配置）
    CharacterPrefab = "DefaultMale/DefaultMale.prefab",
    -- 方式2: 手动配置模型（当预制体不存在时使用）
    CharacterModel = "Platforms/Models/BetaLowpoly/Beta.mdl",
    CharacterMaterials = {
        "Platforms/Materials/BetaBody_MAT.xml",
        "Platforms/Materials/BetaBody_MAT.xml",
        "Platforms/Materials/BetaJoints_MAT.xml",
    },

    -- AnimationStateMachine FSM 配置（双 FSM 架构）
    -- Normal FSM: 单层全身动画（Locomotion + Jump）
    -- Armed FSM: 3 层（Base + LowerBody 跳跃 + UpperBody 射击/换弹）
    CharacterNormalFSM = "urhox-libs/Animation/FSM/DefaultMale_Normal.fsm",
    CharacterArmedFSM = "urhox-libs/Animation/FSM/DefaultMale_Armed.fsm",

    -- 相机配置
    CameraNearClip = 0.1,
    CameraFarClip = 300.0,

    -- 空中控制配置（可根据游戏风格调整）
    -- 详见文件末尾的详细说明，或查看 docs/CharacterComponent_Air_Control_System.md
    AirControlFactor = 0.6,   -- 空中控制系数 (0-1, 0.05=Fall Guys, 0.2=Roblox, 0.4=马里奥)
    -- AirFriction = 0.0,        -- 空中摩擦力 (0=无衰减, 0.5=中等, 2.0=快速)
    -- AirSpeedRatio = 1.0,      -- 空中速度比例 (1.0=和地面一样)

    -- 步行模式（true=默认步行，按Shift跑步；false=默认跑步）
    EnableWalkMode = true,
}

-- ============================================================================
-- 2. 移动平台类 (Moving Platform Class)
-- ============================================================================

-- 平台状态常量
local PLATFORM_STATE_MOVETO_FINISH = 1
local PLATFORM_STATE_MOVETO_START = 2

MovingPlatform = ScriptObject()

function MovingPlatform:Start()
    self.maxSpeed_ = 5.0
    self.minSpeed_ = 1.5
    self.curSpeed_ = self.maxSpeed_
    self.platformState_ = PLATFORM_STATE_MOVETO_FINISH
end

--- 初始化移动平台
---@param startPos Vector3 起始位置
---@param endPos Vector3 结束位置
---@param size Vector3 平台尺寸 (默认 Vector3(4, 0.5, 4))
function MovingPlatform:Initialize(startPos, endPos, size)
    size = size or Vector3(4, 0.5, 4)

    local platformNode = scene_:CreateChild("MovingPlatform")
    platformNode.position = startPos
    -- 标记为移动平台（角色控制器会检测此标记）
    platformNode:SetVar(StringHash("IsMovingPlatform"), true)

    -- 创建平台模型
    local model = platformNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))
    model.castShadows = true
    platformNode.scale = size

    -- 创建平台刚体
    local body = platformNode:CreateComponent("RigidBody")
    body.friction = 1
    body.linearFactor = Vector3(1, 0, 1)
    body.angularFactor = Vector3.ZERO
    body.collisionLayer = CollisionLayerPlatform
    body.collisionMask = CollisionMaskPlatform
    body.useGravity = false

    -- 创建平台碰撞形状
    local shape = platformNode:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)

    -- 保存位置信息
    self.platformNode_ = platformNode
    self.initialPosition_ = startPos
    self.finishPosition_ = endPos
    self.directionToFinish_ = (endPos - startPos):Normalized()
    self.curSpeed_ = self.maxSpeed_
end

function MovingPlatform:FixedUpdate(timeStep)
    if self.platformNode_ == nil then return end

    local platformPos = self.platformNode_.position
    local newPos = platformPos

    if self.platformState_ == PLATFORM_STATE_MOVETO_FINISH then
        local curDistance = self.finishPosition_ - platformPos
        local curDirection = curDistance:Normalized()
        local dist = curDistance:Length()
        local dotd = self.directionToFinish_:DotProduct(curDirection)

        if dotd > 0.0 then
            -- 接近终点时减速
            if dist < 1.0 then
                self.curSpeed_ = self.curSpeed_ * 0.92
            end
            self.curSpeed_ = Clamp(self.curSpeed_, self.minSpeed_, self.maxSpeed_)
            newPos = newPos + curDirection * self.curSpeed_ * timeStep
        else
            newPos = self.finishPosition_
            self.curSpeed_ = self.maxSpeed_
            self.platformState_ = PLATFORM_STATE_MOVETO_START
        end
        self.platformNode_.position = newPos
    elseif self.platformState_ == PLATFORM_STATE_MOVETO_START then
        local curDistance = self.initialPosition_ - platformPos
        local curDirection = curDistance:Normalized()
        local dist = curDistance:Length()
        local dotd = self.directionToFinish_:DotProduct(curDirection)

        if dotd < 0.0 then
            -- 接近起点时减速
            if dist < 1.0 then
                self.curSpeed_ = self.curSpeed_ * 0.92
            end
            self.curSpeed_ = Clamp(self.curSpeed_, self.minSpeed_, self.maxSpeed_)
            newPos = newPos + curDirection * self.curSpeed_ * timeStep
        else
            newPos = self.initialPosition_
            self.curSpeed_ = self.maxSpeed_
            self.platformState_ = PLATFORM_STATE_MOVETO_FINISH
        end
        self.platformNode_.position = newPos
    end
end

-- ============================================================================
-- 3. 生命周期函数 (Lifecycle Functions)
-- ============================================================================

function Start()
    -- 初始化 Sample 工具库
    SampleStart()

    -- 创建场景
    CreateScene()

    -- 创建角色
    CreateCharacter()

    -- 创建 UI
    CreateInstructions()

    -- 创建游戏 HUD（摇杆 + 按钮 + 准星）
    CreateGameHUD()

    -- 订阅事件
    SubscribeToEvents()

    -- 设置鼠标模式（相对模式，隐藏鼠标）
    SampleInitMouseMode(MM_RELATIVE)

    print("=== Third Person Game Started ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 4. 场景创建 (Scene Creation)
-- ============================================================================

function CreateScene()
    scene_ = Scene:new()

    -- 创建场景组件
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")
    scene_:CreateComponent("DebugRenderer")

    -- 创建第三人称相机
    tpCamera_ = ThirdPersonCamera.Create(scene_, {
        modes = {
            normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 },
            armed = { distance = 4.0, offset = Vector3(0.6, 1.6, 0), fov = 45.0 },
            aiming = { distance = 2.0, offset = Vector3(0.4, 1.5, 0), fov = 32.0 },
        },
        transitionSpeed = 8.0,
        farClip = CONFIG.CameraFarClip,
    })
    renderer:SetViewport(0, Viewport:new(scene_, tpCamera_:GetCamera()))

    -- 创建光照
    CreateLighting()

    -- 创建地形（地板、斜坡等）
    CreateTerrain()

    -- 创建移动平台
    CreateMovingPlatforms()
end

--- 创建光照
function CreateLighting()
    -- 创建天空光（环境光）
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.ambientColor = Color(0.4, 0.4, 0.4)
    zone.fogColor = Color(0.7, 0.8, 0.9)
    zone.fogStart = 100.0
    zone.fogEnd = 300.0

    -- 创建定向光（太阳光）
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(0.8, 0.8, 0.8)
    light.castShadows = true
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
end

--- 创建地形：地板和斜坡
function CreateTerrain()
    -- 创建主地板
    CreateFloor(Vector3(0, 0, 0), Vector3(40, 1, 40))

    -- 创建上层平台
    CreateFloor(Vector3(15, 3, 0), Vector3(10, 1, 10))

    -- 创建斜坡（连接地面和上层平台）
    CreateRamp(Vector3(7, 1.5, 0), Vector3(8, 0.5, 4), 20)
end

--- 创建地板
---@param position Vector3 位置
---@param size Vector3 尺寸
function CreateFloor(position, size)
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = position
    floorNode.scale = size

    local model = floorNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))

    local body = floorNode:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = floorNode:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

--- 创建斜坡
---@param position Vector3 斜坡中心位置
---@param size Vector3 斜坡尺寸 (长, 厚, 宽)
---@param angle number 斜坡角度（度数）
function CreateRamp(position, size, angle)
    local rampNode = scene_:CreateChild("Ramp")
    rampNode.position = position
    rampNode.rotation = Quaternion(angle, Vector3(0, 0, 1))
    rampNode.scale = size

    local model = rampNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))

    local body = rampNode:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = rampNode:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

--- 创建移动平台
function CreateMovingPlatforms()
    -- 创建一个水平移动平台
    local platform1 = scene_:CreateScriptObject("MovingPlatform")
    platform1:Initialize(
        Vector3(20, 1, 0),    -- 起始位置
        Vector3(20, 1, 15),   -- 结束位置
        Vector3(4, 0.5, 4)    -- 平台尺寸
    )

    -- 可以创建更多移动平台
    -- local platform2 = scene_:CreateScriptObject("MovingPlatform")
    -- platform2:Initialize(Vector3(-10, 5, 0), Vector3(-10, 5, 20))
end

-- ============================================================================
-- 5. 角色创建 (Character Creation)
-- ============================================================================

function CreateCharacter()
    local objectNode = scene_:CreateChild("Player")
    objectNode:SetPosition(CONFIG.CharacterStartPos)

    -- 创建模型节点
    local modelNode = objectNode:CreateChild("ModelNode")

    -- 方式1: 尝试从预制体加载（推荐）
    local prefabLoaded = false
    if CONFIG.CharacterPrefab then
        local prefabFile = cache:GetResource("XMLFile", CONFIG.CharacterPrefab)
        if prefabFile then
            prefabLoaded = modelNode:LoadXML(prefabFile:GetRoot())
            if prefabLoaded then
                print("Character prefab loaded: " .. CONFIG.CharacterPrefab)
            end
        end
    end

    -- 方式2: 如果预制体加载失败，手动创建模型
    if not prefabLoaded then
        print("Prefab not found, using fallback manual setup")
        -- 创建旋转节点（用于调整模型朝向）
        local adjustNode = modelNode:CreateChild("AdjustNode")
        adjustNode:SetRotation(Quaternion(180, Vector3(0, 1, 0)))

        -- 创建角色模型
        local model = adjustNode:CreateComponent("AnimatedModel")
        model:SetModel(cache:GetResource("Model", CONFIG.CharacterModel))
        for i, matPath in ipairs(CONFIG.CharacterMaterials) do
            model:SetMaterial(i - 1, cache:GetResource("Material", matPath))
        end
        model:SetCastShadows(true)
    end

    -- 确保有 AnimationController（预制体可能已包含）
    modelNode:GetOrCreateComponent("AnimationController")

    -- 创建 AnimationStateMachine（双 FSM 架构）
    -- Normal FSM: 单层全身动画
    -- Armed FSM: 3 层（Base + LowerBody 跳跃 + UpperBody 射击/换弹）
    stateMachine_ = modelNode:CreateComponent("AnimationStateMachine")

    -- 预加载两个 FSM 文件
    normalFSMFile_ = cache:GetResource("JSONFile", CONFIG.CharacterNormalFSM)
    armedFSMFile_ = cache:GetResource("JSONFile", CONFIG.CharacterArmedFSM)

    -- 默认使用 Normal FSM
    if normalFSMFile_ ~= nil then
        stateMachine_:LoadFromJSONFile(normalFSMFile_)
        stateMachine_:Start()
        currentFSMType_ = "normal"
        print("AnimationStateMachine started with Normal FSM")
    else
        print("Warning: Normal FSM not found: " .. CONFIG.CharacterNormalFSM)
    end

    if armedFSMFile_ == nil then
        print("Warning: Armed FSM not found: " .. CONFIG.CharacterArmedFSM)
    end

    -- 创建 AimOffset 组件（用于程序化上半身瞄准）
    -- AimOffset 在动画播放后旋转脊椎骨骼，实现瞄准偏移
    -- 注意：只配置 Spine 系列骨骼，不包括 Neck/Head
    -- 这样补偿旋转时，手臂跟着躯干转，头部朝向由动画 IK 或其他方式控制
    -- 保持持枪时手和头的相对角度正确（枪指向看的方向）
    aimOffset_ = modelNode:CreateComponent("AimOffset")
    -- 配置骨骼权重 (pitchWeight, yawWeight)
    -- 只配置 Spine 系列，权重总和约为 1.0
    aimOffset_:AddBone("Bip001 Spine", 0.40, 0.40)
    aimOffset_:AddBone("Bip001 Spine1", 0.35, 0.35)
    aimOffset_:AddBone("Bip001 Spine2", 0.25, 0.25)
    aimOffset_:SetMaxPitch(50)     -- 限制 pitch 避免极端弯曲
    aimOffset_:SetMaxYaw(30)       -- 限制 yaw 防止极端扭曲
    aimOffset_:SetSmoothSpeed(12)  -- 平滑过渡速度
    aimOffset_:SetYawCompensation(0)  -- 补偿持枪动画的脊椎旋转
    print("AimOffset component created with " .. aimOffset_.numBones .. " bones")

    -- 创建刚体
    local body = objectNode:CreateComponent("RigidBody")
    body:SetCollisionLayerAndMask(CollisionLayerCharacter, CollisionMaskCharacter)
    body:SetMass(1)
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    -- 创建碰撞形状（胶囊体）
    local shape = objectNode:CreateComponent("CollisionShape")
    shape:SetCapsule(0.7, 1.8, Vector3(0.0, 0.86, 0.0))

    -- 创建运动学角色控制器
    local kinematicController = objectNode:CreateComponent("KinematicCharacterController")
    kinematicController:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)
    kinematicController:SetJumpSpeed(8.0)

    -- 创建角色组件（只处理物理移动，动画由 AnimationStateMachine 处理）
    character_ = objectNode:CreateComponent("CharacterComponent")

    -- 设置空中控制参数
    character_:SetAirControlFactor(CONFIG.AirControlFactor)
    -- character_:SetAirFriction(CONFIG.AirFriction)
    -- character_:SetAirSpeedRatio(CONFIG.AirSpeedRatio)

    -- 设置步行模式
    character_:SetEnableWalkMode(CONFIG.EnableWalkMode)
end

--- 切换到持枪状态机（3 层架构）
function SwitchToArmedFSM()
    if currentFSMType_ == "armed" then return end
    if armedFSMFile_ == nil or stateMachine_ == nil then return end

    -- 保存当前参数
    local moveSpeed = stateMachine_:GetFloat("moveSpeed")
    local isGrounded = stateMachine_:GetBool("isGrounded")

    -- 加载 Armed FSM（C++ LoadFromJSON 已处理停止旧动画）
    stateMachine_:LoadFromJSONFile(armedFSMFile_)
    stateMachine_:Start()

    -- 恢复参数
    stateMachine_:SetFloat("moveSpeed", moveSpeed)
    stateMachine_:SetBool("isGrounded", isGrounded)

    currentFSMType_ = "armed"
    print("Switched to Armed FSM")
end

--- 切换到普通状态机（单层架构）
function SwitchToNormalFSM()
    if currentFSMType_ == "normal" then return end
    if normalFSMFile_ == nil or stateMachine_ == nil then return end

    -- 保存当前参数
    local moveSpeed = stateMachine_:GetFloat("moveSpeed")
    local isGrounded = stateMachine_:GetBool("isGrounded")

    -- 加载 Normal FSM（C++ LoadFromJSON 已处理停止旧动画）
    stateMachine_:LoadFromJSONFile(normalFSMFile_)
    stateMachine_:Start()

    -- 恢复参数
    stateMachine_:SetFloat("moveSpeed", moveSpeed)
    stateMachine_:SetBool("isGrounded", isGrounded)

    currentFSMType_ = "normal"
    print("Switched to Normal FSM")
end

-- ============================================================================
-- 6. UI 创建 (UI Creation)
-- ============================================================================

function CreateInstructions()
    -- 初始化 UI 系统 (用于操作提示，GameHUD 使用独立的渲染通道)
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        -- 推荐! DPR 缩放 + 小屏密度自适应（见 ui.md §10）
        -- 1 基准像素 ≈ 1 CSS 像素，尺寸遵循 CSS/Web 常识
        scale = UI.Scale.DEFAULT,
    })
    
    local uiRoot = UI.Panel {
        id = "instructionsUI",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Label {
                text = "WASD: 移动 | Shift: 跑步 | Space: 跳跃\nQ: 切换持枪 | 左键: 射击 | 右键: 瞄准 | R: 换弹",
                fontSize = 12,
                fontColor = { 255, 255, 200, 200 },
                position = "absolute",
                top = 10,
                left = 0,
                right = 0,
                textAlign = "center",
                maxLines = 2,
                width = "100%",
            },
        }
    }
    
    UI.SetRoot(uiRoot)
end

--- 创建游戏 HUD（摇杆 + 动作按钮 + 准星 + 触摸视角）
--- 使用 GameHUD 库简化 HUD 创建
function CreateGameHUD()
    -- 初始化 GameHUD
    GameHUD.Initialize()
    GameHUD.SetControls(character_.controls)

    -- 创建完整 HUD（摇杆 + 跳跃 + 跑步 + 射击系统）
    -- CTRL_JUMP 和 CTRL_RUN 由 GameHUD 内部自动设置
    GameHUD.Create({
        enableJump = true,     -- 启用跳跃按钮
        enableRun = true,      -- 3D 角色游戏需要跑步功能
        enableShooter = true,  -- 启用射击系统（切枪 + 装弹 + 射击 + 准星）
        onArm = function(isArmed)
            isArmed_ = isArmed
            -- 切换状态机
            if isArmed then
                SwitchToArmedFSM()
            else
                SwitchToNormalFSM()
            end
            -- 切换相机模式
            tpCamera_:SetMode(isArmed and "armed" or "normal")
            -- 进入持枪模式时，强制角色转向相机方向
            if isArmed then
                local characterNode = character_:GetNode()
                characterNode.worldRotation = Quaternion(0, character_.controls.yaw, 0)
            end
        end,
        onShoot = function()
            if stateMachine_ then
                stateMachine_:SetTrigger("shoot")
            end
        end,
        onReload = function()
            if stateMachine_ then
                stateMachine_:SetTrigger("reload")
            end
        end,
        onAimChange = function(isAiming)
            isAiming_ = isAiming
            -- 切换相机模式
            if isAiming then
                tpCamera_:SetMode("aiming")
            else
                tpCamera_:SetMode(isArmed_ and "armed" or "normal")
            end
        end,
    })

    -- 启用触摸视角控制（移动端在空白区域滑动 = 旋转视角）
    -- 使用 controls 模式：自动更新 character_.controls.yaw/pitch
    GameHUD.EnableTouchLook({
        camera = tpCamera_:GetNode(),
    })
end

-- ============================================================================
-- 7. 事件处理 (Event Handlers)
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    -- 取消订阅 SceneUpdate 避免冲突
    UnsubscribeFromEvent("SceneUpdate")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if character_ == nil then return end

    -- 注意：CTRL_JUMP/RUN 和瞄准状态由 GameHUD 内部 ScriptObject 自动处理
    -- 注意：触摸视角控制由 GameHUD.EnableTouchLook() 自动处理

    -- 触摸输入更新（双指缩放等，视角旋转由 GameHUD 处理）
    if touchEnabled then
        UpdateTouches(character_.controls)
    end

    -- 输入处理
    -- 注意：摇杆移动、跳跃、跑步、射击、装弹、切换武器、触摸视角都由 GameHUD 处理
    if ui.focusElement == nil then
        -- PC 端：鼠标控制视角
        if not touchEnabled then
            character_.controls.yaw = character_.controls.yaw + input.mouseMoveX * YAW_SENSITIVITY
            character_.controls.pitch = character_.controls.pitch + input.mouseMoveY * YAW_SENSITIVITY
        end

        -- 限制俯仰角
        character_.controls.pitch = Clamp(character_.controls.pitch, -80.0, 80.0)

        -- 战斗模式设置（根据 isArmed_ 状态，由 GameHUD 回调更新）
        -- 持枪时：角色面向相机方向（战斗模式）
        -- 非持枪时：角色面向移动方向（探索模式）
        character_.autoRotateToMoveDir = not isArmed_
        -- 战斗模式使用较慢的旋转速度，更自然
        character_.rotationSpeed = isArmed_ and 180.0 or 1440.0

        -- 切换陀螺仪（移动端）
        if input:GetKeyPress(KEY_G) then
            useGyroscope = not useGyroscope
        end

        -- 调试快捷键
        if input:GetKeyPress(KEY_F5) and stateMachine_ then
            stateMachine_:DebugPrintState()
        end
        if input:GetKeyPress(KEY_F6) and stateMachine_ then
            stateMachine_:DebugPrintParameters()
        end
        if input:GetKeyPress(KEY_F7) and aimOffset_ then
            aimOffset_:DebugPrintBones()
        end
        if input:GetKeyPress(KEY_F8) and stateMachine_ then
            stateMachine_:DebugPrintBlendSpaceTracks()
        end
    end
end

---@param eventType string
---@param eventData PostUpdateEventData
function HandlePostUpdate(eventType, eventData)
    if character_ == nil then return end

    -- 更新 AnimationStateMachine 参数
    -- FSM 会根据这些参数自动处理所有层的状态转换
    if stateMachine_ ~= nil then
        local moveSpeed = character_:GetMoveSpeed()
        local isGrounded = character_:IsOnGround()
        local isJumping = character_:IsJumping()

        -- 触发跳跃动画（只在起跳帧触发）
        if character_:IsJumpStarted() then
            stateMachine_:SetTrigger("jump")
        end

        -- 当 isJumping 为 true 且还没离地时，强制 isGrounded 为 false
        local effectiveGrounded = isGrounded and not isJumping

        -- 设置共享参数（所有层都可以访问）
        stateMachine_:SetFloat("moveSpeed", moveSpeed)
        stateMachine_:SetBool("isGrounded", effectiveGrounded)
        stateMachine_:SetBool("isJumping", isJumping)
        -- 注意：isArmed 不再需要，因为我们使用双 FSM 架构（Normal/Armed）
    end

    local timeStep = eventData["TimeStep"]:GetFloat()

    -- 更新 AimOffset 组件
    -- 持枪时启用，设置目标角度
    if aimOffset_ ~= nil then
        aimOffset_:SetEnabled(isArmed_)
        if isArmed_ then
            local cameraNode = tpCamera_:GetNode()
            -- 从相机节点获取实际 pitch
            local cameraPitch = cameraNode.worldRotation:PitchAngle()
            aimOffset_:SetTargetPitch(cameraPitch)

            -- 计算相对 yaw：相机方向 vs 角色朝向
            local characterNode = character_:GetNode()
            local characterYaw = characterNode.worldRotation:YawAngle()
            local cameraYaw = cameraNode.worldRotation:YawAngle()
            local relativeYaw = cameraYaw - characterYaw

            -- 归一化到 -180 到 180 范围
            while relativeYaw > 180 do relativeYaw = relativeYaw - 360 end
            while relativeYaw < -180 do relativeYaw = relativeYaw + 360 end

            aimOffset_:SetTargetYaw(relativeYaw)
        end
    end

    -- 更新第三人称相机（一行搞定：平滑过渡 + 墙壁碰撞检测）
    local characterNode = character_:GetNode()
    tpCamera_:Update(timeStep, characterNode, character_.controls.yaw, character_.controls.pitch)
end

-- ============================================================================
-- 8. 使用说明 (Usage Instructions)
-- ============================================================================
--[[
    这个脚手架提供了第三人称角色游戏的基础框架，包括：

    v3.0 架构升级 - 双 FSM 架构（Normal + Armed）:
    - 采用类似 Unity 多 Animator Controller 的设计
    - Normal FSM: 单层全身动画（Locomotion + Jump）
    - Armed FSM: 3 层架构
      * Layer 0 (Base): RifleLocomotion BlendSpace（全身）
      * Layer 1 (LowerBody): 跳跃动画，使用 LowerBody BoneMask
      * Layer 2 (UpperBody): 射击/换弹动画，使用 UpperBody BoneMask
    - Q 键切换 FSM，平滑过渡
    - 所有动画逻辑都在 FSM 配置文件中声明式定义
    - Lua 只需设置参数，FSM 自动处理状态转换和动画混合

    功能清单:
    - 第三人称角色控制 (WASD移动 + Shift跑步 + 空格跳跃)
    - 武器系统 (Q切换持枪 + 左键射击 + R换弹)
    - 双 FSM 动画系统（Normal/Armed 切换）
    - 持枪时上下半身分离（LowerBody 跳跃 + UpperBody 射击）
    - 预制体加载（推荐）+ 手动配置回退
    - 第三人称相机 (跟随角色，射线检测防穿墙)
    - 移动平台 (MovingPlatform 类)
    - 斜坡支持
    - 触摸屏支持 (iOS/Android) - GameHUD 摇杆 + 动作按钮 + 准星
    - 碰撞层系统

    架构说明：
    - CharacterComponent: 只处理物理（移动、跳跃、空中控制）
    - AnimationStateMachine: 根据状态加载不同 FSM
      * Normal FSM: 单层 Locomotion + Jump
      * Armed FSM: 3 层 Base + LowerBody + UpperBody
    - Lua 脚本:
      * 在 HandlePostUpdate 中设置动画参数（moveSpeed, isGrounded 等）
      * 通过 SetTrigger 触发动作（jump, shoot, reload）
      * 通过 SwitchToArmedFSM/SwitchToNormalFSM 切换状态机
      * 不需要手动控制任何动画播放！

    FSM 参数说明（两个 FSM 共享）:
    - moveSpeed (float): 移动速度，用于 BlendSpace 动画混合
    - isGrounded (bool): 是否着地
    - isJumping (bool): 是否在跳跃
    - jump (trigger): 触发跳跃动画
    - shoot (trigger): 触发射击动画（仅 Armed FSM）
    - reload (trigger): 触发换弹动画（仅 Armed FSM）

    如何扩展：

    1. 更换角色模型：
       方式1（推荐）: 修改 CONFIG.CharacterPrefab 指向你的预制体
       方式2: 修改 CONFIG.CharacterModel 和 CONFIG.CharacterMaterials

    2. 自定义动画状态机：
       - 创建自己的 .fsm 文件（参考 DefaultMale_Normal.fsm / DefaultMale_Armed.fsm）
       - 修改 CONFIG.CharacterNormalFSM 和 CONFIG.CharacterArmedFSM
       - FSM 文件使用 layers 数组定义多个动画层
       - 每个层有独立的 states 和 transitions

    3. 添加更多地形：
       CreateFloor(位置, 尺寸)
       CreateRamp(位置, 尺寸, 角度)

    4. 添加更多移动平台：
       local platform = scene_:CreateScriptObject("MovingPlatform")
       platform:Initialize(起始位置, 结束位置, 平台尺寸)

    5. 调整空中控制（在 CONFIG 中修改）：
       - AirControlFactor: 空中控制系数（范围 0-1）
         * 0.0 = 空中完全无法控制
         * 0.05 = 很弱控制（Fall Guys 风格）
         * 0.4 = 较强控制（马里奥风格）
         * 0.6 = 中等控制（默认）
         * 1.0 = 完全控制

    6. 查看 FSM 调试信息：
       - stateMachine_:DebugPrintState() - 打印所有层状态
       - stateMachine_:DebugPrintLayers() - 打印层配置
       - stateMachine_:DebugPrintTransitions() - 打印转换条件
       - stateMachine_:DebugPrintSkeleton() - 打印骨骼层级

    控制说明：
    - WASD: 移动角色（默认步行）
    - Shift: 跑步
    - 鼠标: 旋转视角
    - 空格: 跳跃
    - Q: 切换持枪状态（切换 FSM）
    - 鼠标左键: 射击（持枪时）
    - R: 换弹（持枪时）
    - G: 切换陀螺仪（移动端）
    - ESC: 退出

    Normal FSM 动画层说明（单层）:
    Layer 0 (Base):
    - Locomotion: 移动（BlendSpace: Idle/Walk/Run）
    - JumpStart/JumpAir/JumpLanding: 跳跃动画序列

    Armed FSM 动画层说明（3 层）:
    Layer 0 (Base - 全身):
    - RifleLocomotion: 持枪移动（BlendSpace: RifleIdle/RifleWalk/RifleRun）

    Layer 1 (LowerBody - BoneMask: Root/Pelvis/腿部):
    - Empty: 默认空状态
    - JumpStart/JumpAir/JumpLanding: 跳跃动画（只影响下半身）

    Layer 2 (UpperBody - BoneMask: Spine 及子骨骼):
    - Empty: 默认空状态
    - RifleShoot: 射击动画（一次性，只影响上半身）
    - RifleReload: 换弹动画（一次性，只影响上半身）

    上下半身分离原理（Armed FSM）：
    - Layer 1 使用 LowerBody BoneMask（Root, Bip001, Pelvis, 腿部骨骼）
    - Layer 2 使用 UpperBody BoneMask（startBone: Spine）
    - 跳跃时：Layer 1 播放跳跃动画影响下半身，Layer 0 持枪动画影响上半身
    - 射击时：Layer 2 播放射击动画覆盖上半身，下半身继续播放 Layer 0/1 的动画
]]

