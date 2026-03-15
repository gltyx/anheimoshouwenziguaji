-- ============================================================================
-- Shared.lua - 服务器和客户端共享的代码
-- ============================================================================

local Shared = {}

-- ============================================================================
-- 配置
-- ============================================================================

Shared.CONFIG = {
    -- 移动（CharacterComponent 使用）
    WalkSpeed = 0.025,
    RunSpeed = 0.1,
    MouseSensitivity = 0.15,

    -- 玩家
    PlayerHeight = 1.8,
    PlayerRadius = 0.35,
    EyeHeight = 1.6,

    -- 地图
    MapSize = 40,
    WallHeight = 3.0,

    -- 战斗
    MaxHealth = 100,
    ShootInterval = 0.15,
    DamagePerHit = 25,

    -- 资源
    PlayerPrefab = "DefaultMale/DefaultMale.prefab",
    NormalFSM = "urhox-libs/Animation/FSM/DefaultMale_Normal.fsm",
    ArmedFSM = "urhox-libs/Animation/FSM/DefaultMale_Armed.fsm",

    -- 相机（第三人称越肩）
    Camera = {
        normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 },
        armed = { distance = 4.0, offset = Vector3(0.6, 1.6, 0), fov = 45.0 },
        aiming = { distance = 2.0, offset = Vector3(0.4, 1.5, 0), fov = 32.0 },  -- 瞄准拉近
        transitionSpeed = 8.0,
    },
}

-- ============================================================================
-- 事件名常量
-- ============================================================================

Shared.EVENTS = {
    CLIENT_READY = "ClientReady",
    ASSIGN_ROLE = "AssignRole",
    HEALTH_UPDATE = "HealthUpdate",
    PLAYER_DIED = "PlayerDied",
    PLAYER_RESPAWN = "PlayerRespawn",
    TOGGLE_ARMED = "ToggleArmed",      -- 客户端请求切换持枪
    SHOOT_HIT = "ShootHit",            -- 服务器广播：射击命中
}

-- ============================================================================
-- 网络同步变量名（Node::SetVar）
-- ============================================================================

Shared.VARS = {
    IS_ROLE = "IsRole",    -- 角色节点标记，bool
    IS_ARMED = "IsArmed",  -- 持枪状态，bool
}

-- ============================================================================
-- 控制按钮常量（与 C++ CTRL_* 对应）
-- ============================================================================

Shared.CTRL = {
    FORWARD = 1,
    BACK = 2,
    LEFT = 4,
    RIGHT = 8,
    JUMP = 16,
    RUN = 32,
    SHOOT = 64,  -- 自定义，服务器处理
}

-- ============================================================================
-- 出生点
-- ============================================================================

Shared.SPAWN_POINTS = {
    Vector3(-15, 1.0, -15),
    Vector3(15, 1.0, -15),
    Vector3(-15, 1.0, 15),
    Vector3(15, 1.0, 15),
}

-- ============================================================================
-- 材质创建
-- ============================================================================

