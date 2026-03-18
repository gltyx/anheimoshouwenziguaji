-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 游戏系统模块
-- 战斗、装备、技能、宝石、黑市、孔位、自动分解
-- ============================================================================
local CFG = require("config")
local M = {}

---@diagnostic disable: undefined-global

-- ============================================================================
-- 加载管理员定制CDK (从 admin_cdks.json 合并到 CDK_REWARDS)
-- ============================================================================
local function loadAdminCDKs()
    local ADMIN_CDK_FILE = "admin_cdks.json"
    if not fileSystem:FileExists(ADMIN_CDK_FILE) then return end
    local file = File(ADMIN_CDK_FILE, FILE_READ)
    if not file:IsOpen() then return end
    local ok, data = pcall(cjson.decode, file:ReadString())
    file:Close()
    if not ok or type(data) ~= "table" then return end

    local count = 0
    for code, info in pairs(data) do
        if type(info) == "table" and not CFG.CDK_REWARDS[code] then
            local entry = { name = info.name or "管理员礼包", once = true }
            if info.type == "review" then
                entry.review = true
                entry.diamonds = info.diamonds or 500
            elseif info.vipLevel then
                entry.vipLevel = info.vipLevel
            elseif info.type == "festival" then
                entry.tickets = info.tickets or 1000
            end
            -- 通用字段透传
            if info.gold then entry.gold = info.gold end
            if info.diamonds and not entry.review then entry.diamonds = info.diamonds end
            if info.tickets and not entry.tickets then entry.tickets = info.tickets end
            CFG.CDK_REWARDS[code] = entry
            count = count + 1
        end
    end
    if count > 0 then
        print("[Admin CDK] 已加载 " .. count .. " 个管理员定制CDK")
    end
end
loadAdminCDKs()

-- ============================================================================
-- 玩家创建 (技能不再初始拥有)
-- ============================================================================
function M.createPlayer(classId)
    local cls = CFG.CLASSES[classId]
    -- 生成6位随机玩家ID
    local playerId = math.random(100000, 999999)
    local p = {
        classId = classId,
        className = cls.name,
        playerId = playerId,
        vipLevel = 0,
        usedCDKs = {},  -- 已使用的兑换码记录
        dailyTasks = nil, -- 每日任务数据 (首次登录时初始化)
        level = 1, exp = 0, expNext = 100,
        gold = 0,
        diamonds = 0,
        tickets = 0,
        hellTickets = 0,
        -- 基础属性
        baseHp = cls.baseHp, baseAtk = cls.baseAtk, baseDef = cls.baseDef,
        baseAspd = cls.baseAspd, baseCrit = cls.baseCrit, baseCritDmg = cls.baseCritDmg,
        -- 计算后总属性
        maxHp = cls.baseHp, hp = cls.baseHp,
        atk = cls.baseAtk, def = cls.baseDef,
        aspd = cls.baseAspd, crit = cls.baseCrit, critDmg = cls.baseCritDmg,
        antiCrit = 0, antiCritDmg = 0,
        lifesteal = 0, penetration = 0,
        expBonus = 0, goldBonus = 0,
        equipDropBonus = 0,
        -- 技能 (空，从黑市购买)
        skills = {},
        -- 装备栏 (6个槽位)
        equipment = {},
        -- 装备背包
        bag = {},
        -- 宝石背包
        gemBag = {},
        -- 碎片
        equipFragments = {},
        skillFragments = {},
        gemFragments = {},
        -- 保护卷
        protectionScrolls = 0,
        gemProtectionScrolls = 0,
        skillProtectionScrolls = 0,
        -- 爆率药水 (剩余秒数, 0=无效果)
        dropPotionTimer = 0,
        -- 经验药水 (剩余秒数, 0=无效果)
        expPotionTimer = 0,
        -- 攻击计时器
        atkTimer = 0,
        -- 击杀计数
        killCount = 0,
        -- 当前区域
        currentZone = 1,
        -- 被动收益计时
        passiveTimer = 0,
        -- 自动分解设置 (品质ID → true/false)
        autoDecompose = {
            equip = {},  -- { gray = true, green = true, ... }
            skill = {},
            gem   = {},
        },
        -- 称号系统
        titles = {},               -- { [titleId] = true } 已解锁的称号
        titleCounters = {          -- 称号进度计数器
            zone1Kills = 0,            -- 新手平原击杀数
            adventureBossKills = 0,    -- 奇遇BOSS击杀数
            enhanceConsecFails = 0,    -- 强化连续失败次数
            enhanceConsecSuccess = 0,  -- 单件装备连续成功次数(当前)
            enhanceConsecSuccessMax = 0, -- 单件装备连续成功最大记录
            eliteTicketsSpent = 0,     -- 累计消耗精英门票
            hellTicketsSpent = 0,      -- 累计消耗地狱门票
            weaponEnhanceMax = 0,      -- 单件武器最高强化等级
            zoneKills = {},            -- 各区域击杀数 { [zoneIdx] = count }
            zoneKillsMax = 0,          -- 单区域最高击杀数
        },
    }
    return p
end

-- ============================================================================
-- 属性重算 (基础 + 等级 + 装备 + 宝石)
-- ============================================================================
function M.recalcStats(player)
    local cls = CFG.CLASSES[player.classId]
    local lv = player.level - 1
    player.baseHp   = cls.baseHp + lv * cls.hpPerLv
    player.baseAtk  = cls.baseAtk + lv * cls.atkPerLv
    player.baseDef  = cls.baseDef + lv * cls.defPerLv
    player.baseAspd = cls.baseAspd
    player.baseCrit = cls.baseCrit
    player.baseCritDmg = cls.baseCritDmg

    local totalHp = player.baseHp
    local totalAtk = player.baseAtk
    local totalDef = player.baseDef
    local totalAspd = player.baseAspd
    local totalCrit = player.baseCrit
    local totalCritDmg = player.baseCritDmg
    local totalAntiCrit = 0
    local totalAntiCritDmg = 0
    local totalLifesteal = 0
    local totalPenetration = 0
    local totalExpBonus = 0
    local totalGoldBonus = 0

    for _, slot in ipairs(CFG.EQUIP_SLOTS) do
        local equip = player.equipment[slot.id]
        if equip then
            local enhMult = 1 + equip.enhance * 0.5
            -- 多属性基础值 (强化只影响基础属性)
            for _, bs in ipairs(equip.baseStats) do
                local val = math.floor(bs.value * enhMult)
                if bs.id == "hp"  then totalHp  = totalHp  + val end
                if bs.id == "atk" then totalAtk = totalAtk + val end
                if bs.id == "def" then totalDef = totalDef + val end
            end
            -- 装备词缀
            if equip.affixes then
                for _, af in ipairs(equip.affixes) do
                    if af.id == "aspd"        then
                        -- 神话(qualityIdx=11)及以下品质攻速词缀减半，至尊(12)不减
                        local aspdVal = af.value
                        if equip.qualityIdx <= 11 then aspdVal = aspdVal * 0.5 end
                        totalAspd = totalAspd + aspdVal / 100 * player.baseAspd
                    end
                    if af.id == "crit"        then totalCrit = totalCrit + af.value end
                    if af.id == "critDmg"     then totalCritDmg = totalCritDmg + af.value end
                    if af.id == "antiCrit"    then totalAntiCrit = totalAntiCrit + af.value end
                    if af.id == "antiCritDmg" then totalAntiCritDmg = totalAntiCritDmg + af.value end
                    if af.id == "lifesteal"   then totalLifesteal = totalLifesteal + af.value end
                    if af.id == "penetration" then totalPenetration = totalPenetration + af.value end
                    if af.id == "expBonus"    then totalExpBonus = totalExpBonus + af.value end
                    if af.id == "goldBonus"   then totalGoldBonus = totalGoldBonus + af.value end
                end
            end
            -- 装备上的宝石
            if equip.sockets then
                for _, gem in ipairs(equip.sockets) do
                    if gem then
                        local gemEnhMult = 1 + (gem.enhance or 0) * 0.1
                        for _, ga in ipairs(gem.affixes) do
                            local gv = ga.value * gemEnhMult
                            if ga.id == "atk"        then totalAtk = totalAtk + gv end
                            if ga.id == "hp"         then totalHp = totalHp + gv end
                            if ga.id == "def"        then totalDef = totalDef + gv end
                            if ga.id == "crit"       then totalCrit = totalCrit + gv end
                            if ga.id == "critDmg"    then totalCritDmg = totalCritDmg + gv end
                            if ga.id == "antiCrit"   then totalAntiCrit = totalAntiCrit + gv end
                            if ga.id == "antiCritDmg"then totalAntiCritDmg = totalAntiCritDmg + gv end
                        end
                    end
                end
            end
        end
    end

    -- VIP加成 (爆率、金币、经验)
    local vipBonus = CFG.VIP_BONUSES[player.vipLevel or 0] or CFG.VIP_BONUSES[0]
    local totalEquipDropBonus = vipBonus.equipDropBonus
    totalGoldBonus = totalGoldBonus + vipBonus.goldBonus
    totalExpBonus = totalExpBonus + (vipBonus.expBonus or 0)

    -- 称号被动加成
    if player.titles then
        for _, titleDef in ipairs(CFG.TITLES) do
            if player.titles[titleDef.id] then
                local b = titleDef.bonuses
                if b.atk then totalAtk = totalAtk + b.atk end
                if b.hp then totalHp = totalHp + b.hp end
                if b.def then totalDef = totalDef + b.def end
                if b.crit then totalCrit = totalCrit + b.crit end
                if b.equipDropBonus then totalEquipDropBonus = totalEquipDropBonus + b.equipDropBonus end
            end
        end
    end

    -- 属性上限 (各职业攻速上限不同)
    local aspdCap = CFG.CLASS_MAX_ASPD[player.classId] or 2.5
    totalAspd = math.min(totalAspd, aspdCap)
    local bonusCap = 200 + (vipBonus.expBonus or 0)
    totalExpBonus = math.min(totalExpBonus, bonusCap)
    local goldCap = 200 + (vipBonus.goldBonus or 0)
    totalGoldBonus = math.min(totalGoldBonus, goldCap)

    local oldMaxHp = player.maxHp
    player.maxHp = totalHp
    player.atk = totalAtk
    player.def = totalDef
    player.aspd = totalAspd
    player.crit = totalCrit
    player.critDmg = totalCritDmg
    player.antiCrit = totalAntiCrit
    player.antiCritDmg = totalAntiCritDmg
    player.lifesteal = totalLifesteal
    player.penetration = totalPenetration
    player.expBonus = totalExpBonus
    player.goldBonus = totalGoldBonus
    player.equipDropBonus = totalEquipDropBonus
    if oldMaxHp > 0 then
        player.hp = math.floor(player.hp * player.maxHp / oldMaxHp)
    end
    player.hp = math.min(player.hp, player.maxHp)
