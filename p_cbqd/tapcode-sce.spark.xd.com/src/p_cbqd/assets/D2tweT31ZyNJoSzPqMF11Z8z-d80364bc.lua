-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 配置数据模块
-- ============================================================================
local M = {}

-- 游戏版本号 (每次更新时递增)
M.GAME_VERSION = "1.0.0"

-- 存档系统
M.SAVE_VERSION = 3          -- 存档数据版本号 (数据结构变更时递增, 需与 migrateVersion 最大版本一致)
M.SAVE_INTERVAL = 3          -- 自动保存间隔(秒) 3秒
M.SAVE_MIN_INTERVAL = 2      -- 两次保存最小间隔(秒)

-- 背包上限
M.MAX_SKILLS = 30           -- 技能书上限
M.MAX_GEMS = 30             -- 宝石上限
M.MAX_FRAGMENTS = 3000      -- 单品阶碎片上限
M.ANTI_CHEAT_SALT = "DH_GJ_2026_AC"  -- 反作弊校验盐值

-- 反作弊阈值
M.AC_MAX_ASPD = 3.05           -- 攻速上限 (游戏硬上限3.00, 留容差)

-- 各职业攻速上限
M.CLASS_MAX_ASPD = {
    assassin = 3.0,
    warrior  = 2.8,
    mage     = 2.5,
}
-- ============================================================================
-- 每日任务配置
-- ============================================================================
M.DAILY_RESET_HOUR = 6  -- 每天早上6点重置
M.DAILY_TASKS = {
    { id = "zone_kills",  name = "区域扫荡", desc = "击杀区域内怪物",   target = 10000, reward = 1000, icon = "⚔️" },
    { id = "elite_kills", name = "精英猎杀", desc = "击杀精英怪物",     target = 5000,  reward = 1000, icon = "👹" },
    { id = "hell_kills",  name = "地狱征伐", desc = "击杀地狱BOSS",     target = 500,   reward = 1000, icon = "💀" },
    { id = "buy_gems",    name = "宝石收集", desc = "购买宝石",         target = 2,     reward = 1000, icon = "💎" },
    { id = "buy_skills",  name = "技能研习", desc = "购买技能",         target = 4,     reward = 1000, icon = "📖" },
}

M.AC_MAX_LEVEL = 999           -- 最大等级
M.AC_MAX_DIAMONDS = 500000     -- 钻石绝对上限
M.AC_MAX_GOLD = 99999999999    -- 金币绝对上限 (999亿)
M.AC_MAX_TICKETS = 100000      -- 门票绝对上限
M.AC_MIN_KILLS_PER_LV = 3     -- 每级最少击杀数 (Lv20以上生效)
M.AC_MAX_KILLS_PER_SAVE = 1500 -- 两次保存间最大击杀数

-- ============================================================================
-- 职业定义 (技能不再初始拥有，改为从黑市购买)
-- ============================================================================
M.CLASSES = {
    warrior = {
        name = "战士", icon = "⚔️",
        desc = "高血量高防御的近战职业，擅长持久战斗",
        baseHp = 180, baseAtk = 10, baseDef = 15,
        baseAspd = 1.0, baseCrit = 0, baseCritDmg = 200,
        hpPerLv = 12, atkPerLv = 2, defPerLv = 2,
    },
    mage = {
        name = "法师", icon = "🔮",
        desc = "高攻击的远程职业，技能伤害倍率最高",
        baseHp = 120, baseAtk = 15, baseDef = 10,
        baseAspd = 0.8, baseCrit = 5, baseCritDmg = 180,
        hpPerLv = 8, atkPerLv = 3, defPerLv = 1,
    },
    assassin = {
        name = "刺客", icon = "🗡️",
        desc = "高暴击高攻速的敏捷职业，擅长爆发输出",
        baseHp = 150, baseAtk = 10, baseDef = 10,
        baseAspd = 1.5, baseCrit = 30, baseCritDmg = 250,
        hpPerLv = 10, atkPerLv = 2, defPerLv = 1,
    },
}

