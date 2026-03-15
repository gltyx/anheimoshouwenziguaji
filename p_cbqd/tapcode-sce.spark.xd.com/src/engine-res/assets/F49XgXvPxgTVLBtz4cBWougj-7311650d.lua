-- ============================================================================
-- Server.lua - 服务器端逻辑
-- ============================================================================

local Server = {}
local Shared = require("Shared")

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 服务器模式下 mock 图形接口
-- ============================================================================

if GetGraphics() == nil then
    local mockGraphics = {
        SetWindowIcon = function() end,
        SetWindowTitleAndIcon = function() end,
        GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end,
    }
    ---@diagnostic disable-next-line: lowercase-global
    function GetGraphics() return mockGraphics end
    graphics = mockGraphics

    console = { background = {} }
    function GetConsole() return console end

    debugHud = {}
    function GetDebugHud() return debugHud end
end

-- ============================================================================
-- 服务器变量
-- ============================================================================

local scene_ = nil
local maxPlayers_ = 4  -- 默认值，从 settings.json 加载

-- 角色池（预创建）
local rolePool_ = {}             -- { [roleId] = roleNode }
local roleAssignments_ = {}      -- { [roleId] = connKey or nil }

-- 连接数据
local connectionRoles_ = {}      -- { [connKey] = roleId }
local serverConnections_ = {}    -- { [connKey] = connection }

-- 玩家数据（游戏逻辑层，按 roleId 索引）
local serverHealth_ = {}         -- { [roleId] = { current, max } }
local serverShootCooldown_ = {}  -- { [roleId] = cooldown }
local serverArmedState_ = {}     -- { [roleId] = bool }

-- 延迟回调
local pendingCallbacks_ = {}
local delayedCallbacks_ = {}

-- 快捷引用
local CONFIG = Shared.CONFIG
local EVENTS = Shared.EVENTS
local CTRL = Shared.CTRL
local VARS = Shared.VARS

-- ============================================================================
-- 入口函数
-- ============================================================================

function Server.Start()
    SampleStart()

    -- 加载配置
    LoadSettings()

    Shared.RegisterEvents()
    scene_ = Shared.CreateScene(true)  -- isServer = true

    -- 预创建所有角色
    CreateRolePool()

    SubscribeToEvent(EVENTS.CLIENT_READY, "HandleClientReady")
    SubscribeToEvent(EVENTS.TOGGLE_ARMED, "HandleToggleArmed")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent("Update", "HandleUpdate")
end

function LoadSettings()
    local settingsFile = cache:GetResource("JSONFile", "settings.json")
    if settingsFile then
        local root = settingsFile:GetRoot()
        if root:Contains("multiplayer") then
            local multiplayer = root:Get("multiplayer")
            if multiplayer:Contains("max_players") then
                maxPlayers_ = multiplayer:Get("max_players"):GetInt()
            end
        end
    end
end

function CreateRolePool()
    print("[Server] 创建角色池，maxPlayers: " .. maxPlayers_)
    for roleId = 1, maxPlayers_ do
        local spawnPos = Shared.GetSpawnPointByIndex(roleId)
        local roleNode = CreatePlayerRole(scene_, roleId, spawnPos)

        rolePool_[roleId] = roleNode
        roleAssignments_[roleId] = nil  -- 未分配

        -- 初始化游戏数据
        serverHealth_[roleId] = { current = CONFIG.MaxHealth, max = CONFIG.MaxHealth }
        serverShootCooldown_[roleId] = 0
        serverArmedState_[roleId] = false

        print("[Server] 创建 Role_" .. roleId .. " (ID: " .. roleNode.ID .. ")")
    end
end

function FindFreeRole()
    for roleId = 1, maxPlayers_ do
        if roleAssignments_[roleId] == nil then
            return roleId
        end
    end
    return nil  -- 没有空闲角色
end

function Server.Stop()
end

-- ============================================================================
-- 玩家连接/断开
-- ============================================================================

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    print("[Server] 收到 ClientReady")

    connection.scene = scene_

    local connKey = tostring(connection)

    -- 查找空闲角色
    local roleId = FindFreeRole()
    if roleId == nil then
        print("[Server] 服务器已满，拒绝连接")
        connection:Disconnect()
        return
    end

    local roleNode = rolePool_[roleId]
    print("[Server] 分配 Role_" .. roleId .. " (ID: " .. roleNode.ID .. ") 给玩家")

    -- 分配角色
    roleAssignments_[roleId] = connKey
    connectionRoles_[connKey] = roleId
    serverConnections_[connKey] = connection

    -- 设置 owner（用于 controls 同步）
    roleNode:SetOwner(connection)

    -- 重置角色状态
    ResetRoleState(roleId)

    -- 延迟发送角色分配
    local nodeId = roleNode.ID
    local conn = connection
    DelayOneFrame(function()
        local assignData = VariantMap()
        assignData["NodeId"] = Variant(nodeId)
        conn:SendRemoteEvent(EVENTS.ASSIGN_ROLE, true, assignData)
        print("[Server] 发送 ASSIGN_ROLE, NodeId: " .. nodeId)
    end)