function Shared.CreatePBRMaterial(color, metallic, roughness)
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(color.r, color.g, color.b, 1.0)))
    material:SetShaderParameter("MatSpecColor", Variant(Color(0.5, 0.5, 0.5, 1.0)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    return material
end

-- ============================================================================
-- 场景创建
-- ============================================================================

function Shared.CreateScene(isServer)
    local scene = Scene()

    scene:CreateComponent("Octree", LOCAL)
    scene:CreateComponent("DebugRenderer", LOCAL)

    local physicsWorld = scene:CreateComponent("PhysicsWorld", LOCAL)
    physicsWorld:SetGravity(Vector3(0, -20.0, 0))

    -- 光照（仅客户端需要）
    if not isServer then
        scene:InstantiateXML("LightGroup/Daytime.xml", Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
    end

    -- 创建地图
    Shared.CreateMap(scene, isServer)

    return scene
end

-- ============================================================================
-- 地图创建
-- ============================================================================

function Shared.CreateMap(scene, isServer)
    local mapSize = Shared.CONFIG.MapSize
    local halfSize = mapSize / 2
    local wallHeight = Shared.CONFIG.WallHeight

    -- 地面
    local floor = scene:CreateChild("Floor", LOCAL)
    floor.position = Vector3(0, -0.5, 0)
    floor.scale = Vector3(mapSize, 1, mapSize)
    if not isServer then
        local floorModel = floor:CreateComponent("StaticModel", LOCAL)
        floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        floorModel:SetMaterial(Shared.CreatePBRMaterial(Color(0.3, 0.3, 0.35), 0.0, 0.8))
    end

    local floorBody = floor:CreateComponent("RigidBody", LOCAL)
    floorBody:SetCollisionLayer(1)
    local floorShape = floor:CreateComponent("CollisionShape", LOCAL)
    floorShape:SetBox(Vector3(1, 1, 1))

    -- 四面围墙
    Shared.CreateWall(scene, Vector3(0, wallHeight / 2, -halfSize), Vector3(mapSize, wallHeight, 1), isServer)
    Shared.CreateWall(scene, Vector3(0, wallHeight / 2, halfSize), Vector3(mapSize, wallHeight, 1), isServer)
    Shared.CreateWall(scene, Vector3(-halfSize, wallHeight / 2, 0), Vector3(1, wallHeight, mapSize), isServer)
    Shared.CreateWall(scene, Vector3(halfSize, wallHeight / 2, 0), Vector3(1, wallHeight, mapSize), isServer)

    -- 掩体
    Shared.CreateCover(scene, Vector3(0, 1, 0), Vector3(4, 2, 4), Color(0.5, 0.4, 0.3), isServer)
    Shared.CreateCover(scene, Vector3(-12, 0.75, -12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
    Shared.CreateCover(scene, Vector3(12, 0.75, -12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
    Shared.CreateCover(scene, Vector3(-12, 0.75, 12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
    Shared.CreateCover(scene, Vector3(12, 0.75, 12), Vector3(3, 1.5, 3), Color(0.4, 0.5, 0.4), isServer)
end

function Shared.CreateWall(scene, position, size, isServer)
    local wall = scene:CreateChild("Wall", LOCAL)
    wall.position = position
    wall.scale = size

    if not isServer then
        local model = wall:CreateComponent("StaticModel", LOCAL)
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Shared.CreatePBRMaterial(Color(0.4, 0.4, 0.45), 0.0, 0.7))
    end

    local body = wall:CreateComponent("RigidBody", LOCAL)
    body:SetCollisionLayer(1)
    local shape = wall:CreateComponent("CollisionShape", LOCAL)
    shape:SetBox(Vector3(1, 1, 1))
end

function Shared.CreateCover(scene, position, size, color, isServer)
    local cover = scene:CreateChild("Cover", LOCAL)
    cover.position = position
    cover.scale = size

    if not isServer then
        local model = cover:CreateComponent("StaticModel", LOCAL)
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(Shared.CreatePBRMaterial(color, 0.1, 0.6))
        model.castShadows = true
    end

    local body = cover:CreateComponent("RigidBody", LOCAL)
    body:SetCollisionLayer(1)
    local shape = cover:CreateComponent("CollisionShape", LOCAL)
    shape:SetBox(Vector3(1, 1, 1))
end

-- ============================================================================
-- 注册远端事件
-- ============================================================================

function Shared.RegisterEvents()
    for _, eventName in pairs(Shared.EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
end

-- ============================================================================
-- 工具函数
-- ============================================================================

function Shared.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function Shared.GetRandomSpawnPoint()
    local index = math.random(1, #Shared.SPAWN_POINTS)
    return Shared.SPAWN_POINTS[index]
end

function Shared.GetSpawnPointByIndex(index)
    local i = ((index - 1) % #Shared.SPAWN_POINTS) + 1
    return Shared.SPAWN_POINTS[i]
end

return Shared
