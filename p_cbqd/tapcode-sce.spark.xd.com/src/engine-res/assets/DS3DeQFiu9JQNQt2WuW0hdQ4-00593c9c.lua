-- Space Shooter - NanoVG 街机射击游戏
-- 这个示例展示：
--     - 使用 NanoVG API 创建完整的 2D 游戏
--     - 矢量图形渲染（飞船、敌人、子弹）
--     - 粒子效果系统（爆炸、尾焰、星空）
--     - 完整的游戏循环和状态管理
--     - 碰撞检测和物理系统
--     - 音效集成

-- ============================================================================
-- 常量定义
-- ============================================================================

-- 游戏状态
local STATE_MENU = 0
local STATE_PLAYING = 1
local STATE_PAUSED = 2
local STATE_GAMEOVER = 3
local STATE_VICTORY = 4

-- 实体类型
local ENTITY_PLAYER = 0
local ENTITY_ENEMY = 1
local ENTITY_BULLET = 2
local ENTITY_POWERUP = 3

-- 敌人类型
local ENEMY_SMALL = 0    -- 小型快速敌人
local ENEMY_MEDIUM = 1   -- 中型敌人
local ENEMY_LARGE = 2    -- 大型敌人
local ENEMY_BOSS = 3     -- Boss

-- AI行为模式
local AI_STRAIGHT = 0    -- 直线下落
local AI_SINE = 1        -- 正弦波
local AI_CHASE = 2       -- 追踪玩家

-- 道具类型
local POWERUP_WEAPON = 0    -- 武器升级
local POWERUP_HEALTH = 1    -- 生命恢复
local POWERUP_SHIELD = 2    -- 护盾
local POWERUP_LASER_WHIP = 3    -- 镭射鞭

-- 游戏参数
local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local PLAYER_SPEED = 350
local PLAYER_SHOOT_INTERVAL = 0.15
local PLAYER_MAX_HEALTH = 3
local PLAYER_INVINCIBLE_TIME = 2.0
local BULLET_SPEED = 600
local ENEMY_BULLET_SPEED = 300
local MAX_PARTICLES = 500
local STAR_COUNT = 100

-- 镭射鞭参数
local WHIP_LENGTH = 1200       -- 鞭子最大长度（贯穿屏幕）
local WHIP_DURATION = 4.0      -- 持续时间（增加到4秒）
local WHIP_COOLDOWN = 0.6      -- 冷却时间
local WHIP_WIDTH_BASE = 15     -- 根部宽度（加粗）
local WHIP_WIDTH_TIP = 4       -- 末端宽度（加粗）
local WHIP_CHARGES = 3         -- 每次拾取补充的使用次数
local WHIP_MAX_CHARGES = 15    -- 最大充能次数
local WHIP_DAMAGE_PER_SEC = 5  -- 每秒伤害
local WHIP_DETECT_RADIUS = 120 -- 吸附检测半径（更大的范围）
local WHIP_SWING_SPEED = 3     -- 甩动速度
local WHIP_SWING_AMOUNT = 25   -- 甩动幅度

-- Boss参数
local BOSS_WAVE_INTERVAL = 8   -- 每8波出现一次Boss
local BOSS_BASE_HEALTH = 100   -- Boss基础血量
local BOSS_HEALTH_SCALE = 50   -- 每次Boss增加的血量
local BOSS_BASE_SIZE = 120     -- Boss基础尺寸（增大到120）

-- Boss攻击模式
local BOSS_ATTACK_NORMAL = 0   -- 普通射击
local BOSS_ATTACK_SPREAD = 1   -- 扇形弹幕
local BOSS_ATTACK_HOMING = 2   -- 追踪弹
local BOSS_ATTACK_LASER = 3    -- 脉冲镭射
local BOSS_LASER_CHARGE_TIME = 0.3  -- 镭射充能时间（瞄准前摇）

-- ============================================================================
-- 全局变量
-- ============================================================================

local nvgContext = nil
local gameState = STATE_MENU
local score = 0
local highScore = 0
local currentWave = 1
local waveEnemiesLeft = 0
local isFirstTimeEver = true  -- 首次启动游戏标志（体验关卡）
local bossCount = 0  -- Boss出现次数计数

-- 移动平台触控支持
local touchEnabled = false
local whipButtonPressed = false
local lastTouchCount = 0  -- 上一帧的触控数量
local wasTouching = false  -- 上一帧是否有触控（用于检测touchup）

-- 虚拟触控板系统
local virtualPad = {
    active = false,        -- 触控板是否激活
    centerX = 0,          -- 触控板中心X（屏幕坐标）
    centerY = 0,          -- 触控板中心Y（屏幕坐标）
    width = 0,            -- 触控板宽度
    height = 0,           -- 触控板高度
    scale = 0.3           -- 触控板缩放比例（30%）
}

-- 玩家数据
local player = {
    x = 0,
    y = 0,
    vx = 0,
    vy = 0,
    health = PLAYER_MAX_HEALTH,
    maxHealth = PLAYER_MAX_HEALTH,
    weaponLevel = 1,
    shootTimer = 0,
    invincibleTimer = 0,
    radius = 15,
    alive = true,
    shieldHits = 0,  -- 护盾剩余抵挡次数（0-3）
    hasLaserWhip = true,
    laserWhipCharges = 0,  -- 初始0发
    whipCooldown = 0
}

-- 实体列表
local enemies = {}
local bullets = {}
local powerups = {}
local particles = {}
local stars = {}
local whips = {}  -- 镭射鞭列表

-- 输入状态
local input = {
    left = false,
    right = false,
    up = false,
    down = false,
    useWhip = false
}

-- 波次配置
local waveConfig = {
    enemyCount = 5,
    spawnInterval = 0.8,
    difficulty = 1.0
}

local waveTimer = 0
local spawnTimer = 0

-- 音效资源
local scene_ = nil
local sounds = {
    shoot = nil,
    explosion = nil,
    powerup = nil,
    hit = nil
}

-- 屏幕震动
local screenShake = {
    time = 0,
    intensity = 0
}

-- 字体
local fontId = -1

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 数学工具
local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- 圆形碰撞检测
local function circleCollision(x1, y1, r1, x2, y2, r2)
    return distance(x1, y1, x2, y2) < (r1 + r2)
end

-- 随机数工具
local function randomFloat(min, max)
    return min + math.random() * (max - min)
end

local function randomInt(min, max)
    return math.random(min, max)
end

-- 缓动函数
local function easeOutQuad(t)
    return t * (2 - t)
end

local function easeInQuad(t)
    return t * t
end