end

function ResetRoleState(roleId)
    local roleNode = rolePool_[roleId]
    if roleNode == nil then return end

    -- 重置位置
    roleNode.position = Shared.GetSpawnPointByIndex(roleId)

    -- 重置游戏数据
    serverHealth_[roleId] = { current = CONFIG.MaxHealth, max = CONFIG.MaxHealth }
    serverShootCooldown_[roleId] = 0
    serverArmedState_[roleId] = false

    -- 重置网络同步变量
    roleNode:SetVar(VARS.IS_ARMED, Variant(false))

    -- 重置 CharacterComponent
    local character = roleNode:GetComponent("CharacterComponent")
    if character then
        character.autoRotateToMoveDir = true
        character.rotationSpeed = 1440.0
    end
end

function CreatePlayerRole(scene, roleId, spawnPos)
    local roleNode = scene:CreateChild("Role_" .. roleId, REPLICATED)
    roleNode.position = spawnPos

    -- RigidBody（碰撞检测 + 射线命中）
    local body = roleNode:CreateComponent("RigidBody", REPLICATED)
    body:SetCollisionLayerAndMask(CollisionLayerCharacter, CollisionMaskCharacter)
    body.mass = 1.0
    body:SetLinearFactor(Vector3.ZERO)
    body:SetAngularFactor(Vector3.ZERO)
    body:SetCollisionEventMode(COLLISION_ALWAYS)

    -- CollisionShape
    local shape = roleNode:CreateComponent("CollisionShape", REPLICATED)
    shape:SetCapsule(CONFIG.PlayerRadius * 2, CONFIG.PlayerHeight,
                     Vector3(0, CONFIG.PlayerHeight / 2, 0))

    -- KinematicCharacterController（服务器 LOCAL）
    local kcc = roleNode:CreateComponent("KinematicCharacterController", LOCAL)
    kcc:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)
    kcc:SetJumpSpeed(8.0)

    -- CharacterComponent（REPLICATED，属性同步到客户端）
    local character = roleNode:CreateComponent("CharacterComponent", REPLICATED)
    character:SetWalkSpeed(CONFIG.WalkSpeed)
    character:SetRunSpeed(CONFIG.RunSpeed)
    character:SetEnableWalkMode(true)
    character.autoRotateToMoveDir = true

    -- 设置角色标记和初始持枪状态（网络同步变量）
    roleNode:SetVar(VARS.IS_ROLE, Variant(true))
    roleNode:SetVar(VARS.IS_ARMED, Variant(false))

    return roleNode
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData:GetPtr("Connection", "Connection")
    local connKey = tostring(connection)

    local roleId = connectionRoles_[connKey]
    if roleId then
        -- 释放角色（不删除）
        roleAssignments_[roleId] = nil

        -- 清除 owner
        local roleNode = rolePool_[roleId]
        if roleNode then
            roleNode:SetOwner(nil)
        end

        -- 重置角色状态
        ResetRoleState(roleId)
    end

    connectionRoles_[connKey] = nil
    serverConnections_[connKey] = nil
end

-- ============================================================================
-- 切换持枪状态
-- ============================================================================

