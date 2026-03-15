-- 84_VirtualControlsSwitchDemo
-- 演示 VirtualControls.SetControls() 切换角色控制器
--
-- 功能：
--   - 创建两个角色（红色和蓝色）
--   - 使用 VirtualControls 摇杆控制当前角色移动
--   - 按 Tab 键或点击切换按钮切换控制的角色
--   - 相机自动跟随当前控制的角色

require "LuaScripts/Utilities/Sample"
require "LuaScripts/Utilities/Touch"
require "LuaScripts/Utilities/VirtualControls"

-- 场景和相机
local scene_ = nil
local cameraNode_ = nil

-- 两个角色
local characters_ = {}  -- {character1, character2}
local currentCharacterIndex_ = 1  -- 当前控制的角色索引

-- 虚拟控件
local jumpButton_ = nil
local switchButton_ = nil

-- UI
local statusText_ = nil

--------------------------------------------------------------------------------
-- 辅助函数
--------------------------------------------------------------------------------

--- 获取当前控制的角色
local function GetCurrentCharacter()
    return characters_[currentCharacterIndex_]
end

--- 切换到下一个角色
local function SwitchToNextCharacter()
    -- 切换索引
    currentCharacterIndex_ = currentCharacterIndex_ % #characters_ + 1
    
    local character = GetCurrentCharacter()
    
    -- 关键：使用 SetControls 切换控制目标
    VirtualControls.SetControls(character.controls)
    
    -- 更新 UI
    local names = {"红色机器人", "蓝色机器人"}
    statusText_.text = "当前控制: " .. names[currentCharacterIndex_] .. "\n按 Tab 或点击 Switch 切换角色"
    
    print("[Switch] 切换到角色 " .. currentCharacterIndex_ .. ": " .. names[currentCharacterIndex_])
end

--------------------------------------------------------------------------------
-- 角色创建
--------------------------------------------------------------------------------

--- 创建角色
---@param position Vector3 出生位置
---@param color string 颜色标识 ("red" 或 "blue")
---@return CharacterComponent
local function CreateCharacter(position, color)
    local objectNode = scene_:CreateChild("Character_" .. color)
    objectNode:SetPosition(position)

    -- 旋转节点
    local adjustNode = objectNode:CreateChild("AdjustNode")
    adjustNode:SetRotation(Quaternion(180, Vector3(0, 1, 0)))

    -- 创建模型
    local model = adjustNode:CreateComponent("AnimatedModel")
    model:SetModel(cache:GetResource("Model", "Platforms/Models/BetaLowpoly/Beta.mdl"))
    
    -- 根据颜色设置不同材质
    if color == "red" then
        -- 使用红色材质（复用现有材质，实际项目中可以创建不同颜色的材质）
        model:SetMaterial(0, cache:GetResource("Material", "Platforms/Materials/BetaBody_MAT.xml"))
        model:SetMaterial(1, cache:GetResource("Material", "Platforms/Materials/BetaBody_MAT.xml"))
        model:SetMaterial(2, cache:GetResource("Material", "Platforms/Materials/BetaJoints_MAT.xml"))
    else
        -- 使用蓝色材质
        model:SetMaterial(0, cache:GetResource("Material", "Platforms/Materials/BetaJoints_MAT.xml"))
        model:SetMaterial(1, cache:GetResource("Material", "Platforms/Materials/BetaJoints_MAT.xml"))
        model:SetMaterial(2, cache:GetResource("Material", "Platforms/Materials/BetaBody_MAT.xml"))
    end
    model:SetCastShadows(true)
    
    -- 动画控制器
    adjustNode:CreateComponent("AnimationController")

    -- 刚体
    local body = objectNode:CreateComponent("RigidBody")
    body:SetCollisionLayerAndMask(CollisionLayerCharacter, CollisionMaskCharacter)
    body:SetMass(1)
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    -- 碰撞形状
    local shape = objectNode:CreateComponent("CollisionShape")
    shape:SetCapsule(0.7, 1.8, Vector3(0.0, 0.86, 0.0))

    -- 运动学角色控制器
    local kinematicController = objectNode:CreateComponent("KinematicCharacterController")
    kinematicController:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)
    kinematicController:SetJumpSpeed(8.0)

    -- 角色组件
    -- CharacterComponent 只处理物理移动，动画需要单独处理
    local character = objectNode:CreateComponent("CharacterComponent")
    character:SetAirControlFactor(0.6)

    -- 保存动画路径到角色数据中，以便在 Update 中播放动画
    character.animationPaths = {
        idle = "Platforms/Models/BetaLowpoly/Beta_Idle.ani",
        run = "Platforms/Models/BetaLowpoly/Beta_Run.ani",
        jump = "Platforms/Models/BetaLowpoly/Beta_JumpStart.ani",
        air = "Platforms/Models/BetaLowpoly/Beta_JumpLoop1.ani",
    }
    
    -- 保存 AnimationController 引用
    character.animController = adjustNode:GetComponent("AnimationController")
    
    -- 播放初始待机动画
    if character.animController then
        character.animController:PlayExclusive(character.animationPaths.idle, 0, true, 0.2)
    end

    return character