-- 点到线段的距离（用于鞭子碰撞检测）
local function pointToSegmentDistance(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local lenSq = dx * dx + dy * dy
    
    if lenSq == 0 then
        return distance(px, py, x1, y1)
    end
    
    -- 计算投影参数t
    local t = ((px - x1) * dx + (py - y1) * dy) / lenSq
    t = clamp(t, 0, 1)
    
    -- 计算最近点
    local nearestX = x1 + t * dx
    local nearestY = y1 + t * dy
    
    return distance(px, py, nearestX, nearestY)
end

-- ============================================================================
-- 粒子系统
-- ============================================================================

local function createParticle(x, y, vx, vy, life, size, r, g, b, a)
    if #particles >= MAX_PARTICLES then
        return
    end
    
    table.insert(particles, {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        life = life,
        maxLife = life,
        size = size,
        r = r,
        g = g,
        b = b,
        a = a
    })
end

local function createExplosion(x, y, count, speed, size, r, g, b)
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local vx = math.cos(angle) * randomFloat(speed * 0.5, speed)
        local vy = math.sin(angle) * randomFloat(speed * 0.5, speed)
        local life = randomFloat(0.5, 1.0)
        createParticle(x, y, vx, vy, life, size, r, g, b, 1.0)
    end
end

local function createEngineTrail(x, y)
    -- 主引擎尾焰（青色）
    for i = 1, 2 do
        local vx = randomFloat(-15, 15)
        local vy = randomFloat(80, 200)
        local size = randomFloat(4, 8)
        createParticle(x, y, vx, vy, 0.5, size, 0.3, 0.9, 1.0, 1.0)
    end
    
    -- 白色核心
    local vx = randomFloat(-5, 5)
    local vy = randomFloat(100, 180)
    createParticle(x, y, vx, vy, 0.3, 3, 1.0, 1.0, 1.0, 1.0)
end

local function initStars()
    stars = {}
    for i = 1, STAR_COUNT do
        table.insert(stars, {
            x = randomFloat(0, SCREEN_WIDTH),
            y = randomFloat(0, SCREEN_HEIGHT),
            size = randomFloat(1, 3),
            speed = randomFloat(20, 80),
            brightness = randomFloat(0.3, 1.0)
        })
    end
end

-- ============================================================================
-- 实体创建函数
-- ============================================================================

local function resetPlayer()
    player.x = SCREEN_WIDTH / 2
    player.y = SCREEN_HEIGHT - 100
    player.vx = 0
    player.vy = 0
    player.health = player.maxHealth
    player.weaponLevel = 1
    player.shootTimer = 0
    player.invincibleTimer = PLAYER_INVINCIBLE_TIME
    player.alive = true
    player.shieldHits = 0
    player.hasLaserWhip = true
    player.laserWhipCharges = 0  -- 初始0发
    player.whipCooldown = 0
end

local function createBullet(x, y, vx, vy, damage, fromPlayer)
    table.insert(bullets, {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        damage = damage,
        radius = fromPlayer and 5 or 6,
        fromPlayer = fromPlayer,
        alive = true
    })
end

local function playerShoot()
    if player.shootTimer > 0 then
        return
    end
    
    player.shootTimer = PLAYER_SHOOT_INTERVAL
    
    if player.weaponLevel == 1 then
        -- 1级：单发
        createBullet(player.x, player.y - 20, 0, -BULLET_SPEED, 1, true)
        -- 发射粒子特效
        for i = 1, 5 do
            local angle = -math.pi / 2 + randomFloat(-0.3, 0.3)
            local speed = randomFloat(50, 100)
            local vx = math.cos(angle) * speed
            local vy = math.sin(angle) * speed
            createParticle(player.x, player.y - 20, vx, vy, 0.2, 2, 0.5, 1.0, 1.0, 1.0)
        end
    elseif player.weaponLevel == 2 then
        -- 2级：双发
        createBullet(player.x - 10, player.y - 20, 0, -BULLET_SPEED, 1, true)
        createBullet(player.x + 10, player.y - 20, 0, -BULLET_SPEED, 1, true)
        -- 双发射口粒子
        for side = -1, 1, 2 do
            for i = 1, 4 do
                local angle = -math.pi / 2 + randomFloat(-0.3, 0.3)
                local speed = randomFloat(50, 100)
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                createParticle(player.x + side * 10, player.y - 20, vx, vy, 0.2, 2, 0.5, 1.0, 1.0, 1.0)
            end
        end
    elseif player.weaponLevel == 3 then
        -- 3级：三发
        createBullet(player.x - 15, player.y - 20, 0, -BULLET_SPEED, 1, true)
        createBullet(player.x, player.y - 20, 0, -BULLET_SPEED, 2, true)
        createBullet(player.x + 15, player.y - 20, 0, -BULLET_SPEED, 1, true)
        -- 三发射口粒子
        for _, xOffset in ipairs({-15, 0, 15}) do
            for i = 1, 4 do
                local angle = -math.pi / 2 + randomFloat(-0.3, 0.3)
                local speed = randomFloat(60, 120)
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                createParticle(player.x + xOffset, player.y - 20, vx, vy, 0.2, 2, 0.5, 1.0, 1.0, 1.0)
            end
        end
    elseif player.weaponLevel == 4 then
        -- 4级：三发 + 两颗散射弹
        createBullet(player.x - 15, player.y - 20, 0, -BULLET_SPEED, 1, true)
        createBullet(player.x, player.y - 20, 0, -BULLET_SPEED, 2, true)
        createBullet(player.x + 15, player.y - 20, 0, -BULLET_SPEED, 1, true)
        
        -- 散射弹（向左上和右上，角度25度）
        local scatterAngle = math.pi / 7.2  -- 约25度
        createBullet(player.x - 10, player.y - 15, 
                    -math.sin(scatterAngle) * BULLET_SPEED, -math.cos(scatterAngle) * BULLET_SPEED, 
                    1, true)
        createBullet(player.x + 10, player.y - 15, 
                    math.sin(scatterAngle) * BULLET_SPEED, -math.cos(scatterAngle) * BULLET_SPEED, 
                    1, true)
        
        -- 粒子特效
        for _, xOffset in ipairs({-15, 0, 15}) do
            for i = 1, 4 do
                local angle = -math.pi / 2 + randomFloat(-0.3, 0.3)
                local speed = randomFloat(60, 120)
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                createParticle(player.x + xOffset, player.y - 20, vx, vy, 0.2, 2, 0.5, 1.0, 1.0, 1.0)
            end
        end
        -- 散射弹粒子
        for side = -1, 1, 2 do
            for i = 1, 3 do
                local angle = -math.pi / 2 + side * scatterAngle + randomFloat(-0.2, 0.2)
                local speed = randomFloat(50, 100)
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                createParticle(player.x + side * 10, player.y - 15, vx, vy, 0.2, 2, 1.0, 0.8, 0.3, 1.0)
            end
        end
    elseif player.weaponLevel >= 5 then
        -- 5级：三发 + 四颗散射弹（两个角度）
        createBullet(player.x - 15, player.y - 20, 0, -BULLET_SPEED, 1, true)
        createBullet(player.x, player.y - 20, 0, -BULLET_SPEED, 2, true)
        createBullet(player.x + 15, player.y - 20, 0, -BULLET_SPEED, 1, true)
        
        -- 第一组散射弹（角度25度）
        local scatterAngle1 = math.pi / 7.2  -- 约25度
        createBullet(player.x - 10, player.y - 15, 
                    -math.sin(scatterAngle1) * BULLET_SPEED, -math.cos(scatterAngle1) * BULLET_SPEED, 
                    1, true)
        createBullet(player.x + 10, player.y - 15, 
                    math.sin(scatterAngle1) * BULLET_SPEED, -math.cos(scatterAngle1) * BULLET_SPEED, 
                    1, true)
        
        -- 第二组散射弹（角度45度）
        local scatterAngle2 = math.pi / 4  -- 45度
        createBullet(player.x - 12, player.y - 10, 
                    -math.sin(scatterAngle2) * BULLET_SPEED, -math.cos(scatterAngle2) * BULLET_SPEED, 
                    1, true)
        createBullet(player.x + 12, player.y - 10, 
                    math.sin(scatterAngle2) * BULLET_SPEED, -math.cos(scatterAngle2) * BULLET_SPEED, 
                    1, true)
        
        -- 粒子特效
        for _, xOffset in ipairs({-15, 0, 15}) do
            for i = 1, 4 do
                local angle = -math.pi / 2 + randomFloat(-0.3, 0.3)
                local speed = randomFloat(60, 120)
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                createParticle(player.x + xOffset, player.y - 20, vx, vy, 0.2, 2, 0.5, 1.0, 1.0, 1.0)
            end
        end
        -- 散射弹粒子（第一组）
        for side = -1, 1, 2 do
            for i = 1, 3 do
                local angle = -math.pi / 2 + side * scatterAngle1 + randomFloat(-0.2, 0.2)
                local speed = randomFloat(50, 100)
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                createParticle(player.x + side * 10, player.y - 15, vx, vy, 0.2, 2, 1.0, 0.8, 0.3, 1.0)
            end
        end
        -- 散射弹粒子（第二组）
        for side = -1, 1, 2 do
            for i = 1, 3 do
                local angle = -math.pi / 2 + side * scatterAngle2 + randomFloat(-0.2, 0.2)
                local speed = randomFloat(50, 100)
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                createParticle(player.x + side * 12, player.y - 10, vx, vy, 0.2, 2, 1.0, 0.6, 0.2, 1.0)
            end
        end
    end
    
    -- 播放射击音效
    playSound("shoot")
end

local function createEnemy(enemyType)
    local enemy = {
        type = enemyType,
        x = randomFloat(50, SCREEN_WIDTH - 50),
        y = -50,
        vx = 0,
        vy = 0,
        health = 1,
        maxHealth = 1,
        radius = 15,
        shootTimer = 0,
        shootInterval = 2.0,
        aiType = AI_STRAIGHT,
        aiTimer = 0,
        alive = true,
        points = 100
    }
    
    -- 根据类型设置属性
    if enemyType == ENEMY_SMALL then
        enemy.health = 1
        enemy.maxHealth = 1
        enemy.radius = 12
        enemy.vy = randomFloat(80, 120)
        enemy.shootInterval = 3.0
        enemy.points = 100
        enemy.aiType = randomInt(0, 1) == 0 and AI_STRAIGHT or AI_SINE
    elseif enemyType == ENEMY_MEDIUM then
        enemy.health = 3
        enemy.maxHealth = 3
        enemy.radius = 18
        enemy.vy = randomFloat(60, 90)
        enemy.shootInterval = 2.0
        enemy.points = 200
        enemy.aiType = AI_SINE
    elseif enemyType == ENEMY_LARGE then
        enemy.health = 5
        enemy.maxHealth = 5
        enemy.radius = 25
        enemy.vy = randomFloat(40, 60)
        enemy.shootInterval = 1.5
        enemy.points = 500
        enemy.aiType = AI_CHASE
    elseif enemyType == ENEMY_BOSS then
        -- Boss等级（根据当前波次计算，保持递增难度）
        local bossLevel = math.floor(currentWave / BOSS_WAVE_INTERVAL)
        
        enemy.health = BOSS_BASE_HEALTH + bossLevel * BOSS_HEALTH_SCALE
        enemy.maxHealth = enemy.health
        enemy.radius = BOSS_BASE_SIZE
        enemy.vy = 20  -- Boss移动较慢
        enemy.shootInterval = math.max(0.3, 1.0 - bossLevel * 0.1)  -- 攻击频率递增
        enemy.points = 5000 + bossLevel * 2000
        enemy.aiType = AI_CHASE
        
        -- Boss特有属性
        enemy.isBoss = true
        enemy.bossLevel = bossLevel
        enemy.phase = 1  -- 阶段（1-3）
        enemy.attackMode = BOSS_ATTACK_NORMAL
        enemy.attackTimer = 0
        enemy.attackCooldown = 2.0
        enemy.laserActive = false
        enemy.laserTimer = 0
        enemy.laserDuration = 3.0
        enemy.laserAngle = 0
        
        -- Boss多部件（飞碟UFO设计）
        enemy.tentacles = {}  -- 机械臂数组
        local tentacleCount = 6  -- 6条机械臂
        for i = 0, tentacleCount - 1 do
            local angle = (i / tentacleCount) * math.pi * 2
            -- 机械臂血量随波次增加（提升一倍）
            local tentacleHealth = 20 * bossLevel  -- 基础20，每波增加20
            table.insert(enemy.tentacles, {
                angle = angle,              -- 基准角度（安装位置）
                angleRange = math.pi * 0.4, -- 摆动角度范围（±72度）
                swingSpeed = 0.8 + math.random() * 0.4,  -- 摆动速度（随机）
                baseX = 0,                  -- 基部X（相对核心）
                baseY = 0,                  -- 基部Y（相对核心）
                length = 180,               -- 机械臂长度
                segments = 5,               -- 机械臂节数（减少节数，提升性能）
                baseWidth = 20,             -- 机械臂基部宽度
                wavePhase = i * 0.5,       -- 波动相位
                health = tentacleHealth,    -- 机械臂生命值（根据波次，提升一倍）
                maxHealth = tentacleHealth, -- 机械臂最大血量
                positions = {},             -- 存储每节的实际位置（用于碰撞检测）
                destroyed = false           -- 是否被摧毁（用于爆炸后消失）
            })
        end
        
        -- 小飞碟护卫（真实敌机）
        enemy.minions = {}  -- 小飞碟数组
        local minionCount = 6  -- 6个小飞碟
        for i = 0, minionCount - 1 do
            local angle = (i / minionCount) * math.pi * 2
            local baseDistance = 200 + math.random() * 120  -- 基础距离：200-320
            -- 小飞碟血量随波次增加（提升一倍）
            local minionHealth = 16 * bossLevel  -- 基础16，每波增加16
            table.insert(enemy.minions, {
                angle = angle,              -- 当前角度
                baseAngle = angle,          -- 基准角度
                distance = baseDistance,    -- 当前距离
                baseDistance = baseDistance,-- 基础距离
                orbitSpeed = 0.3,           -- 轨道旋转速度
                floatPhase = math.random() * math.pi * 2,  -- 漂浮相位
                health = minionHealth,      -- 小飞碟血量（根据波次，提升一倍）
                maxHealth = minionHealth,   -- 最大血量
                radius = 30,                -- 小飞碟半径（稍微缩小到30）
                shootTimer = math.random() * 2,  -- 射击计时器
                shootInterval = 2.0         -- 射击间隔
            })
        end
    end
    
    table.insert(enemies, enemy)
    return enemy
end

local function createPowerup(x, y, powerupType)
    table.insert(powerups, {
        type = powerupType,
        x = x,
        y = y,
        vy = 100,
        radius = 12,
        alive = true,
        pulseTimer = 0
    })
end

-- ============================================================================
-- Boss攻击系统
-- ============================================================================

-- Boss扇形弹幕攻击
local function bossSpreadAttack(boss)
    local bulletCount = 12 + boss.bossLevel * 3  -- 随等级增加弹幕密度
    local spreadAngle = math.pi * 0.6  -- 扇形角度（约108度）
    local startAngle = math.pi / 2 - spreadAngle / 2
    
    for i = 0, bulletCount - 1 do
        local angle = startAngle + (spreadAngle / (bulletCount - 1)) * i
        local speed = ENEMY_BULLET_SPEED * 1.2
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        createBullet(boss.x, boss.y + 30, vx, vy, 1, false)
        
        -- 弹幕特效
        for j = 1, 2 do
            createParticle(boss.x, boss.y + 30, vx * 0.3, vy * 0.3, 0.3, 3, 1.0, 0.3, 0.0, 1.0)
        end
    end
    
    addScreenShake(0.2, 8)
    playSound("shoot")
end

-- Boss追踪弹攻击
local function bossHomingAttack(boss)
    local homingCount = 3 + boss.bossLevel  -- 追踪弹数量
    
    for i = 1, homingCount do
        -- 计算朝向玩家的方向
        local dx = player.x - boss.x
        local dy = player.y - boss.y
        local dist = math.sqrt(dx * dx + dy * dy)
        
        if dist > 0 then
            local speed = ENEMY_BULLET_SPEED * 0.8  -- 追踪弹稍慢
            local vx = (dx / dist) * speed
            local vy = (dy / dist) * speed
            
            -- 添加一些随机偏移
            local offsetAngle = (i - homingCount / 2) * 0.3
            local cosOff = math.cos(offsetAngle)
            local sinOff = math.sin(offsetAngle)
            local finalVx = vx * cosOff - vy * sinOff
            local finalVy = vx * sinOff + vy * cosOff
            
            createBullet(boss.x, boss.y + 30, finalVx, finalVy, 1, false)
            
            -- 追踪弹特效（紫色）
            for j = 1, 3 do
                createParticle(boss.x, boss.y + 30, finalVx * 0.2, finalVy * 0.2, 0.4, 4, 0.8, 0.2, 1.0, 1.0)
            end
        end
    end
    
    addScreenShake(0.15, 6)
    playSound("shoot")
end

-- Boss镭射激活
local function bossActivateLaser(boss)
    boss.laserActive = true
    boss.laserTimer = 0
    -- 镭射指向玩家
    local dx = player.x - boss.x
    local dy = player.y - boss.y
    boss.laserAngle = math.atan2(dy, dx)
    
    -- 激活特效
    for i = 1, 20 do
        local angle = math.random() * math.pi * 2
        local speed = randomFloat(100, 250)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        createParticle(boss.x, boss.y, vx, vy, 0.6, 5, 1.0, 0.5, 0.0, 1.0)
    end
    
    addScreenShake(0.4, 12)
    playSound("powerup")
end

-- Boss镭射更新和伤害检测
local function updateBossLaser(boss, dt)
    if not boss.laserActive then
        return
    end
    
    boss.laserTimer = boss.laserTimer + dt
    
    -- 镭射持续时间结束
    if boss.laserTimer >= boss.laserDuration then
        boss.laserActive = false
        return
    end
    
    -- 镭射慢慢追踪玩家
    local targetAngle = math.atan2(player.y - boss.y, player.x - boss.x)
    local angleDiff = targetAngle - boss.laserAngle
    -- 角度标准化到 -π 到 π
    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
    
    boss.laserAngle = boss.laserAngle + angleDiff * 0.02  -- 慢速追踪
    
    -- 镭射伤害检测（只有充能完成后才造成伤害）
    if boss.laserTimer < BOSS_LASER_CHARGE_TIME then
        -- 充能阶段：不造成伤害
        return
    end
    
    -- 镭射伤害检测（射线碰撞，使用更长的长度确保命中）
    local laserLength = 2000  -- 与渲染长度一致
    local laserEndX = boss.x + math.cos(boss.laserAngle) * laserLength
    local laserEndY = boss.y + math.sin(boss.laserAngle) * laserLength
    
    -- 检测镭射与玩家的碰撞
    if player.alive and player.invincibleTimer <= 0 then
        -- 点到线段的距离
        local px = player.x - boss.x
        local py = player.y - boss.y
        local lx = laserEndX - boss.x
        local ly = laserEndY - boss.y
        local lenSq = lx * lx + ly * ly
        if lenSq > 0 then
            local t = math.max(0, math.min(1, (px * lx + py * ly) / lenSq))
            local closestX = boss.x + lx * t
            local closestY = boss.y + ly * t
            local dist = distance(player.x, player.y, closestX, closestY)
            
            if dist < player.radius + 15 then  -- 增大判定范围
                -- 持续伤害
                if math.random() < 0.3 then  -- 30%几率每帧造成伤害
                    if player.shieldHits > 0 then
                        player.shieldHits = player.shieldHits - 1
                        createExplosion(player.x, player.y, 15, 100, 4, 0.0, 0.7, 1.0)
                        playSound("hit")
                    else
                        player.health = player.health - 1
                        player.invincibleTimer = PLAYER_INVINCIBLE_TIME
                        createExplosion(player.x, player.y, 20, 120, 5, 1.0, 0.0, 0.0)
                        addScreenShake(0.3, 15)
                        
                        if player.health <= 0 then
                            player.alive = false
                            createExplosion(player.x, player.y, 40, 180, 6, 1.0, 0.3, 0.0)
                            playSound("explosion")
                            gameState = STATE_GAMEOVER
                        end
                    end
                end
            end
        end
    end
    
    -- 镭射粒子特效
    if math.random() < 0.5 then
        local t = math.random()
        local px = boss.x + (laserEndX - boss.x) * t
        local py = boss.y + (laserEndY - boss.y) * t
        createParticle(px, py, randomFloat(-50, 50), randomFloat(-50, 50), 0.3, 4, 1.0, 0.8, 0.2, 1.0)
    end
end

-- ============================================================================
-- 镭射鞭系统
-- ============================================================================

local function createWhip(x, y, angle)
    local whip = {
        startX = x,
        startY = y,
        angle = angle,
        lifetime = WHIP_DURATION,
        targetEnemy = nil,        -- 吸附的目标
        targetType = nil,         -- 目标类型（"enemy", "tentacle", "minion"）
        damageTimer = 0,          -- 伤害计时器
        hitEnemies = {},          -- 路径伤害计时器（每个敌人独立计时）
        swingTimer = 0,           -- 甩动计时器
        lightningTimer = 0,       -- 闪电效果计时器
        targetLockTimer = 0       -- 目标锁定计时器（至少维持2秒）
    }
    
    -- 计算默认终点（直线向前，贯穿屏幕）
    whip.defaultEndX = x + math.cos(angle) * WHIP_LENGTH
    whip.defaultEndY = y + math.sin(angle) * WHIP_LENGTH
    
    table.insert(whips, whip)
    
    -- 播放特殊音效
    playSound("powerup")
    
    -- 激活时震屏！
    addScreenShake(0.3, 15)
    
    -- 激活时爆炸性粒子特效
    for i = 1, 30 do
        local angle_particle = math.random() * math.pi * 2
        local speed = randomFloat(100, 300)
        local vx = math.cos(angle_particle) * speed
        local vy = math.sin(angle_particle) * speed
        createParticle(x, y, vx, vy, 0.5, 5, 0.5, 1.0, 1.0, 1.0)
    end
    
    return whip
end

local function playerUseWhip()
    -- 检查是否拥有镭射鞭
    if not player.hasLaserWhip or player.laserWhipCharges <= 0 then
        return
    end
    
    -- 检查冷却时间
    if player.whipCooldown > 0 then
        return
    end
    
    -- 检查是否已经有活跃的鞭子
    if #whips > 0 then
        return
    end
    
    -- 消耗一次使用次数
    player.laserWhipCharges = player.laserWhipCharges - 1
    if player.laserWhipCharges <= 0 then
        player.hasLaserWhip = false
    end
    
    -- 重置冷却
    player.whipCooldown = WHIP_COOLDOWN
    
    -- 默认向上发射（正前方）
    local angle = -math.pi / 2
    
    createWhip(player.x, player.y, angle)
end

-- ============================================================================
-- 游戏逻辑更新
-- ============================================================================

local function updatePlayer(dt)
    if not player.alive then
        return
    end
    
    -- 更新计时器
    if player.shootTimer > 0 then
        player.shootTimer = player.shootTimer - dt
    end
    
    if player.invincibleTimer > 0 then
        player.invincibleTimer = player.invincibleTimer - dt
    end
    
    if player.whipCooldown > 0 then
        player.whipCooldown = player.whipCooldown - dt
    end
    
    -- 移动（支持触控和键盘，两种方式同时有效）
    player.vx = 0
    player.vy = 0
    
    -- 键盘移动（始终有效）
    if input.left then
        player.vx = -PLAYER_SPEED
    elseif input.right then
        player.vx = PLAYER_SPEED
    end
    
    if input.up then
        player.vy = -PLAYER_SPEED
    elseif input.down then
        player.vy = PLAYER_SPEED
    end
    
    -- 触控/鼠标移动：使用虚拟触控板系统（如果有输入，覆盖键盘输入）
    if gameState == STATE_PLAYING then
        local inputSystem = GetInput()
        local hasPointerInput = false
        local rawX, rawY = 0, 0
        
        -- 检测触控输入（移动平台）
        if inputSystem:GetNumTouches() > 0 then
            local touch = inputSystem:GetTouch(0)
            rawX = touch.position.x
            rawY = touch.position.y
            hasPointerInput = true
        -- 检测鼠标左键按下（PC）
        elseif inputSystem:GetMouseButtonDown(MOUSEB_LEFT) then
            rawX = inputSystem:GetMousePosition().x
            rawY = inputSystem:GetMousePosition().y
            hasPointerInput = true
        end
        
        if hasPointerInput then
            local graphics = GetGraphics()
            local windowW = graphics:GetWidth()
            local windowH = graphics:GetHeight()
            
            -- 映射到游戏坐标
            local touchX = rawX * (SCREEN_WIDTH / windowW)
            local touchY = rawY * (SCREEN_HEIGHT / windowH)
            
            -- 初始化虚拟触控板
            if not virtualPad.active then
                virtualPad.active = true
                virtualPad.width = SCREEN_WIDTH * virtualPad.scale
                virtualPad.height = SCREEN_HEIGHT * virtualPad.scale
                
                -- 触控板中心位置：使按下点在触控板中的相对位置 = 飞机在屏幕中的相对位置
                local playerRelX = player.x / SCREEN_WIDTH  -- 飞机相对位置 (0-1)
                local playerRelY = player.y / SCREEN_HEIGHT
                
                -- 触控点应在触控板中的位置（相对中心的偏移）
                local targetOffsetX = (playerRelX - 0.5) * virtualPad.width
                local targetOffsetY = (playerRelY - 0.5) * virtualPad.height
                
                -- 计算触控板中心
                virtualPad.centerX = touchX - targetOffsetX
                virtualPad.centerY = touchY - targetOffsetY
            end
            
            -- 计算触控点相对于触控板中心的偏移
            local offsetX = touchX - virtualPad.centerX
            local offsetY = touchY - virtualPad.centerY
            
            -- 映射到触控板相对坐标（-0.5 到 +0.5）
            local relX = offsetX / virtualPad.width
            local relY = offsetY / virtualPad.height
            
            -- 限制在触控板范围内
            relX = clamp(relX, -0.5, 0.5)
            relY = clamp(relY, -0.5, 0.5)
            
            -- 映射到屏幕目标位置
            local targetX = (relX + 0.5) * SCREEN_WIDTH
            local targetY = (relY + 0.5) * SCREEN_HEIGHT
            
            -- 限制在屏幕边界内
            targetX = clamp(targetX, player.radius, SCREEN_WIDTH - player.radius)
            targetY = clamp(targetY, player.radius, SCREEN_HEIGHT - player.radius)
            
            -- 计算移动方向
            local dx = targetX - player.x
            local dy = targetY - player.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            -- 朝目标移动（触控速度1.5倍）
            if dist > 10 then
                player.vx = (dx / dist) * PLAYER_SPEED * 1.5
                player.vy = (dy / dist) * PLAYER_SPEED * 1.5
            end
        else
            -- 没有触控输入时，重置虚拟触控板
            virtualPad.active = false
        end
    end
    
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt
    
    -- 边界限制
    player.x = clamp(player.x, player.radius, SCREEN_WIDTH - player.radius)
    player.y = clamp(player.y, player.radius, SCREEN_HEIGHT - player.radius)
    
    -- 自动射击
    playerShoot()
    
    -- 使用镭射鞭（键盘或触控按钮）
    if input.useWhip or whipButtonPressed then
        playerUseWhip()
        whipButtonPressed = false  -- 重置按钮状态
    end
    
    -- 引擎尾焰（更频繁更炫，匹配独立引擎火箭位置）
    if math.random() < 0.8 then
        -- 左右引擎火箭（放大1.5倍后的位置）
        local scale = 1.5
        createEngineTrail(player.x - 11 * scale, player.y + 14 * scale)
        createEngineTrail(player.x + 11 * scale, player.y + 14 * scale)
    end
    
    -- 移动时的侧向粒子
    if math.abs(player.vx) > 100 and math.random() < 0.3 then
        local side = player.vx > 0 and -1 or 1
        local vx = side * randomFloat(50, 100)
        local vy = randomFloat(20, 60)
        createParticle(player.x + side * player.radius * 0.7, player.y, vx, vy, 0.3, 3, 0.5, 0.8, 1.0, 0.8)
    end
end

local function updateEnemies(dt)
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        
        if not enemy.alive then
            table.remove(enemies, i)
        else
            -- Boss特殊逻辑
            if enemy.isBoss then
                -- 更新Boss阶段（根据血量）
                local healthPercent = enemy.health / enemy.maxHealth
                if healthPercent > 0.66 then
                    enemy.phase = 1
                elseif healthPercent > 0.33 then
                    enemy.phase = 2
                else
                    enemy.phase = 3
                end
                
                -- Boss移动（左右横向移动 + 限定高度）
                enemy.aiTimer = enemy.aiTimer + dt
                local targetY = 150  -- Boss保持在屏幕上方
                local targetX = SCREEN_WIDTH / 2 + math.sin(enemy.aiTimer * 0.8) * 300
                
                local dx = targetX - enemy.x
                local dy = targetY - enemy.y
                local moveSpeed = 150
                
                enemy.x = enemy.x + dx * dt * 0.5
                enemy.y = enemy.y + dy * dt * 0.8
                
                -- 更新Boss镭射
                updateBossLaser(enemy, dt)
                
                -- 更新小飞碟护卫（移动+射击）
                if enemy.minions then
                    for _, minion in ipairs(enemy.minions) do
                        if minion.health > 0 then
                            -- 轨道旋转
                            minion.angle = minion.angle + minion.orbitSpeed * dt
                            
                            -- 漂浮运动（距离波动）
                            minion.floatPhase = minion.floatPhase + dt * 2
                            minion.distance = minion.baseDistance + math.sin(minion.floatPhase) * 40
                            
                            -- 射击逻辑
                            minion.shootTimer = minion.shootTimer + dt
                            if minion.shootTimer >= minion.shootInterval then
                                minion.shootTimer = 0
                                
                                -- 计算小飞碟世界坐标
                                local minionX = enemy.x + math.cos(minion.angle) * minion.distance
                                local minionY = enemy.y + math.sin(minion.angle) * minion.distance
                                
                                -- 向玩家射击
                                if player.alive then
                                    local dx = player.x - minionX
                                    local dy = player.y - minionY
                                    local dist = math.sqrt(dx * dx + dy * dy)
                                    if dist > 0 then
                                        local vx = (dx / dist) * ENEMY_BULLET_SPEED * 0.8
                                        local vy = (dy / dist) * ENEMY_BULLET_SPEED * 0.8
                                        createBullet(minionX, minionY, vx, vy, 1, false)
                                        playSound("shoot")
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Boss攻击逻辑
                enemy.attackTimer = enemy.attackTimer + dt
                
                if enemy.attackTimer >= enemy.attackCooldown then
                    enemy.attackTimer = 0
                    
                    -- 判断是否解放镭射能力（血量 <= 2/3）
                    local canUseLaser = (enemy.health <= enemy.maxHealth * 0.67)
                    
                    -- 根据阶段和血量选择攻击模式
                    if enemy.phase == 1 then
                        -- 阶段1：普通射击 + 扇形弹幕 (+ 镭射)
                        local rand = math.random()
                        if canUseLaser and rand < 0.25 then
                            -- 低血量时可以使用镭射
                            if not enemy.laserActive then
                                bossActivateLaser(enemy)
                            end
                        elseif rand < 0.7 then
                            -- 普通射击
                            if player.alive then
                                local dx = player.x - enemy.x
                                local dy = player.y - enemy.y
                                local dist = math.sqrt(dx * dx + dy * dy)
                                if dist > 0 then
                                    local vx = (dx / dist) * ENEMY_BULLET_SPEED
                                    local vy = (dy / dist) * ENEMY_BULLET_SPEED
                                    createBullet(enemy.x, enemy.y + 30, vx, vy, 1, false)
                                    playSound("shoot")
                                end
                            end
                        else
                            bossSpreadAttack(enemy)
                        end
                    elseif enemy.phase == 2 then
                        -- 阶段2：扇形弹幕 + 追踪弹 (+ 镭射)
                        local rand = math.random()
                        if canUseLaser and rand < 0.3 then
                            -- 低血量时可以使用镭射
                            if not enemy.laserActive then
                                bossActivateLaser(enemy)
                            end
                        elseif rand < 0.5 then
                            bossSpreadAttack(enemy)
                        else
                            bossHomingAttack(enemy)
                        end
                    else
                        -- 阶段3：全部攻击模式 + 镭射（镭射概率更高）
                        local rand = math.random()
                        if canUseLaser and rand < 0.4 then
                            -- 低血量时使用镭射（概率更高）
                            if not enemy.laserActive then
                                bossActivateLaser(enemy)
                            end
                        elseif rand < 0.6 then
                            bossSpreadAttack(enemy)
                        else
                            bossHomingAttack(enemy)
                        end
                    end
                end
            else
                -- 普通敌人AI行为
                enemy.aiTimer = enemy.aiTimer + dt
                
                if enemy.aiType == AI_STRAIGHT then
                    -- 直线下落
                    enemy.y = enemy.y + enemy.vy * dt
                elseif enemy.aiType == AI_SINE then
                    -- 正弦波
                    enemy.y = enemy.y + enemy.vy * dt
                    enemy.x = enemy.x + math.sin(enemy.aiTimer * 3) * 100 * dt
                elseif enemy.aiType == AI_CHASE then
                    -- 追踪玩家
                    if player.alive then
                        local dx = player.x - enemy.x
                        local dy = player.y - enemy.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist > 0 then
                            enemy.vx = (dx / dist) * enemy.vy * 0.5
                            enemy.vy = math.max(enemy.vy * 0.3, 40)
                        end
                    end
                    enemy.x = enemy.x + enemy.vx * dt
                    enemy.y = enemy.y + enemy.vy * dt
                end
                
                -- 普通敌人射击
                enemy.shootTimer = enemy.shootTimer - dt
                if enemy.shootTimer <= 0 and enemy.y > 0 and enemy.y < SCREEN_HEIGHT - 100 then
                    enemy.shootTimer = enemy.shootInterval
                    if player.alive then
                        local dx = player.x - enemy.x
                        local dy = player.y - enemy.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist > 0 then
                            local vx = (dx / dist) * ENEMY_BULLET_SPEED
                            local vy = (dy / dist) * ENEMY_BULLET_SPEED
                            createBullet(enemy.x, enemy.y, vx, vy, 1, false)
                        end
                    end
                end
                
                -- 移出屏幕
                if enemy.y > SCREEN_HEIGHT + 50 then
                    enemy.alive = false
                end
            end
            
            -- 边界限制
            enemy.x = clamp(enemy.x, enemy.radius, SCREEN_WIDTH - enemy.radius)
        end
    end
end

local function updateBullets(dt)
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        
        if not bullet.alive then
            table.remove(bullets, i)
        else
            bullet.x = bullet.x + bullet.vx * dt
            bullet.y = bullet.y + bullet.vy * dt
            
            -- 移出屏幕
            if bullet.x < -10 or bullet.x > SCREEN_WIDTH + 10 or
               bullet.y < -10 or bullet.y > SCREEN_HEIGHT + 10 then
                bullet.alive = false
            end
        end
    end
end

local function updatePowerups(dt)
    for i = #powerups, 1, -1 do
        local powerup = powerups[i]
        
        if not powerup.alive then
            table.remove(powerups, i)
        else
            powerup.y = powerup.y + powerup.vy * dt
            powerup.pulseTimer = powerup.pulseTimer + dt
            
            if powerup.y > SCREEN_HEIGHT + 50 then
                powerup.alive = false
            end
        end
    end
end

local function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

local function updateStars(dt)
    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > SCREEN_HEIGHT then
            star.y = 0
            star.x = randomFloat(0, SCREEN_WIDTH)
        end
    end
end

local function updateWhips(dt)
    for i = #whips, 1, -1 do
        local whip = whips[i]
        
        -- 更新生命周期
        whip.lifetime = whip.lifetime - dt
        if whip.lifetime > 0 then
            -- 更新起点（跟随玩家）
            whip.startX = player.x
            whip.startY = player.y
            
            -- 更新默认终点
            whip.defaultEndX = player.x + math.cos(whip.angle) * WHIP_LENGTH
            whip.defaultEndY = player.y + math.sin(whip.angle) * WHIP_LENGTH
            
            -- 更新目标锁定计时器
            whip.targetLockTimer = whip.targetLockTimer + dt
            
            -- 检查当前目标是否仍然有效
            local currentTargetValid = false
            if whip.targetEnemy then
                if whip.targetType == "enemy" and whip.targetEnemy.alive then
                    currentTargetValid = true
                elseif whip.targetType == "tentacle" and whip.targetEnemy.tentacle and not whip.targetEnemy.tentacle.destroyed and whip.targetEnemy.tentacle.health > 0 then
                    currentTargetValid = true
                elseif whip.targetType == "minion" and whip.targetEnemy.minion and whip.targetEnemy.minion.health > 0 and whip.targetEnemy.boss and whip.targetEnemy.boss.alive then
                    currentTargetValid = true
                end
            end
            
            -- 寻找吸附目标（只有在无目标、目标失效、或锁定超过2秒时才重新寻找）
            -- 注意：如果当前吸附的是Boss本体或普通敌人，则不受2秒限制（持续吸附直到死亡）
            local shouldFindNewTarget = false
            if not currentTargetValid then
                shouldFindNewTarget = true
            elseif whip.targetLockTimer >= 2.0 then
                -- 只有小目标（触手、小飞碟）才会在2秒后重新寻找
                if whip.targetType == "tentacle" or whip.targetType == "minion" then
                    shouldFindNewTarget = true
                end
            end
            
            if shouldFindNewTarget then
                whip.targetEnemy = nil
                whip.targetType = nil
                
                -- 计算射线方向
                local dirX = math.cos(whip.angle)
                local dirY = math.sin(whip.angle)
                
                -- 寻找射线附近最近的目标
                local closestTarget = nil
                local closestTargetType = nil
                local closestDist = WHIP_DETECT_RADIUS
                
                -- 1. 检测普通敌人和Boss本体
                for _, enemy in ipairs(enemies) do
                    if enemy.alive then
                        -- Boss保护机制：检查是否可以作为目标
                        local canTarget = true
                        if enemy.type == ENEMY_BOSS and enemy.tentacles then
                            local anyTentacleAlive = false
                            for _, tentacle in ipairs(enemy.tentacles) do
                                if not tentacle.destroyed and tentacle.health > 0 then
                                    anyTentacleAlive = true
                                    break
                                end
                            end
                            -- Boss有机械臂保护时不能作为目标
                            if anyTentacleAlive then
                                canTarget = false
                            end
                        end
                        
                        if canTarget then
                            -- 计算敌人到射线的距离
                            local dx = enemy.x - player.x
                            local dy = enemy.y - player.y
                            
                            -- 投影到射线上
                            local projection = dx * dirX + dy * dirY
                            
                            -- 只考虑前方的敌人
                            if projection > 0 and projection < WHIP_LENGTH then
                                -- 计算垂直距离
                                local projX = player.x + dirX * projection
                                local projY = player.y + dirY * projection
                                local dist = distance(enemy.x, enemy.y, projX, projY)
                                
                                if dist < closestDist then
                                    closestDist = dist
                                    closestTarget = enemy
                                    closestTargetType = "enemy"
                                end
                            end
                        end
                        
                        -- 2. 检测Boss的机械臂（触手）
                        if enemy.type == ENEMY_BOSS and enemy.tentacles then
                            for _, tentacle in ipairs(enemy.tentacles) do
                                if not tentacle.destroyed and tentacle.health > 0 and tentacle.positions then
                                    -- 检测机械臂每一节
                                    for _, segment in ipairs(tentacle.positions) do
                                        local dx = segment.x - player.x
                                        local dy = segment.y - player.y
                                        local projection = dx * dirX + dy * dirY
                                        
                                        if projection > 0 and projection < WHIP_LENGTH then
                                            local projX = player.x + dirX * projection
                                            local projY = player.y + dirY * projection
                                            local dist = distance(segment.x, segment.y, projX, projY)
                                            
                                            if dist < closestDist then
                                                closestDist = dist
                                                closestTarget = { x = segment.x, y = segment.y, tentacle = tentacle, segment = segment }
                                                closestTargetType = "tentacle"
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- 3. 检测Boss的小飞碟
                        if enemy.type == ENEMY_BOSS and enemy.minions then
                            for _, minion in ipairs(enemy.minions) do
                                if minion.health > 0 then
                                    local minionX = enemy.x + math.cos(minion.angle) * minion.distance
                                    local minionY = enemy.y + math.sin(minion.angle) * minion.distance
                                    
                                    local dx = minionX - player.x
                                    local dy = minionY - player.y
                                    local projection = dx * dirX + dy * dirY
                                    
                                    if projection > 0 and projection < WHIP_LENGTH then
                                        local projX = player.x + dirX * projection
                                        local projY = player.y + dirY * projection
                                        local dist = distance(minionX, minionY, projX, projY)
                                        
                                        if dist < closestDist then
                                            closestDist = dist
                                            closestTarget = { x = minionX, y = minionY, minion = minion, boss = enemy }
                                            closestTargetType = "minion"
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                whip.targetEnemy = closestTarget
                whip.targetType = closestTargetType
                
                -- 如果找到新目标，重置锁定计时器
                if closestTarget then
                    whip.targetLockTimer = 0
                end
            else
                -- 目标仍然有效，更新目标的实时位置
                if whip.targetEnemy then
                    if whip.targetType == "minion" and whip.targetEnemy.minion and whip.targetEnemy.boss then
                        -- 更新小飞碟的实时位置（它们在旋转）
                        whip.targetEnemy.x = whip.targetEnemy.boss.x + math.cos(whip.targetEnemy.minion.angle) * whip.targetEnemy.minion.distance
                        whip.targetEnemy.y = whip.targetEnemy.boss.y + math.sin(whip.targetEnemy.minion.angle) * whip.targetEnemy.minion.distance
                    elseif whip.targetType == "tentacle" and whip.targetEnemy.tentacle and whip.targetEnemy.tentacle.positions then
                        -- 更新机械臂节点的实时位置（它们在摆动）
                        -- 找到最接近原始位置的节点（因为positions每帧重建）
                        local closestSegment = whip.targetEnemy.tentacle.positions[1]
                        local closestDist = 999999
                        for _, segment in ipairs(whip.targetEnemy.tentacle.positions) do
                            local dist = distance(segment.x, segment.y, whip.targetEnemy.x, whip.targetEnemy.y)
                            if dist < closestDist then
                                closestDist = dist
                                closestSegment = segment
                            end
                        end
                        whip.targetEnemy.x = closestSegment.x
                        whip.targetEnemy.y = closestSegment.y
                        whip.targetEnemy.segment = closestSegment
                    elseif whip.targetType == "enemy" and whip.targetEnemy.alive then
                        -- 普通敌人/Boss本体的位置已经是实时的，无需更新
                    end
                end
            end
            
            -- 更新伤害计时器
            whip.damageTimer = whip.damageTimer + dt
            
            -- 更新甩动计时器
            whip.swingTimer = whip.swingTimer + dt
            
            -- 更新闪电效果计时器
            whip.lightningTimer = whip.lightningTimer + dt
            
            -- 更新路径伤害计时器（每个敌人独立计时）
            for enemyId, timer in pairs(whip.hitEnemies) do
                if timer > 0 then
                    whip.hitEnemies[enemyId] = timer - dt
                end
            end
        else
            -- 生命周期结束，移除鞭子
            table.remove(whips, i)
        end
    end
end

local function checkWhipCollisions()
    for _, whip in ipairs(whips) do
        -- 确定鞭子终点
        local endX, endY
        local hasTarget = false
        
        -- 检查目标是否有效
        if whip.targetEnemy then
            if whip.targetType == "enemy" and whip.targetEnemy.alive then
                hasTarget = true
                endX = whip.targetEnemy.x
                endY = whip.targetEnemy.y
            elseif whip.targetType == "tentacle" and whip.targetEnemy.tentacle and not whip.targetEnemy.tentacle.destroyed then
                hasTarget = true
                endX = whip.targetEnemy.x
                endY = whip.targetEnemy.y
            elseif whip.targetType == "minion" and whip.targetEnemy.minion and whip.targetEnemy.minion.health > 0 then
                hasTarget = true
                endX = whip.targetEnemy.x
                endY = whip.targetEnemy.y
            end
        end
        
        if not hasTarget then
            endX = whip.defaultEndX
            endY = whip.defaultEndY
        end
        
        -- 只有在有目标时才计算贝塞尔曲线控制点
        local cp1X, cp1Y, cp2X, cp2Y
        
        if hasTarget then
            -- 计算垂直偏移（产生弧度）
            local dx = endX - whip.startX
            local dy = endY - whip.startY
            local dist = math.sqrt(dx * dx + dy * dy)
            local perpX = -dy / (dist + 0.001)
            local perpY = dx / (dist + 0.001)
            
            -- 根据目标相对位置动态调整弧线方向
            local angleToTarget = math.atan2(dy, dx)
            local angleToPlayer = math.atan2(-player.y, -player.x)
            local relativeAngle = angleToTarget - angleToPlayer
            
            -- 根据相对角度调整弧线方向（左侧弧向左，右侧弧向右）
            local directionMultiplier = 1
            if dx < 0 then
                directionMultiplier = -1  -- 目标在左侧，弧线向左
            end
            
            -- 多段动态扭曲效果（段数在1-3之间动态变化）
            -- 动态段数：使用sin函数让段数在1-3之间平滑变化
            local segmentPhase = math.sin(whip.swingTimer * WHIP_SWING_SPEED * 2.0) * 0.5 + 0.5  -- 0-1
            local numSegments = 1 + math.floor(segmentPhase * 2.5)  -- 1, 2, 或 3
            
            -- 基础幅度
            local baseArc = 80
            
            -- 第一控制点（33%位置）- 多段扭曲
            local arc1 = baseArc
            arc1 = arc1 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 6.0) * 70   -- 主摆动
            arc1 = arc1 + math.cos(whip.swingTimer * WHIP_SWING_SPEED * 10.0 + 0.0) * 50  -- 段1扭曲
            if numSegments >= 2 then
                arc1 = arc1 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 15.0 + 1.0) * 40  -- 段2扭曲
            end
            if numSegments >= 3 then
                arc1 = arc1 + math.cos(whip.swingTimer * WHIP_SWING_SPEED * 20.0 + 2.0) * 30  -- 段3扭曲
            end
            arc1 = arc1 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 25.0) * 15  -- 快速颤动
            
            -- 第二控制点（67%位置）- 与第一个相位相反，形成S型扭曲
            local arc2 = baseArc
            arc2 = arc2 - math.sin(whip.swingTimer * WHIP_SWING_SPEED * 6.0) * 70   -- 反向摆动
            arc2 = arc2 - math.cos(whip.swingTimer * WHIP_SWING_SPEED * 10.0 + math.pi) * 50  -- 反向段1
            if numSegments >= 2 then
                arc2 = arc2 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 15.0 + 2.0) * 40  -- 段2扭曲
            end
            if numSegments >= 3 then
                arc2 = arc2 - math.cos(whip.swingTimer * WHIP_SWING_SPEED * 20.0 + 3.0) * 30  -- 段3扭曲
            end
            arc2 = arc2 - math.sin(whip.swingTimer * WHIP_SWING_SPEED * 25.0) * 15  -- 反向颤动
            
            cp1X = whip.startX + dx * 0.33 + perpX * arc1 * directionMultiplier
            cp1Y = whip.startY + dy * 0.33 + perpY * arc1 * directionMultiplier
            cp2X = whip.startX + dx * 0.67 + perpX * arc2 * directionMultiplier
            cp2Y = whip.startY + dy * 0.67 + perpY * arc2 * directionMultiplier
        end
        
        -- 持续伤害吸附目标
        if whip.targetEnemy then
            local canDamage = true
            local targetX, targetY
            local targetStillValid = false
            
            -- 检查目标是否仍然有效，并获取目标位置
            if whip.targetType == "enemy" then
                if whip.targetEnemy.alive then
                    targetStillValid = true
                    targetX = whip.targetEnemy.x
                    targetY = whip.targetEnemy.y
                    
                    -- Boss保护机制
                    if whip.targetEnemy.type == ENEMY_BOSS and whip.targetEnemy.tentacles then
                        local anyTentacleAlive = false
                        for _, tentacle in ipairs(whip.targetEnemy.tentacles) do
                            if not tentacle.destroyed and tentacle.health > 0 then
                                anyTentacleAlive = true
                                break
                            end
                        end
                        if anyTentacleAlive then
                            canDamage = false
                            whip.targetEnemy = nil
                        end
                    end
                end
            elseif whip.targetType == "tentacle" then
                if whip.targetEnemy.tentacle and not whip.targetEnemy.tentacle.destroyed and whip.targetEnemy.tentacle.health > 0 then
                    targetStillValid = true
                    targetX = whip.targetEnemy.x
                    targetY = whip.targetEnemy.y
                end
            elseif whip.targetType == "minion" then
                if whip.targetEnemy.minion and whip.targetEnemy.minion.health > 0 and whip.targetEnemy.boss and whip.targetEnemy.boss.alive then
                    targetStillValid = true
                    -- 更新小飞碟的实时位置
                    targetX = whip.targetEnemy.boss.x + math.cos(whip.targetEnemy.minion.angle) * whip.targetEnemy.minion.distance
                    targetY = whip.targetEnemy.boss.y + math.sin(whip.targetEnemy.minion.angle) * whip.targetEnemy.minion.distance
                    whip.targetEnemy.x = targetX
                    whip.targetEnemy.y = targetY
                end
            end
            
            if not targetStillValid then
                whip.targetEnemy = nil
                whip.targetType = nil
            end
            
            if canDamage and targetStillValid and whip.damageTimer >= 0.3 then  -- 每0.3秒造成一次伤害（降低频率）
                whip.damageTimer = 0
                
                -- 根据目标类型扣血（降低伤害）
                if whip.targetType == "enemy" then
                    whip.targetEnemy.health = whip.targetEnemy.health - WHIP_DAMAGE_PER_SEC * 0.3 * 0.7  -- 降低到70%
                elseif whip.targetType == "tentacle" then
                    whip.targetEnemy.tentacle.health = whip.targetEnemy.tentacle.health - WHIP_DAMAGE_PER_SEC * 0.3 * 0.7
                elseif whip.targetType == "minion" then
                    whip.targetEnemy.minion.health = whip.targetEnemy.minion.health - WHIP_DAMAGE_PER_SEC * 0.3 * 0.7
                end
                
                -- 闪电命中特效（吸附目标）- 蓝紫色系 - 增强版
                -- 外层：青蓝色闪电
                for j = 1, 15 do  -- 8 -> 15
                    local angle = math.random() * math.pi * 2
                    local speed = randomFloat(120, 300)
                    local vx = math.cos(angle) * speed
                    local vy = math.sin(angle) * speed
                    createParticle(targetX, targetY, vx, vy, 0.5, 7, 0.3, 0.8, 1.0, 1.0)  -- 增大：5->7
                end
                
                -- 中层：紫色能量
                for j = 1, 10 do  -- 6 -> 10
                    local angle = math.random() * math.pi * 2
                    local speed = randomFloat(80, 220)
                    local vx = math.cos(angle) * speed
                    local vy = math.sin(angle) * speed
                    createParticle(targetX, targetY, vx, vy, 0.6, 8, 0.7, 0.4, 1.0, 1.0)  -- 增大：6->8
                end
                
                -- 核心：亮青色闪光
                for j = 1, 6 do  -- 4 -> 6
                    local angle = math.random() * math.pi * 2
                    local speed = randomFloat(60, 150)
                    local vx = math.cos(angle) * speed
                    local vy = math.sin(angle) * speed
                    createParticle(targetX, targetY, vx, vy, 0.4, 6, 0.5, 1.0, 1.0, 1.0)  -- 增大：4->6
                end
                
                -- 持续震屏（增强）
                addScreenShake(0.25, 8)
                playSound("hit")
                
                -- 检查是否击杀（根据目标类型）
                local targetDead = false
                if whip.targetType == "enemy" then
                    if whip.targetEnemy.health <= 0 then
                        whip.targetEnemy.alive = false
                        score = score + whip.targetEnemy.points * 2
                        targetDead = true
                        waveEnemiesLeft = waveEnemiesLeft - 1
                    end
                elseif whip.targetType == "tentacle" then
                    if whip.targetEnemy.tentacle.health <= 0 then
                        whip.targetEnemy.tentacle.destroyed = true
                        score = score + 150  -- 击毁触手得分
                        targetDead = true
                    end
                elseif whip.targetType == "minion" then
                    if whip.targetEnemy.minion.health <= 0 then
                        score = score + 100  -- 击毁小飞碟得分
                        targetDead = true
                    end
                end
                
                if targetDead then
                    -- 超级华丽的爆炸效果
                    createExplosion(targetX, targetY, 60, 350, 12, 0.5, 1.0, 1.0)
                    createExplosion(targetX, targetY, 50, 300, 10, 1.0, 0.4, 1.0)
                    createExplosion(targetX, targetY, 40, 250, 8, 0.3, 0.8, 1.0)
                    
                    playSound("explosion")
                    addScreenShake(0.6, 25)  -- 更强的震屏
                    
                    whip.targetEnemy = nil
                    whip.targetType = nil
                end
            end
        end
        
        -- 检测鞭子路径上的其他敌人
        local segments = 25
        for i = 1, segments do
            local t = i / segments
            
            -- 根据是否有目标使用不同的路径采样
            local x, y
            
            if hasTarget then
                -- 贝塞尔曲线采样（有目标时）
                local mt = 1 - t
                local mt2 = mt * mt
                local mt3 = mt2 * mt
                local t2 = t * t
                local t3 = t2 * t
                
                x = mt3 * whip.startX + 
                    3 * mt2 * t * cp1X + 
                    3 * mt * t2 * cp2X + 
                    t3 * endX
                y = mt3 * whip.startY + 
                    3 * mt2 * t * cp1Y + 
                    3 * mt * t2 * cp2Y + 
                    t3 * endY
            else
                -- 直线采样（无目标时）
                x = whip.startX + (endX - whip.startX) * t
                y = whip.startY + (endY - whip.startY) * t
            end
            
            -- 检测路径伤害（普通敌人和小飞碟）
            for _, enemy in ipairs(enemies) do
                if enemy.alive and enemy ~= whip.targetEnemy then
                    -- Boss保护机制：检查是否可以造成伤害
                    local canDamage = true
                    if enemy.type == ENEMY_BOSS and enemy.tentacles then
                        local anyTentacleAlive = false
                        for _, tentacle in ipairs(enemy.tentacles) do
                            if not tentacle.destroyed and tentacle.health > 0 then
                                anyTentacleAlive = true
                                break
                            end
                        end
                        -- Boss有机械臂保护时路径也不能伤害
                        if anyTentacleAlive then
                            canDamage = false
                        end
                    end
                    
                    local enemyId = tostring(enemy)
                    if canDamage then
                        if distance(x, y, enemy.x, enemy.y) < enemy.radius + WHIP_WIDTH_BASE then
                            -- 路径伤害计时器（每0.1秒可以命中一次）
                            if not whip.hitEnemies[enemyId] then
                                whip.hitEnemies[enemyId] = 0
                            end
                            
                            if whip.hitEnemies[enemyId] <= 0 then
                                whip.hitEnemies[enemyId] = 0.1  -- 重置计时器
                                
                                -- 路径伤害（略低于吸附伤害）
                                enemy.health = enemy.health - 1
                            
                            -- 闪电命中特效（路径目标）- 蓝紫色系 - 增强版
                            -- 青蓝色闪电
                            for j = 1, 8 do  -- 4 -> 8
                                local angle = math.random() * math.pi * 2
                                local speed = randomFloat(80, 220)
                                local vx = math.cos(angle) * speed
                                local vy = math.sin(angle) * speed
                                createParticle(enemy.x, enemy.y, vx, vy, 0.4, 6, 0.3, 0.8, 1.0, 1.0)  -- 增大：4->6
                            end
                            
                            -- 紫色能量
                            for j = 1, 5 do  -- 3 -> 5
                                local angle = math.random() * math.pi * 2
                                local speed = randomFloat(60, 150)
                                local vx = math.cos(angle) * speed
                                local vy = math.sin(angle) * speed
                                createParticle(enemy.x, enemy.y, vx, vy, 0.5, 7, 0.6, 0.4, 1.0, 1.0)  -- 增大：5->7
                            end
                            
                                -- 震屏效果
                                addScreenShake(0.15, 5)
                                playSound("hit")
                                
                                if enemy.health <= 0 then
                                    enemy.alive = false
                                    score = score + enemy.points
                                    -- 增强爆炸效果
                                    createExplosion(enemy.x, enemy.y, 40, 250, 8, 1.0, 0.5, 1.0)
                                    createExplosion(enemy.x, enemy.y, 30, 180, 6, 0.7, 1.0, 1.0)
                                    playSound("explosion")
                                    addScreenShake(0.3, 10)
                                    waveEnemiesLeft = waveEnemiesLeft - 1
                                end
                            end
                        end
                    end
                    
                    -- 同时检测Boss的小飞碟（和普通敌人一样的逻辑）
                    if enemy.type == ENEMY_BOSS and enemy.minions then
                        for _, minion in ipairs(enemy.minions) do
                            if minion.health > 0 then
                                -- 排除主目标（如果主目标是这个小飞碟）
                                local isMainTarget = (whip.targetType == "minion" and whip.targetEnemy and whip.targetEnemy.minion == minion)
                                
                                if not isMainTarget then
                                    local minionX = enemy.x + math.cos(minion.angle) * minion.distance
                                    local minionY = enemy.y + math.sin(minion.angle) * minion.distance
                                    local minionId = tostring(minion)
                                    
                                    -- 和普通敌人相同的检测范围
                                    if distance(x, y, minionX, minionY) < minion.radius + WHIP_WIDTH_BASE then
                                    -- 路径伤害计时器（每0.1秒可以命中一次）
                                    if not whip.hitEnemies[minionId] then
                                        whip.hitEnemies[minionId] = 0
                                    end
                                    
                                    if whip.hitEnemies[minionId] <= 0 then
                                        whip.hitEnemies[minionId] = 0.1  -- 重置计时器
                                        
                                        -- 路径伤害（和普通敌人一样，略低于吸附伤害）
                                        minion.health = minion.health - 1
                                        
                                        -- 闪电命中特效（和普通敌人一样）- 蓝紫色系 - 增强版
                                        -- 青蓝色闪电
                                        for j = 1, 8 do  -- 4 -> 8
                                            local angle = math.random() * math.pi * 2
                                            local speed = randomFloat(80, 220)
                                            local vx = math.cos(angle) * speed
                                            local vy = math.sin(angle) * speed
                                            createParticle(minionX, minionY, vx, vy, 0.4, 6, 0.3, 0.8, 1.0, 1.0)  -- 增大：4->6
                                        end
                                        
                                        -- 紫色能量
                                        for j = 1, 5 do  -- 3 -> 5
                                            local angle = math.random() * math.pi * 2
                                            local speed = randomFloat(60, 150)
                                            local vx = math.cos(angle) * speed
                                            local vy = math.sin(angle) * speed
                                            createParticle(minionX, minionY, vx, vy, 0.5, 7, 0.6, 0.4, 1.0, 1.0)  -- 增大：5->7
                                        end
                                        
                                        -- 震屏效果
                                        addScreenShake(0.15, 5)
                                        playSound("hit")
                                        
                                        if minion.health <= 0 then
                                            -- 和普通敌人一样的爆炸效果
                                            createExplosion(minionX, minionY, 40, 250, 8, 1.0, 0.5, 1.0)
                                            createExplosion(minionX, minionY, 30, 180, 6, 0.7, 1.0, 1.0)
                                            score = score + 50
                                            playSound("explosion")
                                            addScreenShake(0.3, 10)
                                        end
                                    end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- 检测路径伤害（Boss机械臂 - 特殊处理）
            for _, enemy in ipairs(enemies) do
                if enemy.alive and enemy.type == ENEMY_BOSS then
                    -- 检测机械臂（保持特殊处理逻辑）
                    if enemy.tentacles then
                        for _, tentacle in ipairs(enemy.tentacles) do
                            if not tentacle.destroyed and tentacle.health > 0 and tentacle.positions then
                                -- 排除主目标（如果主目标是这个触手）
                                local isMainTarget = (whip.targetType == "tentacle" and whip.targetEnemy and whip.targetEnemy.tentacle == tentacle)
                                
                                if not isMainTarget then
                                    local tentacleId = tostring(tentacle)
                                    for _, segment in ipairs(tentacle.positions) do
                                        -- 增大检测范围到1.5倍
                                        if distance(x, y, segment.x, segment.y) < (segment.radius + WHIP_WIDTH_BASE) * 1.5 then
                                        -- 路径伤害计时器（每0.1秒可以命中一次）
                                        if not whip.hitEnemies[tentacleId] then
                                            whip.hitEnemies[tentacleId] = 0
                                        end
                                        
                                        if whip.hitEnemies[tentacleId] <= 0 then
                                            whip.hitEnemies[tentacleId] = 0.1  -- 重置计时器
                                            tentacle.health = tentacle.health - 1  -- 路径伤害（略低于吸附伤害）
                                            
                                            -- 命中特效（蓝紫色）- 增强版
                                            for j = 1, 6 do  -- 3 -> 6
                                                local angle = math.random() * math.pi * 2
                                                local speed = randomFloat(60, 150)
                                                local vx = math.cos(angle) * speed
                                                local vy = math.sin(angle) * speed
                                                createParticle(segment.x, segment.y, vx, vy, 0.4, 5, 0.5, 0.6, 1.0, 1.0)  -- 增大：3->5
                                            end
                                            playSound("hit")
                                            
                                            if tentacle.health <= 0 then
                                                tentacle.destroyed = true
                                                createExplosion(segment.x, segment.y, 30, 160, 8, 0.8, 0.4, 0.9)
                                                score = score + 100
                                                playSound("explosion")
                                            end
                                        end
                                        break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            -- 检测并销毁敌方子弹
            for _, bullet in ipairs(bullets) do
                if bullet.alive and not bullet.fromPlayer then
                    if distance(x, y, bullet.x, bullet.y) < bullet.radius + WHIP_WIDTH_BASE then
                        bullet.alive = false
                        
                        -- 子弹被销毁的超华丽闪电特效
                        -- 外圈白色闪电爆发
                        for j = 1, 15 do
                            local angle = math.random() * math.pi * 2
                            local speed = randomFloat(80, 200)
                            local vx = math.cos(angle) * speed
                            local vy = math.sin(angle) * speed
                            createParticle(bullet.x, bullet.y, vx, vy, 0.4, 4, 0.9, 1.0, 1.0, 1.0)
                        end
                        
                        -- 内圈青色闪电
                        for j = 1, 10 do
                            local angle = math.random() * math.pi * 2
                            local speed = randomFloat(50, 150)
                            local vx = math.cos(angle) * speed
                            local vy = math.sin(angle) * speed
                            createParticle(bullet.x, bullet.y, vx, vy, 0.5, 5, 0.3, 0.9, 1.0, 1.0)
                        end
                        
                        -- 黄色能量闪光
                        for j = 1, 8 do
                            local angle = math.random() * math.pi * 2
                            local speed = randomFloat(60, 180)
                            local vx = math.cos(angle) * speed
                            local vy = math.sin(angle) * speed
                            createParticle(bullet.x, bullet.y, vx, vy, 0.3, 3, 1.0, 1.0, 0.6, 1.0)
                        end
                        
                        playSound("hit")
                    end
                end
            end
            
            -- 生成闪电溢出效果（边缘小火花）
            if whip.lightningTimer >= 0.03 then
                if i % 3 == 0 then
                    -- 小闪电粒子（从路径点向外溢出）
                    for j = 1, 3 do  -- 增加到3个
                        local angle = math.random() * math.pi * 2
                        local speed = randomFloat(80, 150)  -- 提高速度，快速向外扩散
                        local vx = math.cos(angle) * speed
                        local vy = math.sin(angle) * speed
                        createParticle(x, y, vx, vy, 0.3, 2.5, 0.9, 1.0, 1.0, 1.0)  -- 稍大一点，更明显
                    end
                end
            end
        end
        
        -- 重置闪电计时器
        if whip.lightningTimer >= 0.03 then
            whip.lightningTimer = 0
        end
    end
