-- ============================================================================
-- 玩家数据序列化/反序列化 (存档用)
-- 从 systems.lua 拆分出来的独立模块
-- ============================================================================
local CFG = require("config")

local M = {}

-- systems 模块引用 (通过 setup 注入，避免循环依赖)
local SYS = nil

--- 初始化模块依赖
---@param systems table systems 模块引用
function M.setup(systems)
    SYS = systems
end

-- ============================================================================
-- 序列化辅助函数
-- ============================================================================

--- 序列化装备对象 (剔除运行时字段)
local function serializeEquip(equip)
    if not equip then return nil end
    local e = {
        name = equip.name, slot = equip.slot,
        qualityId = equip.qualityId, qualityIdx = equip.qualityIdx,
        reqLv = equip.reqLv, enhance = equip.enhance,
        locked = equip.locked or false,
        baseStats = equip.baseStats, affixes = equip.affixes,
        naturalSockets = equip.naturalSockets, maxSockets = equip.maxSockets,
        sockets = {},
    }
    for i = 1, (equip.maxSockets or 0) do
        if equip.sockets[i] then
            e.sockets[i] = {
                name = equip.sockets[i].name,
                qualityId = equip.sockets[i].qualityId,
                qualityIdx = equip.sockets[i].qualityIdx,
                affixes = equip.sockets[i].affixes,
                enhance = equip.sockets[i].enhance or 0,
                locked = equip.sockets[i].locked or false,
            }
        end
    end
    return e
end

--- 序列化技能对象
local function serializeSkill(skill)
    if not skill then return nil end
    return {
        name = skill.name, cd = skill.cd, mult = skill.mult,
        desc = skill.desc, quality = skill.quality,
        enhance = skill.enhance, locked = skill.locked or false,
        classId = skill.classId,
        equipped = skill.equipped or false,
    }
end

--- 序列化宝石对象
local function serializeGem(gem)
    if not gem then return nil end
    return {
        name = gem.name, qualityId = gem.qualityId,
        qualityIdx = gem.qualityIdx, affixes = gem.affixes,
        enhance = gem.enhance or 0,
        locked = gem.locked or false,
    }
end

-- ============================================================================
-- 序列化: 玩家数据 → 3个存档块
-- ============================================================================