end

--------------------------------------------------------------------------------
-- 场景创建
--------------------------------------------------------------------------------

local function CreateFloor()
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = Vector3(0, -0.5, 0)
    floorNode.scale = Vector3(50, 1, 50)

    local model = floorNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))

    local body = floorNode:CreateComponent("RigidBody")
    body.collisionLayer = CollisionLayerStatic
    body.collisionMask = CollisionMaskStatic

    local shape = floorNode:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

function CreateScene()
    scene_ = Scene:new()

    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")
    scene_:CreateComponent("DebugRenderer")

    -- 相机
    cameraNode_ = Node()
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 300.0
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- 光照
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.ambientColor = Color(0.4, 0.4, 0.4)
    zone.fogColor = Color(0.7, 0.8, 0.9)
    zone.fogStart = 100.0
    zone.fogEnd = 300.0

    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(0.8, 0.8, 0.8)
    light.castShadows = true
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)

    -- 地板
    CreateFloor()

    -- 创建两个角色
    local char1 = CreateCharacter(Vector3(-3, 1, 0), "red")
    local char2 = CreateCharacter(Vector3(3, 1, 0), "blue")
    
    table.insert(characters_, char1)
    table.insert(characters_, char2)
    
    print("[Init] 创建了 " .. #characters_ .. " 个角色")
end

--------------------------------------------------------------------------------
-- 虚拟控件创建
--------------------------------------------------------------------------------

function CreateVirtualControls()
    -- 初始化（VirtualControls 会自动订阅 NanoVGRender 事件）
    VirtualControls.Initialize()
    
    local isMobile = VirtualControls.IsMobile()
    
    -- 创建移动摇杆（左下角）
    local joystickPosOffset = 260
    VirtualControls.CreateJoystick({
        position = Vector2(joystickPosOffset, -joystickPosOffset),
        alignment = {HA_LEFT, VA_BOTTOM},
        baseRadius = 150,
        knobRadius = 60,
        moveRadius = 110,
        deadZone = 0.15,
        opacity = 0.5,
        activeOpacity = 0.85,
        isPressCenter = true,
        pressRegionRadius = 250,
        keyBinding = isMobile and nil or "WASD",
        showKeyHints = not isMobile,
    })
    
    -- 绑定到第一个角色
    VirtualControls.SetControls(characters_[1].controls)
    
    -- 创建跳跃按钮（右下角）
    jumpButton_ = VirtualControls.CreateButton({
        position = Vector2(-160, -160),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 70,
        label = "Jump",
        keyBinding = "SPACE",
        opacity = 0.5,
        activeOpacity = 0.9,
        color = {100, 200, 255},
        pressedColor = {150, 230, 255},
    })
    
    -- 创建切换角色按钮（右下角，跳跃按钮上方）
    switchButton_ = VirtualControls.CreateButton({
        position = Vector2(-160, -320),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 50,
        label = "Switch",
        keyBinding = "TAB",
        opacity = 0.5,
        activeOpacity = 0.9,
        color = {255, 200, 100},
        pressedColor = {255, 230, 150},
        on_press = function()
            SwitchToNextCharacter()
        end,
    })
    
    print("[VirtualControls] 虚拟控件创建完成")
end

--------------------------------------------------------------------------------
-- UI 创建
--------------------------------------------------------------------------------

function CreateUI()
    -- 状态文本
    statusText_ = ui.root:CreateChild("Text")
    statusText_.text = "当前控制: 红色机器人\n按 Tab 或点击 Switch 切换角色"
    statusText_:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 18)
    statusText_.textAlignment = HA_CENTER
    statusText_.horizontalAlignment = HA_CENTER
    statusText_.verticalAlignment = VA_TOP
    statusText_:SetPosition(0, 50)
    statusText_.color = Color(1, 1, 1)
    
    -- 说明文本
    local instructionText = ui.root:CreateChild("Text")
    instructionText.text = 
        "WASD: 移动 | 空格: 跳跃 | Tab: 切换角色\n" ..
        "鼠标: 旋转视角"
    instructionText:SetFont(cache:GetResource("Font", "Fonts/MiSans-Regular.ttf"), 14)
    instructionText.textAlignment = HA_CENTER
    instructionText.horizontalAlignment = HA_CENTER
    instructionText.verticalAlignment = VA_BOTTOM
    instructionText:SetPosition(0, -20)