end

local function checkCollisions()
    -- 玩家子弹 vs 敌人
    for _, bullet in ipairs(bullets) do
        if bullet.alive and bullet.fromPlayer then
            for _, enemy in ipairs(enemies) do
                if enemy.alive and circleCollision(bullet.x, bullet.y, bullet.radius,
                                                    enemy.x, enemy.y, enemy.radius) then
                        -- Boss保护机制：只有机械臂全部被打掉才能攻击本体
                        if enemy.type == ENEMY_BOSS and enemy.tentacles then
                            local anyTentacleAlive = false
                            for _, tentacle in ipairs(enemy.tentacles) do
                                if not tentacle.destroyed and tentacle.health > 0 then
                                    anyTentacleAlive = true
                                    break
                                end
                            end
                            
                            if anyTentacleAlive then
                                -- 机械臂还在，无法伤害本体（护盾抵挡）
                                bullet.alive = false
                                
                                -- 计算碰撞点
                                local dx = enemy.x - bullet.x
                                local dy = enemy.y - bullet.y
                                local dist = math.sqrt(dx * dx + dy * dy)
                                local shieldHitX, shieldHitY
                                if dist > 0 then
                                    local ratio = (bullet.radius + 2) / dist
                                    shieldHitX = bullet.x + dx * ratio
                                    shieldHitY = bullet.y + dy * ratio
                                else
                                    shieldHitX = bullet.x
                                    shieldHitY = bullet.y
                                end
                                
                                -- 在碰撞点生成蓝色护盾爆炸特效
                                createExplosion(shieldHitX, shieldHitY, 12, 80, 4, 0.2, 0.6, 1.0)
                                -- 额外的蓝色护盾能量波
                                for j = 1, 10 do
                                    local angle = math.random() * math.pi * 2
                                    local speed = randomFloat(60, 140)
                                    local vx = math.cos(angle) * speed
                                    local vy = math.sin(angle) * speed
                                    createParticle(shieldHitX, shieldHitY, vx, vy, 0.4, 4, 0.3, 0.7, 1.0, 1.0)
                                end
                                playSound("hit")
                                -- 不执行下面的伤害逻辑
                                break
                            end
                        end
                    
                    bullet.alive = false
                    enemy.health = enemy.health - bullet.damage
                    
                    -- 计算碰撞点（子弹和敌人之间的接触点）
                    local dx = enemy.x - bullet.x
                    local dy = enemy.y - bullet.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    local hitX, hitY
                    if dist > 0 then
                        -- 碰撞点在子弹到敌人方向上，距离子弹 bullet.radius + 一点偏移
                        local ratio = (bullet.radius + 2) / dist
                        hitX = bullet.x + dx * ratio
                        hitY = bullet.y + dy * ratio
                    else
                        -- 完全重合（极少情况）
                        hitX = bullet.x
                        hitY = bullet.y
                    end
                    
                    if enemy.health <= 0 then
                        enemy.alive = false
                        score = score + enemy.points
                        
                        -- 爆炸效果（在碰撞点）
                        if enemy.type == ENEMY_BOSS then
                            createExplosion(hitX, hitY, 50, 200, 8, 1.0, 0.5, 0.0)
                            playSound("explosion")
                            addScreenShake(0.5, 20)
                        else
                            createExplosion(hitX, hitY, 20, 150, 5, 1.0, 0.3, 0.0)
                            playSound("hit")
                        end
                        
                        -- 掉落道具
                        local dropRand = math.random()
                        if dropRand < 0.1 then
                            -- 10%概率掉落镭射鞭
                            createPowerup(enemy.x, enemy.y, POWERUP_LASER_WHIP)
                        elseif dropRand < 0.3 then
                            -- 20%概率掉落其他道具
                            local powerupType = randomInt(0, 2)
                            createPowerup(enemy.x, enemy.y, powerupType)
                        end
                        
                        waveEnemiesLeft = waveEnemiesLeft - 1
                    else
                        -- 击中但未击杀：在碰撞点生成打击特效
                        -- 青白色小爆炸
                        for j = 1, 8 do
                            local angle = math.random() * math.pi * 2
                            local speed = randomFloat(50, 150)
                            local vx = math.cos(angle) * speed
                            local vy = math.sin(angle) * speed
                            createParticle(hitX, hitY, vx, vy, 0.3, 3, 0.5, 1.0, 1.0, 1.0)
                        end
                        -- 黄色火花
                        for j = 1, 5 do
                            local angle = math.random() * math.pi * 2
                            local speed = randomFloat(60, 180)
                            local vx = math.cos(angle) * speed
                            local vy = math.sin(angle) * speed
                            createParticle(hitX, hitY, vx, vy, 0.25, 2, 1.0, 1.0, 0.5, 1.0)
                        end
                        playSound("hit")
                    end
                    
                    break
                end
            end
        end
    end
    
    -- 玩家子弹 vs Boss机械臂
    for _, bullet in ipairs(bullets) do
        if bullet.alive and bullet.fromPlayer then
            local bulletDestroyed = false
            for _, enemy in ipairs(enemies) do
                if not bulletDestroyed and enemy.alive and enemy.type == ENEMY_BOSS and enemy.tentacles then
                        for _, tentacle in ipairs(enemy.tentacles) do
                            if not bulletDestroyed and not tentacle.destroyed and tentacle.health > 0 and tentacle.positions then
                                -- 检测机械臂每一节
                                for _, segment in ipairs(tentacle.positions) do
                                if circleCollision(bullet.x, bullet.y, bullet.radius,
                                                 segment.x, segment.y, segment.radius) then
                                    bullet.alive = false
                                    tentacle.health = tentacle.health - bullet.damage
                                    
                                    if tentacle.health <= 0 then
                                        -- 机械臂被摧毁（标记为已摧毁）
                                        tentacle.destroyed = true
                                        createExplosion(segment.x, segment.y, 30, 160, 8, 0.8, 0.4, 0.9)
                                        playSound("explosion")
                                        score = score + 100  -- 击毁机械臂得分
                                        addScreenShake(0.3, 10)
                                        
                                        -- 掉落道具
                                        if math.random() < 0.3 then
                                            createPowerup(segment.x, segment.y, POWERUP_LASER_WHIP)
                                        end
                                    else
                                        -- 击中但未摧毁
                                        createExplosion(segment.x, segment.y, 8, 70, 4, 0.8, 0.6, 1.0)
                                        playSound("hit")
                                    end
                                    
                                    bulletDestroyed = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 玩家子弹 vs Boss小飞碟护卫
    for _, bullet in ipairs(bullets) do
        if bullet.alive and bullet.fromPlayer then
            for _, enemy in ipairs(enemies) do
                if enemy.alive and enemy.type == ENEMY_BOSS and enemy.minions then
                    for _, minion in ipairs(enemy.minions) do
                        if minion.health > 0 then
                            local minionX = enemy.x + math.cos(minion.angle) * minion.distance
                            local minionY = enemy.y + math.sin(minion.angle) * minion.distance
                            
                            if circleCollision(bullet.x, bullet.y, bullet.radius,
                                             minionX, minionY, minion.radius) then
                                bullet.alive = false
                                minion.health = minion.health - bullet.damage
                                
                                if minion.health <= 0 then
                                    -- 小飞碟被摧毁
                                    createExplosion(minionX, minionY, 20, 120, 5, 0.5, 0.3, 0.8)
                                    playSound("explosion")
                                    score = score + 50  -- 击毁小飞碟得分
                                    
                                    -- 小概率掉落道具
                                    if math.random() < 0.15 then
                                        createPowerup(minionX, minionY, POWERUP_LASER_WHIP)
                                    end
                                else
                                    -- 击中但未摧毁
                                    createExplosion(minionX, minionY, 5, 60, 3, 0.5, 0.5, 1.0)
                                end
                                
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 敌人子弹 vs 玩家
    if player.alive and player.invincibleTimer <= 0 then
        for _, bullet in ipairs(bullets) do
            if bullet.alive and not bullet.fromPlayer then
                if circleCollision(bullet.x, bullet.y, bullet.radius,
                                  player.x, player.y, player.radius) then
                    bullet.alive = false
                    
                    if player.shieldHits > 0 then
                        player.shieldHits = player.shieldHits - 1
                        -- 护盾抵挡特效（根据剩余次数调整强度）
                        local intensity = player.shieldHits / 3
                        createExplosion(player.x, player.y, 15, 100, 4, 0.0, 0.5 + intensity * 0.5, 1.0)
                        playSound("hit")
                    else
                        player.health = player.health - 1
                        player.invincibleTimer = PLAYER_INVINCIBLE_TIME
                        createExplosion(player.x, player.y, 15, 100, 4, 1.0, 0.0, 0.0)
                        addScreenShake(0.3, 15)
                        
                        if player.health <= 0 then
                            player.alive = false
                            createExplosion(player.x, player.y, 40, 180, 6, 1.0, 0.3, 0.0)
                            playSound("explosion")
                            gameState = STATE_GAMEOVER
                        end
                    end
                    
                    break
                end
            end
        end
    end
    
    -- 玩家 vs 道具
    if player.alive then
        for _, powerup in ipairs(powerups) do
            -- 增大拾取范围（+30半径）
            if powerup.alive and circleCollision(powerup.x, powerup.y, powerup.radius + 30,
                                                 player.x, player.y, player.radius) then
                powerup.alive = false
                
                if powerup.type == POWERUP_WEAPON then
                    player.weaponLevel = math.min(player.weaponLevel + 1, 5)  -- 最大等级提升到5
                elseif powerup.type == POWERUP_HEALTH then
                    player.health = math.min(player.health + 1, player.maxHealth)
                elseif powerup.type == POWERUP_SHIELD then
                    player.shieldHits = 3  -- 护盾可抵挡3次伤害
                elseif powerup.type == POWERUP_LASER_WHIP then
                    player.hasLaserWhip = true
                    -- 增加充能，但不超过最大值
                    player.laserWhipCharges = math.min(player.laserWhipCharges + WHIP_CHARGES, WHIP_MAX_CHARGES)
                    -- 特殊的闪电拾取效果
                    createExplosion(powerup.x, powerup.y, 20, 120, 5, 0.8, 1.0, 1.0)
                    createExplosion(powerup.x, powerup.y, 15, 100, 4, 1.0, 0.4, 1.0)
                end
                
                createExplosion(powerup.x, powerup.y, 10, 80, 3, 1.0, 1.0, 0.0)
                playSound("powerup")
                score = score + 50
            end
        end
    end
    
    -- 玩家 vs 敌人（撞击）
    if player.alive and player.invincibleTimer <= 0 then
        for _, enemy in ipairs(enemies) do
            if enemy.alive and circleCollision(player.x, player.y, player.radius,
                                              enemy.x, enemy.y, enemy.radius) then
                enemy.alive = false
                
                if player.shieldHits > 0 then
                    player.shieldHits = player.shieldHits - 1
                    -- 护盾抵挡特效（根据剩余次数调整强度）
                    local intensity = player.shieldHits / 3
                    createExplosion(player.x, player.y, 20, 120, 5, 0.0, 0.5 + intensity * 0.5, 1.0)
                    playSound("hit")
                else
                    player.health = player.health - 1
                    player.invincibleTimer = PLAYER_INVINCIBLE_TIME
                    createExplosion(player.x, player.y, 20, 120, 5, 1.0, 0.0, 0.0)
                    addScreenShake(0.3, 15)
                    
                    if player.health <= 0 then
                        player.alive = false
                        createExplosion(player.x, player.y, 40, 180, 6, 1.0, 0.3, 0.0)
                        playSound("explosion")
                        gameState = STATE_GAMEOVER
                    end
                end
                
                break
            end
        end
    end
    
    -- 玩家 vs Boss小飞碟（碰撞）
    if player.alive and player.invincibleTimer <= 0 then
        for _, enemy in ipairs(enemies) do
            if enemy.alive and enemy.type == ENEMY_BOSS and enemy.tentacles then
                -- 检测小飞碟碰撞
                if enemy.minions then
                    for _, minion in ipairs(enemy.minions) do
                        if minion.health > 0 then
                            local minionAngle = minion.angle + GetTime():GetElapsedTime() * minion.orbitSpeed
                            local minionX = enemy.x + math.cos(minionAngle) * minion.distance
                            local minionY = enemy.y + math.sin(minionAngle) * minion.distance
                            
                            if circleCollision(player.x, player.y, player.radius,
                                             minionX, minionY, minion.radius) then
                                -- 小飞碟被击中
                                minion.health = 0
                                createExplosion(minionX, minionY, 15, 100, 4, 0.5, 0.3, 0.8)
                                
                                if player.shieldHits > 0 then
                                    player.shieldHits = player.shieldHits - 1
                                    local intensity = player.shieldHits / 3
                                    createExplosion(player.x, player.y, 15, 100, 4, 0.0, 0.5 + intensity * 0.5, 1.0)
                                    playSound("hit")
                                else
                                    player.health = player.health - 1
                                    player.invincibleTimer = PLAYER_INVINCIBLE_TIME
                                    createExplosion(player.x, player.y, 15, 100, 4, 1.0, 0.0, 0.0)
                                    addScreenShake(0.3, 15)
                                    playSound("hit")
                                    
                                    if player.health <= 0 then
                                        player.alive = false
                                        createExplosion(player.x, player.y, 40, 180, 6, 1.0, 0.3, 0.0)
                                        playSound("explosion")
                                        gameState = STATE_GAMEOVER
                                    end
                                end
                                
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 关卡系统
-- ============================================================================

