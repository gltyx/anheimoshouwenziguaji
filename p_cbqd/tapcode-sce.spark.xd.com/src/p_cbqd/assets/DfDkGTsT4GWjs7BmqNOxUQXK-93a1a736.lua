-- ============================================================================
-- 战斗掉落与击杀结算系统
-- 从 main.lua 拆分出来的独立模块
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")
local SaveSys = require("save_system")

local M = {}

-- 稀有装备高亮边框: 品质越高越绚丽
local RARE_BORDERS = {
    [7]  = { star = "★",    border = "★★★★★★★★★★★★",           color = {255, 215, 0, 255},   bg = {60, 50, 10, 220} },
    [8]  = { star = "✦",    border = "✦✦✦✦✦✦✦✦✦✦✦✦",           color = {220, 220, 240, 255}, bg = {50, 50, 60, 220} },
    [9]  = { star = "✧",    border = "✧✧✧✧✧✧✧✧✧✧✧✧✧",          color = {100, 220, 255, 255}, bg = {15, 50, 65, 230} },
    [10] = { star = "◆",    border = "◆◆◆◆◆◆◆◆◆◆◆◆◆◆",         color = {200, 150, 50, 255},  bg = {55, 35, 10, 230} },
    [11] = { star = "❖",    border = "❖❖❖❖❖❖❖❖❖❖❖❖❖❖❖",        color = {255, 80, 180, 255},  bg = {65, 15, 45, 240} },
    [12] = { star = "✪",    border = "✪✪✪✪✪✪✪✪✪✪✪✪✪✪✪✪",       color = {255, 50, 50, 255},   bg = {70, 10, 10, 240} },
}

--- 辅助颜色转换
local function qcArr(colorArr)
    return {colorArr[1], colorArr[2], colorArr[3], 255}
end