end

--------------------------------------------------------------------------------
-- 事件处理
--------------------------------------------------------------------------------

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    UnsubscribeFromEvent("SceneUpdate")
end

function HandleUpdate(eventType, eventData)
    local character = GetCurrentCharacter()
    if character == nil then return end

    -- 清除控制状态
    character.controls:Set(CTRL_FORWARD + CTRL_BACK + CTRL_LEFT + CTRL_RIGHT + CTRL_JUMP, false)

    -- 触摸更新
    if touchEnabled then 
        UpdateTouches(character.controls) 
    end

    if ui.focusElement == nil then
        -- 跳跃按钮
        if jumpButton_ and jumpButton_.isPressed then
            character.controls:Set(CTRL_JUMP, true)
        end

        -- 触摸控制视角
        if touchEnabled then
            for i = 0, input.numTouches - 1 do
                local state = input:GetTouch(i)
                local isOccupied = VirtualControls.IsTouchOccupied(state.touchID)
                if not state.touchedElement and not isOccupied then
                    local camera = cameraNode_:GetComponent("Camera")
                    if camera then
                        character.controls.yaw = character.controls.yaw + 
                            TOUCH_SENSITIVITY * camera.fov / graphics.height * state.delta.x
                        character.controls.pitch = character.controls.pitch + 
                            TOUCH_SENSITIVITY * camera.fov / graphics.height * state.delta.y
                    end
                end
            end
        else
            character.controls.yaw = character.controls.yaw + input.mouseMoveX * YAW_SENSITIVITY
            character.controls.pitch = character.controls.pitch + input.mouseMoveY * YAW_SENSITIVITY
        end
        
        character.controls.pitch = Clamp(character.controls.pitch, -80.0, 80.0)
    end
end

function HandlePostUpdate(eventType, eventData)
    local character = GetCurrentCharacter()
    if character == nil then return end

    local characterNode = character:GetNode()
    
    -- 更新所有角色的动画
    for _, char in ipairs(characters_) do
        UpdateCharacterAnimation(char)
    end
    
    -- 相机跟随当前角色
    local rot = Quaternion(character.controls.yaw, Vector3(0.0, 1.0, 0.0))
    local dir = rot * Quaternion(character.controls.pitch, Vector3.RIGHT)

    local aimPoint = characterNode.position + rot * Vector3(0.0, 1.7, 0.0)

    local rayDir = dir * Vector3(0.0, 0.0, -1.0)
    local rayDistance = cameraDistance
    local result = scene_:GetComponent("PhysicsWorld"):RaycastSingle(
        Ray(aimPoint, rayDir), 
        rayDistance, 
        CollisionMaskCamera
    )
    if result.body ~= nil then
        rayDistance = Min(rayDistance, result.distance)
    end
    rayDistance = Clamp(rayDistance, CAMERA_MIN_DIST, cameraDistance)

    cameraNode_.position = aimPoint + rayDir * rayDistance
    cameraNode_.rotation = dir
end

--- 更新角色动画
---@param character CharacterComponent
function UpdateCharacterAnimation(character)
    local animController = character.animController
    local animPaths = character.animationPaths
    
    if animController == nil or animPaths == nil then
        return
    end
    
    local isOnGround = character:IsOnGround()
    local isMoving = character:IsMoving()
    local isJumpStarted = character:IsJumpStarted()
    
    -- 跳跃开始时播放跳跃动画
    if isJumpStarted then
        animController:PlayExclusive(animPaths.jump, 0, false, 0.1)
        return
    end
    
    -- 在空中时播放空中动画
    if not isOnGround then
        -- 只有跳跃动画播放完后才切换到空中循环
        if not animController:IsPlaying(animPaths.jump) then
            animController:PlayExclusive(animPaths.air, 0, true, 0.2)
        end
        return
    end
    
    -- 在地面时根据移动状态播放动画
    if isMoving then
        animController:PlayExclusive(animPaths.run, 0, true, 0.2)
    else
        animController:PlayExclusive(animPaths.idle, 0, true, 0.2)
    end
end

--------------------------------------------------------------------------------
-- 入口
--------------------------------------------------------------------------------

function Start()
    SampleStart()
    
    CreateScene()
    CreateVirtualControls()
    CreateUI()
    SubscribeToEvents()
    
    SampleInitMouseMode(MM_RELATIVE)
    
    print("=== 84_VirtualControlsSwitchDemo Started ===")
    print("按 Tab 键或点击 Switch 按钮切换控制的角色")
end