local function startWave()
    waveTimer = 0
    spawnTimer = 0
    
    -- 配置波次
    waveConfig.enemyCount = 5 + currentWave * 2
    waveConfig.spawnInterval = math.max(0.3, 1.0 - currentWave * 0.05)
    waveConfig.difficulty = 1.0 + currentWave * 0.2
    
    waveEnemiesLeft = waveConfig.enemyCount
end

local function updateWaveSystem(dt)
    if waveEnemiesLeft <= 0 and #enemies == 0 then
        currentWave = currentWave + 1
        startWave()
        
        -- 波次奖励
        score = score + currentWave * 100
    end
    
    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 and waveEnemiesLeft > 0 then
        spawnTimer = waveConfig.spawnInterval
        
        -- 根据波次决定敌人类型
        local rand = math.random()
        local enemyType = ENEMY_SMALL
        
        -- Boss波次（每10波出现一次，替换整波敌人）
        if currentWave % BOSS_WAVE_INTERVAL == 0 then
            enemyType = ENEMY_BOSS
            waveEnemiesLeft = 0  -- Boss出现后清空波次，只生成一个Boss
        else
            -- 普通波次
            if currentWave >= 3 then
                if rand < 0.6 then
                    enemyType = ENEMY_SMALL
                elseif rand < 0.85 then
                    enemyType = ENEMY_MEDIUM
                else
                    enemyType = ENEMY_LARGE
                end
            elseif currentWave >= 2 then
                if rand < 0.7 then
                    enemyType = ENEMY_SMALL
                else
                    enemyType = ENEMY_MEDIUM
                end
            end
        end
        
        createEnemy(enemyType)
    end
