-- ============================================================================
-- Client.lua - 客户端逻辑
-- ============================================================================

local Client = {}
local Shared = require("Shared")

require "LuaScripts/Utilities/Sample"
require "urhox-libs.UI.GameHUD"

-- ============================================================================
-- 客户端变量
-- ============================================================================

local scene_ = nil
local cameraNode_ = nil
local myRoleNode_ = nil

-- 相机控制
local yaw_ = 0.0
local pitch_ = 0.0

-- 相机参数（平滑过渡）
local currentCameraDistance_ = 5.0
local currentCameraOffset_ = Vector3(0, 1.7, 0)
local currentCameraFOV_ = 45.0

-- 玩家状态（本地）
local health_ = Shared.CONFIG.MaxHealth
local maxHealth_ = Shared.CONFIG.MaxHealth
local isDead_ = false
local isAiming_ = false  -- 瞄准状态（右键按住）

-- 游戏逻辑数据（isArmed 现在从节点变量读取，不再需要本地缓存）

-- 动画管理
local playerAnimData_ = {}    -- { [nodeId] = { fsm, fsmType, normalFile, armedFile } }

-- 命中特效
local hitEffects_ = {}

-- 射击冷却（客户端本地，用于触发视觉效果）
local shootCooldown_ = 0.0

-- NanoVG
local nvgCtx_ = nil
local fontNormal_ = -1

-- GameHUD 组件
local hudComponents_ = nil


-- 状态
local pendingNodeId_ = 0  -- 等待同步的自己角色节点 ID
local pendingRoleNodes_ = {}  -- 待检查的 replicated 节点 ID 队列
local needSendReady_ = false
local needBindControls_ = true  -- 需要绑定 GameHUD controls
local pendingCallbacks_ = {}

-- 快捷引用
local CONFIG = Shared.CONFIG
local EVENTS = Shared.EVENTS
local CTRL = Shared.CTRL
local VARS = Shared.VARS

-- ============================================================================
-- 入口函数
-- ============================================================================

function Client.Start()
    SampleStart()

    Shared.RegisterEvents()
    scene_ = Shared.CreateScene(false)  -- isServer = false

    SetupNanoVG()
    SetupCamera()
    SetupGameHUD()

    input.mouseMode = MM_RELATIVE

    -- 事件监听
    SubscribeToEvent(EVENTS.ASSIGN_ROLE, "HandleAssignRole")
    SubscribeToEvent(EVENTS.HEALTH_UPDATE, "HandleHealthUpdate")
    SubscribeToEvent(EVENTS.PLAYER_DIED, "HandlePlayerDied")
    SubscribeToEvent(EVENTS.PLAYER_RESPAWN, "HandlePlayerRespawn")
    SubscribeToEvent(EVENTS.SHOOT_HIT, "HandleShootHit")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate")
    -- NodeAdded 是场景级别的事件，需要订阅到特定场景
    SubscribeToEvent(scene_, "NodeAdded", "HandleNodeAdded")

    local serverConn = network:GetServerConnection()
    if serverConn then
        serverConn.scene = scene_
    end

    needSendReady_ = true
end

function Client.Stop()
    if nvgCtx_ ~= nil then
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================

function SetupNanoVG()
    nvgCtx_ = nvgCreate(1)
    if nvgCtx_ == nil then
        print("[Client] ERROR: 无法创建 NanoVG 上下文")
        return
    end

    fontNormal_ = nvgCreateFont(nvgCtx_, "sans", "Fonts/MiSans-Regular.ttf")
    if fontNormal_ == -1 then
        print("[Client] ERROR: 无法加载字体")
    end

    SubscribeToEvent(nvgCtx_, "NanoVGRender", "HandleNanoVGRender")
end

function SetupCamera()
    cameraNode_ = Node()
    local camera = cameraNode_:CreateComponent("Camera", LOCAL)
    camera.nearClip = 0.1
    camera.farClip = 500.0
    camera.fov = CONFIG.Camera.normal.fov

    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
    renderer.hdrRendering = true