--- 处理怪物被杀事件
--- @param S table 共享状态表，包含以下字段（直接修改）:
---   player, currentMob, currentZone, eliteMode, hellMode,
---   autoElite, autoEliteZone, autoHell, autoHellZone,
---   previousNormalZone, zoneKillCount, spawnWaiting, spawnTimer,
---   adventureBossTriggered, currentView
---   addLog (function)
function M.onMobKilled(S)
    local mob = S.currentMob
    local player = S.player
    local addLog = S.addLog

    player.killCount = player.killCount + 1
    if not S.eliteMode and not S.hellMode then
        S.zoneKillCount = S.zoneKillCount + 1
    end

    -- 每日任务击杀计数
    if S.hellMode then
        SYS.addDailyProgress(player, "hell_kills", 1)
    elseif S.eliteMode then
        SYS.addDailyProgress(player, "elite_kills", 1)
    elseif not mob.isAdventureBoss then
        SYS.addDailyProgress(player, "zone_kills", 1)
    end

    -- 称号计数
    local tc = player.titleCounters
    if tc then
        -- 新手平原(zone 1)击杀计数
        if S.currentZone == 1 and not S.eliteMode and not mob.isAdventureBoss then
            tc.zone1Kills = (tc.zone1Kills or 0) + 1
            local t = SYS.checkTitles(player, "zone1_kills")
            if t then
                addLog("━━━ 隐藏称号解锁! ━━━", t.color)
                addLog(t.icon .. " " .. t.name .. " " .. t.icon, t.color)
                addLog(t.desc, {200, 200, 220, 255})
                addLog("被动效果: 攻击+" .. (t.bonuses.atk or 0), {100, 255, 100, 255})
                addLog("━━━━━━━━━━━━━━━", t.color)
            end
        end
        -- 奇遇BOSS击杀计数
        if mob.isAdventureBoss then
            tc.adventureBossKills = (tc.adventureBossKills or 0) + 1
            local t = SYS.checkTitles(player, "adventure_boss_kills")
            if t then
                addLog("━━━ 隐藏称号解锁! ━━━", t.color)
                addLog(t.icon .. " " .. t.name .. " " .. t.icon, t.color)
                addLog(t.desc, {200, 200, 220, 255})
                addLog("被动效果: 掉落率+" .. (t.bonuses.equipDropBonus or 0) .. "%", {100, 255, 100, 255})
                addLog("━━━━━━━━━━━━━━━", t.color)
            end
        end
        -- 区域击杀计数 (不含精英/地狱/奇遇BOSS)
        if not S.eliteMode and not S.hellMode and not mob.isAdventureBoss then
            if not tc.zoneKills then tc.zoneKills = {} end
            local zk = S.currentZone
            tc.zoneKills[zk] = (tc.zoneKills[zk] or 0) + 1
            if tc.zoneKills[zk] > (tc.zoneKillsMax or 0) then
                tc.zoneKillsMax = tc.zoneKills[zk]
            end
            local t = SYS.checkTitles(player, "zone_kills_max")
            if t then
                addLog("━━━ 隐藏称号解锁! ━━━", t.color)
                addLog(t.icon .. " " .. t.name .. " " .. t.icon, t.color)
                addLog(t.desc, {200, 200, 220, 255})
                addLog("被动效果: 攻击+" .. (t.bonuses.atk or 0) .. " 防御+" .. (t.bonuses.def or 0), {100, 255, 100, 255})
                addLog("━━━━━━━━━━━━━━━", t.color)
            end
        end
    end

    -- 经验和金币
    local expMult = 1 + player.expBonus / 100 + ((player.expPotionTimer or 0) > 0 and 0.5 or 0)
    local expGain = math.floor(mob.exp * expMult)
    local goldGain = math.floor(mob.gold * (1 + player.goldBonus / 100))
    player.exp = player.exp + expGain
    player.gold = player.gold + goldGain
    addLog("击杀 " .. mob.name .. " | +" .. expGain .. "经验 +" .. goldGain .. "金币", {100, 255, 100, 255})

    -- 升级
    if SYS.checkLevelUp(player) then
        addLog("🎉 升级! Lv." .. player.level, {255, 255, 100, 255})
    end

    -- 掉落
    local drops
    if mob.isAdventureBoss then
        -- 奇遇BOSS特殊掉落: 90%暗金 8%神话 2%至尊
        drops = { equips = {}, gems = {}, skills = {} }
        local roll = math.random()
        local qi
        if roll < 0.02 then
            qi = 12  -- 至尊 2%
        elseif roll < 0.10 then
            qi = 11  -- 神话 8%
        else
            qi = 10  -- 暗金 90%
        end
        local slot = CFG.EQUIP_SLOTS[math.random(1, #CFG.EQUIP_SLOTS)]
        drops.equips[1] = SYS.generateEquip(S.currentZone, qi, slot.id, player.level)
        addLog("━━━ 奇遇BOSS战利品 ━━━", {255, 215, 0, 255})
    else
        drops = SYS.rollLoot(S.currentZone, S.eliteMode or S.hellMode, mob.eliteType, player, S.hellMode)
    end

    -- 自动分解 (奇遇BOSS掉落不自动分解)
    if not mob.isAdventureBoss then
        local autoMsgs = SYS.autoDecomposeDrops(drops, player)
        for _, msg in ipairs(autoMsgs) do
            addLog(msg, {200, 200, 100, 255})
        end
    end

    -- 处理保留的掉落物
    for _, equip in ipairs(drops.equips) do
        player.bag[#player.bag + 1] = equip
        local eqColor = SYS.getQualityColor(equip.qualityIdx)
        local rb = RARE_BORDERS[equip.qualityIdx]
        if rb then
            addLog(rb.border, rb.color, rb.bg)
            addLog(rb.star .. " " .. equip.name .. " [" .. equip.maxSockets .. "孔] " .. rb.star, qcArr(eqColor), rb.bg)
            addLog(rb.border, rb.color, rb.bg)
        else
            addLog("获得 " .. equip.name .. " [" .. equip.maxSockets .. "孔]", qcArr(eqColor))
        end
    end
    for _, gem in ipairs(drops.gems) do
        if #player.gemBag >= CFG.MAX_GEMS then
            addLog("宝石已满(" .. CFG.MAX_GEMS .. "), 无法获取更多", {255, 150, 50, 255})
            break
        end
        player.gemBag[#player.gemBag + 1] = gem
        local gc = SYS.getGemQualityColor(gem.qualityIdx)
        addLog("💎 获得 " .. gem.name, qcArr(gc), {20, 40, 30, 220})
    end
    for _, skill in ipairs(drops.skills) do
        if #player.skills >= CFG.MAX_SKILLS then
            addLog("技能书已满(" .. CFG.MAX_SKILLS .. "), 无法获取更多", {255, 150, 50, 255})
            break
        end
        -- 自动装备（不超过4个）
        if SYS.getEquippedCount(player) < SYS.MAX_EQUIPPED_SKILLS then
            skill.equipped = true
            skill.cdTimer = 0
        else
            skill.equipped = false
        end
        player.skills[#player.skills + 1] = skill
        local sq = CFG.SKILL_QUALITIES[skill.quality]
        local equipTag = skill.equipped and " [已装备]" or " [未装备]"
        addLog("获得技能 [" .. sq.name .. "] " .. skill.name .. equipTag, qcArr(sq.color))
    end

    -- 门票掉落 (橙黄色 + 背景)
    if drops.ticketDrop then
        player.tickets = player.tickets + drops.ticketDrop
        addLog("✦ 获得 🎫门票 x" .. drops.ticketDrop .. " ✦", {255, 200, 60, 255}, {60, 45, 10, 230})
    end
    -- 钻石掉落 (青蓝色 + 背景)
    if drops.diamondDrop then
        player.diamonds = player.diamonds + drops.diamondDrop
        addLog("✧ 获得 💎钻石 x" .. drops.diamondDrop .. " ✧", {120, 230, 255, 255}, {15, 50, 65, 230})
    end

    -- 标记存档需要保存
    SaveSys.markDirty()

    -- 下一个怪物
    S.currentMob = nil
    S.spawnWaiting = true
    S.spawnTimer = 0

    -- 奇遇BOSS触发检查 (击杀非奇遇BOSS的怪物后有概率触发)
    if not mob.isAdventureBoss then
        if SYS.checkAdventureBossSpawn(player.vipLevel or 0) then
            S.adventureBossTriggered = true
        end
    end

    -- 自动地狱续战: 地狱击杀后自动扣票继续
    if S.hellMode and S.autoHell and S.autoHellZone then
        local cost = CFG.getHellTicketCost()
        if player.hellTickets >= cost then
            player.hellTickets = player.hellTickets - cost
            SaveSys.markDirty()
            SaveSys.saveGame(player)
            -- 保持 hellMode=true, currentZone=autoHellZone, 下一只地狱怪自动生成
        else
            addLog("🔥 地狱门票不足，自动地狱挑战结束", {255,180,100,255})
            S.autoHell = false
            S.autoHellZone = nil
            S.hellMode = false
            S.currentZone = S.previousNormalZone
        end
    elseif S.hellMode and not S.autoHell then
        -- 单次地狱挑战结束后回到普通区域
        S.hellMode = false
        S.currentZone = S.previousNormalZone
    -- 自动精英续战: 精英击杀后自动扣票继续
    elseif S.eliteMode and S.autoElite and S.autoEliteZone then
        local cost = CFG.getEliteTicketCost(S.autoEliteZone)
        if player.tickets >= cost then
            player.tickets = player.tickets - cost
            SaveSys.markDirty()
            SaveSys.saveGame(player)
            -- 保持 eliteMode=true, currentZone=autoEliteZone, 下一只精英自动生成
        else
            addLog("门票不足，自动精英挑战结束", {255,180,100,255})
            S.autoElite = false
            S.autoEliteZone = nil
            S.eliteMode = false
            S.currentZone = S.previousNormalZone
        end
    elseif S.eliteMode and not S.autoElite then
        -- 单次精英挑战结束后回到普通区域
        S.eliteMode = false
        S.currentZone = S.previousNormalZone
    end

    -- 精英副本通关后10%概率掉落地狱门票（仅精英副本，不含区域精英和地狱副本）
    if S.eliteMode and mob.isElite and not S.hellMode and not mob.isAdventureBoss then
        if math.random() < CFG.HELL_TICKET_DROP_RATE then
            player.hellTickets = player.hellTickets + 1
            addLog("🔥 获得 地狱门票 x1 🔥", {255, 80, 30, 255}, {65, 15, 10, 230})
        end
    end
end

return M