end

-- ============================================================================
-- 音效系统
-- ============================================================================

function playSound(soundType)
    if not scene_ then
        return
    end
    
    local soundResource = nil
    if soundType == "shoot" then
        soundResource = "Sounds/PlayerFistHit.wav"
    elseif soundType == "explosion" then
        soundResource = "Sounds/BigExplosion.wav"
    elseif soundType == "hit" then
        soundResource = "Sounds/SmallExplosion.wav"
    elseif soundType == "powerup" then
        soundResource = "Sounds/Powerup.wav"
    end
    
    if soundResource then
        local sound = cache:GetResource("Sound", soundResource)
        if sound then
            local soundSource = scene_:CreateComponent("SoundSource")
            soundSource:SetAutoRemoveMode(REMOVE_COMPONENT)
            soundSource:Play(sound)
            soundSource.gain = 0.5
        end
    end
end

-- ============================================================================
-- 屏幕效果
-- ============================================================================

function addScreenShake(time, intensity)
    screenShake.time = time
    screenShake.intensity = intensity
end

function updateScreenShake(dt)
    if screenShake.time > 0 then
        screenShake.time = screenShake.time - dt
    end
end

function getScreenShakeOffset()
    if screenShake.time > 0 then
        local intensity = screenShake.intensity * (screenShake.time / 0.5)
        return randomFloat(-intensity, intensity), randomFloat(-intensity, intensity)
    end
    return 0, 0
end

-- ============================================================================
-- NanoVG 渲染函数
-- ============================================================================