end

-- ============================================================================
-- 升级检测
-- ============================================================================
function M.checkLevelUp(player)
    local leveled = false
    while player.exp >= player.expNext do
        player.exp = player.exp - player.expNext
        player.level = player.level + 1
        local mult
        if player.level <= 40 then
            -- 1-40级: 温和增长
            mult = 1.18
        elseif player.level == 41 then
            -- 41级: 跳涨100倍作为门槛，但经验减半
            mult = 1.18 * 100 * 0.5
        elseif player.level == 42 then
            -- 42级: 一次性经验减半 + 1.05倍增长
            mult = 1.05 * 0.5
        else
            -- 43级+: 恒定1.05倍平稳增长
            mult = 1.05
        end
        player.expNext = math.floor(player.expNext * mult)
        leveled = true
    end
    if leveled then
        M.recalcStats(player)
        player.hp = player.maxHp
    end
    return leveled
end

-- ============================================================================
-- 伤害计算
-- ============================================================================
function M.calcDamage(atkStats, defStats, skillMult)
    local rawAtk = atkStats.atk
    if skillMult then
        rawAtk = rawAtk * skillMult / 100
    end
    local pen = atkStats.penetration or 0
    local penForDef = math.min(pen, 100)
    local penBonusDmg = 0
    if pen > 100 then
        penBonusDmg = math.min(pen - 100, 200) / 100
    end
    local effDef = defStats.def * (1 - penForDef / 100)
    effDef = math.max(0, effDef)
    local dmg = math.max(1, math.floor(rawAtk - effDef * 0.6))
    if penBonusDmg > 0 then
        dmg = math.floor(dmg * (1 + penBonusDmg))
    end
    local isCrit = false
    local critChance = (atkStats.crit or 0) - (defStats.antiCrit or 0)
    if critChance > 0 and math.random(1, 1000) <= critChance * 10 then
        isCrit = true
        local critMult = ((atkStats.critDmg or 200) - (defStats.antiCritDmg or 0)) / 100
        critMult = math.max(1.2, critMult)
        dmg = math.floor(dmg * critMult)
    end
    
    -- 直接限制技能伤害：技能伤害不能超过基础攻击力的100倍
    if skillMult then
        local maxSkillDmg = atkStats.atk * 100
        dmg = math.min(dmg, maxSkillDmg)
    end
    
    return dmg, isCrit
end

-- ============================================================================
-- 技能实际伤害倍率 (品质+强化)
-- ============================================================================
function M.getSkillMult(skill)
    local qualityData = CFG.SKILL_QUALITIES[skill.quality]
    local baseMult = skill.mult * qualityData.mult
    local enhMult = 1 + skill.enhance * 0.10
    return math.floor(baseMult * enhMult)
end