function M.serializePlayer(player)
    -- 核心数据
    local core = {
        saveVersion = CFG.SAVE_VERSION,
        classId = player.classId,
        playerId = player.playerId,
        level = player.level, exp = player.exp, expNext = player.expNext,
        gold = player.gold, diamonds = player.diamonds, tickets = player.tickets,
        vipLevel = player.vipLevel, usedCDKs = player.usedCDKs,
        killCount = player.killCount,
        equipFragments = player.equipFragments,
        skillFragments = player.skillFragments,
        gemFragments = player.gemFragments,
        protectionScrolls = player.protectionScrolls or 0,
        gemProtectionScrolls = player.gemProtectionScrolls or 0,
        skillProtectionScrolls = player.skillProtectionScrolls or 0,
        dropPotionTimer = math.floor((player.dropPotionTimer or 0) * 10) / 10,
        expPotionTimer = math.floor((player.expPotionTimer or 0) * 10) / 10,
        autoDecompose = player.autoDecompose,
        lastOnlineTime = os.time(),
        currentZone = player.currentZone or 1,
        gameVersion = CFG.GAME_VERSION,
        titles = player.titles or {},
        titleCounters = player.titleCounters or {},
        hellTickets = player.hellTickets or 0,
        dailyTasks = player.dailyTasks,
    }

    -- 装备数据
    local equipData = { equipment = {}, bag = {} }
    for _, slot in ipairs(CFG.EQUIP_SLOTS) do
        equipData.equipment[slot.id] = serializeEquip(player.equipment[slot.id])
    end
    for _, equip in ipairs(player.bag) do
        equipData.bag[#equipData.bag + 1] = serializeEquip(equip)
    end

    -- 技能+宝石数据
    local skillsData = { skills = {}, gemBag = {} }
    for _, skill in ipairs(player.skills) do
        skillsData.skills[#skillsData.skills + 1] = serializeSkill(skill)
    end
    for _, gem in ipairs(player.gemBag) do
        skillsData.gemBag[#skillsData.gemBag + 1] = serializeGem(gem)
    end

    return core, equipData, skillsData
end

-- ============================================================================
-- 反序列化: 从存档数据恢复玩家对象
-- ============================================================================

function M.deserializePlayer(core, equipData, skillsData)
    if not core or not core.classId then return nil end
    local cls = CFG.CLASS_BY_ID[core.classId] or CFG.CLASSES[core.classId]
    if not cls then return nil end

    -- 类型保护: 云端 JSON 解码可能返回非 table 类型
    if equipData and type(equipData) ~= "table" then
        print("[存档] ⚠️ equipData 类型异常: " .. type(equipData) .. ", 重置为空")
        equipData = nil
    end
    if skillsData and type(skillsData) ~= "table" then
        print("[存档] ⚠️ skillsData 类型异常: " .. type(skillsData) .. ", 重置为空")
        skillsData = nil
    end
    if equipData then
        if equipData.equipment and type(equipData.equipment) ~= "table" then
            print("[存档] ⚠️ equipment 类型异常, 重置为空")
            equipData.equipment = {}
        end
        if equipData.bag and type(equipData.bag) ~= "table" then
            print("[存档] ⚠️ bag 类型异常, 重置为空")
            equipData.bag = {}
        end
    end

    -- 创建基础玩家
    local p = SYS.createPlayer(core.classId)

    -- 恢复核心数据
    p.playerId = core.playerId or p.playerId
    p.level = core.level or 1
    p.exp = core.exp or 0
    p.expNext = core.expNext or 100
    p.gold = core.gold or 0
    p.diamonds = core.diamonds or 0
    p.tickets = core.tickets or 0
    p.vipLevel = core.vipLevel or 0
    p.usedCDKs = core.usedCDKs or {}
    p.killCount = core.killCount or 0
    p.protectionScrolls = core.protectionScrolls or 0
    p.gemProtectionScrolls = core.gemProtectionScrolls or 0
    p.skillProtectionScrolls = core.skillProtectionScrolls or 0
    p.dropPotionTimer = core.dropPotionTimer or 0
    p.expPotionTimer = core.expPotionTimer or 0
    p.lastOnlineTime = core.lastOnlineTime or 0
    p.currentZone = core.currentZone or 1
    p.hellTickets = core.hellTickets or 0

    -- 恢复称号
    if core.titles then
        for k, v in pairs(core.titles) do
            p.titles[k] = v
        end
    end
    if core.titleCounters then
        for k, v in pairs(core.titleCounters) do
            p.titleCounters[k] = v
        end
    end

    -- 恢复每日任务
    if core.dailyTasks then
        p.dailyTasks = core.dailyTasks
    end

    -- 恢复碎片
    if core.equipFragments then
        for k, v in pairs(core.equipFragments) do
            p.equipFragments[k] = v
        end
    end
    if core.skillFragments then
        for k, v in pairs(core.skillFragments) do
            p.skillFragments[k] = v
        end
    end
    if core.gemFragments then
        for k, v in pairs(core.gemFragments) do
            p.gemFragments[k] = v
        end
    end

    -- 恢复自动分解设置
    if core.autoDecompose then
        if core.autoDecompose.equip then
            for k, v in pairs(core.autoDecompose.equip) do
                p.autoDecompose.equip[k] = v
            end
        end
        if core.autoDecompose.skill then
            for k, v in pairs(core.autoDecompose.skill) do
                p.autoDecompose.skill[k] = v
            end
        end
        if core.autoDecompose.gem then
            for k, v in pairs(core.autoDecompose.gem) do
                p.autoDecompose.gem[k] = v
            end
        end
    end

    -- 恢复装备
    if equipData then
        if equipData.equipment then
            for slotId, equip in pairs(equipData.equipment) do
                if equip then
                    -- 恢复 sockets 为正确格式
                    if equip.sockets then
                        for i = 1, (equip.maxSockets or 0) do
                            if not equip.sockets[i] then
                                equip.sockets[i] = nil  -- 保持空孔
                            end
                        end
                    else
                        equip.sockets = {}
                    end
                    p.equipment[slotId] = equip
                end
            end
        end
        if equipData.bag then
            p.bag = {}
            for _, equip in ipairs(equipData.bag) do
                if equip then
                    if not equip.sockets then equip.sockets = {} end
                    p.bag[#p.bag + 1] = equip
                end
            end
        end
    end

    -- 恢复技能
    if skillsData then
        if skillsData.skills then
            p.skills = {}
            for _, skill in ipairs(skillsData.skills) do
                if skill then
                    skill.cdTimer = 0  -- 重置冷却计时器
                    p.skills[#p.skills + 1] = skill
                end
            end
            -- 迁移：旧存档没有 equipped 字段，自动设前4个为已装备
            local hasEquippedField = false
            for _, sk in ipairs(p.skills) do
                if sk.equipped ~= nil then hasEquippedField = true break end
            end
            if not hasEquippedField then
                for i, sk in ipairs(p.skills) do
                    sk.equipped = (i <= SYS.MAX_EQUIPPED_SKILLS)
                end
            end
        end
        if skillsData.gemBag then
            p.gemBag = {}
            for _, gem in ipairs(skillsData.gemBag) do
                if gem then
                    p.gemBag[#p.gemBag + 1] = gem
                end
            end
        end
    end

    -- 重算属性
    SYS.recalcStats(p)
    p.hp = p.maxHp

    return p
end

return M