local function drawBackground(ctx, w, h)
    -- 渐变背景
    local bg = nvgLinearGradient(ctx, w / 2, 0, w / 2, h,
                                  nvgRGBA(10, 10, 40, 255),
                                  nvgRGBA(0, 0, 0, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)
    
    -- 星空
    for _, star in ipairs(stars) do
        nvgBeginPath(ctx)
        nvgCircle(ctx, star.x, star.y, star.size)
        local brightness = star.brightness
        nvgFillColor(ctx, nvgRGBA(255 * brightness, 255 * brightness, 255 * brightness, 200))
        nvgFill(ctx)
    end
end

local function drawPlayer(ctx)
    if not player.alive then
        return
    end
    
    -- 无敌闪烁
    if player.invincibleTimer > 0 and math.floor(player.invincibleTimer * 10) % 2 == 0 then
        return
    end
    
    local time = GetTime():GetElapsedTime()
    local pulse = math.sin(time * 8) * 0.2 + 0.8
    local glow = math.sin(time * 3) * 0.3 + 1.0
    local scale = 1.5  -- 整体放大1.5倍
    
    nvgSave(ctx)
    nvgTranslate(ctx, player.x, player.y)
    nvgScale(ctx, scale, scale)
    
    -- 外层能量场（超大光晕）
    local outerHalo = nvgRadialGradient(ctx, 0, 0, 0, player.radius * 3.5,
        nvgRGBA(0, 255, 255, 60 * glow),
        nvgRGBA(100, 200, 255, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, player.radius * 3.5)
    nvgFillPaint(ctx, outerHalo)
    nvgFill(ctx)
    
    -- 中层能量场
    local midHalo = nvgRadialGradient(ctx, 0, 0, 0, player.radius * 2.2,
        nvgRGBA(50, 220, 255, 100 * glow),
        nvgRGBA(0, 200, 255, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, player.radius * 2.2)
    nvgFillPaint(ctx, midHalo)
    nvgFill(ctx)
    
    -- 护盾效果（根据剩余次数显示）
    if player.shieldHits > 0 then
        local shieldPulse = math.sin(time * 5) * 0.3 + 0.7
        local intensity = player.shieldHits / 3  -- 0.33, 0.67, 1.0
        
        -- 外圈（根据强度调整颜色）
        nvgBeginPath(ctx)
        nvgCircle(ctx, 0, 0, player.radius + 12)
        local shieldGradient = nvgRadialGradient(ctx, 0, 0, player.radius + 8, player.radius + 12,
            nvgRGBA(0, 255 * intensity, 255, 150 * shieldPulse * intensity),
            nvgRGBA(0, 255 * intensity, 255, 0))
        nvgStrokePaint(ctx, shieldGradient)
        nvgStrokeWidth(ctx, 3 + player.shieldHits)  -- 4, 5, 6 根据次数
        nvgStroke(ctx)
        
        -- 内圈
        nvgBeginPath(ctx)
        nvgCircle(ctx, 0, 0, player.radius + 8)
        nvgStrokeColor(ctx, nvgRGBA(100, 255 * intensity, 255, 200 * shieldPulse * intensity))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
        
        -- 护盾次数指示（三个小圆点）
        for i = 1, 3 do
            local angle = math.pi / 2 + (i - 2) * 0.5  -- 顶部三个点
            local dotX = math.cos(angle) * (player.radius + 10)
            local dotY = math.sin(angle) * (player.radius + 10)
            
            nvgBeginPath(ctx)
            nvgCircle(ctx, dotX, dotY, 2)
            if i <= player.shieldHits then
                -- 剩余的显示为亮色
                nvgFillColor(ctx, nvgRGBA(100, 255, 255, 255 * shieldPulse))
            else
                -- 已消耗的显示为暗色
                nvgFillColor(ctx, nvgRGBA(50, 100, 100, 100))
            end
            nvgFill(ctx)
        end
    end
    
    -- ====== 红蓝战机新设计 ======
    
    -- 1. 主机身（红色为主）
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, -22)  -- 尖锐机头
    nvgLineTo(ctx, -4, -18)
    nvgLineTo(ctx, -5, -10)
    nvgLineTo(ctx, -6, 8)   -- 连接到尾部
    nvgLineTo(ctx, -5, 12)
    nvgLineTo(ctx, 5, 12)
    nvgLineTo(ctx, 6, 8)
    nvgLineTo(ctx, 5, -10)
    nvgLineTo(ctx, 4, -18)
    nvgClosePath(ctx)
    local bodyGrad = nvgLinearGradient(ctx, 0, -22, 0, 12,
        nvgRGBA(255, 80, 100, 255),   -- 红色
        nvgRGBA(200, 40, 60, 255))
    nvgFillPaint(ctx, bodyGrad)
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 150, 150, 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    
    -- 2. 侧边蓝色装甲条纹
    for i = -1, 1, 2 do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, i * 3, -16)
        nvgLineTo(ctx, i * 4, -10)
        nvgLineTo(ctx, i * 5, 0)
        nvgLineTo(ctx, i * 5.5, 8)
        nvgLineTo(ctx, i * 4.5, 10)
        nvgLineTo(ctx, i * 4, 8)
        nvgLineTo(ctx, i * 3.5, 0)
        nvgLineTo(ctx, i * 2.5, -10)
        nvgClosePath(ctx)
        local stripeGrad = nvgLinearGradient(ctx, i * 3, -16, i * 5, 8,
            nvgRGBA(100, 180, 255, 255),
            nvgRGBA(50, 120, 200, 255))
        nvgFillPaint(ctx, stripeGrad)
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(150, 220, 255, 255))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
    
    -- 3. 驾驶舱（可见玻璃罩）
    nvgBeginPath(ctx)
    nvgEllipse(ctx, 0, -10, 4, 6)
    local cockpitGrad = nvgRadialGradient(ctx, 0, -12, 0, 7,
        nvgRGBA(150, 220, 255, 230),
        nvgRGBA(80, 150, 220, 180))
    nvgFillPaint(ctx, cockpitGrad)
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(200, 240, 255, 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    
    -- 驾驶舱高光
    nvgBeginPath(ctx)
    nvgEllipse(ctx, -1, -13, 2, 3)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
    nvgFill(ctx)
    
    -- 驾驶舱内部阴影（模拟深度）
    nvgBeginPath(ctx)
    nvgEllipse(ctx, 0, -8, 3, 4)
    nvgFillColor(ctx, nvgRGBA(40, 60, 80, 150))
    nvgFill(ctx)
    
    -- 4. 独立引擎火箭（两侧捆绑，底部略突出，略微缩小）
    for i = -1, 1, 2 do
        -- 引擎主体（长圆柱形火箭）
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, i * 11 - 2.2, -8, 4.4, 22, 1.8)
        local rocketGrad = nvgLinearGradient(ctx, i * 11, -8, i * 11, 14,
            nvgRGBA(90, 100, 130, 255),
            nvgRGBA(60, 70, 100, 255))
        nvgFillPaint(ctx, rocketGrad)
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(130, 150, 180, 255))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        
        -- 火箭顶部圆锥
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, i * 11 - 2.2, -8)
        nvgLineTo(ctx, i * 11, -10.5)
        nvgLineTo(ctx, i * 11 + 2.2, -8)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(70, 80, 110, 255))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(110, 130, 160, 255))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
        
        -- 火箭分段线
        for j = 0, 3 do
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, i * 11 - 2.2, -8 + j * 5.5)
            nvgLineTo(ctx, i * 11 + 2.2, -8 + j * 5.5)
            nvgStrokeColor(ctx, nvgRGBA(50, 60, 80, 200))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)
        end
        
        -- 火箭侧面散热片
        for j = 0, 2 do
            nvgBeginPath(ctx)
            nvgRect(ctx, i * 11 - 1.8, -4 + j * 5.5, 3.6, 1.3)
            nvgFillColor(ctx, nvgRGBA(40, 50, 70, 255))
            nvgFill(ctx)
        end
        
        -- 引擎喷口（圆形大开口，略突出机身）
        nvgBeginPath(ctx)
        nvgCircle(ctx, i * 11, 14, 3.5)
        nvgFillColor(ctx, nvgRGBA(30, 40, 60, 255))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(80, 100, 130, 255))
        nvgStrokeWidth(ctx, 1.8)
        nvgStroke(ctx)
        
        -- 喷口内环结构
        for j = 1, 3 do
            nvgBeginPath(ctx)
            nvgCircle(ctx, i * 11, 14, 0.8 + j * 0.7)
            nvgStrokeColor(ctx, nvgRGBA(70, 90, 120, 150))
            nvgStrokeWidth(ctx, 0.5)
            nvgStroke(ctx)
        end
        
        -- 引擎内部渐变
        nvgBeginPath(ctx)
        nvgCircle(ctx, i * 11, 14, 3)
        local engineInner = nvgRadialGradient(ctx, i * 11, 14, 0.5, 3,
            nvgRGBA(80, 120, 160, 255),
            nvgRGBA(40, 60, 90, 255))
        nvgFillPaint(ctx, engineInner)
        nvgFill(ctx)
        
        -- 引擎核心发光（脉动青光）
        nvgBeginPath(ctx)
        nvgCircle(ctx, i * 11, 14, 2.2)
        local engineGlow = nvgRadialGradient(ctx, i * 11, 14, 0, 5.5,
            nvgRGBA(100, 255, 255, 255 * pulse),
            nvgRGBA(50, 200, 255, 0))
        nvgFillPaint(ctx, engineGlow)
        nvgFill(ctx)
        
        -- 引擎强光核心
        nvgBeginPath(ctx)
        nvgCircle(ctx, i * 11, 14, 1)
        nvgFillColor(ctx, nvgRGBA(200, 255, 255, 255 * pulse))
        nvgFill(ctx)
    end
    
    -- 5. 机翼（连接在引擎上，直角三角形，稍微分开，略微缩短）
    for i = -1, 1, 2 do
        -- 主机翼（直角三角形，底边水平，稍短）
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, i * 13.5, 4)      -- 顶部连接点（稍微远离引擎）
        nvgLineTo(ctx, i * 13.5, 12)     -- 底部连接点（垂直边，90度角）
        nvgLineTo(ctx, i * 26, 12)       -- 底边（水平，缩短）
        nvgLineTo(ctx, i * 26, 10)       -- 翼尖（尖）
        nvgClosePath(ctx)
        local wingGrad = nvgLinearGradient(ctx, i * 13.5, 8, i * 26, 11,
            nvgRGBA(220, 60, 80, 255),
            nvgRGBA(180, 30, 50, 255))
        nvgFillPaint(ctx, wingGrad)
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(255, 120, 140, 255))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
        
        -- 机翼中部蓝色装甲条
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, i * 16, 6)
        nvgLineTo(ctx, i * 16, 11)
        nvgLineTo(ctx, i * 22, 11)
        nvgLineTo(ctx, i * 22, 10.5)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(100, 180, 255, 255))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(150, 220, 255, 255))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
        
        -- 翼尖蓝色边缘
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, i * 23.5, 10)
        nvgLineTo(ctx, i * 26, 10)
        nvgLineTo(ctx, i * 26, 12)
        nvgLineTo(ctx, i * 23.5, 12)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(120, 200, 255, 255))
        nvgFill(ctx)
        
        -- 机翼纹理线（沿翼展方向）
        for j = 0, 4 do
            local yPos = 6 + j * 1.2
            if yPos <= 12 then
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, i * 14, yPos)
                nvgLineTo(ctx, i * (14 + (26 - 14) * (yPos - 4) / (12 - 4)), yPos)
                nvgStrokeColor(ctx, nvgRGBA(200, 40, 60, 120))
                nvgStrokeWidth(ctx, 0.8)
                nvgStroke(ctx)
            end
        end
    end
    
    -- 6. 机头武器系统（蓝色）
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, -3, -18)
    nvgLineTo(ctx, -2, -22)
    nvgLineTo(ctx, 0, -23)
    nvgLineTo(ctx, 2, -22)
    nvgLineTo(ctx, 3, -18)
    nvgLineTo(ctx, 0, -19)
    nvgClosePath(ctx)
    local noseGrad = nvgLinearGradient(ctx, 0, -23, 0, -18,
        nvgRGBA(120, 200, 255, 255),
        nvgRGBA(80, 150, 220, 255))
    nvgFillPaint(ctx, noseGrad)
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(180, 230, 255, 255))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    
    -- 7. 前置炮口（发射点）
    for i = -1, 1, 2 do
        nvgBeginPath(ctx)
        nvgCircle(ctx, i * 2.5, -20, 1.5)
        nvgFillColor(ctx, nvgRGBA(40, 80, 120, 255))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(100, 200, 255, 220 * pulse))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
    end
    
    -- 中央主炮
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, -21.5, 1.8)
    nvgFillColor(ctx, nvgRGBA(50, 100, 150, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(150, 220, 255, 240 * pulse))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    
    -- 8. 中央红色装甲板细节
    for yi = 0, 3 do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, -3.5, -14 + yi * 5)
        nvgLineTo(ctx, 3.5, -14 + yi * 5)
        nvgStrokeColor(ctx, nvgRGBA(180, 40, 60, 120))
        nvgStrokeWidth(ctx, 0.8)
        nvgStroke(ctx)
    end
    
    -- 9. 能量导管（红蓝交替发光）
    for i = -1, 1, 2 do
        -- 红色能量线
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, i * 4.5, -8)
        nvgLineTo(ctx, i * 5, 6)
        nvgStrokeColor(ctx, nvgRGBA(255, 100, 120, 180 * pulse))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        
        -- 蓝色能量线
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, i * 2.5, -6)
        nvgLineTo(ctx, i * 3, 8)
        nvgStrokeColor(ctx, nvgRGBA(100, 200, 255, 180 * pulse))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
    end
    
    -- 10. 武器等级指示灯
    if player.weaponLevel >= 2 then
        for i = -1, 1, 2 do
            nvgBeginPath(ctx)
            nvgCircle(ctx, i * 6, 4, 1.8)
            nvgFillColor(ctx, nvgRGBA(255, 200, 0, 255 * pulse))
            nvgFill(ctx)
            local indicatorGlow = nvgRadialGradient(ctx, i * 6, 4, 0, 4,
                nvgRGBA(255, 200, 0, 220 * pulse),
                nvgRGBA(255, 200, 0, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, i * 6, 4, 4)
            nvgFillPaint(ctx, indicatorGlow)
            nvgFill(ctx)
        end
    end
    
    if player.weaponLevel >= 3 then
        nvgBeginPath(ctx)
        nvgCircle(ctx, 0, 6, 1.8)
        nvgFillColor(ctx, nvgRGBA(255, 100, 0, 255 * pulse))
        nvgFill(ctx)
        local indicatorGlow = nvgRadialGradient(ctx, 0, 6, 0, 4,
            nvgRGBA(255, 150, 0, 220 * pulse),
            nvgRGBA(255, 100, 0, 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, 0, 6, 4)
        nvgFillPaint(ctx, indicatorGlow)
        nvgFill(ctx)
    end
    
    -- 11. 机头传感器
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, -20, 1)
    nvgFillColor(ctx, nvgRGBA(255, 100, 100, 220 * pulse))
    nvgFill(ctx)
    local sensorGlow = nvgRadialGradient(ctx, 0, -20, 0, 2,
        nvgRGBA(255, 100, 100, 200 * pulse),
        nvgRGBA(255, 100, 100, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, -20, 2)
    nvgFillPaint(ctx, sensorGlow)
    nvgFill(ctx)
    
    nvgRestore(ctx)
end

local function drawEnemies(ctx)
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            nvgSave(ctx)
            nvgTranslate(ctx, enemy.x, enemy.y)
            
            -- 颜色根据生命值变化
            local healthRatio = enemy.health / enemy.maxHealth
            local r = 255
            local g = 100 * healthRatio
            local b = 0
            
            -- 光晕
            local haloSize = enemy.radius * 1.5
            local halo = nvgRadialGradient(ctx, 0, 0, enemy.radius * 0.5, haloSize,
                                          nvgRGBA(r, g, b, 100),
                                          nvgRGBA(r, g, b, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, 0, 0, haloSize)
            nvgFillPaint(ctx, halo)
            nvgFill(ctx)
            
            -- 根据类型绘制不同形状
            nvgBeginPath(ctx)
            
            if enemy.type == ENEMY_SMALL then
                -- 菱形
                nvgMoveTo(ctx, 0, -enemy.radius)
                nvgLineTo(ctx, enemy.radius * 0.6, 0)
                nvgLineTo(ctx, 0, enemy.radius)
                nvgLineTo(ctx, -enemy.radius * 0.6, 0)
                nvgClosePath(ctx)
            elseif enemy.type == ENEMY_MEDIUM then
                -- 六边形
                for i = 0, 5 do
                    local angle = (i / 6) * math.pi * 2
                    local x = math.cos(angle) * enemy.radius
                    local y = math.sin(angle) * enemy.radius
                    if i == 0 then
                        nvgMoveTo(ctx, x, y)
                    else
                        nvgLineTo(ctx, x, y)
                    end
                end
                nvgClosePath(ctx)
            elseif enemy.type == ENEMY_LARGE then
                -- 八边形
                for i = 0, 7 do
                    local angle = (i / 8) * math.pi * 2
                    local x = math.cos(angle) * enemy.radius
                    local y = math.sin(angle) * enemy.radius
                    if i == 0 then
                        nvgMoveTo(ctx, x, y)
                    else
                        nvgLineTo(ctx, x, y)
                    end
                end
                nvgClosePath(ctx)
            elseif enemy.type == ENEMY_BOSS then
                -- 机械章鱼Boss渲染
                local time = GetTime():GetElapsedTime()
                local pulse = math.sin(time * 3) * 0.2 + 0.8
                
                -- 机械章鱼配色：黑灰紫相间
                local colorBlack = {30, 30, 40}        -- 深黑
                local colorDarkGray = {60, 60, 80}     -- 深灰
                local colorGray = {100, 100, 120}      -- 灰色
                local colorPurple = {120, 60, 180}     -- 紫色
                local colorLightPurple = {160, 100, 220}  -- 亮紫
                local colorGlow = {140, 80, 200}       -- 紫色光晕
                
                -- 阶段变化：越愤怒紫色越亮
                local phaseIntensity = enemy.phase == 1 and 0.7 or enemy.phase == 2 and 1.0 or 1.3
                
                -- 飞碟尺寸定义（用于机械臂和主体）
                local ufoRadius = enemy.radius
                local domeHeight = ufoRadius * 0.35  -- 上半球高度
                local baseHeight = ufoRadius * 0.25  -- 下半球高度
                
                -- 外层能量场（紫色能量）
                for layer = 3, 1, -1 do
                    local layerRadius = enemy.radius * (1.0 + layer * 0.2)
                    local layerAlpha = (30 / layer) * pulse * phaseIntensity
                    local halo = nvgRadialGradient(ctx, 0, 0, enemy.radius, layerRadius,
                                                  nvgRGBA(colorGlow[1], colorGlow[2], colorGlow[3], layerAlpha),
                                                  nvgRGBA(colorPurple[1], colorPurple[2], colorPurple[3], 0))
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, 0, 0, layerRadius)
                    nvgFillPaint(ctx, halo)
                    nvgFill(ctx)
                end
                
                -- 绘制机械臂（6条，从飞碟底部延伸，带旋风螺旋）
                for idx, tentacle in ipairs(enemy.tentacles) do
                    -- 清空之前的位置数据
                    tentacle.positions = {}
                    
                    -- 只渲染未被摧毁的机械臂
                    if not tentacle.destroyed and tentacle.health > 0 then
                        -- 机械臂摆动（限制在角度范围内）
                        local wavePhase = tentacle.wavePhase + time * tentacle.swingSpeed
                        local swingOffset = math.sin(wavePhase) * tentacle.angleRange  -- 在±angleRange范围内摆动
                        local tentacleAngle = tentacle.angle + swingOffset
                    
                    -- 机械臂基部（从飞碟底部圆周边缘开始）
                    -- 底座底部在 y = baseHeight * 1.5
                    local armMountRadius = ufoRadius * 0.85  -- 机械臂安装半径
                    local armMountY = baseHeight * 1.5       -- 机械臂安装高度（飞碟底部）
                    
                    -- 计算圆周上的点
                    local baseX = math.cos(tentacle.angle) * armMountRadius
                    local baseY = armMountY
                    
                    -- 绘制机械臂基部接头（固定连接器）
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, baseX, baseY, tentacle.baseWidth * 0.8)
                    local baseJointGrad = nvgRadialGradient(ctx, baseX - 3, baseY - 3, 3, tentacle.baseWidth * 0.8,
                                                           nvgRGBA(colorGray[1] * 1.4, colorGray[2] * 1.4, colorGray[3] * 1.4, 255),
                                                           nvgRGBA(colorDarkGray[1], colorDarkGray[2], colorDarkGray[3], 255))
                    nvgFillPaint(ctx, baseJointGrad)
                    nvgFill(ctx)
                    nvgStrokeColor(ctx, nvgRGBA(colorPurple[1]*phaseIntensity, colorPurple[2]*phaseIntensity, colorPurple[3]*phaseIntensity, 255))
                    nvgStrokeWidth(ctx, 3)
                    nvgStroke(ctx)
                    
                    -- 基部能量指示灯
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, baseX, baseY, tentacle.baseWidth * 0.3 * pulse)
                    nvgFillColor(ctx, nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 220))
                    nvgFill(ctx)
                    
                    -- 绘制机械臂节段
                    local prevX, prevY = baseX, baseY
                    
                    for seg = 1, tentacle.segments do
                        local segProgress = seg / tentacle.segments
                        local baseAngle = tentacleAngle
                        local waveOffset = math.sin(wavePhase + segProgress * 4) * 0.5 * phaseIntensity
                        local currentAngle = baseAngle + waveOffset
                        
                        local segLength = tentacle.length / tentacle.segments
                        local x = prevX + math.cos(currentAngle) * segLength
                        local y = prevY + math.sin(currentAngle) * segLength
                        
                        -- 机械臂宽度递减
                        local segWidth = tentacle.baseWidth * (1.0 - segProgress * 0.65)
                        
                        -- 机械臂本体（金属质感，深灰色）
                        nvgBeginPath(ctx)
                        nvgMoveTo(ctx, prevX, prevY)
                        nvgLineTo(ctx, x, y)
                        local armGrad = nvgLinearGradient(ctx, prevX, prevY, x, y,
                                                         nvgRGBA(colorGray[1], colorGray[2], colorGray[3], 255),
                                                         nvgRGBA(colorDarkGray[1], colorDarkGray[2], colorDarkGray[3], 255))
                        nvgStrokePaint(ctx, armGrad)
                        nvgStrokeWidth(ctx, segWidth)
                        nvgStroke(ctx)
                        
                        -- 简化关节：只绘制实心圆（移除渐变和描边）
                        nvgBeginPath(ctx)
                        nvgCircle(ctx, x, y, segWidth * 0.6)
                        nvgFillColor(ctx, nvgRGBA(colorGray[1], colorGray[2], colorGray[3], 255))
                        nvgFill(ctx)
                        
                        prevX, prevY = x, y
                    end
                    
                    -- 机械臂末端（三爪钳/风扇，稍微缩小）
                    -- 只在钳子中心保存一个大范围碰撞区域（性能优化）
                    table.insert(tentacle.positions, {
                        x = enemy.x + prevX,
                        y = enemy.y + prevY,
                        radius = 70  -- 大碰撞半径，覆盖整个钳子区域
                    })
                    
                    local clawSize = 35  -- 稍微缩小到35
                    local clawCount = 3
                    for i = 0, clawCount - 1 do
                        local clawAngle = tentacleAngle + (i / clawCount) * math.pi * 2 + time * 2
                        local clawX = prevX + math.cos(clawAngle) * clawSize
                        local clawY = prevY + math.sin(clawAngle) * clawSize
                        
                        -- 爪子主体
                        nvgBeginPath(ctx)
                        nvgMoveTo(ctx, prevX, prevY)
                        nvgLineTo(ctx, clawX, clawY)
                        nvgStrokeColor(ctx, nvgRGBA(colorGray[1], colorGray[2], colorGray[3], 255))
                        nvgStrokeWidth(ctx, 8)
                        nvgStroke(ctx)
                        
                        -- 爪子末端椭圆发光体（代替原来的小光球）
                        nvgSave(ctx)
                        nvgTranslate(ctx, clawX, clawY)
                        nvgRotate(ctx, clawAngle)
                        
                        -- 外层椭圆光晕
                        nvgBeginPath(ctx)
                        nvgEllipse(ctx, 0, 0, 20 * pulse, 12 * pulse)
                        nvgFillColor(ctx, nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 100 * pulse))
                        nvgFill(ctx)
                        
                        -- 内层椭圆核心
                        nvgBeginPath(ctx)
                        nvgEllipse(ctx, 0, 0, 12 * pulse, 7 * pulse)
                        nvgFillColor(ctx, nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 220))
                        nvgFill(ctx)
                        
                        nvgRestore(ctx)
                    end
                    
                    -- 机械臂血量条（在末端上方）
                    if tentacle.health > 0 then
                        local healthPercent = tentacle.health / tentacle.maxHealth
                        local barWidth = 40
                        local barHeight = 4
                        local barX = prevX - barWidth / 2
                        local barY = prevY - 25
                        
                        -- 血量条背景
                        nvgBeginPath(ctx)
                        nvgRect(ctx, barX, barY, barWidth, barHeight)
                        nvgFillColor(ctx, nvgRGBA(40, 40, 40, 200))
                        nvgFill(ctx)
                        
                        -- 血量条前景
                        if healthPercent > 0 then
                            nvgBeginPath(ctx)
                            nvgRect(ctx, barX, barY, barWidth * healthPercent, barHeight)
                            local healthR = (1.0 - healthPercent) * 255
                            local healthG = healthPercent * 255
                            nvgFillColor(ctx, nvgRGBA(healthR, healthG, 80, 220))
                            nvgFill(ctx)
                        end
                        
                        -- 血量条边框
                        nvgBeginPath(ctx)
                        nvgRect(ctx, barX, barY, barWidth, barHeight)
                        nvgStrokeColor(ctx, nvgRGBA(colorPurple[1]*phaseIntensity, colorPurple[2]*phaseIntensity, colorPurple[3]*phaseIntensity, 180))
                        nvgStrokeWidth(ctx, 1)
                        nvgStroke(ctx)
                    end
                    end  -- 结束未被摧毁的机械臂渲染
                end
                
                -- 飞碟UFO主体
                -- 飞碟下部（底座，椭圆形）
                nvgBeginPath(ctx)
                nvgEllipse(ctx, 0, baseHeight * 0.5, ufoRadius * 0.95, baseHeight)
                local baseGrad = nvgRadialGradient(ctx, 0, baseHeight * 0.5, 0, ufoRadius,
                                                  nvgRGBA(colorDarkGray[1], colorDarkGray[2], colorDarkGray[3], 255),
                                                  nvgRGBA(colorBlack[1], colorBlack[2], colorBlack[3], 255))
                nvgFillPaint(ctx, baseGrad)
                nvgFill(ctx)
                nvgStrokeColor(ctx, nvgRGBA(colorBlack[1], colorBlack[2], colorBlack[3], 255))
                nvgStrokeWidth(ctx, 3)
                nvgStroke(ctx)
                
                -- 飞碟中环（主体圆盘）
                nvgBeginPath(ctx)
                nvgEllipse(ctx, 0, 0, ufoRadius, ufoRadius * 0.3)
                local diskGrad = nvgLinearGradient(ctx, 0, -ufoRadius * 0.3, 0, ufoRadius * 0.3,
                                                  nvgRGBA(colorGray[1] * 1.2, colorGray[2] * 1.2, colorGray[3] * 1.2, 255),
                                                  nvgRGBA(colorGray[1], colorGray[2], colorGray[3], 255))
                nvgFillPaint(ctx, diskGrad)
                nvgFill(ctx)
                nvgStrokeColor(ctx, nvgRGBA(colorBlack[1], colorBlack[2], colorBlack[3], 255))
                nvgStrokeWidth(ctx, 4)
                nvgStroke(ctx)
                
                -- 飞碟上部（驾驶舱穹顶）
                nvgBeginPath(ctx)
                nvgEllipse(ctx, 0, -domeHeight * 0.5, ufoRadius * 0.5, domeHeight)
                local domeGrad = nvgRadialGradient(ctx, 0, -domeHeight * 0.8, ufoRadius * 0.2, ufoRadius * 0.6,
                                                  nvgRGBA(colorGray[1] * 1.3, colorGray[2] * 1.3, colorGray[3] * 1.3, 255),
                                                  nvgRGBA(colorGray[1] * 0.9, colorGray[2] * 0.9, colorGray[3] * 0.9, 255))
                nvgFillPaint(ctx, domeGrad)
                nvgFill(ctx)
                nvgStrokeColor(ctx, nvgRGBA(colorPurple[1]*phaseIntensity, colorPurple[2]*phaseIntensity, colorPurple[3]*phaseIntensity, 255))
                nvgStrokeWidth(ctx, 3)
                nvgStroke(ctx)
                
                -- 飞碟圆盘外环灯光（一圈紫色能量点）
                local lightsCount = 12
                for i = 0, lightsCount - 1 do
                    local angle = (i / lightsCount) * math.pi * 2 + time * 0.5
                    local x = math.cos(angle) * ufoRadius * 0.9
                    local y = math.sin(angle) * ufoRadius * 0.9 * 0.3  -- 椭圆形
                    
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, x, y, 5 * pulse)
                    local lightGlow = nvgRadialGradient(ctx, x, y, 0, 7,
                                                       nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 255),
                                                       nvgRGBA(colorGlow[1]*phaseIntensity, colorGlow[2]*phaseIntensity, colorGlow[3]*phaseIntensity, 0))
                    nvgFillPaint(ctx, lightGlow)
                    nvgFill(ctx)
                end
                
                -- 内环装饰圈
                for ring = 1, 3 do
                    nvgBeginPath(ctx)
                    nvgEllipse(ctx, 0, 0, ufoRadius * (0.75 - ring * 0.15), ufoRadius * (0.75 - ring * 0.15) * 0.3)
                    nvgStrokeColor(ctx, nvgRGBA(colorBlack[1], colorBlack[2], colorBlack[3], 150))
                    nvgStrokeWidth(ctx, 2)
                    nvgStroke(ctx)
                end
                
                -- 六芒星装饰（在穹顶顶部）
                local starRadius = ufoRadius * 0.25
                for i = 0, 5 do
                    local angle1 = (i / 6) * math.pi * 2 + time * 0.3
                    local angle2 = ((i + 2) / 6) * math.pi * 2 + time * 0.3
                    local x1 = math.cos(angle1) * starRadius
                    local y1 = -domeHeight * 0.8 + math.sin(angle1) * starRadius * 0.5
                    local x2 = math.cos(angle2) * starRadius
                    local y2 = -domeHeight * 0.8 + math.sin(angle2) * starRadius * 0.5
                    
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, x1, y1)
                    nvgLineTo(ctx, x2, y2)
                    nvgStrokeColor(ctx, nvgRGBA(colorPurple[1]*phaseIntensity, colorPurple[2]*phaseIntensity, colorPurple[3]*phaseIntensity, 180 * pulse))
                    nvgStrokeWidth(ctx, 2)
                    nvgStroke(ctx)
                end
                
                -- 中央核心能量球（飞碟中心）
                nvgBeginPath(ctx)
                nvgCircle(ctx, 0, 0, 20 * pulse)
                local coreGlow = nvgRadialGradient(ctx, 0, 0, 0, 25,
                                                  nvgRGBA(255, 255, 255, 255),
                                                  nvgRGBA(colorGlow[1]*phaseIntensity, colorGlow[2]*phaseIntensity, colorGlow[3]*phaseIntensity, 0))
                nvgFillPaint(ctx, coreGlow)
                nvgFill(ctx)
                
                -- Boss防护罩（只有触手还在时显示）
                local anyTentacleAlive = false
                for _, tentacle in ipairs(enemy.tentacles) do
                    if not tentacle.destroyed and tentacle.health > 0 then
                        anyTentacleAlive = true
                        break
                    end
                end
                
                if anyTentacleAlive then
                    -- 防护罩三层能量场（椭圆形，稍微压扁）
                    for shieldLayer = 3, 1, -1 do
                        local shieldRadiusX = ufoRadius * (1.0 + shieldLayer * 0.12)
                        local shieldRadiusY = shieldRadiusX * 0.5  -- 压扁到50%（之前30%太扁）
                        local shieldAlpha = (40 / shieldLayer) * pulse
                        local shieldPaint = nvgRadialGradient(ctx, 0, 0, ufoRadius * 0.9 * 0.5, shieldRadiusX,
                                                             nvgRGBA(0, 180, 255, shieldAlpha),
                                                             nvgRGBA(100, 200, 255, 0))
                        nvgBeginPath(ctx)
                        nvgEllipse(ctx, 0, 0, shieldRadiusX, shieldRadiusY)  -- 椭圆护罩
                        nvgFillPaint(ctx, shieldPaint)
                        nvgFill(ctx)
                    end
                    
                    -- 防护罩六边形网格纹理（椭圆形）
                    local hexCount = 6
                    for i = 0, hexCount - 1 do
                        local hexAngle = (i / hexCount) * math.pi * 2 + time * 0.5
                        local hexRadiusX = ufoRadius * 1.15
                        local hexRadiusY = hexRadiusX * 0.5  -- 压扁到50%（之前30%太扁）
                        local hexSize = 15
                        
                        for j = 0, 5 do
                            local a1 = hexAngle + (j / 6) * math.pi * 2
                            local a2 = hexAngle + ((j + 1) / 6) * math.pi * 2
                            local x1 = math.cos(a1) * hexRadiusX + math.cos(hexAngle) * hexRadiusX * 0.3
                            local y1 = (math.sin(a1) * hexRadiusY + math.sin(hexAngle) * hexRadiusY * 0.3)  -- Y方向压扁
                            local x2 = math.cos(a2) * hexRadiusX + math.cos(hexAngle) * hexRadiusX * 0.3
                            local y2 = (math.sin(a2) * hexRadiusY + math.sin(hexAngle) * hexRadiusY * 0.3)  -- Y方向压扁
                            
                            nvgBeginPath(ctx)
                            nvgMoveTo(ctx, x1, y1)
                            nvgLineTo(ctx, x2, y2)
                            nvgStrokeColor(ctx, nvgRGBA(100, 220, 255, 100 * pulse))
                            nvgStrokeWidth(ctx, 1.5)
                            nvgStroke(ctx)
                        end
                    end
                end
                
                -- Boss血条（只在触手全被打光后显示）
                if not anyTentacleAlive then
                    local healthPercent = enemy.health / enemy.maxHealth
                    local bossBarWidth = ufoRadius * 2
                    local bossBarHeight = 8
                    local bossBarY = -ufoRadius - 15  -- 降低血条高度
                    
                    -- Boss血条背景
                    nvgBeginPath(ctx)
                    nvgRect(ctx, -bossBarWidth/2, bossBarY, bossBarWidth, bossBarHeight)
                    nvgFillColor(ctx, nvgRGBA(40, 40, 40, 220))
                    nvgFill(ctx)
                    
                    -- Boss血条前景
                    if healthPercent > 0 then
                        nvgBeginPath(ctx)
                        nvgRect(ctx, -bossBarWidth/2, bossBarY, bossBarWidth * healthPercent, bossBarHeight)
                        local bossHealthR = (1.0 - healthPercent) * 255
                        local bossHealthG = healthPercent * 200
                        local bossHealthB = healthPercent * 100
                        nvgFillColor(ctx, nvgRGBA(bossHealthR, bossHealthG, bossHealthB, 240))
                        nvgFill(ctx)
                    end
                    
                    -- Boss血条边框
                    nvgBeginPath(ctx)
                    nvgRect(ctx, -bossBarWidth/2, bossBarY, bossBarWidth, bossBarHeight)
                    nvgStrokeColor(ctx, nvgRGBA(255, 200, 100, 200))
                    nvgStrokeWidth(ctx, 2)
                    nvgStroke(ctx)
                    
                    -- Boss名称
                    nvgFontSize(ctx, 16)
                    nvgFontFace(ctx, "sans-bold")
                    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                    nvgFillColor(ctx, nvgRGBA(255, 220, 100, 255))
                    nvgText(ctx, 0, bossBarY - 20, "BOSS")
                end
                
                -- 绘制小飞碟护卫
                if enemy.minions then
                    for _, minion in ipairs(enemy.minions) do
                        if minion.health > 0 then
                            -- 计算小飞碟位置（绕Boss旋转 + 漂浮）
                            local minionX = enemy.x + math.cos(minion.angle) * minion.distance
                            local minionY = enemy.y + math.sin(minion.angle) * minion.distance
                            
                            -- 转换为相对坐标
                            local relX = minionX - enemy.x
                            local relY = minionY - enemy.y
                            
                            nvgSave(ctx)
                            nvgTranslate(ctx, relX, relY)
                            
                            -- 小飞碟主体（小圆盘，2倍大小）
                            nvgBeginPath(ctx)
                            nvgEllipse(ctx, 0, 0, minion.radius * 1.2, minion.radius * 0.6)  -- radius已经是40（2倍）
                            local minionGrad = nvgRadialGradient(ctx, 0, -3, 5, minion.radius * 1.2,
                                                                nvgRGBA(colorGray[1] * 1.1, colorGray[2] * 1.1, colorGray[3] * 1.1, 255),
                                                                nvgRGBA(colorDarkGray[1], colorDarkGray[2], colorDarkGray[3], 255))
                            nvgFillPaint(ctx, minionGrad)
                            nvgFill(ctx)
                            nvgStrokeColor(ctx, nvgRGBA(colorPurple[1]*phaseIntensity, colorPurple[2]*phaseIntensity, colorPurple[3]*phaseIntensity, 220))
                            nvgStrokeWidth(ctx, 2)
                            nvgStroke(ctx)
                            
                            -- 小飞碟外层光晕
                            nvgBeginPath(ctx)
                            nvgCircle(ctx, 0, 0, minion.radius * 1.8)
                            local outerHalo = nvgRadialGradient(ctx, 0, 0, minion.radius * 0.8, minion.radius * 1.8,
                                                                nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 60 * pulse),
                                                                nvgRGBA(colorGlow[1]*phaseIntensity, colorGlow[2]*phaseIntensity, colorGlow[3]*phaseIntensity, 0))
                            nvgFillPaint(ctx, outerHalo)
                            nvgFill(ctx)
                            
                            -- 小飞碟中层光晕
                            nvgBeginPath(ctx)
                            nvgCircle(ctx, 0, 0, minion.radius * 1.3)
                            local midHalo = nvgRadialGradient(ctx, 0, 0, minion.radius * 0.5, minion.radius * 1.3,
                                                              nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 100 * pulse),
                                                              nvgRGBA(colorGlow[1]*phaseIntensity, colorGlow[2]*phaseIntensity, colorGlow[3]*phaseIntensity, 0))
                            nvgFillPaint(ctx, midHalo)
                            nvgFill(ctx)
                            
                            -- 小飞碟中央光点（增大2倍）
                            nvgBeginPath(ctx)
                            nvgCircle(ctx, 0, 0, 10 * pulse)  -- 从5增加到10
                            local minionCore = nvgRadialGradient(ctx, 0, 0, 0, 14,  -- 从7增加到14
                                                                nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 255),
                                                                nvgRGBA(colorGlow[1]*phaseIntensity, colorGlow[2]*phaseIntensity, colorGlow[3]*phaseIntensity, 0))
                            nvgFillPaint(ctx, minionCore)
                            nvgFill(ctx)
                            
                            -- 血量条（在小飞碟上方，增大2倍）
                            local healthPercent = minion.health / minion.maxHealth
                            local barWidth = 48  -- 从24增加到48
                            local barHeight = 5  -- 从3增加到5
                            local barY = -minion.radius - 10
                            
                            -- 血量条背景
                            nvgBeginPath(ctx)
                            nvgRect(ctx, -barWidth/2, barY, barWidth, barHeight)
                            nvgFillColor(ctx, nvgRGBA(40, 40, 40, 180))
                            nvgFill(ctx)
                            
                            -- 血量条前景
                            if healthPercent > 0 then
                                nvgBeginPath(ctx)
                                nvgRect(ctx, -barWidth/2, barY, barWidth * healthPercent, barHeight)
                                local healthR = (1.0 - healthPercent) * 255
                                local healthG = healthPercent * 255
                                nvgFillColor(ctx, nvgRGBA(healthR, healthG, 50, 200))
                                nvgFill(ctx)
                            end
                            
                            nvgRestore(ctx)
                        end
                    end
                end
                
                -- Boss镭射武器（持续直线照射，紫色）
                if enemy.laserActive then
                    local laserLength = 2000  -- 镭射长度（增加到2000，保证射出屏幕）
                    local laserEndX = math.cos(enemy.laserAngle) * laserLength
                    local laserEndY = math.sin(enemy.laserAngle) * laserLength
                    
                    -- 镭射充能蓄力效果（从细到粗的前摇）
                    local chargeProgress = math.min(enemy.laserTimer / BOSS_LASER_CHARGE_TIME, 1.0)
                    local laserPulse = math.sin(time * 15) * 0.3 + 0.7
                    -- 充能阶段镭射较细（20%），充能完成后达到100%
                    local laserWidth = 0.2 + chargeProgress * 0.8
                    
                    -- 外层紫色能量波（脉动）
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, 0, 0)
                    nvgLineTo(ctx, laserEndX, laserEndY)
                    nvgStrokeColor(ctx, nvgRGBA(colorGlow[1]*phaseIntensity, colorGlow[2]*phaseIntensity, colorGlow[3]*phaseIntensity, 60 * laserPulse))
                    nvgStrokeWidth(ctx, 40 * laserWidth)
                    nvgStroke(ctx)
                    
                    -- 中层紫色能量束
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, 0, 0)
                    nvgLineTo(ctx, laserEndX, laserEndY)
                    nvgStrokeColor(ctx, nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, 200))
                    nvgStrokeWidth(ctx, 24 * laserWidth)
                    nvgStroke(ctx)
                    
                    -- 内层白光核心
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, 0, 0)
                    nvgLineTo(ctx, laserEndX, laserEndY)
                    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
                    nvgStrokeWidth(ctx, 10 * laserWidth)
                    nvgStroke(ctx)
                    
                    -- 镭射发射口充能环（紫色）
                    for i = 1, 3 do
                        nvgBeginPath(ctx)
                        nvgCircle(ctx, 0, 0, 20 + i * 8)
                        nvgStrokeColor(ctx, nvgRGBA(colorLightPurple[1]*phaseIntensity, colorLightPurple[2]*phaseIntensity, colorLightPurple[3]*phaseIntensity, (150 - i * 30) * laserPulse))
                        nvgStrokeWidth(ctx, 3)
                        nvgStroke(ctx)
                    end
                end
                
                -- 跳过通用渲染
                nvgRestore(ctx)
                return
            end
            
            -- 非Boss敌人的通用渲染
            local gradient = nvgLinearGradient(ctx, 0, -enemy.radius, 0, enemy.radius,
                                              nvgRGBA(r, g, b, 255),
                                              nvgRGBA(r * 0.6, g * 0.6, b, 255))
            nvgFillPaint(ctx, gradient)
            nvgFill(ctx)
            
            nvgStrokeColor(ctx, nvgRGBA(255, 150, 0, 255))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
            
            nvgRestore(ctx)
        end
    end