end

function SetupGameHUD()
    GameHUD.Initialize()

    -- 创建 HUD（摇杆 + 跳跃 + 跑步 + 射击系统）
    hudComponents_ = GameHUD.Create({
        enableJump = true,
        enableRun = true,
        enableShooter = true,

        -- Q 键 / Arm 按钮：切换持枪状态
        onArm = function(armed)
            local serverConn = network:GetServerConnection()
            if serverConn then
                serverConn:SendRemoteEvent(EVENTS.TOGGLE_ARMED, true)
            end
        end,

        -- 射击回调（触发动画，实际伤害和命中特效由服务器处理）
        onShoot = function()
            if myRoleNode_ == nil then return end
            local nodeId = myRoleNode_.ID
            local data = playerAnimData_[nodeId]
            if data and data.fsm then
                data.fsm:SetTrigger("shoot")
            end
        end,

        -- 换弹回调
        onReload = function()
            if myRoleNode_ == nil then return end
            local nodeId = myRoleNode_.ID
            local data = playerAnimData_[nodeId]
            if data and data.fsm then
                data.fsm:SetTrigger("reload")
            end
        end,

        -- 瞄准状态变化（右键按住）
        onAimChange = function(aiming)
            isAiming_ = aiming
        end,
    })

    -- 启用触摸视角控制（移动端滑动空白区域旋转视角）
    GameHUD.EnableTouchLook({
        camera = cameraNode_,
        onLook = function(deltaYaw, deltaPitch)
            yaw_ = yaw_ + deltaYaw
            pitch_ = pitch_ + deltaPitch
            pitch_ = Shared.Clamp(pitch_, -89.0, 89.0)
        end,
    })
end

-- ============================================================================
-- 事件处理
-- ============================================================================

function HandleAssignRole(eventType, eventData)
    local nodeId = eventData["NodeId"]:GetUInt()
    local roleNode = scene_:GetNode(nodeId)
    if roleNode then
        BindToRole(roleNode)
    else
        pendingNodeId_ = nodeId
    end
end

function BindToRole(roleNode)
    myRoleNode_ = roleNode
    yaw_ = roleNode.rotation:YawAngle()
end

function HandleNodeAdded(eventType, eventData)
    local node = eventData["Node"]:GetPtr("Node")
    -- 网络同步创建的节点，NodeAdded 事件触发时属性还未读取
    -- 将 replicated 节点加入队列，在 Update 中检查 IS_ROLE 标记
    if node and node.replicated then
        table.insert(pendingRoleNodes_, node.ID)
    end
end

function HandleHealthUpdate(eventType, eventData)
    local nodeId = eventData["NodeId"]:GetUInt()
    local currentHealth = eventData["Health"]:GetInt()
    local maxHealthVal = eventData["MaxHealth"]:GetInt()

    if myRoleNode_ and nodeId == myRoleNode_.ID then
        health_ = currentHealth
        maxHealth_ = maxHealthVal
        if health_ <= 0 then isDead_ = true end
    end
end

function HandlePlayerDied(eventType, eventData)
    local victimId = eventData["VictimId"]:GetUInt()

    if myRoleNode_ and victimId == myRoleNode_.ID then
        isDead_ = true
        isAiming_ = false  -- 死亡时取消瞄准
    end
end

function HandlePlayerRespawn(eventType, eventData)
    local nodeId = eventData["NodeId"]:GetUInt()
    local currentHealth = eventData["Health"]:GetInt()
    local maxHealthVal = eventData["MaxHealth"]:GetInt()

    if myRoleNode_ and nodeId == myRoleNode_.ID then
        isDead_ = false
        health_ = currentHealth
        maxHealth_ = maxHealthVal
    end
end