-- 职业有序列表 + 数字索引 (兼容 ipairs / #CLASSES / CLASSES[1])
M.CLASS_ORDER = { "warrior", "mage", "assassin" }
for i, id in ipairs(M.CLASS_ORDER) do
    M.CLASSES[id].id = id
    M.CLASSES[id].classIdx = i
    M.CLASSES[i] = M.CLASSES[id]
end

-- 按字符串ID查找职业 (兼容旧代码)
M.CLASS_BY_ID = {}
for i, id in ipairs(M.CLASS_ORDER) do
    M.CLASS_BY_ID[id] = M.CLASSES[id]
end

-- 技能池 (从黑市随机获得)
M.SKILL_POOL = {
    warrior = {
        { name = "刺杀剑术", cd = 5, mult = 200, desc = "快速突刺，造成200%攻击伤害" },
        { name = "开天剑法", cd = 7, mult = 300, desc = "强力斩击，造成300%攻击伤害" },
        { name = "逐日剑法", cd = 10, mult = 400, desc = "剑气纵横，造成400%攻击伤害" },
        { name = "裂天斩",   cd = 12, mult = 600, desc = "终极剑技，造成600%攻击伤害" },
    },
    mage = {
        { name = "小火球",   cd = 5, mult = 250, desc = "投射火球，造成250%攻击伤害" },
        { name = "大火球",   cd = 7, mult = 350, desc = "烈焰爆裂，造成350%攻击伤害" },
        { name = "雷电术",   cd = 10, mult = 500, desc = "召唤雷电，造成500%攻击伤害" },
        { name = "灭天火",   cd = 12, mult = 700, desc = "毁灭之焰，造成700%攻击伤害" },
    },
    assassin = {
        { name = "背刺",     cd = 5, mult = 180, desc = "从背后突袭，造成180%攻击伤害" },
        { name = "裂颅",     cd = 7, mult = 230, desc = "精准打击要害，造成230%攻击伤害" },
        { name = "X斩",      cd = 10, mult = 350, desc = "交叉斩击，造成350%攻击伤害" },
        { name = "致命一击", cd = 12, mult = 500, desc = "绝杀之刃，造成500%攻击伤害" },
    },
}

-- 通用技能池 (所有职业可用)
M.UNIVERSAL_SKILL_POOL = {
    { name = "当头一棒", cd = 5,  mult = 170, desc = "猛力一击，造成170%攻击伤害" },
    { name = "致命一击", cd = 7,  mult = 220, desc = "精准打击要害，造成220%攻击伤害" },
    { name = "隐杀",     cd = 10, mult = 330, desc = "暗影突袭，造成330%攻击伤害" },
    { name = "堕天一击", cd = 14, mult = 600, desc = "天崩地裂的终极一击，造成600%攻击伤害" },
}

-- ============================================================================
-- 黄金以上品质装备帅气名前缀/后缀
-- ============================================================================
M.EQUIP_EPIC_PREFIXES = {
    gold     = { "耀世", "辉煌", "荣耀", "圣光", "黄金领域" },
    platinum = { "永恒", "星辰", "苍穹", "铂金之誓", "天命" },
    diamond  = { "破晓", "钻石裁决", "圣裁", "虚空", "命运之钥" },
    darkgold = { "暗焰", "渊暗", "噬魂", "暗金审判", "冥界" },
    myth     = { "神谕", "创世", "万象", "神话之怒", "弑神" },
    supreme  = { "至尊天罚", "毁灭日轮", "混沌终焉", "鸿蒙", "无上" },
}

M.EQUIP_EPIC_SUFFIXES = {
    weapon   = { "之刃", "裁决者", "屠戮者", "毁灭者", "灾厄" },
    helmet   = { "王冠", "圣冕", "天冠", "战盔", "护佑" },
    armor    = { "战甲", "圣铠", "龙鳞甲", "守护铠", "壁垒" },
    boots    = { "疾风靴", "追风履", "幻影靴", "飞翼", "迅步" },
    ring     = { "指环", "契约戒", "誓约", "命运之戒", "轮回" },
    necklace = { "项链", "心脏坠", "灵魂链", "核心", "命脉" },
}

-- ============================================================================
-- 技能品质
-- ============================================================================
M.SKILL_QUALITIES = {
    { id = "gray",   name = "灰", color = {160,160,160}, mult = 1.00 },
    { id = "green",  name = "绿", color = {76,175,80},   mult = 1.15 },
    { id = "blue",   name = "蓝", color = {33,150,243},  mult = 1.30 },
    { id = "purple", name = "紫", color = {156,39,176},  mult = 1.45 },
    { id = "orange", name = "橙", color = {255,152,0},   mult = 1.60 },
}

-- ============================================================================
-- 装备品质 (12个等级)
-- ============================================================================
M.EQUIP_QUALITIES = {
    { id = "gray",     name = "灰", color = {160,160,160}, affixCount = 0, dropRate = 0.50,  eliteOnly = false },
    { id = "green",    name = "绿", color = {76,175,80},   affixCount = 0, dropRate = 0.30,  eliteOnly = false },
    { id = "blue",     name = "蓝", color = {33,150,243},  affixCount = 0, dropRate = 0.10,  eliteOnly = false },
    { id = "purple",   name = "紫", color = {156,39,176},  affixCount = 3, dropRate = 0.05,  eliteOnly = false },
    { id = "orange",   name = "橙", color = {255,152,0},   affixCount = 4, dropRate = 0.02,  eliteOnly = false },
    { id = "red",      name = "红", color = {244,67,54},   affixCount = 5, dropRate = 0.005, eliteOnly = false },
    { id = "gold",     name = "黄金", color = {255,215,0},   affixCount = 6, dropRate = 0.003, eliteOnly = true },
    { id = "platinum", name = "铂金", color = {229,228,226}, affixCount = 6, dropRate = 0.002, eliteOnly = true },
    { id = "diamond",  name = "钻石", color = {185,242,255}, affixCount = 7, dropRate = 0.001, eliteOnly = true },
    { id = "darkgold", name = "暗金", color = {139,90,43},   affixCount = 6, dropRate = 0.0005, eliteOnly = true },
    { id = "myth",     name = "神话", color = {255,50,150},   affixCount = 7, dropRate = 0.0002, eliteOnly = true },
    { id = "supreme",  name = "至尊", color = {255,0,0},     affixCount = 8, dropRate = 0.0001, eliteOnly = true },
}

M.QUALITY_INDEX = {}
for i, q in ipairs(M.EQUIP_QUALITIES) do
    M.QUALITY_INDEX[q.id] = i
end

-- ============================================================================
-- 装备槽位
-- ============================================================================
M.EQUIP_SLOTS = {
    { id = "weapon",   name = "武器", primary = "atk" },
    { id = "helmet",   name = "头盔", primary = "def" },
    { id = "armor",    name = "铠甲", primary = "def" },
    { id = "boots",    name = "靴子", primary = "def" },
    { id = "ring",     name = "戒指", primary = "atk" },
    { id = "necklace", name = "项链", primary = "atk" },
}

-- ============================================================================
-- 装备词缀类型
-- ============================================================================
M.AFFIX_TYPES = {
    { id = "aspd",       name = "攻速",      fmt = "+%.1f%%" },
    { id = "crit",       name = "暴击",      fmt = "+%.1f%%" },
    { id = "critDmg",    name = "爆伤",      fmt = "+%.1f%%" },
    { id = "antiCrit",   name = "抗暴击",    fmt = "+%.1f%%" },
    { id = "antiCritDmg",name = "抗爆伤",    fmt = "+%.1f" },
    { id = "lifesteal",  name = "吸血",      fmt = "+%.2f%%" },
    { id = "penetration",name = "穿透",      fmt = "+%.1f%%" },
    { id = "expBonus",   name = "经验加成",  fmt = "+%.1f%%" },
    { id = "goldBonus",  name = "金币加成",  fmt = "+%.1f%%" },
}

-- ============================================================================
-- 装备词缀范围 (按装备品质)
-- ============================================================================
M.AFFIX_RANGES = {
    purple = {
        aspd={5,15}, crit={5,10}, critDmg={10,40}, antiCrit={5,10},
        antiCritDmg={5,20}, lifesteal={0.1,0.5}, penetration={10,15},
        expBonus={1,5}, goldBonus={1,5},
    },
    orange = {
        aspd={10,19}, crit={10,15}, critDmg={20,60}, antiCrit={10,15},
        antiCritDmg={10,25}, lifesteal={0.2,0.6}, penetration={15,20},
        expBonus={3,8}, goldBonus={3,8},
    },
    red = {
        aspd={10,23}, crit={10,18}, critDmg={40,80}, antiCrit={10,18},
        antiCritDmg={15,30}, lifesteal={0.5,0.8}, penetration={15,25},
        expBonus={5,10}, goldBonus={5,10},
    },
    gold = {
        aspd={15,28}, crit={15,20}, critDmg={60,100}, antiCrit={15,20},
        antiCritDmg={20,30}, lifesteal={0.5,1.0}, penetration={20,25},
        expBonus={10,15}, goldBonus={10,15},
    },
    platinum = {
        aspd={20,30}, crit={20,23}, critDmg={80,130}, antiCrit={20,23},
        antiCritDmg={25,30}, lifesteal={0.8,1.2}, penetration={25,30},
        expBonus={10,20}, goldBonus={10,20},
    },
    diamond = {
        aspd={25,35}, crit={23,25}, critDmg={100,160}, antiCrit={23,25},
        antiCritDmg={30,35}, lifesteal={1.0,1.5}, penetration={30,35},
        expBonus={15,25}, goldBonus={15,25},
    },
    darkgold = {
        aspd={30,40}, crit={25,28}, critDmg={130,200}, antiCrit={25,28},
        antiCritDmg={35,45}, lifesteal={1.3,1.8}, penetration={35,45},
        expBonus={20,30}, goldBonus={20,30},
    },
    myth = {
        aspd={40,55}, crit={25,35}, critDmg={160,250}, antiCrit={25,35},
        antiCritDmg={40,50}, lifesteal={1.5,2.0}, penetration={40,50},
        expBonus={30,35}, goldBonus={30,35},
    },
    supreme = {
        aspd={50,70}, crit={30,40}, critDmg={200,300}, antiCrit={30,40},
        antiCritDmg={50,60}, lifesteal={2.0,3.0}, penetration={50,60},
        expBonus={35,40}, goldBonus={35,40},
    },
}

-- ============================================================================
-- 强化成功率
-- ============================================================================
M.ENHANCE_RATES = { 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100 }
M.MAX_ENHANCE_LEVEL = #M.ENHANCE_RATES
-- 强化金币消耗: 等级 * 基础金币 * 品质倍率
M.ENHANCE_GOLD_BASE = 30   -- 基础金币单价

-- ============================================================================
-- 宝石系统
-- ============================================================================
M.GEM_QUALITIES = {
    { id = "gray",   name = "灰", color = {160,160,160} },
    { id = "green",  name = "绿", color = {76,175,80} },
    { id = "blue",   name = "蓝", color = {33,150,243} },
    { id = "purple", name = "紫", color = {156,39,176} },
    { id = "orange", name = "橙", color = {255,152,0} },
}

-- 宝石词缀类型 (7种)
M.GEM_AFFIX_TYPES = {
    { id = "atk",        name = "攻击", fmt = "+%d" },
    { id = "hp",         name = "生命", fmt = "+%d" },
    { id = "def",        name = "防御", fmt = "+%d" },
    { id = "crit",       name = "暴击", fmt = "+%.1f%%" },
    { id = "critDmg",    name = "爆伤", fmt = "+%.1f%%" },
    { id = "antiCrit",   name = "抗暴击", fmt = "+%.1f%%" },
    { id = "antiCritDmg",name = "抗爆伤", fmt = "+%.1f" },
}

-- 宝石词缀范围
M.GEM_AFFIX_RANGES = {
    gray = {
        atk = {10, 140},     hp = {10, 140},     def = {10, 140},
        crit = {1, 12},      critDmg = {10, 40},
        antiCrit = {1, 12},  antiCritDmg = {10, 40},
    },
    green = {
        atk = {60, 150},     hp = {60, 150},     def = {60, 150},
        crit = {3, 15},      critDmg = {20, 50},
        antiCrit = {3, 15},  antiCritDmg = {20, 50},
    },
    blue = {
        atk = {80, 170},     hp = {80, 170},     def = {80, 170},
        crit = {5, 18},      critDmg = {30, 60},
        antiCrit = {5, 18},  antiCritDmg = {30, 60},
    },
    purple = {
        atk = {100, 180},    hp = {100, 180},    def = {100, 180},
        crit = {10, 20},     critDmg = {40, 70},
        antiCrit = {10, 20}, antiCritDmg = {40, 70},
    },
    orange = {
        atk = {150, 200},    hp = {150, 200},    def = {150, 200},
        crit = {15, 25},     critDmg = {50, 90},
        antiCrit = {15, 25}, antiCritDmg = {50, 90},
    },
}

-- ============================================================================
-- 孔位系统
-- ============================================================================
M.SOCKET_PROBS = { 0.91, 0.047, 0.027, 0.01 }

M.SOCKET_UPGRADE = {
    normal = { cost = 40, rate = 1.0 },
    fifth  = { cost = 100, rate = 0.5 },
}

M.MAX_SOCKETS_NORMAL = 4
M.MAX_SOCKETS_NATURAL4 = 5

-- ============================================================================
-- 黑市系统
-- ============================================================================
M.BLACK_MARKET = {
    skillPrice = 50000,
    gemPrice   = 100000,
    protectionScrollPrice = 1,
    eliteTicketDiamondPrice = 100,
    eliteTicketAmount = 300,
    qualityProbs = { 0.60, 0.23, 0.10, 0.05, 0.03 },
}

-- ============================================================================
-- 掉落系统
-- ============================================================================
M.DROP_RATES = {
    normalMob   = 0.15,
    eliteNorm   = 0.60,
    eliteSilver = 0.80,
    eliteGold   = 1.00,
    gemDrop     = 0.05,
    skillDrop   = 0.02,
}

M.ZONE_GEM_DROP = {
    gray  = 0.0116,
    green = 0.00116,
}

M.ELITE_EQUIP_DROP = {
    gold     = 1/20,
    platinum = 1/50,
    diamond  = 1/200,
    darkgold = 1/500,
    myth     = 1/1000,
    supreme  = 1/3000,
}

M.ELITE_GEM_DROP = {
    gray   = 1/100,
    green  = 1/200,
    blue   = 1/300,
    purple = 1/500,
    orange = 1/2000,
}

M.ELITE_SKILL_DROP = {
    gray   = 1/50,
    green  = 1/150,
    blue   = 1/400,
    purple = 1/800,
    orange = 1/2500,
}

-- ============================================================================
-- 精英副本等级要求 & 门票
-- ============================================================================
function M.getEliteReqLevel(zoneIdx)
    local zone = M.ZONES[zoneIdx]
    if not zone then return 999 end
    if zone.reqLv < 25 then return nil end
    local eliteOrder = 0
    for i = 1, zoneIdx do
        if M.ZONES[i].reqLv >= 25 then
            eliteOrder = eliteOrder + 1
        end
    end
    return 25 + (eliteOrder - 1) * 5
end

function M.getEliteTicketCost(zoneIdx)
    local eliteOrder = 0
    for i = 1, zoneIdx do
        if M.ZONES[i] and M.ZONES[i].reqLv >= 25 then
            eliteOrder = eliteOrder + 1
        end
    end
    return 6 + eliteOrder
end

-- 门票/钻石掉率 (区域击杀)
M.TICKET_DROP_RATE = 0.14
M.DIAMOND_DROP_RATE = 0.0035

-- ============================================================================
-- 地狱副本
-- ============================================================================
M.HELL_TICKET_DROP_RATE = 0.10

function M.getHellReqLevel(zoneIdx)
    local zone = M.ZONES[zoneIdx]
    if not zone then return nil end
    if zone.reqLv < 25 then return nil end
    local eliteReq = M.getEliteReqLevel(zoneIdx)
    if not eliteReq then return nil end
    -- 地狱副本基础等级45, 后续区域在此基础上递增
    local hellLv = eliteReq + 10
    if hellLv < 45 then hellLv = 45 end
    return hellLv
end

function M.getHellTicketCost()
    return 1
end

-- 地狱副本掉率 = 精英掉率 x 3
M.HELL_EQUIP_DROP = {}
for k, v in pairs(M.ELITE_EQUIP_DROP) do
    M.HELL_EQUIP_DROP[k] = v * 3
end

M.HELL_GEM_DROP = {}
for k, v in pairs(M.ELITE_GEM_DROP) do
    M.HELL_GEM_DROP[k] = v * 3
end

M.HELL_SKILL_DROP = {}
for k, v in pairs(M.ELITE_SKILL_DROP) do
    M.HELL_SKILL_DROP[k] = v * 3
end

-- 地狱模式全局开关 (兼容 main.lua 旧逻辑)
M.HELL_MODE = {
    unlockLevel = 25,
    hpMult = 2,
    atkMult = 2,
    rewardMult = 3,
    dropMult = 3,
}

function M.canEnterHell(playerLevel)
    return playerLevel >= M.HELL_MODE.unlockLevel
end

function M.canSpawnElite(zoneIdx, eliteType)
    if eliteType == "normal" then return true end
    if eliteType == "silver" then return zoneIdx >= 5 end
    if eliteType == "gold"   then return zoneIdx >= 10 end
    return false
end

-- 奇遇BOSS配置
M.ADVENTURE_BOSS = {
    spawnRate = {
        [0] = 0.0001,
        [1] = 0.0001,
        [2] = 0.0002,
        [3] = 0.0005,
    },
    hp = 100,
    def = 1,
    atk = 1,
    fixedDmgTaken = 1,
    dropMinQuality = 10,
}

-- ============================================================================
-- 称号系统
-- ============================================================================
M.TITLES = {
    {
        id = "sword_master", name = "十里坡剑神", icon = "🗡️",
        desc = "在新手平原击杀30000只怪物",
        condition = "zone1_kills", threshold = 30000,
        bonuses = { atk = 500 }, color = {255, 215, 0, 255},
    },
    {
        id = "lucky_one", name = "幸运之人", icon = "🍀",
        desc = "击杀100只奇遇BOSS",
        condition = "adventure_boss_kills", threshold = 100,
        bonuses = { equipDropBonus = 10 }, color = {100, 255, 200, 255},
    },
    {
        id = "unlucky", name = "非酋", icon = "😭",
        desc = "强化装备连续失败5次",
        condition = "enhance_consec_fails", threshold = 5,
        bonuses = { enhanceBonus = 2 }, color = {180, 130, 255, 255},
    },
    {
        id = "chosen_one", name = "天选之人", icon = "✨",
        desc = "单件装备连续强化成功8次",
        condition = "enhance_consec_success", threshold = 8,
        bonuses = { enhanceBonus = 2 }, color = {255, 200, 50, 255},
    },
    {
        id = "elite_challenger", name = "精英挑战者", icon = "🎫",
        desc = "累计消耗10000张精英门票",
        condition = "elite_tickets_spent", threshold = 10000,
        bonuses = { equipDropBonus = 10 }, color = {255, 180, 100, 255},
    },
    {
        id = "elite_slayer", name = "精英屠杀者", icon = "🎫",
        desc = "累计消耗50000张精英门票",
        condition = "elite_tickets_spent", threshold = 50000,
        bonuses = { equipDropBonus = 10 }, color = {255, 140, 60, 255},
    },
    {
        id = "elite_terminator", name = "精英终结者", icon = "🎫",
        desc = "累计消耗200000张精英门票",
        condition = "elite_tickets_spent", threshold = 200000,
        bonuses = { equipDropBonus = 20 }, color = {255, 100, 30, 255},
    },
    {
        id = "hell_challenger", name = "地狱挑战者", icon = "🔥",
        desc = "累计消耗5000张地狱门票",
        condition = "hell_tickets_spent", threshold = 5000,
        bonuses = { equipDropBonus = 10 }, color = {255, 80, 40, 255},
    },
    {
        id = "hell_slayer", name = "地狱屠杀者", icon = "🔥",
        desc = "累计消耗20000张地狱门票",
        condition = "hell_tickets_spent", threshold = 20000,
        bonuses = { equipDropBonus = 10 }, color = {255, 50, 20, 255},
    },
    {
        id = "hell_terminator", name = "地狱终结者", icon = "🔥",
        desc = "累计消耗50000张地狱门票",
        condition = "hell_tickets_spent", threshold = 50000,
        bonuses = { equipDropBonus = 20 }, color = {200, 30, 10, 255},
    },
    {
        id = "forge_god", name = "锻造之神", icon = "🔨",
        desc = "强化单件武器至+11",
        condition = "weapon_enhance_max", threshold = 11,
        bonuses = { crit = 50 }, color = {255, 215, 0, 255},
    },
    {
        id = "zone_lord", name = "区域之主", icon = "👑",
        desc = "在单个区域击杀10万只怪物",
        condition = "zone_kills_max", threshold = 100000,
        bonuses = { atk = 300, def = 300 }, color = {255, 255, 100, 255},
    },
}

-- 离线挂机配置
M.OFFLINE_IDLE = {
    [1] = { maxHours = 8,  rewardMult = 0.5 },
    [2] = { maxHours = 12, rewardMult = 1.0 },
    [3] = { maxHours = 24, rewardMult = 1.0 },
}

-- ============================================================================
-- 自动分解 - 品质列表 (用于UI勾选)
-- ============================================================================
M.AUTO_DECOMPOSE_EQUIP_QUALITIES = {
    "gray", "green", "blue", "purple", "orange", "red",
    "gold", "platinum", "diamond", "darkgold", "myth", "supreme",
}

M.AUTO_DECOMPOSE_SKILL_QUALITIES = { "gray", "green", "blue", "purple", "orange" }
M.AUTO_DECOMPOSE_GEM_QUALITIES   = { "gray", "green", "blue", "purple", "orange" }

-- 分解产出 (宝石分解获得金币)
M.GEM_DECOMPOSE_GOLD = {
    gray   = 1000,
    green  = 5000,
    blue   = 20000,
    purple = 100000,
    orange = 500000,
}

-- ============================================================================
-- 20个区域定义
-- ============================================================================
M.MOB_ICONS = {
    ["史莱姆"] = "🟢", ["野兔"] = "🐇", ["蘑菇怪"] = "🍄",
    ["野狼"] = "🐺", ["野猪"] = "🐗", ["毒蛇"] = "🐍",
    ["暗影狼"] = "🐺", ["食人花"] = "🌺", ["树精"] = "🌳",
    ["石傀儡"] = "🗿", ["矿蝎"] = "🦂", ["地精"] = "👺",
    ["骷髅兵"] = "💀", ["幽灵"] = "👻", ["暗影法师"] = "🧙",
    ["毒蛙"] = "🐸", ["沼泽蛇"] = "🐍", ["腐尸"] = "🧟",
    ["火蜥蜴"] = "🦎", ["熔岩虫"] = "🐛", ["火焰元素"] = "🔥",
    ["冰狼"] = "🐺", ["雪人"] = "⛄", ["冰元素"] = "❄️",
    ["亡灵战士"] = "⚔️", ["吸血鬼"] = "🧛", ["死灵法师"] = "💀",
    ["龙蜥"] = "🦎", ["飞龙"] = "🐉", ["岩龙"] = "🐲",
    ["天使战士"] = "👼", ["风元素"] = "🌪️", ["光明守卫"] = "🛡️",
    ["恶魔卫兵"] = "👹", ["地狱犬"] = "🐕", ["暗影恶魔"] = "😈",
    ["魔族斥候"] = "👁️", ["魔族战士"] = "👹", ["魔族法师"] = "🔮",
    ["暗影刺客"] = "🗡️", ["噩梦"] = "😱", ["幻影"] = "👤",
    ["雷元素"] = "⚡", ["雷鸟"] = "🦅", ["风暴巨人"] = "🌩️",
    ["暗夜精灵"] = "🧝", ["梦魇"] = "🌑", ["月影狼"] = "🐺",
    ["血族骑士"] = "🩸", ["血族公爵"] = "🧛", ["血族伯爵"] = "🧛",
    ["混沌兽"] = "👾", ["虚空行者"] = "🌀", ["毁灭者"] = "💥",
    ["堕落天使"] = "😇", ["远古守卫"] = "🏛️", ["神殿骑士"] = "⚔️",
    ["远古巨龙"] = "🐲", ["泰坦"] = "🗿", ["神之仆从"] = "✨",
    ["史莱姆王"] = "👑", ["翡翠巨蛙"] = "🐸", ["暗影狼王"] = "🐺",
    ["矿洞领主"] = "⛏️", ["亡灵将军"] = "💀", ["沼泽巨兽"] = "🐊",
    ["熔岩巨人"] = "🌋", ["霜冻领主"] = "🥶", ["冥王"] = "☠️",
    ["荒原龙王"] = "🐲", ["堕落天使长"] = "😈", ["深渊领主"] = "👿",
    ["魔族统帅"] = "👹", ["迷宫守护者"] = "🏰", ["雷霆泰坦"] = "⚡",
    ["永夜之王"] = "🌑", ["血族亲王"] = "🧛", ["混沌君主"] = "🌀",
    ["远古神灵"] = "🔱", ["至高神王"] = "👑",
}

M.ZONES = {
    { name = "新手平原",   reqLv = 1,  color = {76,175,80},   mobs = {"史莱姆","野兔","蘑菇怪"},         elite = "史莱姆王" },
    { name = "翡翠草原",   reqLv = 5,  color = {102,187,106}, mobs = {"野狼","野猪","毒蛇"},             elite = "翡翠巨蛙" },
    { name = "幽暗森林",   reqLv = 10, color = {56,142,60},   mobs = {"暗影狼","食人花","树精"},         elite = "暗影狼王" },
    { name = "矮人矿洞",   reqLv = 15, color = {121,85,72},   mobs = {"石傀儡","矿蝎","地精"},           elite = "矿洞领主" },
    { name = "银月废墟",   reqLv = 20, color = {158,158,158}, mobs = {"骷髅兵","幽灵","暗影法师"},       elite = "亡灵将军" },
    { name = "毒沼泽地",   reqLv = 25, color = {104,159,56},  mobs = {"毒蛙","沼泽蛇","腐尸"},           elite = "沼泽巨兽" },
    { name = "烈焰火山",   reqLv = 30, color = {244,67,54},   mobs = {"火蜥蜴","熔岩虫","火焰元素"},     elite = "熔岩巨人" },
    { name = "冰封峡谷",   reqLv = 35, color = {3,169,244},   mobs = {"冰狼","雪人","冰元素"},           elite = "霜冻领主" },
    { name = "亡灵墓穴",   reqLv = 40, color = {69,90,100},   mobs = {"亡灵战士","吸血鬼","死灵法师"},   elite = "冥王" },
    { name = "龙息荒原",   reqLv = 45, color = {255,87,34},   mobs = {"龙蜥","飞龙","岩龙"},             elite = "荒原龙王" },
    { name = "天空之城",   reqLv = 50, color = {100,181,246}, mobs = {"天使战士","风元素","光明守卫"},   elite = "堕落天使长" },
    { name = "深渊裂隙",   reqLv = 55, color = {63,81,181},   mobs = {"恶魔卫兵","地狱犬","暗影恶魔"},   elite = "深渊领主" },
    { name = "魔族边境",   reqLv = 60, color = {156,39,176},  mobs = {"魔族斥候","魔族战士","魔族法师"}, elite = "魔族统帅" },
    { name = "暗影迷宫",   reqLv = 65, color = {48,63,159},   mobs = {"暗影刺客","噩梦","幻影"},         elite = "迷宫守护者" },
    { name = "雷霆之峰",   reqLv = 70, color = {255,235,59},  mobs = {"雷元素","雷鸟","风暴巨人"},       elite = "雷霆泰坦" },
    { name = "永夜森林",   reqLv = 75, color = {33,33,33},    mobs = {"暗夜精灵","梦魇","月影狼"},       elite = "永夜之王" },
    { name = "血色城堡",   reqLv = 80, color = {183,28,28},   mobs = {"血族骑士","血族公爵","血族伯爵"}, elite = "血族亲王" },
    { name = "混沌深渊",   reqLv = 85, color = {74,20,140},   mobs = {"混沌兽","虚空行者","毁灭者"},     elite = "混沌君主" },
    { name = "神殿废墟",   reqLv = 90, color = {255,193,7},   mobs = {"堕落天使","远古守卫","神殿骑士"}, elite = "远古神灵" },
    { name = "世界之巅",   reqLv = 95, color = {255,0,0},     mobs = {"远古巨龙","泰坦","神之仆从"},     elite = "至高神王" },
}

-- ============================================================================
-- 怪物数值公式
-- ============================================================================
function M.getMobStats(zoneIdx)
    local zone = M.ZONES[zoneIdx]
    local reqLv = zone and zone.reqLv or (zoneIdx * 5)

    local scaleFactor
    if zoneIdx <= 4 then
        scaleFactor = 1.0
    elseif zoneIdx <= 6 then
        scaleFactor = 1.3 + (zoneIdx - 4) * 0.25
    elseif zoneIdx <= 8 then
        scaleFactor = 2.0 + (zoneIdx - 6) * 0.6
    else
        scaleFactor = 3.2 * (1.35 ^ (zoneIdx - 8))
    end

    local baseHp  = 60 + reqLv * 8
    local baseAtk = 5 + reqLv * 1.8
    local baseDef = 3 + reqLv * 1.2

    local hp  = math.floor(baseHp * scaleFactor)
    local atk = math.floor(baseAtk * scaleFactor)
    local def = math.floor(baseDef * scaleFactor)

    local exp  = math.floor((15 + zoneIdx * 14) * math.sqrt(scaleFactor))
    local gold = math.floor((8 + zoneIdx * 7) * math.sqrt(scaleFactor))

    return { hp = hp, atk = atk, def = def, exp = exp, gold = gold }
end

M.ELITE_TYPES = {
    normal = { name = "普通精英", color = {255,152,0},   atkM = 1.5, defM = 1.5, hpM = 4,  dropM = 2 },
    silver = { name = "白银精英", color = {192,192,192}, atkM = 2.0, defM = 2.0, hpM = 7,  dropM = 3 },
    gold   = { name = "黄金精英", color = {255,215,0},   atkM = 3.0, defM = 3.0, hpM = 12, dropM = 5 },
}

-- 精英怪物技能配置
M.ELITE_SKILL = {
    cooldown = 8,
    minMult = 200,
    maxMult = 1000,
    cd = 8,  -- 兼容旧代码 (main.lua 使用 .cd)
}

-- 装备基础属性
M.EQUIP_BASE_STATS = {
    weapon   = { stats = { {id="atk", base=8, perZone=7} } },
    helmet   = { stats = { {id="def", base=7, perZone=5.5} } },
    armor    = { stats = { {id="def", base=7, perZone=5.5} } },
    boots    = { stats = { {id="def", base=3.5, perZone=2.75}, {id="hp", base=17, perZone=13.8} } },
    ring     = { stats = { {id="def", base=1.3, perZone=1.1}, {id="atk", base=2, perZone=1.67}, {id="hp", base=10, perZone=8.3} } },
    necklace = { stats = { {id="atk", base=2.5, perZone=2.1}, {id="hp", base=13.3, perZone=11.1} } },
}

-- 品质倍率
M.QUALITY_STAT_MULT = {
    gray=1.0, green=1.3, blue=1.7, purple=2.2, orange=3.0,
    red=5.0, gold=6.0, platinum=7.0, diamond=8.0,
    darkgold=8.5, myth=9.0, supreme=10.0,
}

function M.getPassiveRates(zoneIdx)
    return {
        expPerMin  = math.floor(5 + zoneIdx * 4),
        goldPerMin = math.floor(3 + zoneIdx * 3),
    }
end

-- 被动挂机收益 (兼容 main.lua 旧逻辑)
M.PASSIVE_INCOME = {
    interval = 60,
    goldPerLevel = 5,
    expPerLevel = 3,
}

-- ============================================================================
-- VIP 系统
-- ============================================================================
M.VIP_BONUSES = {
    [0] = { equipDropBonus = 0,  goldBonus = 0,  expBonus = 0 },
    [1] = { equipDropBonus = 100, goldBonus = 100, expBonus = 50 },
    [2] = { equipDropBonus = 30, goldBonus = 30, expBonus = 30 },
    [3] = { equipDropBonus = 50, goldBonus = 50, expBonus = 50 },
}

-- ============================================================================
-- CDK 兑换码系统 (暂时精简, 后续补充)
-- ============================================================================
M.CDK_REWARDS = {
    -- 评价礼包: 所有人可用, 每人限领一次, 500钻石
    ["HAOPING"] = { name = "评价礼包", review = true, diamonds = 500 },

    -- ==================== VIP2礼包CDK (VIP2 + 500钻石 + 2000门票, 每码限用一次, 每人限领一次) ====================
    ["V2XAJI0Y"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V26DPBHS"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2AHXTHV"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23A3ZMF"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V28MDD4V"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V230T9NT"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23W5UZB"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2IKCIDK"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2WNNHJ7"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2XVG0FN"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V29XUY41"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2IBLJH7"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V25LXO6Q"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2JIUJV6"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2OH9SDB"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2DW2PCN"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V29T84AZ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2YTJXEP"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2Q85JSG"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V265KXVF"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V21T2TAL"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2A753LC"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V258DRC1"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V21ERTJ5"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2PHT0HL"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V29XPSEI"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2MVIHCW"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2I64CIY"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2HE7UR2"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23GDPPQ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V20Y9DOM"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V25IGQPK"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2I7P5TB"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V294874F"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2RHOCN9"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2J2QP89"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2UZFK8U"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2T0CVS4"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2F8CGVY"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2IE6IVW"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2PVS7HZ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2IOYKL1"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2CQ99CH"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2J755NF"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V24ZW9XA"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23KX7EE"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2DTJVZH"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2WJR64D"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2PJA1WJ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V20TPAC5"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V26T4UFE"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2L6246H"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ID25OW"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2F75935"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2A0L725"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23J2D54"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2I3QK2I"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2AGL58K"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2XO9T7E"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V28G8JDP"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V20LVSNU"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2JZA7TZ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V20YNCXL"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2L4ZKLO"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2OKEP7Y"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V26WKTAK"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2PUXQPH"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2R62GDS"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2WM31YI"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2HAIR4C"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2OWGZRI"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2XA11DP"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2G8SBI4"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2Q2Y9V8"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V26WZS3T"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V260RJIW"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V21SWJCK"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2JLTEIY"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ZCOTOH"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2P6VZ41"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2NAM148"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2P0TVHH"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2PBMYOF"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2QEWAOU"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2AXEQBN"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2HL1N13"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2JCAT9M"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2X2X18H"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2AFEYUH"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2Z1GV0E"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V238DALY"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V28OZCYW"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2D14VE9"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V22MPNSM"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V243D8W3"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ZP08J3"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2TRP0J4"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23D5IQV"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2NB4GH2"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2M5ZJA8"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2DZR1YX"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2R2DHYL"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2URTP0L"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ZJJEGE"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2T1GHR0"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V29SKDGI"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2GATJ9T"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ZE5R5U"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2QPGB7R"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23OCWBF"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2UK9E1V"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V22ISQP4"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V29KWV08"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2HHXFGC"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2AQVKIZ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ZQY72W"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2X7PTX6"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23CFL0U"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2KEYZ7S"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2RCBPLJ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2D84U89"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2YJB1QX"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V26GVWRD"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2MLY4LY"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2K83TQL"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2L8OS9X"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2TOGN1W"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V21HT7PZ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2E9VIFT"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2TD96QE"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23RZSJ4"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V29ITN7S"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V255J2O7"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2S3KKV9"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2RFTMTT"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2QLGZUI"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V21B0Z3N"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2X39RBS"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2V55PSQ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V20OXFQ8"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2MYX444"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2NLZ15B"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2CW790P"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2DW5PY6"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2B2KNFT"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2U2GC5W"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2I6FQJJ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2A26YFP"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2MVXPJ4"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2HNRIUU"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V29K9XJU"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2Y0BVR6"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2K2VMWW"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2YZX4W6"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2XLPU0D"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2K0GET8"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2T63J3R"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V230ME8F"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2840982"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2N2ATQY"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2YV37DI"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2A5U6HC"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V236KOF8"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2KRD5EQ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2Y08P0F"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ODRO8B"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2NP84DY"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2T9MOGE"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V24QXXVA"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V22IEUC1"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2HH5LF6"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2A4FEJG"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2XAA2IL"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2GB0S0R"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V22SDS8B"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V225SQ8C"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2ROYR6C"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2CVCJWT"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2L9TQVD"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2Z4X1ZH"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2QIMQOD"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2PXNF7C"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23DD03U"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2VULEMX"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V215Z8VM"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2UHXID4"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2N1U349"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V23WXA73"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2JGZLMA"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V25UOFWB"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V20HPMNZ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V21UDBFW"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2YJXRPJ"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V21EPKYR"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2YBOVAK"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2HEJLA0"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2GNZS43"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2C5BA75"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2UUZPEA"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },
    ["V2L2W37D"] = { name = "VIP2礼包", vipLevel = 2, diamonds = 500, tickets = 2000 },

    -- ==================== VIP3礼包CDK (VIP3 + 1500钻石 + 5000门票, 每码限用一次, 每人限领一次) ====================
    ["V34IVSOL"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3MLGSES"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V36M033I"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3FHV1XG"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V31R11Q7"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3UWW5WF"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3CPKJCS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3LQC3C5"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V34WSQT2"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V36Q3XLR"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3FCD6MZ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3SGIPPS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3FNKOMV"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V32XCDYK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V30X65MU"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3FM8ZOV"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V37LN23Y"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V330YSXP"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NNGH8R"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3IEC4D1"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V345BM1E"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NF313F"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3POYIPK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V30QTL3Q"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V34N89QK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NS832E"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3JX5TD4"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V34K1J6F"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3P8HQMA"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3BSI9NB"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V374X2EK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V33ZEZQA"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3CJ4T0S"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3EKKBP2"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3QD6VAS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3IFPWIO"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3XD9CSS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V39TOQW9"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3JA2M0W"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V310LBT3"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3G2QZW3"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3C1QKBH"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3B7S9TJ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V31GM25L"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3EN606N"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V39RR7S2"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V30CV3TL"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3CXLVPY"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3MB5M9J"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V398CWN2"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3Y8FV2B"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3C2NNUV"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3Y8N1UT"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3OXIE0R"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NUJJQ9"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3K6RE4Q"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V36QDY4L"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3MCT64Z"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V37W2SEH"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3E2ATN2"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3TWDL9Z"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3S13C9X"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3QYM52X"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3G8P6BE"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3FFLZM7"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V364JWTE"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3KTSG7F"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3XZV4U3"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3BBXUX1"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3OXRWK8"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3R2YKCC"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3PRHVLZ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3049ENU"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3LQJIDK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NWI5FL"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3UL1RSR"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3LA8S8H"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3MBR5XQ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3T4P501"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NOUHTC"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3S1K9YE"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V39O2M71"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3HSSBEL"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3RQVSLW"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3F90KM3"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3TZK3NY"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V39V20YA"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3R821UZ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3VGWW4F"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3YB8DAL"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3FYO175"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V30CEHLX"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3SLG6MM"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V31ZXYVG"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3IUI9KK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3HZLM72"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3JEYN93"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V382KKZM"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3PJRHT7"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3ZEWVIY"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3TWBOZD"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V31AT7O7"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V35RH8LX"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V36DUT07"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V36G5G79"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3OR7875"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3AUD9K9"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3TR74QG"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3EFQJG0"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V32U1G46"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V33SDYGF"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3LIJI18"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3K0AXYC"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3ELOS6Z"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3LE6KWH"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3EF0VOT"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3QTXHI1"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V35CQZCU"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3CTSUFL"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3SEHUDS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V33QSQCQ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V330O30U"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3BMC97C"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V37BO119"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3XP9N56"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NYXTXM"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3GTT0IA"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3AKYTT3"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3IMJ70E"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V33P15AH"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3DBVZB0"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3OIH5CS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3K30LVY"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3LKFXHK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3C856WP"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3R97Y2L"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3OFN1R4"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3KZ36U8"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3UEIHX7"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V34D0GJY"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3V5G10U"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3R5L8A7"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V38E9RIV"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3H6T1NT"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3MJSRD9"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3Q46NOU"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3HFJ7UP"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3FLN4RX"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3YJ38XR"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3G2GZR7"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3TXCB48"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3Y1O4IZ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3ASNWYW"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3RRATAT"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3J9A3Y3"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V36DDFGS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V33JONOU"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V39IY4X4"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V31DNTCA"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3GRP2U4"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3DTBH55"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3RBC76U"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3B7L8V1"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3ZOCFI4"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3O6L1F9"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V30S9BP4"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3M18O1B"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3J9RM7P"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3YXDW2Z"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3CFZW0L"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3DALMJE"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3GQTOAM"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3DVLNKN"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3D669UG"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3NEKRCP"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3PRCJIW"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3VHDK8L"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3W2LM34"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V39EL8HL"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V388KZRU"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3IN3OEU"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3VTYT8Q"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3ZPKY32"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3ORWIXZ"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V32C9ROS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V37YT2M6"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3TWD1XM"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3XB9YO1"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V38PAJSS"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3UUQO1V"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3SMADO8"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3E7FLQH"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3RRPZLK"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V33E4XYF"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V39IGFU8"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3IOGXPB"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3WHVNZH"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V313CD5G"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3LQJ5SX"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },
    ["V3VWVM4W"] = { name = "VIP3礼包", vipLevel = 3, diamonds = 1500, tickets = 5000 },

    -- ==================== 节日礼包CDK (2000门票 + 100W金币, 每码每人限用一次) ====================
    ["JR2XHDFA"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JR340HLK"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JR5JERM1"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRB366D6"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRB3IQ73"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRE1556H"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRE8C33A"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRHMDTLZ"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRHQ9CPA"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRINECAO"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRKO6O34"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRLUF0SW"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRPX0KZD"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRQ5YAJN"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRUSQWIA"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRVG1KD3"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRXT3NJH"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRYBSE9G"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRZQ2RBT"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
    ["JRZSRV5F"] = { name = "节日礼包", gold = 1000000, tickets = 2000 },
}
M.VIP1_CDK = "VIP1"
M.REVIEW_CDK = "REVIEW_USED"

return M