end

local function drawBullets(ctx)
    local time = GetTime():GetElapsedTime()
    
    for _, bullet in ipairs(bullets) do
        if bullet.alive then
            nvgSave(ctx)
            
            if bullet.fromPlayer then
                -- 玩家子弹（超炫青色能量弹）
                local pulse = math.sin(time * 20 + bullet.x + bullet.y) * 0.3 + 1.0
                
                -- 外层大光晕
                local outerHalo = nvgRadialGradient(ctx, bullet.x, bullet.y, 0, bullet.radius * 4,
                    nvgRGBA(0, 255, 255, 100 * pulse),
                    nvgRGBA(0, 255, 255, 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, bullet.x, bullet.y, bullet.radius * 4)
                nvgFillPaint(ctx, outerHalo)
                nvgFill(ctx)
                
                -- 中层光晕
                local midHalo = nvgRadialGradient(ctx, bullet.x, bullet.y, bullet.radius * 0.5, bullet.radius * 2.5,
                    nvgRGBA(50, 255, 255, 200),
                    nvgRGBA(0, 255, 255, 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, bullet.x, bullet.y, bullet.radius * 2.5)
                nvgFillPaint(ctx, midHalo)
                nvgFill(ctx)
                
                -- 主体能量核心
                nvgBeginPath(ctx)
                nvgCircle(ctx, bullet.x, bullet.y, bullet.radius * 1.2)
                local coreGradient = nvgRadialGradient(ctx, bullet.x, bullet.y, 0, bullet.radius * 1.2,
                    nvgRGBA(200, 255, 255, 255),
                    nvgRGBA(100, 255, 255, 255))
                nvgFillPaint(ctx, coreGradient)
                nvgFill(ctx)
                
                -- 白色核心亮点
                nvgBeginPath(ctx)
                nvgCircle(ctx, bullet.x, bullet.y, bullet.radius * 0.5)
                nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
                nvgFill(ctx)
                
                -- 如果是强化子弹，加光圈
                if bullet.damage > 1 then
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, bullet.x, bullet.y, bullet.radius * 2)
                    nvgStrokeColor(ctx, nvgRGBA(255, 255, 100, 200 * pulse))
                    nvgStrokeWidth(ctx, 2)
                    nvgStroke(ctx)
                end
            else
                -- 敌人子弹（红色能量弹）
                local pulse = math.sin(time * 15 + bullet.x + bullet.y) * 0.3 + 1.0
                
                -- 外层光晕
                local outerHalo = nvgRadialGradient(ctx, bullet.x, bullet.y, 0, bullet.radius * 3.5,
                    nvgRGBA(255, 100, 0, 120 * pulse),
                    nvgRGBA(255, 100, 0, 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, bullet.x, bullet.y, bullet.radius * 3.5)
                nvgFillPaint(ctx, outerHalo)
                nvgFill(ctx)
                
                -- 中层光晕
                local midHalo = nvgRadialGradient(ctx, bullet.x, bullet.y, bullet.radius * 0.5, bullet.radius * 2,
                    nvgRGBA(255, 150, 100, 200),
                    nvgRGBA(255, 100, 0, 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, bullet.x, bullet.y, bullet.radius * 2)
                nvgFillPaint(ctx, midHalo)
                nvgFill(ctx)
                
                -- 主体
                nvgBeginPath(ctx)
                nvgCircle(ctx, bullet.x, bullet.y, bullet.radius)
                local coreGradient = nvgRadialGradient(ctx, bullet.x, bullet.y, 0, bullet.radius,
                    nvgRGBA(255, 200, 150, 255),
                    nvgRGBA(255, 100, 50, 255))
                nvgFillPaint(ctx, coreGradient)
                nvgFill(ctx)
            end
            
            nvgRestore(ctx)
        end
    end
end

local function drawPowerups(ctx)
    for _, powerup in ipairs(powerups) do
        if powerup.alive then
            nvgSave(ctx)
            nvgTranslate(ctx, powerup.x, powerup.y)
            
            local pulse = math.sin(powerup.pulseTimer * 5) * 0.3 + 1.0
            nvgScale(ctx, pulse, pulse)
            
            local r, g, b = 255, 215, 0
            if powerup.type == POWERUP_HEALTH then
                r, g, b = 0, 255, 100
            elseif powerup.type == POWERUP_SHIELD then
                r, g, b = 0, 200, 255
            elseif powerup.type == POWERUP_LASER_WHIP then
                -- 紫色闪电
                r, g, b = 200, 100, 255
            end
            
            -- 光晕
            local halo = nvgRadialGradient(ctx, 0, 0, powerup.radius * 0.5, powerup.radius * 2,
                                          nvgRGBA(r, g, b, 120),
                                          nvgRGBA(r, g, b, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, 0, 0, powerup.radius * 2)
            nvgFillPaint(ctx, halo)
            nvgFill(ctx)
            
            -- 主体
            nvgBeginPath(ctx)
            nvgCircle(ctx, 0, 0, powerup.radius)
            nvgFillColor(ctx, nvgRGBA(r, g, b, 255))
            nvgFill(ctx)
            
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 200))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
            
            nvgRestore(ctx)
        end
    end
end

local function drawWhips(ctx)
    for _, whip in ipairs(whips) do
        nvgSave(ctx)
        
        -- 确定终点（与 checkWhipCollisions 保持一致）
        local endX, endY
        local hasTarget = false
        
        -- 检查目标是否有效
        if whip.targetEnemy then
            if whip.targetType == "enemy" and whip.targetEnemy.alive then
                hasTarget = true
                endX = whip.targetEnemy.x
                endY = whip.targetEnemy.y
            elseif whip.targetType == "tentacle" and whip.targetEnemy.tentacle and not whip.targetEnemy.tentacle.destroyed then
                hasTarget = true
                endX = whip.targetEnemy.x
                endY = whip.targetEnemy.y
            elseif whip.targetType == "minion" and whip.targetEnemy.minion and whip.targetEnemy.minion.health > 0 and whip.targetEnemy.boss and whip.targetEnemy.boss.alive then
                hasTarget = true
                -- 更新小飞碟的实时位置
                endX = whip.targetEnemy.boss.x + math.cos(whip.targetEnemy.minion.angle) * whip.targetEnemy.minion.distance
                endY = whip.targetEnemy.boss.y + math.sin(whip.targetEnemy.minion.angle) * whip.targetEnemy.minion.distance
                whip.targetEnemy.x = endX
                whip.targetEnemy.y = endY
            end
        end
        
        if not hasTarget then
            endX = whip.defaultEndX
            endY = whip.defaultEndY
        end
        
        -- 计算脉动效果
        local pulse = math.sin(GetTime():GetElapsedTime() * 10) * 0.3 + 1.0
        
        if hasTarget then
            -- 有目标时：绘制超华丽弧形（动态方向）
            local dx = endX - whip.startX
            local dy = endY - whip.startY
            local dist = math.sqrt(dx * dx + dy * dy)
            local perpX = -dy / (dist + 0.001)
            local perpY = dx / (dist + 0.001)
            
            -- 根据目标相对位置动态调整弧线方向
            local directionMultiplier = 1
            if dx < 0 then
                directionMultiplier = -1  -- 目标在左侧，弧线向左
            end
            
            -- 多段动态扭曲效果（段数在1-3之间动态变化，与碰撞检测同步）
            -- 动态段数：使用sin函数让段数在1-3之间平滑变化
            local segmentPhase = math.sin(whip.swingTimer * WHIP_SWING_SPEED * 2.0) * 0.5 + 0.5  -- 0-1
            local numSegments = 1 + math.floor(segmentPhase * 2.5)  -- 1, 2, 或 3
            
            -- 基础幅度
            local baseArc = 80
            
            -- 第一控制点（33%位置）- 多段扭曲
            local arc1 = baseArc
            arc1 = arc1 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 6.0) * 70   -- 主摆动
            arc1 = arc1 + math.cos(whip.swingTimer * WHIP_SWING_SPEED * 10.0 + 0.0) * 50  -- 段1扭曲
            if numSegments >= 2 then
                arc1 = arc1 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 15.0 + 1.0) * 40  -- 段2扭曲
            end
            if numSegments >= 3 then
                arc1 = arc1 + math.cos(whip.swingTimer * WHIP_SWING_SPEED * 20.0 + 2.0) * 30  -- 段3扭曲
            end
            arc1 = arc1 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 25.0) * 15  -- 快速颤动
            
            -- 第二控制点（67%位置）- 与第一个相位相反，形成S型扭曲
            local arc2 = baseArc
            arc2 = arc2 - math.sin(whip.swingTimer * WHIP_SWING_SPEED * 6.0) * 70   -- 反向摆动
            arc2 = arc2 - math.cos(whip.swingTimer * WHIP_SWING_SPEED * 10.0 + math.pi) * 50  -- 反向段1
            if numSegments >= 2 then
                arc2 = arc2 + math.sin(whip.swingTimer * WHIP_SWING_SPEED * 15.0 + 2.0) * 40  -- 段2扭曲
            end
            if numSegments >= 3 then
                arc2 = arc2 - math.cos(whip.swingTimer * WHIP_SWING_SPEED * 20.0 + 3.0) * 30  -- 段3扭曲
            end
            arc2 = arc2 - math.sin(whip.swingTimer * WHIP_SWING_SPEED * 25.0) * 15  -- 反向颤动
            
            local cp1X = whip.startX + dx * 0.33 + perpX * arc1 * directionMultiplier
            local cp1Y = whip.startY + dy * 0.33 + perpY * arc1 * directionMultiplier
            local cp2X = whip.startX + dx * 0.67 + perpX * arc2 * directionMultiplier
            local cp2Y = whip.startY + dy * 0.67 + perpY * arc2 * directionMultiplier
            
            -- 第一层：超大光晕
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX, whip.startY)
            nvgBezierTo(ctx, cp1X, cp1Y, cp2X, cp2Y, endX, endY)
            local outerGlow = nvgLinearGradient(ctx,
                whip.startX, whip.startY, endX, endY,
                nvgRGBA(50, 200, 255, 100 * pulse),
                nvgRGBA(255, 50, 255, 100 * pulse))
            nvgStrokePaint(ctx, outerGlow)
            nvgStrokeWidth(ctx, WHIP_WIDTH_BASE * 4)
            nvgStroke(ctx)
            
            -- 第二层：外层光晕
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX, whip.startY)
            nvgBezierTo(ctx, cp1X, cp1Y, cp2X, cp2Y, endX, endY)
            local glowGradient = nvgLinearGradient(ctx,
                whip.startX, whip.startY, endX, endY,
                nvgRGBA(100, 255, 255, 200 * pulse),
                nvgRGBA(255, 100, 255, 200 * pulse))
            nvgStrokePaint(ctx, glowGradient)
            nvgStrokeWidth(ctx, WHIP_WIDTH_BASE * 2.5)
            nvgStroke(ctx)
            
            -- 第三层：主体
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX, whip.startY)
            nvgBezierTo(ctx, cp1X, cp1Y, cp2X, cp2Y, endX, endY)
            local mainGradient = nvgLinearGradient(ctx,
                whip.startX, whip.startY, endX, endY,
                nvgRGBA(0, 255, 255, 255),
                nvgRGBA(255, 150, 255, 255))
            nvgStrokePaint(ctx, mainGradient)
            nvgStrokeWidth(ctx, WHIP_WIDTH_BASE)
            nvgStroke(ctx)
            
            -- 第四层：核心闪电（带随机抖动）
            local jitter = math.random() * 2 - 1
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX + jitter, whip.startY + jitter)
            nvgBezierTo(ctx, cp1X + jitter, cp1Y + jitter, cp2X + jitter, cp2Y + jitter, endX + jitter, endY + jitter)
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
            nvgStrokeWidth(ctx, WHIP_WIDTH_TIP)
            nvgStroke(ctx)
            
            -- 绘制超炫吸附点效果
            local targetPulse = math.sin(GetTime():GetElapsedTime() * 15) * 0.5 + 1.0
            
            -- 内圈发光
            nvgBeginPath(ctx)
            nvgCircle(ctx, endX, endY, 12 * targetPulse)
            local radialGradient = nvgRadialGradient(ctx, endX, endY, 0, 12 * targetPulse,
                nvgRGBA(255, 255, 255, 200),
                nvgRGBA(255, 255, 100, 0))
            nvgFillPaint(ctx, radialGradient)
            nvgFill(ctx)
            
            -- 中圈
            nvgBeginPath(ctx)
            nvgCircle(ctx, endX, endY, 18 * targetPulse)
            nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 255))
            nvgStrokeWidth(ctx, 3)
            nvgStroke(ctx)
            
            -- 外圈
            nvgBeginPath(ctx)
            nvgCircle(ctx, endX, endY, 25 * targetPulse)
            nvgStrokeColor(ctx, nvgRGBA(255, 100, 255, 150))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        else
            -- 无目标时：绘制超炫直线
            -- 第一层：超大光晕
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX, whip.startY)
            nvgLineTo(ctx, endX, endY)
            local outerGlow = nvgLinearGradient(ctx,
                whip.startX, whip.startY, endX, endY,
                nvgRGBA(50, 200, 255, 100 * pulse),
                nvgRGBA(50, 200, 255, 20))
            nvgStrokePaint(ctx, outerGlow)
            nvgStrokeWidth(ctx, WHIP_WIDTH_BASE * 4)
            nvgStroke(ctx)
            
            -- 第二层：外层光晕
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX, whip.startY)
            nvgLineTo(ctx, endX, endY)
            local glowGradient = nvgLinearGradient(ctx,
                whip.startX, whip.startY, endX, endY,
                nvgRGBA(100, 255, 255, 200 * pulse),
                nvgRGBA(100, 255, 255, 50))
            nvgStrokePaint(ctx, glowGradient)
            nvgStrokeWidth(ctx, WHIP_WIDTH_BASE * 2.5)
            nvgStroke(ctx)
            
            -- 第三层：主体
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX, whip.startY)
            nvgLineTo(ctx, endX, endY)
            local mainGradient = nvgLinearGradient(ctx,
                whip.startX, whip.startY, endX, endY,
                nvgRGBA(0, 255, 255, 255),
                nvgRGBA(0, 255, 255, 100))
            nvgStrokePaint(ctx, mainGradient)
            nvgStrokeWidth(ctx, WHIP_WIDTH_BASE)
            nvgStroke(ctx)
            
            -- 第四层：核心闪电（带随机抖动）
            local jitter = math.random() * 2 - 1
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, whip.startX + jitter, whip.startY + jitter)
            nvgLineTo(ctx, endX + jitter, endY + jitter)
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
            nvgStrokeWidth(ctx, WHIP_WIDTH_TIP)
            nvgStroke(ctx)
        end
        
        nvgRestore(ctx)
    end