function HandleToggleArmed(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local roleId = connectionRoles_[connKey]

    if roleId == nil then return end

    local roleNode = rolePool_[roleId]
    if roleNode == nil then return end

    local newArmed = not (serverArmedState_[roleId] or false)
    serverArmedState_[roleId] = newArmed

    local character = roleNode:GetComponent("CharacterComponent")
    if character then
        character.autoRotateToMoveDir = not newArmed
        character.rotationSpeed = newArmed and 180.0 or 1440.0
    end

    roleNode:SetVar(VARS.IS_ARMED, Variant(newArmed))
end

-- ============================================================================
-- 更新循环
-- ============================================================================

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    ProcessPendingCallbacks()
    ProcessDelayedCallbacks()

    -- 遍历已分配的角色
    for roleId, connKey in pairs(roleAssignments_) do
        if connKey then
            local roleNode = rolePool_[roleId]
            local connection = serverConnections_[connKey]

            if connection and roleNode then
                if serverShootCooldown_[roleId] > 0 then
                    serverShootCooldown_[roleId] = serverShootCooldown_[roleId] - dt
                end

                MoveRole(roleNode, connection, roleId, dt)
                HandleShoot(roleNode, connection, roleId, dt)
            end
        end
    end
end

function MoveRole(roleNode, connection, roleId, dt)
    local character = roleNode:GetComponent("CharacterComponent")
    if character == nil then return end

    local controls = connection.controls
    local buttons = controls.buttons

    character.controls:Set(CTRL_FORWARD, (buttons & CTRL.FORWARD) ~= 0)
    character.controls:Set(CTRL_BACK, (buttons & CTRL.BACK) ~= 0)
    character.controls:Set(CTRL_LEFT, (buttons & CTRL.LEFT) ~= 0)
    character.controls:Set(CTRL_RIGHT, (buttons & CTRL.RIGHT) ~= 0)
    character.controls:Set(CTRL_JUMP, (buttons & CTRL.JUMP) ~= 0)
    character.controls:Set(CTRL_RUN, (buttons & CTRL.RUN) ~= 0)

    character.controls.yaw = controls.yaw
    character.controls.pitch = controls.pitch
end

function HandleShoot(roleNode, connection, roleId, dt)
    local controls = connection.controls
    local buttons = controls.buttons

    if (buttons & CTRL.SHOOT) == 0 then return end
    if serverShootCooldown_[roleId] > 0 then return end

    local health = serverHealth_[roleId]
    if health == nil or health.current <= 0 then return end

    if not serverArmedState_[roleId] then return end

    serverShootCooldown_[roleId] = CONFIG.ShootInterval

    local yaw = controls.yaw
    local pitch = controls.pitch

    local rot = Quaternion(yaw, Vector3.UP)
    local eyePos = roleNode.position + rot * CONFIG.Camera.armed.offset

    local yawRot = Quaternion(yaw, Vector3.UP)
    local pitchRot = Quaternion(pitch, Vector3.RIGHT)
    local shootDir = yawRot * pitchRot * Vector3.FORWARD

    local physicsWorld = scene_:GetComponent("PhysicsWorld")
    local result = physicsWorld:RaycastSingle(Ray(eyePos, shootDir), 100.0)

    if result.body ~= nil then
        local hitNode = result.body:GetNode()
        local hitPos = result.position

        BroadcastShootHit(hitPos)

        -- 如果命中其他玩家，造成伤害
        if hitNode ~= roleNode and string.find(hitNode.name, "Role_") then
            for hitRoleId, node in pairs(rolePool_) do
                if node == hitNode then
                    ApplyDamage(hitRoleId, CONFIG.DamagePerHit, roleId)
                    break
                end
            end
        end
    end
end

function BroadcastShootHit(hitPos)
    local eventData = VariantMap()
    eventData["HitX"] = Variant(hitPos.x)
    eventData["HitY"] = Variant(hitPos.y)
    eventData["HitZ"] = Variant(hitPos.z)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.SHOOT_HIT, true, eventData)
    end
end

-- ============================================================================
-- 伤害系统
-- ============================================================================

function ApplyDamage(victimRoleId, damage, attackerRoleId)
    local health = serverHealth_[victimRoleId]
    if health == nil or health.current <= 0 then return end

    health.current = health.current - damage
    if health.current < 0 then health.current = 0 end

    local victimNode = rolePool_[victimRoleId]
    local nodeId = victimNode and victimNode.ID or 0

    BroadcastHealthUpdate(nodeId, health.current, health.max)

    if health.current <= 0 then
        PlayerDied(victimRoleId, attackerRoleId)
    end
end

function BroadcastHealthUpdate(nodeId, current, max)
    local eventData = VariantMap()
    eventData["NodeId"] = Variant(nodeId)
    eventData["Health"] = Variant(current)
    eventData["MaxHealth"] = Variant(max)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.HEALTH_UPDATE, true, eventData)
    end
end

function PlayerDied(victimRoleId, attackerRoleId)
    local victimNode = rolePool_[victimRoleId]
    if victimNode == nil then return end

    -- 隐藏模型
    local modelNode = victimNode:GetChild("ModelNode")
    if modelNode then
        modelNode.enabled = false
    end

    -- 广播死亡事件
    local eventData = VariantMap()
    eventData["VictimId"] = Variant(victimNode.ID)
    eventData["AttackerId"] = Variant(0)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.PLAYER_DIED, true, eventData)
    end

    local roleId = victimRoleId
    DelayFrames(180, function() RespawnPlayer(roleId) end)
end

function RespawnPlayer(roleId)
    local roleNode = rolePool_[roleId]
    local health = serverHealth_[roleId]

    if roleNode == nil or health == nil then return end

    health.current = health.max
    roleNode.position = Shared.GetRandomSpawnPoint()

    -- 显示模型
    local modelNode = roleNode:GetChild("ModelNode")
    if modelNode then
        modelNode.enabled = true
    end

    local nodeId = roleNode.ID

    local eventData = VariantMap()
    eventData["NodeId"] = Variant(nodeId)
    eventData["Health"] = Variant(health.current)
    eventData["MaxHealth"] = Variant(health.max)

    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(EVENTS.PLAYER_RESPAWN, true, eventData)
    end

    BroadcastHealthUpdate(nodeId, health.current, health.max)
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

function DelayFrames(frames, callback)
    table.insert(delayedCallbacks_, { frames = frames, callback = callback })
end

function ProcessDelayedCallbacks()
    local i = 1
    while i <= #delayedCallbacks_ do
        local item = delayedCallbacks_[i]
        item.frames = item.frames - 1
        if item.frames <= 0 then
            item.callback()
            table.remove(delayedCallbacks_, i)
        else
            i = i + 1
        end
    end
end

return Server