-- 从节点变量读取持枪状态
function GetNodeArmedState(node)
    local isArmedVar = node:GetVar(VARS.IS_ARMED)
    if isArmedVar:IsEmpty() then return false end
    return isArmedVar:GetBool()
end

-- ============================================================================
-- 动画设置
-- ============================================================================

function SetupPlayerAnimation(roleNode)
    local nodeId = roleNode.ID
    print("[Client] SetupPlayerAnimation: " .. roleNode.name .. " (ID: " .. nodeId .. ")")

    if playerAnimData_[nodeId] then
        print("[Client] " .. roleNode.name .. " 动画已存在，跳过")
        return true
    end

    -- 客户端创建 ModelNode（使用 InstantiateXML 加载 prefab，LOCAL 模式避免网络 ID 冲突）
    local modelNode = roleNode:GetChild("ModelNode")
    if modelNode == nil then
        print("[Client] 为 " .. roleNode.name .. " 创建 ModelNode")
        modelNode = scene_:InstantiateXML(CONFIG.PlayerPrefab, Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
        if modelNode then
            modelNode.name = "ModelNode"
            modelNode.parent = roleNode
            modelNode.position = Vector3.ZERO
            modelNode.rotation = Quaternion.IDENTITY
            print("[Client] ModelNode 创建成功，ID: " .. modelNode.ID)
        else
            print("[Client] ERROR: 无法加载 prefab: " .. CONFIG.PlayerPrefab)
            return false
        end
    else
        print("[Client] " .. roleNode.name .. " 已有 ModelNode")
    end

    modelNode:GetOrCreateComponent("AnimationController", LOCAL)

    local stateMachine = modelNode:CreateComponent("AnimationStateMachine", LOCAL)
    local normalFile = cache:GetResource("JSONFile", CONFIG.NormalFSM)
    local armedFile = cache:GetResource("JSONFile", CONFIG.ArmedFSM)

    if normalFile then
        stateMachine:LoadFromJSONFile(normalFile)
        stateMachine:Start()
    else
        print("[Client] ERROR: Normal FSM 文件未找到: " .. CONFIG.NormalFSM)
    end

    -- 创建 AimOffset 组件（用于程序化上半身瞄准）
    local aimOffset = modelNode:CreateComponent("AimOffset", LOCAL)
    aimOffset:AddBone("Bip001 Spine", 0.40, 0.40)
    aimOffset:AddBone("Bip001 Spine1", 0.35, 0.35)
    aimOffset:AddBone("Bip001 Spine2", 0.25, 0.25)
    aimOffset:SetMaxPitch(50)
    aimOffset:SetMaxYaw(30)
    aimOffset:SetSmoothSpeed(12)
    aimOffset:SetYawCompensation(0)
    aimOffset:SetEnabled(false)

    playerAnimData_[nodeId] = {
        fsm = stateMachine,
        fsmType = "normal",
        normalFile = normalFile,
        armedFile = armedFile,
        aimOffset = aimOffset,
        modelNode = modelNode,
    }
    return true
end

function SwitchPlayerFSM(nodeId, toArmed)
    local data = playerAnimData_[nodeId]
    if data == nil then return end

    local targetType = toArmed and "armed" or "normal"
    if data.fsmType == targetType then return end

    local fsm = data.fsm
    local targetFile = toArmed and data.armedFile or data.normalFile

    if fsm and targetFile then
        local moveSpeed = fsm:GetFloat("moveSpeed")
        local isGrounded = fsm:GetBool("isGrounded")

        fsm:LoadFromJSONFile(targetFile)
        fsm:Start()

        fsm:SetFloat("moveSpeed", moveSpeed)
        fsm:SetBool("isGrounded", isGrounded)

        data.fsmType = targetType
    end
end

-- ============================================================================
-- 工具函数
-- ============================================================================

function IsMyRoleArmed()
    if myRoleNode_ == nil then return false end
    return GetNodeArmedState(myRoleNode_)
end

-- ============================================================================
-- 更新循环
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    ProcessPendingCallbacks()
    UpdateHitEffects(dt)

    -- 处理待检查的 replicated 节点（检查 IS_ROLE 标记）
    if #pendingRoleNodes_ > 0 then
        local nodesToCheck = pendingRoleNodes_
        pendingRoleNodes_ = {}
        for _, nodeId in ipairs(nodesToCheck) do
            local node = scene_:GetNode(nodeId)
            if node then
                local isRoleVar = node:GetVar(VARS.IS_ROLE)
                if not isRoleVar:IsEmpty() and isRoleVar:GetBool() then
                    if not playerAnimData_[nodeId] then
                        SetupPlayerAnimation(node)
                    end
                end
            end
        end
    end

    -- 检查等待的节点（ASSIGN_ROLE 可能在节点同步之前到达）
    if pendingNodeId_ ~= 0 then
        local roleNode = scene_:GetNode(pendingNodeId_)
        if roleNode then
            pendingNodeId_ = 0
            BindToRole(roleNode)
        end
    end

    local serverConn = network:GetServerConnection()

    -- 绑定 GameHUD 到网络连接的 controls
    if needBindControls_ and serverConn then
        needBindControls_ = false
        GameHUD.SetControls(serverConn.controls)
    end

    -- 发送 Ready 事件
    if needSendReady_ then
        needSendReady_ = false
        if serverConn then
            serverConn:SendRemoteEvent(EVENTS.CLIENT_READY, true)
        end
    end

    if myRoleNode_ == nil then return end

    if isDead_ then
        return
    end

    UpdateMouseLook(dt)
    UpdateMovement(dt)
end

function HandlePostUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    UpdateCamera(dt)
    UpdateAllAnimations()
end

function UpdateMouseLook(dt)
    local mouseMove = input.mouseMove

    yaw_ = yaw_ + mouseMove.x * CONFIG.MouseSensitivity
    pitch_ = pitch_ + mouseMove.y * CONFIG.MouseSensitivity
    pitch_ = Shared.Clamp(pitch_, -89.0, 89.0)
end

function UpdateMovement(dt)
    if myRoleNode_ == nil then return end

    local serverConn = network:GetServerConnection()
    if serverConn == nil then return end

    local controls = serverConn.controls

    -- 设置视角（鼠标控制，触摸由 GameHUD.EnableTouchLook 处理）
    controls.yaw = yaw_
    controls.pitch = pitch_

    -- GameHUD 自动设置 CTRL_FORWARD/BACK/LEFT/RIGHT/JUMP/RUN
    -- 这里处理 SHOOT（服务器需要知道射击状态）
    local isShooting = false
    if IsMyRoleArmed() then
        -- PC: 鼠标左键 / 移动端: Fire 按钮
        isShooting = input:GetMouseButtonDown(MOUSEB_LEFT)
        if hudComponents_ and hudComponents_.shootButton then
            isShooting = isShooting or hudComponents_.shootButton.isPressed
        end
    end
    controls:Set(CTRL.SHOOT, isShooting)

    -- 射击冷却
    if shootCooldown_ > 0 then
        shootCooldown_ = shootCooldown_ - dt
    end

    -- PC 端射击动画（鼠标左键按下瞬间触发，命中特效由服务器广播）
    if IsMyRoleArmed() and input:GetMouseButtonPress(MOUSEB_LEFT) and shootCooldown_ <= 0 then
        shootCooldown_ = CONFIG.ShootInterval
        -- 触发射击动画
        local nodeId = myRoleNode_.ID
        local data = playerAnimData_[nodeId]
        if data and data.fsm then
            data.fsm:SetTrigger("shoot")
        end
    end
end

function UpdateCamera(dt)
    if myRoleNode_ == nil or cameraNode_ == nil then return end

    -- 根据状态选择目标参数：瞄准 > 持枪 > 普通
    local targetConfig
    if isAiming_ then
        targetConfig = CONFIG.Camera.aiming
    elseif IsMyRoleArmed() then
        targetConfig = CONFIG.Camera.armed
    else
        targetConfig = CONFIG.Camera.normal
    end

    -- 平滑过渡
    local lerpFactor = 1.0 - math.exp(-CONFIG.Camera.transitionSpeed * dt)
    currentCameraDistance_ = Lerp(currentCameraDistance_, targetConfig.distance, lerpFactor)
    currentCameraOffset_ = currentCameraOffset_:Lerp(targetConfig.offset, lerpFactor)
    currentCameraFOV_ = Lerp(currentCameraFOV_, targetConfig.fov, lerpFactor)

    -- 应用 FOV
    local camera = cameraNode_:GetComponent("Camera")
    if camera then
        camera.fov = currentCameraFOV_
    end

    -- 计算相机位置
    local rot = Quaternion(yaw_, Vector3.UP)
    local dir = rot * Quaternion(pitch_, Vector3.RIGHT)
    local aimPoint = myRoleNode_.position + rot * currentCameraOffset_
    local rayDir = dir * Vector3(0, 0, -1)
    local distance = currentCameraDistance_

    -- 碰撞检测避免穿墙
    local physicsWorld = scene_:GetComponent("PhysicsWorld")
    if physicsWorld then
        local result = physicsWorld:RaycastSingle(Ray(aimPoint, rayDir), distance, 1)
        if result.body then
            distance = math.max(1.0, result.distance - 0.2)
        end
    end

    cameraNode_.position = aimPoint + rayDir * distance
    cameraNode_.rotation = dir
end

function UpdateAllAnimations()
    for nodeId, data in pairs(playerAnimData_) do
        local roleNode = scene_:GetNode(nodeId)
        if roleNode then
            local character = roleNode:GetComponent("CharacterComponent")
            if character and data.fsm then
                -- 从节点变量读取 isArmed（服务器自动同步）
                local isArmed = GetNodeArmedState(roleNode)
                local expectedType = isArmed and "armed" or "normal"
                if data.fsmType ~= expectedType then
                    SwitchPlayerFSM(nodeId, isArmed)
                end

                -- 从 CharacterComponent 同步属性读取状态
                data.fsm:SetFloat("moveSpeed", character.moveSpeed)
                data.fsm:SetBool("isGrounded", character.onGround)

                if character.jumpStarted then
                    data.fsm:SetTrigger("jump")
                end

                -- 更新 AimOffset（持枪时启用）
                if data.aimOffset then
                    data.aimOffset:SetEnabled(isArmed)
                    if isArmed and myRoleNode_ and roleNode.ID == myRoleNode_.ID then
                        -- 自己的角色：使用本地 pitch
                        data.aimOffset:SetTargetPitch(pitch_)
                        -- 计算相对 yaw：相机方向 vs 角色朝向
                        local characterYaw = roleNode.worldRotation:YawAngle()
                        local relativeYaw = yaw_ - characterYaw
                        while relativeYaw > 180 do relativeYaw = relativeYaw - 360 end
                        while relativeYaw < -180 do relativeYaw = relativeYaw + 360 end
                        data.aimOffset:SetTargetYaw(relativeYaw)
                    end
                end
            end
        else
            -- 节点已删除，清理
            playerAnimData_[nodeId] = nil
        end
    end
end

-- ============================================================================
-- 射击特效
-- ============================================================================

function SpawnHitEffect(position, normal)
    -- 简单的命中粒子效果（LOCAL，不需要同步）
    local effectNode = scene_:CreateChild("HitEffect", LOCAL)
    effectNode.position = position

    -- 创建一个小球作为命中标记
    local model = effectNode:CreateComponent("StaticModel", LOCAL)
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    effectNode.scale = Vector3(0.1, 0.1, 0.1)

    local material = Shared.CreatePBRMaterial(Color(1, 0.8, 0), 0.9, 0.2)
    material:SetShaderParameter("MatEmissiveColor", Variant(Color(2, 1.5, 0)))
    model:SetMaterial(material)

    -- 添加到特效列表
    table.insert(hitEffects_, {
        node = effectNode,
        lifeTime = 0.3,
        elapsed = 0
    })
end

function UpdateHitEffects(dt)
    local i = 1
    while i <= #hitEffects_ do
        local effect = hitEffects_[i]
        effect.elapsed = effect.elapsed + dt

        local scale = 0.1 * (1 - effect.elapsed / effect.lifeTime)
        if scale <= 0 or effect.elapsed >= effect.lifeTime then
            effect.node:Remove()
            table.remove(hitEffects_, i)
        else
            effect.node.scale = Vector3(scale, scale, scale)
            i = i + 1
        end
    end
end

-- 处理服务器广播的射击命中事件
function HandleShootHit(eventType, eventData)
    local hitX = eventData["HitX"]:GetFloat()
    local hitY = eventData["HitY"]:GetFloat()
    local hitZ = eventData["HitZ"]:GetFloat()
    local hitPos = Vector3(hitX, hitY, hitZ)

    -- 生成命中特效
    SpawnHitEffect(hitPos, Vector3.UP)
end

-- ============================================================================
-- NanoVG UI 渲染
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if nvgCtx_ == nil then return end

    local gfx = GetGraphics()
    local width = gfx:GetWidth()
    local height = gfx:GetHeight()

    nvgBeginFrame(nvgCtx_, width, height, 1.0)

    -- 准心由 GameHUD 绘制，这里只绘制血条和死亡画面
    DrawHealthBar(nvgCtx_, width, height)

    if isDead_ then DrawDeathScreen(nvgCtx_, width, height) end

    nvgEndFrame(nvgCtx_)
end

function DrawHealthBar(ctx, width, height)
    local barWidth, barHeight = 200, 20
    local x, y = 20, height - 50
    local healthPercent = health_ / maxHealth_

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, barWidth, barHeight, 4)
    nvgFillColor(ctx, nvgRGBA(50, 50, 50, 180))
    nvgFill(ctx)

    local r, g, b = 200, 50, 50
    if healthPercent > 0.5 then r, g, b = 50, 200, 50
    elseif healthPercent > 0.25 then r, g, b = 200, 200, 50 end

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 2, y + 2, (barWidth - 4) * healthPercent, barHeight - 4, 2)
    nvgFillColor(ctx, nvgRGBA(r, g, b, 220))
    nvgFill(ctx)

    if fontNormal_ ~= -1 then
        nvgFontFaceId(ctx, fontNormal_)
        nvgFontSize(ctx, 16)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(ctx, x + barWidth / 2, y + barHeight / 2, health_ .. " / " .. maxHealth_)
    end
end

function DrawDeathScreen(ctx, width, height)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(100, 0, 0, 150))
    nvgFill(ctx)

    if fontNormal_ ~= -1 then
        nvgFontFaceId(ctx, fontNormal_)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        nvgFontSize(ctx, 48)
        nvgFillColor(ctx, nvgRGBA(255, 50, 50, 255))
        nvgText(ctx, width / 2, height / 2 - 30, "你死了")

        nvgFontSize(ctx, 24)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
        nvgText(ctx, width / 2, height / 2 + 30, "等待重生...")
    end
end

function HandlePostRenderUpdate(eventType, eventData)
    -- 调试渲染（可选）
end

-- ============================================================================
-- 延迟执行
-- ============================================================================

function DelayOneFrame(callback)
    table.insert(pendingCallbacks_, callback)
end

function ProcessPendingCallbacks()
    if #pendingCallbacks_ > 0 then
        local callbacks = pendingCallbacks_
        pendingCallbacks_ = {}
        for _, cb in ipairs(callbacks) do cb() end
    end
end

return Client