end

local function drawParticles(ctx)
    for _, p in ipairs(particles) do
        local lifeRatio = p.life / p.maxLife
        local alpha = p.a * lifeRatio
        local size = p.size * lifeRatio
        
        nvgBeginPath(ctx)
        nvgCircle(ctx, p.x, p.y, size)
        nvgFillColor(ctx, nvgRGBA(p.r * 255, p.g * 255, p.b * 255, alpha * 255))
        nvgFill(ctx)
    end
end

local function drawUI(ctx, w, h)
    nvgFontSize(ctx, 24)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    
    -- 得分
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, 20, 20, "Score: " .. score, nil)
    
    -- 波次
    nvgText(ctx, 20, 50, "Wave: " .. currentWave, nil)
    
    -- 生命值
    nvgText(ctx, 20, 80, "Health:", nil)
    for i = 1, player.maxHealth do
        if i <= player.health then
            nvgBeginPath(ctx)
            nvgCircle(ctx, 110 + i * 25, 90, 8)
            nvgFillColor(ctx, nvgRGBA(255, 0, 100, 255))
            nvgFill(ctx)
        else
            nvgBeginPath(ctx)
            nvgCircle(ctx, 110 + i * 25, 90, 8)
            nvgStrokeColor(ctx, nvgRGBA(100, 100, 100, 255))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end
    end
    
    -- 武器等级
    nvgText(ctx, 20, 110, "Weapon: Lv." .. player.weaponLevel, nil)
    
    -- 护盾状态
    if player.shieldHits > 0 then
        nvgFillColor(ctx, nvgRGBA(100, 255, 255, 255))
        nvgText(ctx, 20, 140, "Shield:", nil)
        
        -- 绘制护盾次数图标（三个圆点）
        for i = 1, 3 do
            nvgBeginPath(ctx)
            nvgCircle(ctx, 100 + i * 20, 150, 6)
            if i <= player.shieldHits then
                -- 剩余的护盾显示为亮色
                local shieldGlow = nvgRadialGradient(ctx, 100 + i * 20, 150, 0, 8,
                    nvgRGBA(100, 255, 255, 255),
                    nvgRGBA(0, 200, 255, 100))
                nvgFillPaint(ctx, shieldGlow)
            else
                -- 已消耗的护盾显示为暗色
                nvgFillColor(ctx, nvgRGBA(50, 100, 100, 100))
            end
            nvgFill(ctx)
            
            -- 边框
            if i <= player.shieldHits then
                nvgStrokeColor(ctx, nvgRGBA(150, 255, 255, 255))
                nvgStrokeWidth(ctx, 2)
                nvgStroke(ctx)
            end
        end
    end
    
    -- 镭射鞭状态
    if player.hasLaserWhip then
        local yOffset = player.shieldHits > 0 and 170 or 140
        nvgFillColor(ctx, nvgRGBA(200, 100, 255, 255))
        nvgText(ctx, 20, yOffset, "Laser Whip: " .. player.laserWhipCharges .. "/" .. WHIP_MAX_CHARGES, nil)
        
        -- 绘制闪电图标
        nvgBeginPath(ctx)
        local iconX, iconY = 150, yOffset + 10
        nvgMoveTo(ctx, iconX, iconY - 8)
        nvgLineTo(ctx, iconX + 5, iconY)
        nvgLineTo(ctx, iconX - 2, iconY)
        nvgLineTo(ctx, iconX + 3, iconY + 8)
        nvgLineTo(ctx, iconX - 3, iconY + 2)
        nvgLineTo(ctx, iconX + 2, iconY + 2)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(255, 255, 100, 255))
        nvgFill(ctx)
    end
end

-- 绘制移动平台触控按钮
local function drawTouchControls(ctx, w, h)
    if gameState ~= STATE_PLAYING then
        return
    end
    
    -- 只有拥有镭射鞭时才显示按钮
    if not player.hasLaserWhip or player.laserWhipCharges <= 0 then
        return
    end
    
    -- 镭射鞭按钮（右下角，加大尺寸，不要太靠角）
    local buttonSize = 180  -- 增大到180，更容易点击
    local margin = 60  -- 边距增加到60
    local buttonX = w - buttonSize - margin
    local buttonY = h - buttonSize - margin
    local buttonCenterX = buttonX + buttonSize / 2
    local buttonCenterY = buttonY + buttonSize / 2
    
    -- 检测触控和鼠标点击
    local inputSystem = GetInput()
    local buttonTouched = false
    
    -- 获取坐标映射参数
    local graphics = GetGraphics()
    local windowW = graphics:GetWidth()
    local windowH = graphics:GetHeight()
    
    -- 检测触控输入
    for i = 0, inputSystem:GetNumTouches() - 1 do
        local touch = inputSystem:GetTouch(i)
        local rawX = touch.position.x
        local rawY = touch.position.y
        
        -- 将触控坐标直接映射到游戏坐标（简单缩放）
        local touchX = rawX * (w / windowW)
        local touchY = rawY * (h / windowH)
        
        local dx = touchX - buttonCenterX
        local dy = touchY - buttonCenterY
        if math.sqrt(dx * dx + dy * dy) < buttonSize / 2 then
            buttonTouched = true
            whipButtonPressed = true
            break
        end
    end
    
    -- 检测鼠标点击（PC）
    if not buttonTouched and inputSystem:GetMouseButtonDown(MOUSEB_LEFT) then
        local mousePos = inputSystem:GetMousePosition()
        local mouseX = mousePos.x * (w / windowW)
        local mouseY = mousePos.y * (h / windowH)
        
        local dx = mouseX - buttonCenterX
        local dy = mouseY - buttonCenterY
        if math.sqrt(dx * dx + dy * dy) < buttonSize / 2 then
            buttonTouched = true
            whipButtonPressed = true
        end
    end
    
    -- 绘制按钮背景（圆形）
    local time = GetTime():GetElapsedTime()
    local pulse = math.sin(time * 4) * 0.2 + 0.8
    
    -- 外圈发光
    nvgBeginPath(ctx)
    nvgCircle(ctx, buttonCenterX, buttonCenterY, buttonSize / 2)
    local outerGlow = nvgRadialGradient(ctx, buttonCenterX, buttonCenterY, buttonSize / 2.5, buttonSize / 2,
        nvgRGBA(200, 100, 255, buttonTouched and 200 or 100),
        nvgRGBA(200, 100, 255, 0))
    nvgFillPaint(ctx, outerGlow)
    nvgFill(ctx)
    
    -- 按钮主体
    nvgBeginPath(ctx)
    nvgCircle(ctx, buttonCenterX, buttonCenterY, buttonSize / 2.5)
    local buttonGradient = nvgRadialGradient(ctx, buttonCenterX, buttonCenterY - 10, 5, buttonSize / 2.5,
        nvgRGBA(150, 80, 200, buttonTouched and 255 or 200),
        nvgRGBA(80, 40, 120, buttonTouched and 255 or 200))
    nvgFillPaint(ctx, buttonGradient)
    nvgFill(ctx)
    
    -- 边框
    nvgBeginPath(ctx)
    nvgCircle(ctx, buttonCenterX, buttonCenterY, buttonSize / 2.5)
    nvgStrokeColor(ctx, nvgRGBA(200, 100, 255, 255 * pulse))
    nvgStrokeWidth(ctx, buttonTouched and 4 or 3)
    nvgStroke(ctx)
    
    -- 闪电图标
    local iconScale = buttonTouched and 1.2 or 1.0
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, buttonCenterX, buttonCenterY - 15 * iconScale)
    nvgLineTo(ctx, buttonCenterX + 8 * iconScale, buttonCenterY)
    nvgLineTo(ctx, buttonCenterX - 3 * iconScale, buttonCenterY)
    nvgLineTo(ctx, buttonCenterX + 5 * iconScale, buttonCenterY + 15 * iconScale)
    nvgLineTo(ctx, buttonCenterX - 5 * iconScale, buttonCenterY + 3 * iconScale)
    nvgLineTo(ctx, buttonCenterX + 3 * iconScale, buttonCenterY + 3 * iconScale)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(255, 255, 150, 255))
    nvgFill(ctx)
    
    -- 充能数量
    nvgFontSize(ctx, 18)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, buttonCenterX, buttonY - 5, "x" .. player.laserWhipCharges, nil)
end

local function drawMenu(ctx, w, h)
    -- 标题
    nvgFontSize(ctx, 72)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    
    nvgFillColor(ctx, nvgRGBA(100, 200, 255, 255))
    nvgText(ctx, w / 2, h / 3, "THUNDER STORM", nil)
    
    -- 说明
    nvgFontSize(ctx, 24)
    nvgFillColor(ctx, nvgRGBA(200, 200, 200, 255))
    nvgText(ctx, w / 2, h / 2, "Press Any Key or Touch to Start", nil)
    nvgText(ctx, w / 2, h / 2 + 40, "WASD / Arrow Keys or Touch to Move", nil)
    nvgText(ctx, w / 2, h / 2 + 80, "Auto Shooting", nil)
    nvgText(ctx, w / 2, h / 2 + 120, "SPACE / Z / Right Mouse to Use Laser Whip", nil)
    
    if highScore > 0 then
        nvgText(ctx, w / 2, h - 100, "High Score: " .. highScore, nil)
    end
end

local function drawGameOver(ctx, w, h)
    -- 标题
    nvgFontSize(ctx, 60)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    
    nvgFillColor(ctx, nvgRGBA(255, 100, 100, 255))
    nvgText(ctx, w / 2, h / 3, "GAME OVER", nil)
    
    -- 得分
    nvgFontSize(ctx, 36)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, w / 2, h / 2, "Final Score: " .. score, nil)
    
    if score > highScore then
        nvgFillColor(ctx, nvgRGBA(255, 215, 0, 255))
        nvgText(ctx, w / 2, h / 2 + 50, "NEW HIGH SCORE!", nil)
    end
    
    -- 重试提示
    nvgFontSize(ctx, 24)
    nvgFillColor(ctx, nvgRGBA(200, 200, 200, 255))
    nvgText(ctx, w / 2, h - 150, "Press Any Key or Touch to Restart", nil)
end

local function drawPauseMenu(ctx, w, h)
    -- 半透明背景
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 150))
    nvgFill(ctx)
    
    -- 暂停文字
    nvgFontSize(ctx, 48)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, w / 2, h / 2, "PAUSED", nil)
    
    nvgFontSize(ctx, 24)
    nvgText(ctx, w / 2, h / 2 + 60, "Press ESC to Resume", nil)
end

-- ============================================================================
-- 输入处理
-- ============================================================================

local function handleInput()
    local inputSystem = GetInput()
    
    -- 键盘输入
    input.left = inputSystem:GetKeyDown(KEY_LEFT) or inputSystem:GetKeyDown(KEY_A)
    input.right = inputSystem:GetKeyDown(KEY_RIGHT) or inputSystem:GetKeyDown(KEY_D)
    input.up = inputSystem:GetKeyDown(KEY_UP) or inputSystem:GetKeyDown(KEY_W)
    input.down = inputSystem:GetKeyDown(KEY_DOWN) or inputSystem:GetKeyDown(KEY_S)
    -- 镭射鞭：Z键、空格键（游戏中）、右键
    -- 空格键在菜单界面用于开始游戏，游戏中用于释放镭射鞭
    input.useWhip = inputSystem:GetKeyPress(KEY_Z) or 
                    (inputSystem:GetKeyPress(KEY_SPACE) and gameState == STATE_PLAYING) or 
                    inputSystem:GetMouseButtonPress(MOUSEB_RIGHT)
    
    -- 游戏状态切换
    if inputSystem:GetKeyPress(KEY_ESCAPE) then
        if gameState == STATE_PLAYING then
            gameState = STATE_PAUSED
        elseif gameState == STATE_PAUSED then
            gameState = STATE_PLAYING
        end
    end
    
    -- 按任意键/鼠标/触控开始游戏
    if gameState == STATE_MENU or gameState == STATE_GAMEOVER then
        local shouldStart = false
        
        -- 检测任意键盘按键（检查scancodes，排除ESC）
        for scancode = 0, 255 do
            if inputSystem:GetScancodePress(scancode) and scancode ~= SCANCODE_ESCAPE then
                shouldStart = true
                break
            end
        end
        
        -- 检测任意鼠标按键
        if not shouldStart then
            if inputSystem:GetMouseButtonPress(MOUSEB_LEFT) or 
               inputSystem:GetMouseButtonPress(MOUSEB_RIGHT) or
               inputSystem:GetMouseButtonPress(MOUSEB_MIDDLE) then
                shouldStart = true
            end
        end
        
        -- 检测触控抬起（touchup）：上一帧有触控，当前帧没有触控
        if not shouldStart then
            local isTouching = inputSystem:GetNumTouches() > 0
            if wasTouching and not isTouching then
                shouldStart = true
            end
            wasTouching = isTouching
        end
        
        if shouldStart then
            if gameState == STATE_MENU then
                startNewGame()
            elseif gameState == STATE_GAMEOVER then
                startNewGame()
            end
        end
    else
        -- 游戏进行中，保持触控状态更新
        wasTouching = inputSystem:GetNumTouches() > 0
    end
end

-- ============================================================================
-- 游戏流程
-- ============================================================================

function startNewGame()
    gameState = STATE_PLAYING
    score = 0
    
    -- 体验关卡：首次启动时直接进入第10个Boss波次
    local isFirstTime = isFirstTimeEver
    if isFirstTimeEver then
        currentWave = BOSS_WAVE_INTERVAL * 10  -- 第80波（第10个Boss波次）
        bossCount = 0    -- Boss强度根据波次计算
        isFirstTimeEver = false  -- 标记已经玩过体验关卡
    else
        currentWave = 1  -- 正常从第1波开始
        bossCount = 0
    end
    
    -- 清空所有实体
    enemies = {}
    bullets = {}
    powerups = {}
    particles = {}
    whips = {}
    
    -- 重置玩家
    resetPlayer()
    
    -- 体验关卡特殊装备
    if isFirstTime then
        player.shieldHits = 3           -- 3护盾
        player.laserWhipCharges = 9     -- 3镭射
        player.weaponLevel = 5          -- 5级普通子弹
    end
    
    -- 开始波次
    startWave()
end

-- ============================================================================
-- 主循环
-- ============================================================================

function Start()
    -- 设置窗口标题
    local graphics = GetGraphics()
    if graphics ~= nil then
        graphics.windowTitle = "Thunder Storm - 2D Shooter"
    end
    
    -- 检测平台并启用触控
    local platform = GetPlatform()
    if platform == "Android" or platform == "iOS" or platform == "Web" then
        touchEnabled = true
        print("Thunder Storm: Touch controls enabled for " .. platform)
    end
    
    -- 显示鼠标光标（所有平台）
    local input = GetInput()
    if input ~= nil then
        input:SetMouseVisible(true)
        input:SetMouseMode(MM_FREE)
    end
    
    -- 创建 NanoVG 上下文
    nvgContext = nvgCreate(1)
    
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end
    
    print("Thunder Storm: NanoVG context created successfully")
    
    -- 加载字体
    fontId = nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf")
    if fontId < 0 then
        print("WARNING: Failed to load font")
    end
    
    -- 创建音效场景
    scene_ = Scene()
    
    -- 初始化
    initStars()
    
    -- 获取屏幕尺寸
    local graphics = GetGraphics()
    SCREEN_WIDTH = graphics:GetWidth()
    SCREEN_HEIGHT = graphics:GetHeight()
    
    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
end

function Stop()
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
        print("Space Shooter: NanoVG context deleted")
    end
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    -- 处理输入
    handleInput()
    
    -- 更新游戏状态
    if gameState == STATE_PLAYING then
        updatePlayer(dt)
        updateEnemies(dt)
        updateBullets(dt)
        updatePowerups(dt)
        updateParticles(dt)
        updateStars(dt)
        updateWhips(dt)
        updateWaveSystem(dt)
        checkCollisions()
        checkWhipCollisions()
        updateScreenShake(dt)
    elseif gameState == STATE_MENU then
        updateStars(dt)
    elseif gameState == STATE_GAMEOVER then
        if score > highScore then
            highScore = score
        end
        updateParticles(dt)
        updateStars(dt)
    end
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then
        return
    end
    
    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()
    
    -- 开始 NanoVG 帧
    nvgBeginFrame(nvgContext, width, height, 1.0)
    
    -- 应用屏幕震动
    local shakeX, shakeY = getScreenShakeOffset()
    if shakeX ~= 0 or shakeY ~= 0 then
        nvgTranslate(nvgContext, shakeX, shakeY)
    end
    
    -- 绘制背景
    drawBackground(nvgContext, width, height)
    
    if gameState == STATE_MENU then
        drawMenu(nvgContext, width, height)
    elseif gameState == STATE_PLAYING or gameState == STATE_PAUSED then
        -- 绘制游戏元素（从背景到前景）
        drawPowerups(nvgContext)
        drawBullets(nvgContext)
        drawEnemies(nvgContext)
        drawWhips(nvgContext)
        drawPlayer(nvgContext)
        drawParticles(nvgContext)  -- 粒子特效最后绘制，显示在最上层
        drawUI(nvgContext, width, height)
        
        -- 绘制触控按钮（移动平台）
        drawTouchControls(nvgContext, width, height)
        
        if gameState == STATE_PAUSED then
            drawPauseMenu(nvgContext, width, height)
        end
    elseif gameState == STATE_GAMEOVER then
        drawPowerups(nvgContext)
        drawBullets(nvgContext)
        drawEnemies(nvgContext)
        drawParticles(nvgContext)  -- 粒子特效最后绘制
        drawGameOver(nvgContext, width, height)
    end
    
    -- 结束 NanoVG 帧
    nvgEndFrame(nvgContext)
end

-- 屏幕操纵杆补丁
function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end