-- ============================================================================
-- 怪物生成
-- ============================================================================
function M.generateMob(zoneIdx)
    local zone = CFG.ZONES[zoneIdx]
    local stats = CFG.getMobStats(zoneIdx)
    local mobName = zone.mobs[math.random(1, #zone.mobs)]
    local mobIcon = CFG.MOB_ICONS[mobName] or "❓"
    return {
        name = mobName,
        icon = mobIcon,
        hp = stats.hp, maxHp = stats.hp,
        atk = stats.atk, def = stats.def,
        exp = stats.exp, gold = stats.gold,
        isElite = false, eliteType = nil,
        antiCrit = 0, antiCritDmg = 0,
        penetration = 0, crit = 0, critDmg = 150,
    }
end

--- 生成奇遇BOSS (固定属性, 被攻击固定受伤1点)
function M.generateAdventureBoss()
    local cfg = CFG.ADVENTURE_BOSS
    return {
        name = "✨ 奇遇BOSS ✨",
        icon = "✨",
        hp = cfg.hp, maxHp = cfg.hp,
        atk = cfg.atk, def = cfg.def,
        exp = 0, gold = 0,
        isElite = false, eliteType = nil,
        isAdventureBoss = true,
        antiCrit = 0, antiCritDmg = 0,
        penetration = 0, crit = 0, critDmg = 0,
    }
end

--- 检查是否触发奇遇BOSS
---@param vipLevel number
---@return boolean
function M.checkAdventureBossSpawn(vipLevel)
    local rate = CFG.ADVENTURE_BOSS.spawnRate[vipLevel] or CFG.ADVENTURE_BOSS.spawnRate[0]
    return math.random() < rate
end

-- ============================================================================
-- 地狱副本怪物生成 (基于同区域精英, 属性翻倍)
-- ============================================================================
function M.generateHellMob(zoneIdx, eliteType)
    -- 基于同区域精英怪生成, 难度为精英的2倍
    local elite = M.generateElite(zoneIdx, eliteType)
    -- 地狱难度: HP/攻/防翻倍, 暴击属性×1.5
    elite.hp = elite.hp * 2
    elite.maxHp = elite.maxHp * 2
    elite.atk = elite.atk * 2
    elite.def = elite.def * 2
    elite.crit = elite.crit * 1.5
    elite.critDmg = elite.critDmg * 1.5
    elite.isHell = true
    -- 修改名称显示
    local zone = CFG.ZONES[zoneIdx]
    local hellName = zone and zone.elite or "精英"
    elite.name = "🔥地狱 " .. hellName
    elite.icon = CFG.MOB_ICONS[zone and zone.elite] or "👹"
    return elite
end

function M.generateElite(zoneIdx, eliteType)
    local zone = CFG.ZONES[zoneIdx]
    local stats = CFG.getMobStats(zoneIdx)
    local et = CFG.ELITE_TYPES[eliteType]
    local reqLv = zone and zone.reqLv or (zoneIdx * 5)

    -- 精英类型倍率: gold > silver > normal
    local typeCritBonus = ({normal = 1.0, silver = 1.5, gold = 2.0})[eliteType] or 1.0

    -- 30级以后(zoneIdx>=7)精英难度大幅增加
    local eliteScaleFactor = 1.0
    if reqLv >= 30 then
        -- zone7(Lv30)开始,每5级难度翻1.5倍
        local tiers = math.floor((reqLv - 30) / 5)
        eliteScaleFactor = 1.5 ^ (tiers + 1) -- Lv30=1.5x, Lv35=2.25x, Lv40=3.375x ...
    end

    -- 高额暴击率: 基础20% + 区域递增 + 精英类型加成
    local baseCrit = 20 + zoneIdx * 2.5
    local crit = baseCrit * typeCritBonus

    -- 巨量暴击伤害: 基础250% + 区域递增 + 精英类型加成
    local baseCritDmg = 250 + zoneIdx * 15
    local critDmg = baseCritDmg * typeCritBonus

    local eliteIcon = CFG.MOB_ICONS[zone.elite] or "👹"
    return {
        name = et.name .. " " .. zone.elite,
        icon = eliteIcon,
        hp = math.floor(stats.hp * et.hpM * eliteScaleFactor),
        maxHp = math.floor(stats.hp * et.hpM * eliteScaleFactor),
        atk = math.floor(stats.atk * et.atkM * eliteScaleFactor),
        def = math.floor(stats.def * et.defM * eliteScaleFactor),
        exp = stats.exp * et.dropM, gold = stats.gold * et.dropM,
        isElite = true, eliteType = eliteType,
        antiCrit = crit,       -- 抗暴击 = 暴击值
        antiCritDmg = zoneIdx * 2.0 * typeCritBonus,
        penetration = zoneIdx * 0.8 * typeCritBonus,
        crit = crit,
        critDmg = critDmg,
        -- 技能计时器 (精英怪物技能)
        skillTimer = 0,
    }
end

-- ============================================================================
-- 装备生成 (含孔位)
-- ============================================================================
function M.generateEquip(zoneIdx, qualityIdx, slotId, playerLevel, hellLevel)
    local quality = CFG.EQUIP_QUALITIES[qualityIdx]
    local slotData = nil
    for _, s in ipairs(CFG.EQUIP_SLOTS) do
        if s.id == slotId then slotData = s break end
    end
    if not slotData then
        slotData = CFG.EQUIP_SLOTS[math.random(1, #CFG.EQUIP_SLOTS)]
    end

    -- 装备等级
    local zone = CFG.ZONES[zoneIdx]
    local baseReqLv, maxDropLv
    if hellLevel then
        -- 地狱副本: 副本等级 ±5
        baseReqLv = math.max(1, hellLevel - 5)
        maxDropLv = hellLevel + 5
    else
        -- 普通/精英: 区域reqLv ~ reqLv+4
        baseReqLv = zone and zone.reqLv or 1
        maxDropLv = baseReqLv + 4
    end
    -- 上限玩家等级
    if playerLevel then
        maxDropLv = math.min(maxDropLv, playerLevel)
    end
    -- 确保 baseReqLv 不超过 maxDropLv
    baseReqLv = math.min(baseReqLv, maxDropLv)
    local equipLevel = math.max(baseReqLv, math.random(baseReqLv, maxDropLv))

    local baseInfo = CFG.EQUIP_BASE_STATS[slotData.id]
    local qMult = CFG.QUALITY_STAT_MULT[quality.id]

    -- 多属性基础值生成 (使用equipLevel代替zoneIdx计算)
    -- 将equipLevel映射到等效zoneIdx用于公式: (equipLevel - 1) / 5 ≈ zoneIdx
    local effectiveZoneIdx = math.max(1, (equipLevel - 1) / 5)
    local baseStats = {}
    for _, statDef in ipairs(baseInfo.stats) do
        local rawValue = (statDef.base + effectiveZoneIdx * statDef.perZone) * qMult
        rawValue = rawValue * (0.9 + math.random() * 0.2)
        rawValue = math.floor(rawValue)
        baseStats[#baseStats + 1] = { id = statDef.id, value = rawValue }
    end

    -- 孔位判定
    local naturalSockets = 1  -- 100%至少1孔
    local r = math.random()
    if r < CFG.SOCKET_PROBS[4] then
        naturalSockets = 4
    elseif r < CFG.SOCKET_PROBS[4] + CFG.SOCKET_PROBS[3] then
        naturalSockets = 3
    elseif r < CFG.SOCKET_PROBS[4] + CFG.SOCKET_PROBS[3] + CFG.SOCKET_PROBS[2] then
        naturalSockets = 2
    end

    -- 装备名称生成: 所有装备显示等级, 黄金以上品质使用帅气名
    local equipName
    local prefixes = CFG.EQUIP_EPIC_PREFIXES[quality.id]
    local suffixes = CFG.EQUIP_EPIC_SUFFIXES[slotData.id]
    if prefixes and suffixes then
        local prefix = prefixes[math.random(1, #prefixes)]
        local suffix = suffixes[math.random(1, #suffixes)]
        equipName = "[" .. quality.name .. "]Lv" .. equipLevel .. " " .. prefix .. suffix
    else
        equipName = "[" .. quality.name .. "]Lv" .. equipLevel .. slotData.name
    end

    local equip = {
        name = equipName,
        slot = slotData.id,
        qualityId = quality.id,
        qualityIdx = qualityIdx,
        reqLv = equipLevel,
        baseStats = baseStats,
        enhance = 0,
        affixes = {},
        -- 孔位
        sockets = {},          -- 已镶嵌的宝石 (nil=空孔)
        naturalSockets = naturalSockets,  -- 天生孔数
        maxSockets = naturalSockets,      -- 当前总孔数(含开孔)
        locked = false,
    }
    -- 初始化空孔
    for i = 1, naturalSockets do
        equip.sockets[i] = nil
    end

    -- 词缀生成
    if quality.affixCount > 0 and CFG.AFFIX_RANGES[quality.id] then
        local ranges = CFG.AFFIX_RANGES[quality.id]
        local availableTypes = {}
        for _, at in ipairs(CFG.AFFIX_TYPES) do
            if ranges[at.id] then
                availableTypes[#availableTypes + 1] = at.id
            end
        end
        local chosen = {}
        local count = math.min(quality.affixCount, #availableTypes)
        while #chosen < count do
            local idx = math.random(1, #availableTypes)
            local aid = availableTypes[idx]
            local found = false
            for _, c in ipairs(chosen) do if c == aid then found = true break end end
            if not found then
                chosen[#chosen + 1] = aid
            end
        end
        for _, aid in ipairs(chosen) do
            local rng = ranges[aid]
            local val = rng[1] + math.random() * (rng[2] - rng[1])
            val = math.floor(val * 100) / 100
            equip.affixes[#equip.affixes + 1] = { id = aid, value = val }
        end
    end

    return equip
end

-- ============================================================================
-- 宝石生成
-- ============================================================================
function M.generateGem(qualityIdx)
    local gq = CFG.GEM_QUALITIES[qualityIdx]
    local ranges = CFG.GEM_AFFIX_RANGES[gq.id]

    -- 从7种词缀中随机选3种
    local available = {}
    for _, ga in ipairs(CFG.GEM_AFFIX_TYPES) do
        available[#available + 1] = ga.id
    end
    local chosen = {}
    while #chosen < 3 and #available > 0 do
        local idx = math.random(1, #available)
        chosen[#chosen + 1] = available[idx]
        table.remove(available, idx)
    end

    local affixes = {}
    for _, aid in ipairs(chosen) do
        local rng = ranges[aid]
        local val = rng[1] + math.random() * (rng[2] - rng[1])
        -- 整数类属性取整, 百分比类保留一位
        if aid == "atk" or aid == "hp" or aid == "def" then
            val = math.floor(val)
        else
            val = math.floor(val * 10) / 10
        end
        affixes[#affixes + 1] = { id = aid, value = val }
    end

    return {
        name = "[" .. gq.name .. "]宝石",
        qualityId = gq.id,
        qualityIdx = qualityIdx,
        affixes = affixes,
        enhance = 0,
        locked = false,
    }
end

-- ============================================================================
-- 掉落判定 (区域怪: 装备+门票+钻石+宝石; 精英: 装备+宝石+技能)
-- ============================================================================
function M.rollLoot(zoneIdx, isElite, eliteType, player, isHell)
    local drops = { equips = {}, gems = {}, skills = {} }
    local bonus = 1 + (player.equipDropBonus or 0) / 100
    -- 爆率药水加成 (+30%)
    if (player.dropPotionTimer or 0) > 0 then
        bonus = bonus + 0.3
    end

    -- 地狱副本等级 (用于装备等级范围计算)
    local hellLevel = isHell and CFG.getHellReqLevel(zoneIdx) or nil

    if isElite then
        -- 选择掉率表: 地狱用3倍表, 普通精英用标准表
        local equipDropTable = isHell and CFG.HELL_EQUIP_DROP or CFG.ELITE_EQUIP_DROP
        local gemDropTable = isHell and CFG.HELL_GEM_DROP or CFG.ELITE_GEM_DROP
        local skillDropTable = isHell and CFG.HELL_SKILL_DROP or CFG.ELITE_SKILL_DROP

        -- 精英/地狱副本装备掉落 (按配置概率 * 爆率加成)
        for qId, prob in pairs(equipDropTable) do
            if math.random() < prob * bonus then
                local qi = CFG.QUALITY_INDEX[qId]
                if qi then
                    local slot = CFG.EQUIP_SLOTS[math.random(1, #CFG.EQUIP_SLOTS)]
                    drops.equips[#drops.equips + 1] = M.generateEquip(zoneIdx, qi, slot.id, player.level, hellLevel)
                end
            end
        end
        -- 精英/地狱副本宝石掉落 (爆率加成, 受上限限制)
        if #player.gemBag < CFG.MAX_GEMS then
            for qId, prob in pairs(gemDropTable) do
                if math.random() < prob * bonus then
                    local qi = nil
                    for i, gq in ipairs(CFG.GEM_QUALITIES) do
                        if gq.id == qId then qi = i break end
                    end
                    if qi then
                        drops.gems[#drops.gems + 1] = M.generateGem(qi)
                    end
                end
            end
        end
        -- 精英/地狱副本技能掉落 (爆率加成, 受上限限制)
        if #player.skills < CFG.MAX_SKILLS then
            for qId, prob in pairs(skillDropTable) do
                if math.random() < prob * bonus then
                    local qi = nil
                    for i, sq in ipairs(CFG.SKILL_QUALITIES) do
                        if sq.id == qId then qi = i break end
                    end
                    if qi then
                        drops.skills[#drops.skills + 1] = M.generateSkill(player.classId, qi)
                    end
                end
            end
        end
    else
        -- 区域怪物装备掉落 (最高铂金)
        local maxQualIdx = 8 -- 普通怪最高铂金(8)
        for qi = maxQualIdx, 1, -1 do
            local q = CFG.EQUIP_QUALITIES[qi]
            local rate = q.dropRate * bonus
            -- 紫(4)、橙(5)品质爆率降低一倍(减半)，红(6)再额外降低10倍
            if qi >= 4 and qi <= 6 then rate = rate * 0.5 end
            if qi == 6 then rate = rate * 0.1 end
            -- 黄金(7): 红装实际爆率的15%, 铂金(8): 红装实际爆率的10%
            -- 红装实际爆率 = 0.005 * 0.5 * 0.1 = 0.00025
            if qi == 7 then rate = 0.00025 * 0.15 * bonus end
            if qi == 8 then rate = 0.00025 * 0.10 * bonus end
            if math.random() < rate then
                local slot = CFG.EQUIP_SLOTS[math.random(1, #CFG.EQUIP_SLOTS)]
                drops.equips[#drops.equips + 1] = M.generateEquip(zoneIdx, qi, slot.id, player.level)
                break
            end
        end
        -- 区域宝石掉落 (只有灰色和绿色, 受上限限制, 受爆率加成)
        if #player.gemBag < CFG.MAX_GEMS then
            if math.random() < CFG.ZONE_GEM_DROP.gray * bonus then
                drops.gems[#drops.gems + 1] = M.generateGem(1) -- 灰
            end
            if math.random() < CFG.ZONE_GEM_DROP.green * bonus then
                drops.gems[#drops.gems + 1] = M.generateGem(2) -- 绿
            end
        end
    end

    -- 门票掉落 (区域和精英都可以, 受爆率加成)
    if math.random() < CFG.TICKET_DROP_RATE * bonus then
        drops.ticketDrop = 1
    end
    -- 钻石掉落 (精英副本精英怪20%基础掉率*爆率加成, 地狱/普通怪原逻辑)
    local diamondRate
    if isElite and not isHell then
        diamondRate = 0.20 * bonus
    else
        diamondRate = CFG.DIAMOND_DROP_RATE * bonus * (isHell and 100 or 1)
    end
    if math.random() < diamondRate then
        drops.diamondDrop = 1
    end

    return drops
end

-- ============================================================================
-- 技能生成 (黑市购买或掉落, 50%概率出通用技能)
-- ============================================================================
function M.generateSkill(classId, qualityIdx)
    local pool
    -- 50%概率从通用技能池抽取
    if math.random() < 0.5 then
        pool = CFG.UNIVERSAL_SKILL_POOL
    else
        pool = CFG.SKILL_POOL[classId]
    end
    local template = pool[math.random(1, #pool)]
    -- 判断技能归属: 从通用池抽取则标记 "universal"，否则标记职业classId
    local skillClassId = (pool == CFG.UNIVERSAL_SKILL_POOL) and "universal" or classId
    return {
        name = template.name,
        cd = template.cd,
        mult = template.mult,
        desc = template.desc,
        quality = qualityIdx,
        enhance = 0,
        cdTimer = 0,
        locked = false,
        classId = skillClassId,  -- 技能归属职业 ("universal"=通用)
    }
end

-- ============================================================================
-- 黑市购买
-- ============================================================================
function M.buySkill(player)
    if #player.skills >= CFG.MAX_SKILLS then
        return nil, "技能书已满(" .. CFG.MAX_SKILLS .. "个上限)"
    end
    local price = CFG.BLACK_MARKET.skillPrice
    if player.gold < price then
        return nil, "金币不足(需要" .. M.formatGold(price) .. ")"
    end
    player.gold = player.gold - price
    -- 按真实概率抽取品质
    local qi = M.rollQuality(CFG.BLACK_MARKET.qualityProbs)
    local skill = M.generateSkill(player.classId, qi)
    -- 检查自动分解
    local qId = CFG.SKILL_QUALITIES[qi].id
    if M.shouldAutoDecompose(player, "skill", qId, skill) then
        local count = 1 + skill.enhance
        local cur = player.skillFragments[qId] or 0
        local actual = math.min(count, CFG.MAX_FRAGMENTS - cur)
        if actual > 0 then
            player.skillFragments[qId] = cur + actual
        end
        return skill, "自动分解: " .. skill.name .. " (获得" .. actual .. "碎片)"
    end
    -- 自动装备（不超过4个, 且无同名已装备技能）
    local hasNameConflict = false
    for _, sk in ipairs(player.skills) do
        if sk.equipped and sk.name == skill.name then
            hasNameConflict = true
            break
        end
    end
    if not hasNameConflict and M.getEquippedCount(player) < M.MAX_EQUIPPED_SKILLS then
        skill.equipped = true
        skill.cdTimer = 0
    else
        skill.equipped = false
    end
    player.skills[#player.skills + 1] = skill
    return skill, nil
end

function M.buyGem(player)
    if #player.gemBag >= CFG.MAX_GEMS then
        return nil, "宝石已满(" .. CFG.MAX_GEMS .. "个上限)"
    end
    local price = CFG.BLACK_MARKET.gemPrice
    if player.gold < price then
        return nil, "金币不足(需要" .. M.formatGold(price) .. ")"
    end
    player.gold = player.gold - price
    local qi = M.rollQuality(CFG.BLACK_MARKET.qualityProbs)
    local gem = M.generateGem(qi)
    -- 检查自动分解
    local qId = CFG.GEM_QUALITIES[qi].id
    if M.shouldAutoDecompose(player, "gem", qId, gem) then
        local count, qualId = M.decomposeGem(gem, player)
        local qualName = ""
        for _, gq in ipairs(CFG.GEM_QUALITIES) do
            if gq.id == qualId then qualName = gq.name break end
        end
        return gem, "自动分解: " .. gem.name .. " (获得" .. qualName .. "碎片 x" .. count .. ")"
    end
    player.gemBag[#player.gemBag + 1] = gem
    return gem, nil
end

-- 按概率表抽品质 (返回1-5的索引)
function M.rollQuality(probs)
    local r = math.random()
    local acc = 0
    for i, p in ipairs(probs) do
        acc = acc + p
        if r <= acc then return i end
    end
    return 1
end

-- ============================================================================
-- 孔位操作
-- ============================================================================
-- 开孔 (给装备增加一个孔)
function M.addSocket(equip, player)
    local isNatural4 = (equip.naturalSockets >= 4)
    local maxS = isNatural4 and CFG.MAX_SOCKETS_NATURAL4 or CFG.MAX_SOCKETS_NORMAL
    if equip.maxSockets >= maxS then
        return false, "已达最大孔数"
    end

    local cfg
    if isNatural4 and equip.maxSockets == 4 then
        cfg = CFG.SOCKET_UPGRADE.fifth
    else
        cfg = CFG.SOCKET_UPGRADE.normal
    end

    if player.diamonds < cfg.cost then
        return false, "钻石不足(需要" .. cfg.cost .. ")"
    end

    player.diamonds = player.diamonds - cfg.cost

    if math.random() <= cfg.rate then
        equip.maxSockets = equip.maxSockets + 1
        equip.sockets[equip.maxSockets] = nil -- 新空孔
        M.recalcStats(player)
        return true, "开孔成功! 当前" .. equip.maxSockets .. "孔"
    else
        return false, "开孔失败! 钻石已消耗"
    end
end

-- 镶嵌宝石
function M.socketGem(equip, socketIdx, gem, player)
    if socketIdx < 1 or socketIdx > equip.maxSockets then
        return false, "无效孔位"
    end
    if equip.sockets[socketIdx] then
        return false, "该孔已有宝石，请先拆卸"
    end
    equip.sockets[socketIdx] = gem
    M.recalcStats(player)
    return true, "镶嵌成功"
end

-- 拆卸宝石 (返回宝石到背包)
function M.unsocketGem(equip, socketIdx, player)
    if socketIdx < 1 or socketIdx > equip.maxSockets then
        return false, "无效孔位"
    end
    local gem = equip.sockets[socketIdx]
    if not gem then
        return false, "该孔没有宝石"
    end
    equip.sockets[socketIdx] = nil
    player.gemBag[#player.gemBag + 1] = gem
    M.recalcStats(player)
    return true, "拆卸成功"
end

-- ============================================================================
-- 装备强化 (失败装备消失!)
-- ============================================================================
-- 获取强化消耗
function M.getEnhanceCost(equip)
    local level = equip.enhance + 1
    if level > 15 then return nil end
    local goldCost = level * CFG.ENHANCE_GOLD_BASE * equip.qualityIdx
    local fragCost = level
    local fragId = equip.qualityId
    local qualityName = CFG.EQUIP_QUALITIES[equip.qualityIdx].name
    return {
        gold = goldCost,
        fragCost = fragCost,
        fragId = fragId,
        qualityName = qualityName,
        rate = CFG.ENHANCE_RATES[level] or 5,
        level = level,
    }
end

function M.enhanceEquip(equip, player)
    local level = equip.enhance + 1
    if level > 15 then return false, "已达最大强化等级", false end
    local fragId = equip.qualityId
    local fragCount = player.equipFragments[fragId] or 0
    local fragCost = level
    local goldCost = level * CFG.ENHANCE_GOLD_BASE * equip.qualityIdx
    if player.gold < goldCost then
        return false, "金币不足(需要" .. goldCost .. "金币)", false
    end
    if fragCount < fragCost then
        return false, "碎片不足(需要" .. fragCost .. "个" .. CFG.EQUIP_QUALITIES[equip.qualityIdx].name .. "碎片)", false
    end
    player.gold = player.gold - goldCost
    player.equipFragments[fragId] = fragCount - fragCost
    local rate = CFG.ENHANCE_RATES[level] or 5

    -- 称号强化概率加成 (非酋/天选之人各+2%)
    local enhanceBonus = M.getTitleEnhanceBonus(player)
    rate = rate + enhanceBonus

    local hasProtection = (player.protectionScrolls or 0) > 0
    if hasProtection then
        player.protectionScrolls = player.protectionScrolls - 1
    end
    if math.random(1, 100) <= rate then
        equip.enhance = level
        M.recalcStats(player)
        local protMsg = hasProtection and " (已使用保护卷)" or ""
        -- 称号计数: 连续成功+1, 重置连续失败
        local tc = player.titleCounters
        if tc then
            tc.enhanceConsecFails = 0
            tc.enhanceConsecSuccess = (tc.enhanceConsecSuccess or 0) + 1
            if tc.enhanceConsecSuccess > (tc.enhanceConsecSuccessMax or 0) then
                tc.enhanceConsecSuccessMax = tc.enhanceConsecSuccess
            end
            M.checkTitles(player, "enhance_consec_success")
            -- 追踪武器最高强化等级 (锻造之神称号)
            if equip.slot == "weapon" and level > (tc.weaponEnhanceMax or 0) then
                tc.weaponEnhanceMax = level
                M.checkTitles(player, "weapon_enhance_max")
            end
        end
        return true, "强化成功! +" .. level .. " (成功率" .. rate .. "%)" .. protMsg, false
    else
        -- 称号计数: 连续失败+1, 重置连续成功
        local tc = player.titleCounters
        if tc then
            tc.enhanceConsecFails = (tc.enhanceConsecFails or 0) + 1
            tc.enhanceConsecSuccess = 0
            M.checkTitles(player, "enhance_consec_fails")
        end
        if hasProtection then
            -- 有保护卷: 等级-1而不是销毁
            equip.enhance = math.max(0, equip.enhance - 1)
            M.recalcStats(player)
            return false, "强化失败! 保护卷生效, 等级降为+" .. equip.enhance .. " (成功率" .. rate .. "%)", false
        else
            return nil, "强化失败! 装备消失! (成功率" .. rate .. "%)", true
        end
    end
end

-- ============================================================================
-- 装备分解
-- ============================================================================
function M.decomposeEquip(equip, player)
    -- 先拆卸所有宝石到背包
    if equip.sockets then
        for i = 1, equip.maxSockets do
            if equip.sockets[i] then
                player.gemBag[#player.gemBag + 1] = equip.sockets[i]
                equip.sockets[i] = nil
            end
        end
    end
    local fragId = equip.qualityId
    local count = 1 + equip.enhance
    local cur = player.equipFragments[fragId] or 0
    local actual = math.min(count, CFG.MAX_FRAGMENTS - cur)
    if actual > 0 then
        player.equipFragments[fragId] = cur + actual
    end
    return count, fragId
end

-- ============================================================================
-- 技能强化 (失败技能消失!)
-- ============================================================================
function M.enhanceSkill(skill, player)
    local level = skill.enhance + 1
    if level > 15 then return false, "已达最大强化等级" end
    local qualId = CFG.SKILL_QUALITIES[skill.quality].id
    local fragCount = player.skillFragments[qualId] or 0
    local cost = level
    if fragCount < cost then
        return false, "碎片不足(需要" .. cost .. "个" .. CFG.SKILL_QUALITIES[skill.quality].name .. "碎片)"
    end
    player.skillFragments[qualId] = fragCount - cost
    local rate = CFG.ENHANCE_RATES[level] or 5
    local hasProtection = (player.skillProtectionScrolls or 0) > 0
    if hasProtection then
        player.skillProtectionScrolls = player.skillProtectionScrolls - 1
    end
    if math.random(1, 100) <= rate then
        skill.enhance = level
        local protMsg = hasProtection and " (已使用保护卷)" or ""
        return true, "强化成功! +" .. level .. " (成功率" .. rate .. "%)" .. protMsg
    else
        if hasProtection then
            skill.enhance = math.max(0, skill.enhance - 1)
            return false, "强化失败! 保护卷生效, 等级降为+" .. skill.enhance .. " (成功率" .. rate .. "%)"
        else
            return nil, "强化失败! 技能消失! (成功率" .. rate .. "%)"
        end
    end
end

-- ============================================================================
-- 技能分解
-- ============================================================================
M.MAX_EQUIPPED_SKILLS = 4

--- 获取已装备技能数量
function M.getEquippedCount(player)
    local count = 0
    for _, sk in ipairs(player.skills) do
        if sk.equipped then count = count + 1 end
    end
    return count
end

--- 装备技能 (未装备→装备, 需有空位, 不能装备同名技能)
function M.equipSkill(player, skillIdx)
    local skill = player.skills[skillIdx]
    if not skill then return false, "技能不存在" end
    if skill.equipped then return false, "已装备" end
    -- 同名技能检查: 不能同时装备同名技能
    for _, sk in ipairs(player.skills) do
        if sk.equipped and sk.name == skill.name then
            return false, "已装备同名技能[" .. skill.name .. "]，请使用替换功能"
        end
    end
    if M.getEquippedCount(player) >= M.MAX_EQUIPPED_SKILLS then
        return false, "已装备4个技能，请先替换"
    end
    skill.equipped = true
    skill.cdTimer = 0
    return true, "装备成功: " .. skill.name
end

--- 卸下技能 (装备→未装备)
function M.unequipSkill(player, skillIdx)
    local skill = player.skills[skillIdx]
    if not skill then return false, "技能不存在" end
    if not skill.equipped then return false, "未装备" end
    skill.equipped = false
    return true, "卸下成功: " .. skill.name
end

--- 替换技能 (用未装备技能替换已装备技能, 允许同名不同品质替换)
function M.swapSkill(player, equippedIdx, unequippedIdx)
    local eqSkill = player.skills[equippedIdx]
    local ueqSkill = player.skills[unequippedIdx]
    if not eqSkill or not ueqSkill then return false, "技能不存在" end
    if not eqSkill.equipped then return false, "目标不是已装备技能" end
    if ueqSkill.equipped then return false, "替换源已是装备状态" end
    -- 同名检查: 新技能不能与其他已装备技能(被替换的那个除外)同名
    for i, sk in ipairs(player.skills) do
        if sk.equipped and i ~= equippedIdx and sk.name == ueqSkill.name then
            return false, "已装备同名技能[" .. ueqSkill.name .. "]，无法替换"
        end
    end
    eqSkill.equipped = false
    ueqSkill.equipped = true
    ueqSkill.cdTimer = 0
    return true, "替换成功: " .. ueqSkill.name .. " ↔ " .. eqSkill.name
end

function M.decomposeSkill(skill, player)
    local qualId = CFG.SKILL_QUALITIES[skill.quality].id
    local count = 1 + skill.enhance
    local cur = player.skillFragments[qualId] or 0
    local actual = math.min(count, CFG.MAX_FRAGMENTS - cur)
    if actual > 0 then
        player.skillFragments[qualId] = cur + actual
    end
    return count, qualId
end

-- ============================================================================
-- 宝石强化 (失败宝石消失! 每级+10%属性)
-- ============================================================================
function M.enhanceGem(gem, player)
    local level = gem.enhance + 1
    if level > 15 then return false, "已达最大强化等级" end
    local qualId = gem.qualityId
    local fragCount = player.gemFragments[qualId] or 0
    local cost = level
    if fragCount < cost then
        local qualName = ""
        for _, gq in ipairs(CFG.GEM_QUALITIES) do
            if gq.id == qualId then qualName = gq.name break end
        end
        return false, "碎片不足(需要" .. cost .. "个" .. qualName .. "碎片)"
    end
    player.gemFragments[qualId] = fragCount - cost
    local rate = CFG.ENHANCE_RATES[level] or 5
    local hasProtection = (player.gemProtectionScrolls or 0) > 0
    if hasProtection then
        player.gemProtectionScrolls = player.gemProtectionScrolls - 1
    end
    if math.random(1, 100) <= rate then
        gem.enhance = level
        local protMsg = hasProtection and " (已使用保护卷)" or ""
        return true, "强化成功! +" .. level .. " (成功率" .. rate .. "%)" .. protMsg
    else
        if hasProtection then
            gem.enhance = math.max(0, gem.enhance - 1)
            return false, "强化失败! 保护卷生效, 等级降为+" .. gem.enhance .. " (成功率" .. rate .. "%)"
        else
            return nil, "强化失败! 宝石消失! (成功率" .. rate .. "%)"
        end
    end
end

-- ============================================================================
-- 宝石分解 (产出碎片, 数量 = 1 + 强化等级)
-- ============================================================================
function M.decomposeGem(gem, player)
    local qualId = gem.qualityId
    local count = 1 + (gem.enhance or 0)
    local cur = player.gemFragments[qualId] or 0
    local actual = math.min(count, CFG.MAX_FRAGMENTS - cur)
    if actual > 0 then
        player.gemFragments[qualId] = cur + actual
    end
    return count, qualId
end

-- ============================================================================
-- 自动分解判定
-- ============================================================================
function M.shouldAutoDecompose(player, category, qualityId, item)
    -- 上锁物品不自动分解
    if item and item.locked then return false end
    -- 强化过的不自动分解
    if item and item.enhance and item.enhance > 0 then return false end
    -- 已装备的技能不自动分解
    if item and item.equipped then return false end
    local settings = player.autoDecompose[category]
    if settings and settings[qualityId] then
        return true
    end
    return false
end

-- 处理掉落的自动分解
function M.autoDecomposeDrops(drops, player)
    local messages = {}

    -- 装备自动分解
    local keptEquips = {}
    for _, equip in ipairs(drops.equips) do
        if M.shouldAutoDecompose(player, "equip", equip.qualityId, equip) then
            local count, fragId = M.decomposeEquip(equip, player)
            messages[#messages + 1] = "自动分解: " .. equip.name .. " → " .. count .. "碎片"
        else
            keptEquips[#keptEquips + 1] = equip
        end
    end
    drops.equips = keptEquips

    -- 宝石自动分解
    local keptGems = {}
    for _, gem in ipairs(drops.gems) do
        if M.shouldAutoDecompose(player, "gem", gem.qualityId, gem) then
            local count, qualId = M.decomposeGem(gem, player)
            local qn = ""
            for _, gq in ipairs(CFG.GEM_QUALITIES) do if gq.id == qualId then qn = gq.name break end end
            messages[#messages + 1] = "自动分解: " .. gem.name .. " → " .. qn .. "碎片 x" .. count
        else
            keptGems[#keptGems + 1] = gem
        end
    end
    drops.gems = keptGems

    -- 技能自动分解
    local keptSkills = {}
    if drops.skills then
        for _, skill in ipairs(drops.skills) do
            if M.shouldAutoDecompose(player, "skill", CFG.SKILL_QUALITIES[skill.quality].id, skill) then
                local count, qId = M.decomposeSkill(skill, player)
                messages[#messages + 1] = "自动分解: " .. skill.name .. " → " .. count .. "碎片"
            else
                keptSkills[#keptSkills + 1] = skill
            end
        end
    end
    drops.skills = keptSkills

    return messages
end

-- ============================================================================
-- 上锁/解锁
-- ============================================================================
function M.toggleLock(item)
    item.locked = not item.locked
    return item.locked
end

-- ============================================================================
-- 格式化辅助
-- ============================================================================
function M.formatStat(statId, value)
    for _, at in ipairs(CFG.AFFIX_TYPES) do
        if at.id == statId then
            return at.name .. ": " .. string.format(at.fmt, value)
        end
    end
    for _, ga in ipairs(CFG.GEM_AFFIX_TYPES) do
        if ga.id == statId then
            return ga.name .. ": " .. string.format(ga.fmt, value)
        end
    end
    return statId .. ": " .. tostring(value)
end

function M.formatGemStat(statId, value)
    for _, ga in ipairs(CFG.GEM_AFFIX_TYPES) do
        if ga.id == statId then
            return ga.name .. ": " .. string.format(ga.fmt, value)
        end
    end
    return statId .. ": " .. tostring(value)
end

function M.getQualityColor(qualityIdx)
    if qualityIdx <= #CFG.EQUIP_QUALITIES then
        return CFG.EQUIP_QUALITIES[qualityIdx].color
    end
    return {255,255,255}
end

function M.getGemQualityColor(qualityIdx)
    if qualityIdx <= #CFG.GEM_QUALITIES then
        return CFG.GEM_QUALITIES[qualityIdx].color
    end
    return {255,255,255}
end

function M.getSkillQualityColor(qualityIdx)
    if qualityIdx <= #CFG.SKILL_QUALITIES then
        return CFG.SKILL_QUALITIES[qualityIdx].color
    end
    return {255,255,255}
end

-- 判断装备品质是否为稀有(黄金以上, qualityIdx >= 7)
function M.isRareQuality(qualityIdx)
    return qualityIdx >= 7
end

-- ============================================================================
-- 装备评分系统
-- 品质基础分 + 基础属性(归一化) + 词缀 + 孔位 + 强化
-- ============================================================================
function M.calcEquipScore(equip)
    local qualityScores = {
        gray=10, green=25, blue=50, purple=100, orange=180,
        red=300, gold=500, platinum=750, diamond=1100,
        darkgold=1500, myth=2000, supreme=3000,
    }
    local score = qualityScores[equip.qualityId] or 10

    -- 基础属性归一化权重
    local statWeights = { atk = 2, hp = 0.3, def = 2.5 }
    local enhMult = 1 + equip.enhance * 0.5
    for _, bs in ipairs(equip.baseStats) do
        local w = statWeights[bs.id] or 1
        score = score + math.floor(bs.value * enhMult * w)
    end

    -- 词缀贡献
    if equip.affixes then
        for _, af in ipairs(equip.affixes) do
            score = score + math.floor(af.value * 1.5)
        end
    end

    -- 孔位 + 宝石加分
    score = score + (equip.maxSockets or 0) * 25
    if equip.sockets then
        for i = 1, (equip.maxSockets or 0) do
            if equip.sockets[i] then
                score = score + 40
            end
        end
    end

    return score
end

-- 批量分解背包中指定品质的物品 (自动分解勾选时清理背包)
function M.autoDecomposeExisting(player, category, qualityId)
    local msgs = {}
    if category == "equip" then
        local toRemove = {}
        for i, equip in ipairs(player.bag) do
            if equip.qualityId == qualityId and not equip.locked and equip.enhance == 0 then
                toRemove[#toRemove + 1] = i
            end
        end
        for j = #toRemove, 1, -1 do
            local equip = player.bag[toRemove[j]]
            local count, fragId = M.decomposeEquip(equip, player)
            msgs[#msgs + 1] = "分解 " .. equip.name .. " → " .. count .. "碎片"
            table.remove(player.bag, toRemove[j])
        end
    elseif category == "skill" then
        local toRemove = {}
        for i, skill in ipairs(player.skills) do
            local sQid = CFG.SKILL_QUALITIES[skill.quality].id
            if sQid == qualityId and not skill.locked and skill.enhance == 0 and not skill.equipped then
                toRemove[#toRemove + 1] = i
            end
        end
        for j = #toRemove, 1, -1 do
            local skill = player.skills[toRemove[j]]
            local count, qId = M.decomposeSkill(skill, player)
            msgs[#msgs + 1] = "分解 " .. skill.name .. " → " .. count .. "碎片"
            table.remove(player.skills, toRemove[j])
        end
    elseif category == "gem" then
        local toRemove = {}
        for i, gem in ipairs(player.gemBag) do
            if gem.qualityId == qualityId and not gem.locked then
                toRemove[#toRemove + 1] = i
            end
        end
        for j = #toRemove, 1, -1 do
            local gem = player.gemBag[toRemove[j]]
            local count, qualId = M.decomposeGem(gem, player)
            local qn = ""
            for _, gq in ipairs(CFG.GEM_QUALITIES) do if gq.id == qualId then qn = gq.name break end end
            msgs[#msgs + 1] = "分解 " .. gem.name .. " → " .. qn .. "碎片 x" .. count
            table.remove(player.gemBag, toRemove[j])
        end
    end
    return msgs
end

-- ============================================================================
-- CDK 兑换码系统
-- ============================================================================
function M.redeemCDK(player, code)
    local upperCode = string.upper(code)

    -- VIP1 固定CDK (所有玩家通用)
    if upperCode == CFG.VIP1_CDK then
        if player.vipLevel >= 1 then
            return false, "你已经是VIP" .. player.vipLevel .. "，无需重复领取"
        end
        if player.usedCDKs[upperCode] then
            return false, "该兑换码已使用过"
        end
        player.vipLevel = 1
        player.usedCDKs[upperCode] = true
        M.recalcStats(player)
        return true, "恭喜! 已激活VIP1 (爆率+10% 金币+10%)"
    end

    -- 统一兑换码查表 (管理员定制CDK + 普通CDK 全部走此逻辑)
    local reward = CFG.CDK_REWARDS[upperCode]

    -- 查管理员动态生成的CDK (admin_cdks.json)
    if not reward then
        local adminCDKFile = "admin_cdks.json"
        if fileSystem:FileExists(adminCDKFile) then
            local file = File(adminCDKFile, FILE_READ)
            if file:IsOpen() then
                local ok, data = pcall(cjson.decode, file:ReadString())
                file:Close()
                if ok and type(data) == "table" then
                    local adminEntry = data[upperCode]
                    if adminEntry then
                        -- 转换管理员CDK格式为reward格式
                        if adminEntry.type == "review" then
                            reward = { name = adminEntry.name, review = true, diamonds = adminEntry.diamonds or 500, once = true }
                        elseif adminEntry.type == "vip2" then
                            reward = { name = adminEntry.name, vipLevel = 2 }
                        elseif adminEntry.type == "vip3" then
                            reward = { name = adminEntry.name, vipLevel = 3 }
                        elseif adminEntry.type == "festival" then
                            reward = { name = adminEntry.name, tickets = adminEntry.tickets or 1000, once = true }
                        end
                    end
                end
            end
        end
    end

    if not reward then
        return false, "无效的兑换码"
    end

    -- VIP专属CDK (vipLevel=2或3, 每人只能激活一次对应等级, 附带钻石和门票奖励)
    if reward.vipLevel then
        local targetLevel = reward.vipLevel
        local vipKey = "VIP" .. targetLevel .. "_USED"
        if player.usedCDKs[vipKey] then
            return false, "VIP" .. targetLevel .. "礼包已领取，每人限领一次"
        end
        if player.vipLevel >= targetLevel then
            return false, "你已经是VIP" .. player.vipLevel .. "或更高等级"
        end
        player.vipLevel = targetLevel
        player.usedCDKs[vipKey] = true
        player.usedCDKs[upperCode] = true
        -- 发放额外奖励（钻石、门票）
        local extraDiamonds = reward.diamonds or 0
        local extraTickets = reward.tickets or 0
        player.diamonds = player.diamonds + extraDiamonds
        player.tickets = player.tickets + extraTickets
        M.recalcStats(player)
        local bonus = CFG.VIP_BONUSES[targetLevel]
        local msg = "恭喜! 已激活VIP" .. targetLevel .. " (爆率+" .. bonus.equipDropBonus .. "% 金币+" .. bonus.goldBonus .. "%)"
        local extraParts = {}
        if extraDiamonds > 0 then extraParts[#extraParts + 1] = extraDiamonds .. "钻石" end
        if extraTickets > 0 then extraParts[#extraParts + 1] = extraTickets .. "门票" end
        if #extraParts > 0 then
            msg = msg .. " 额外奖励: " .. table.concat(extraParts, " + ")
        end
        return true, msg
    end

    -- 评价礼包CDK (review=true, 每人只能激活一次)
    if reward.review then
        if player.usedCDKs[CFG.REVIEW_CDK] then
            return false, "已领取感谢支持！"
        end
        player.diamonds = player.diamonds + (reward.diamonds or 500)
        player.usedCDKs[CFG.REVIEW_CDK] = true
        player.usedCDKs[upperCode] = true
        return true, "已领取感谢支持！(+" .. (reward.diamonds or 500) .. "钻石)"
    end

    -- VIP等级限制检查
    if reward.reqVip and (player.vipLevel or 0) < reward.reqVip then
        return false, "该兑换码需要VIP" .. reward.reqVip .. "才能领取"
    end

    -- 普通兑换码
    if reward.once and player.usedCDKs[upperCode] then
        return false, "该兑换码已使用过"
    end
    -- 发放奖励
    player.gold = player.gold + (reward.gold or 0)
    player.diamonds = player.diamonds + (reward.diamonds or 0)
    player.tickets = player.tickets + (reward.tickets or 0)
    player.usedCDKs[upperCode] = true
    local rewardText = reward.name .. ": "
    local parts = {}
    if (reward.gold or 0) > 0 then parts[#parts + 1] = reward.gold .. "金币" end
    if (reward.diamonds or 0) > 0 then parts[#parts + 1] = reward.diamonds .. "钻石" end
    if (reward.tickets or 0) > 0 then parts[#parts + 1] = reward.tickets .. "门票" end
    rewardText = rewardText .. table.concat(parts, " + ")
    return true, rewardText
end

function M.formatGold(n)
    if n >= 100000000 then
        return string.format("%.1f亿", n / 100000000)
    elseif n >= 10000 then
        return string.format("%.1fW", n / 10000)
    end
    return tostring(n)
end

-- ============================================================================
-- 转职 (切换职业, 卸下非本职业技能)
-- ============================================================================
function M.changeClass(player, newClassId)
    if not CFG.CLASSES[newClassId] then
        return false, "无效职业"
    end
    if player.classId == newClassId then
        return false, "已经是该职业"
    end
    local oldClassId = player.classId
    player.classId = newClassId
    player.className = CFG.CLASSES[newClassId].name
    -- 卸下非本职业的技能 (通用技能保留)
    local removed = 0
    for i = #player.skills, 1, -1 do
        local sk = player.skills[i]
        if sk.classId and sk.classId ~= "universal" and sk.classId ~= newClassId then
            removed = removed + 1
        end
    end
    -- 重算属性 (基础属性随职业变化)
    M.recalcStats(player)
    player.hp = player.maxHp
    local removedNames = {}
    for i = #player.skills, 1, -1 do
        local sk = player.skills[i]
        if sk.classId and sk.classId ~= "universal" and sk.classId ~= newClassId then
            removedNames[#removedNames + 1] = sk.name
            table.remove(player.skills, i)
        end
    end
    local msg = "转职成功! " .. CFG.CLASSES[oldClassId].name .. " → " .. CFG.CLASSES[newClassId].name
    if #removedNames > 0 then
        msg = msg .. " (卸下" .. #removedNames .. "个技能: " .. table.concat(removedNames, ", ") .. ")"
    end
    return true, msg
end

-- ============================================================================
-- 爆率药水 (购买后自动使用, +30%爆率持续1800秒)
-- ============================================================================
function M.buyDropPotion(player)
    if player.diamonds < 150 then
        return false, "钻石不足(需要150)"
    end
    player.diamonds = player.diamonds - 150
    player.dropPotionTimer = (player.dropPotionTimer or 0) + 1800
    return true, "使用爆率药水! 爆率+30% 持续" .. math.floor(player.dropPotionTimer) .. "秒"
end

-- ============================================================================
-- 经验药水 (购买后自动使用, +50%经验持续43200秒=12小时)
-- ============================================================================
function M.buyExpPotion(player)
    if player.diamonds < 100 then
        return false, "钻石不足(需要100)"
    end
    player.diamonds = player.diamonds - 100
    player.expPotionTimer = (player.expPotionTimer or 0) + 43200
    return true, "使用经验药水! 经验+50% 持续" .. M.formatPotionTime(player.expPotionTimer)
end

-- 购买装备保护卷 (88钻石)
function M.buyProtectionScroll(player)
    local price = CFG.BLACK_MARKET.protectionScrollPrice
    if player.diamonds < price then
        return false, "钻石不足(需要" .. price .. ")"
    end
    player.diamonds = player.diamonds - price
    player.protectionScrolls = (player.protectionScrolls or 0) + 1
    return true, "购买成功! 装备保护卷 x" .. player.protectionScrolls
end

-- 购买宝石保护卷 (88钻石)
function M.buyGemProtectionScroll(player)
    local price = CFG.BLACK_MARKET.protectionScrollPrice
    if player.diamonds < price then
        return false, "钻石不足(需要" .. price .. ")"
    end
    player.diamonds = player.diamonds - price
    player.gemProtectionScrolls = (player.gemProtectionScrolls or 0) + 1
    return true, "购买成功! 宝石保护卷 x" .. player.gemProtectionScrolls
end

-- 购买技能保护卷 (88钻石)
function M.buySkillProtectionScroll(player)
    local price = CFG.BLACK_MARKET.protectionScrollPrice
    if player.diamonds < price then
        return false, "钻石不足(需要" .. price .. ")"
    end
    player.diamonds = player.diamonds - price
    player.skillProtectionScrolls = (player.skillProtectionScrolls or 0) + 1
    return true, "购买成功! 技能保护卷 x" .. player.skillProtectionScrolls
end

-- 购买精英门票 (100钻石 → 300张)
function M.buyEliteTickets(player)
    local price = CFG.BLACK_MARKET.eliteTicketDiamondPrice
    local amount = CFG.BLACK_MARKET.eliteTicketAmount
    if player.diamonds < price then
        return false, "钻石不足(需要" .. price .. ")"
    end
    player.diamonds = player.diamonds - price
    player.tickets = (player.tickets or 0) + amount
    return true, "购买成功! 精英门票 +" .. amount .. " (共" .. player.tickets .. "张)"
end

-- 格式化药水剩余时间
function M.formatPotionTime(seconds)
    seconds = math.floor(seconds)
    if seconds >= 3600 then
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        return h .. "小时" .. m .. "分"
    elseif seconds >= 60 then
        return math.floor(seconds / 60) .. "分" .. (seconds % 60) .. "秒"
    end
    return seconds .. "秒"
end

-- 更新药水计时器 (每帧调用, 返回 dropExpired, expExpired)
function M.updatePotionTimer(player, dt)
    local dropExpired = false
    local expExpired = false
    if (player.dropPotionTimer or 0) > 0 then
        player.dropPotionTimer = player.dropPotionTimer - dt
        if player.dropPotionTimer <= 0 then
            player.dropPotionTimer = 0
            dropExpired = true
        end
    end
    if (player.expPotionTimer or 0) > 0 then
        player.expPotionTimer = player.expPotionTimer - dt
        if player.expPotionTimer <= 0 then
            player.expPotionTimer = 0
            expExpired = true
        end
    end
    return dropExpired, expExpired
end

-- ============================================================================
-- 判断技能是否可被当前职业使用
-- ============================================================================
function M.isSkillUsableByClass(skill, classId)
    if not skill.classId then return true end -- 旧技能无标记,视为通用
    return skill.classId == "universal" or skill.classId == classId
end

-- ============================================================================
-- 每日任务系统
-- ============================================================================

--- 获取当前"任务日"编号 (以北京时间早上6点为日界线)
function M.getDailyTaskDay()
    local utc = os.time()
    local beijing = utc + 8 * 3600          -- UTC → 北京时间
    local adjusted = beijing - CFG.DAILY_RESET_HOUR * 3600  -- 6点重置偏移
    return math.floor(adjusted / 86400)
end

--- 初始化或重置每日任务数据
function M.initDailyTasks(player)
    local today = M.getDailyTaskDay()
    if not player.dailyTasks then
        player.dailyTasks = { lastResetDay = today, progress = {}, claimed = {} }
        for _, task in ipairs(CFG.DAILY_TASKS) do
            player.dailyTasks.progress[task.id] = 0
            player.dailyTasks.claimed[task.id] = false
        end
        return
    end
    -- 检查是否需要重置
    if player.dailyTasks.lastResetDay ~= today then
        player.dailyTasks.lastResetDay = today
        for _, task in ipairs(CFG.DAILY_TASKS) do
            player.dailyTasks.progress[task.id] = 0
            player.dailyTasks.claimed[task.id] = false
        end
    end
end

--- 增加每日任务进度
---@param player table
---@param taskId string 任务ID
---@param amount number 增加量 (默认1)
function M.addDailyProgress(player, taskId, amount)
    M.initDailyTasks(player)
    local dt = player.dailyTasks
    dt.progress[taskId] = (dt.progress[taskId] or 0) + (amount or 1)
end

--- 领取每日任务奖励
---@param player table
---@param taskId string
---@return boolean success
---@return string msg
function M.claimDailyReward(player, taskId)
    M.initDailyTasks(player)
    local dt = player.dailyTasks
    -- 查找任务配置
    local taskCfg = nil
    for _, t in ipairs(CFG.DAILY_TASKS) do
        if t.id == taskId then taskCfg = t; break end
    end
    if not taskCfg then return false, "任务不存在" end
    if dt.claimed[taskId] then return false, "今日已领取" end
    local prog = dt.progress[taskId] or 0
    if prog < taskCfg.target then
        return false, "任务未完成 (" .. prog .. "/" .. taskCfg.target .. ")"
    end
    -- 发放奖励 (精英门票)
    dt.claimed[taskId] = true
    player.tickets = (player.tickets or 0) + taskCfg.reward
    return true, "领取成功! +" .. taskCfg.reward .. " 精英门票"
end

-- ============================================================================
-- 序列化/反序列化 (已拆分到 player_serializer.lua)
-- ============================================================================
local Serializer = require("player_serializer")
Serializer.setup(M)
M.serializePlayer = Serializer.serializePlayer
M.deserializePlayer = Serializer.deserializePlayer

-- ============================================================================
-- 离线挂机收益计算
-- VIP1: 最多8小时(收益减半), VIP2: 最多12小时, VIP3: 最多24小时
-- 收益 = 平均每小时击杀收益 × 离线小时数 × rewardMult
-- ============================================================================

--- 估算玩家在指定区域每小时的平均收益
---@param player table
---@param zoneIdx number
---@return table {exp, gold, diamonds, tickets, killsPerHour}
function M.estimateHourlyEarnings(player, zoneIdx)
    local mobStats = CFG.getMobStats(zoneIdx)

    -- 估算每次攻击伤害 (不含暴击)
    local pen = player.penetration or 0
    local penForDef = math.min(pen, 100)
    local penBonusDmg = 0
    if pen > 100 then penBonusDmg = math.min(pen - 100, 200) / 100 end
    local effDef = mobStats.def * (1 - penForDef / 100)
    effDef = math.max(0, effDef)
    local baseDmg = math.max(1, math.floor(player.atk - effDef * 0.6))
    if penBonusDmg > 0 then baseDmg = math.floor(baseDmg * (1 + penBonusDmg)) end

    -- 暴击期望伤害
    local critChance = math.max(0, (player.crit or 0)) / 100
    critChance = math.min(critChance, 1.0)
    local critMult = math.max(1.2, ((player.critDmg or 200) - (mobStats.antiCritDmg or 0)) / 100)
    local avgDmg = baseDmg * (1 - critChance) + baseDmg * critChance * critMult

    -- 每秒攻击次数
    local aspd = player.aspd or 1.0

    -- 击杀时间 (秒) = 怪物HP / (DPS) + 生成间隔(0.5s)
    local dps = avgDmg * aspd
    if dps <= 0 then dps = 1 end
    local killTime = mobStats.hp / dps + 0.5
    killTime = math.max(killTime, 0.6)  -- 至少0.6秒一只

    -- 每小时击杀数
    local killsPerHour = math.floor(3600 / killTime)

    -- 经验收益 (含加成)
    local expMult = 1 + (player.expBonus or 0) / 100
    local expPerKill = math.floor(mobStats.exp * expMult)
    local expPerHour = expPerKill * killsPerHour

    -- 金币收益 (含加成)
    local goldMult = 1 + (player.goldBonus or 0) / 100
    local goldPerKill = math.floor(mobStats.gold * goldMult)
    local goldPerHour = goldPerKill * killsPerHour

    -- 门票收益 (概率)
    local bonus = 1 + (player.equipDropBonus or 0) / 100
    local ticketsPerHour = math.floor(killsPerHour * CFG.TICKET_DROP_RATE * bonus)

    -- 钻石收益 (概率, 普通怪只有基础概率)
    local diamondsPerHour = math.floor(killsPerHour * CFG.DIAMOND_DROP_RATE * bonus)

    -- 被动收益 (每分钟)
    local passive = CFG.getPassiveRates(zoneIdx)
    expPerHour = expPerHour + passive.expPerMin * 60 * expMult
    goldPerHour = goldPerHour + passive.goldPerMin * 60 * goldMult

    return {
        exp = math.floor(expPerHour),
        gold = math.floor(goldPerHour),
        diamonds = math.max(diamondsPerHour, 0),
        tickets = math.max(ticketsPerHour, 0),
        killsPerHour = killsPerHour,
    }
end

--- 计算离线挂机收益
---@param player table 玩家数据
---@return table|nil {hours, exp, gold, diamonds, tickets} 或 nil(不满足条件)
function M.calcOfflineEarnings(player)
    -- VIP等级检查
    local vipLevel = player.vipLevel or 0
    local cfg = CFG.OFFLINE_IDLE[vipLevel]
    if not cfg then return nil end  -- 非VIP1/2/3

    -- 离线时间检查
    local lastTime = player.lastOnlineTime or 0
    if lastTime <= 0 then return nil end  -- 首次登录无离线收益

    local now = os.time()
    local offlineSeconds = now - lastTime
    if offlineSeconds < 60 then return nil end  -- 不足1分钟不计算

    -- 限制最大离线时间
    local maxSeconds = cfg.maxHours * 3600
    offlineSeconds = math.min(offlineSeconds, maxSeconds)

    local offlineHours = offlineSeconds / 3600

    -- 使用玩家上次所在区域计算收益
    local zoneIdx = player.currentZone or 1
    zoneIdx = math.max(1, math.min(zoneIdx, #CFG.ZONES))

    local hourly = M.estimateHourlyEarnings(player, zoneIdx)
    local mult = cfg.rewardMult or 1.0

    return {
        hours = offlineHours,
        maxHours = cfg.maxHours,
        rewardMult = mult,
        zoneIdx = zoneIdx,
        zoneName = CFG.ZONES[zoneIdx].name,
        exp = math.floor(hourly.exp * offlineHours * mult),
        gold = math.floor(hourly.gold * offlineHours * mult),
        diamonds = math.floor(hourly.diamonds * offlineHours * mult),
        tickets = math.floor(hourly.tickets * offlineHours * mult),
        kills = math.floor(hourly.killsPerHour * offlineHours),
    }
end

-- ============================================================================
-- 称号系统
-- ============================================================================

--- 检查并解锁称号 (指定条件类型)
---@return table|nil
function M.checkTitles(player, conditionType)
    if not player.titles then player.titles = {} end
    if not player.titleCounters then return nil end
    local tc = player.titleCounters
    local newTitle = nil

    for _, titleDef in ipairs(CFG.TITLES) do
        if titleDef.condition == conditionType and not player.titles[titleDef.id] then
            local reached = false
            if conditionType == "zone1_kills" then
                reached = (tc.zone1Kills or 0) >= titleDef.threshold
            elseif conditionType == "adventure_boss_kills" then
                reached = (tc.adventureBossKills or 0) >= titleDef.threshold
            elseif conditionType == "enhance_consec_fails" then
                reached = (tc.enhanceConsecFails or 0) >= titleDef.threshold
            elseif conditionType == "enhance_consec_success" then
                reached = (tc.enhanceConsecSuccessMax or 0) >= titleDef.threshold
            elseif conditionType == "elite_tickets_spent" then
                reached = (tc.eliteTicketsSpent or 0) >= titleDef.threshold
            elseif conditionType == "hell_tickets_spent" then
                reached = (tc.hellTicketsSpent or 0) >= titleDef.threshold
            elseif conditionType == "weapon_enhance_max" then
                reached = (tc.weaponEnhanceMax or 0) >= titleDef.threshold
            elseif conditionType == "zone_kills_max" then
                reached = (tc.zoneKillsMax or 0) >= titleDef.threshold
            end
            if reached then
                player.titles[titleDef.id] = true
                M.recalcStats(player)
                player._newTitle = titleDef  -- 临时标记供UI层读取提示
                newTitle = titleDef
            end
        end
    end
    return newTitle
end

--- 获取称号的强化概率加成总和
function M.getTitleEnhanceBonus(player)
    if not player.titles then return 0 end
    local bonus = 0
    for _, titleDef in ipairs(CFG.TITLES) do
        if player.titles[titleDef.id] and titleDef.bonuses.enhanceBonus then
            bonus = bonus + titleDef.bonuses.enhanceBonus
        end
    end
    return bonus
end

return M
