-- ============================================================================
-- 战斗循环模块 (从 main.lua HandleUpdate 中拆分)
-- 负责: 怪物生成、玩家攻击、技能释放、怪物反击、死亡/复活、被动收益
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")
local CombatLoot = require("combat_loot")

local M = {}

-- ============================================================================
-- 精英怪物技能处理
-- ============================================================================

--- 处理精英怪物技能攻击
---@param S table 共享状态
---@param dt number
---@return boolean dead 玩家是否阵亡
function M.updateEliteSkill(S, dt)
    local mob = S.currentMob
    local player = S.player
    if not mob or not mob.isElite or mob.hp <= 0 then return false end

    if not mob.skillTimer then mob.skillTimer = 0 end
    mob.skillTimer = mob.skillTimer + dt
    if mob.skillTimer < CFG.ELITE_SKILL.cooldown then return false end

    mob.skillTimer = mob.skillTimer - CFG.ELITE_SKILL.cooldown
    local skillMult = math.random(CFG.ELITE_SKILL.minMult, CFG.ELITE_SKILL.maxMult)
    local skillDmg = math.max(1, math.floor(mob.atk * skillMult / 100 - player.def * 0.6))

    local skillCrit = false
    local critChance = (mob.crit or 0) - (player.antiCrit or 0)
    if critChance > 0 and math.random(1, 1000) <= critChance * 10 then
        skillCrit = true
        local critM = ((mob.critDmg or 200) - (player.antiCritDmg or 0)) / 100
        critM = math.max(1.2, critM)
        skillDmg = math.floor(skillDmg * critM)
    end

    player.hp = player.hp - skillDmg
    S.addDmgFloat(skillDmg, skillCrit, true, true)

    local skillText = skillCrit and ("暴击! " .. skillDmg) or tostring(skillDmg)
    S.addLog("💥 " .. mob.name .. " 释放技能! " .. skillMult .. "% → " .. skillText .. " 伤害",
        {255, 50, 100, 255})

    if player.hp <= 0 then
        player.hp = 0
        S.isDead = true
        S.deathTimer = S.deathReviveTime
        S.currentMob = nil
        if S.hellMode then
            S.addLog("💀 地狱副本中被技能击杀! " .. math.ceil(S.deathReviveTime) .. "秒后复活...", {255, 50, 50, 255})
            S.autoHell = false
            S.autoHellZone = nil
            S.hellMode = false
            S.currentZone = S.previousNormalZone
            S.currentView = "combat"
        elseif S.eliteMode then
            S.addLog("💀 被精英技能击杀! " .. math.ceil(S.deathReviveTime) .. "秒后复活...", {255, 80, 80, 255})
            S.autoElite = false
            S.autoEliteZone = nil
            S.eliteMode = false
            S.currentZone = S.previousNormalZone
            S.currentView = "combat"
        else
            S.addLog("💀 被精英技能击杀! " .. math.ceil(S.deathReviveTime) .. "秒后复活...", {255, 80, 80, 255})
        end
        S.markDirty()
        return true
    end
    return false
end

-- ============================================================================
-- 怪物生成
-- ============================================================================

--- 生成下一只怪物
---@param S table 共享状态
function M.spawnMob(S)
    S.spawnWaiting = false
    if S.adventureBossTriggered then
        S.adventureBossTriggered = false
        S.currentMob = SYS.generateAdventureBoss()
        S.addLog("━━━ 奇遇降临! ━━━", {255, 215, 0, 255})
        S.addLog("✨ 神秘的奇遇BOSS出现了!", {255, 200, 50, 255})
        S.addLog("击杀可获得暗金及以上品质装备!", {255, 180, 100, 255})
    elseif S.hellMode then
        local types = {"normal", "silver", "gold"}
        local et = types[math.random(1, #types)]
        S.currentMob = SYS.generateHellMob(S.currentZone, et)
    elseif S.eliteMode then
        local types = {"normal", "silver", "gold"}
        local et = types[math.random(1, #types)]
        S.currentMob = SYS.generateElite(S.currentZone, et)
    elseif S.zoneKillCount > 0 and S.zoneKillCount % 3 == 0 then
        local types = {"normal", "silver", "gold"}
        local et = types[math.random(1, #types)]
        S.currentMob = SYS.generateElite(S.currentZone, et)
        S.addLog("精英BOSS出现!", {255, 200, 50, 255})
    else
        S.currentMob = SYS.generateMob(S.currentZone)
    end
    S.addLog("出现: " .. S.currentMob.name, {200, 200, 255, 255})
    S.markDirty()
end

-- ============================================================================
-- 玩家攻击 + 技能 + 怪物反击
-- ============================================================================

--- 执行一次攻击回合（普攻 + 技能 + 怪反击）
---@param S table 共享状态
---@return boolean dead 玩家是否阵亡
---@return boolean killed 怪物是否被击杀
function M.doAttackRound(S)
    local player = S.player
    local mob = S.currentMob

    -- 普攻
    local dmg, isCrit = SYS.calcDamage(player, mob, nil)
    if mob.isAdventureBoss then
        dmg = CFG.ADVENTURE_BOSS.fixedDmgTaken
        isCrit = false
    end
    mob.hp = mob.hp - dmg
    S.addDmgFloat(dmg, isCrit, false, false)
    local dmgText = isCrit and ("暴击! " .. dmg) or tostring(dmg)
    S.addLog("你对 " .. mob.name .. " 造成 " .. dmgText .. " 伤害",
        isCrit and {255, 200, 50, 255} or {180, 220, 180, 255})

    -- 吸血
    if player.lifesteal > 0 then
        local heal = math.floor(dmg * player.lifesteal / 100)
        if heal > 0 then
            player.hp = math.min(player.maxHp, player.hp + heal)
        end
    end

    -- 技能 (只使用已装备的)
    for _, skill in ipairs(player.skills) do
        if not skill.equipped then goto continueSkill end
        skill.cdTimer = skill.cdTimer + 1 / player.aspd
        if skill.cdTimer >= skill.cd then
            skill.cdTimer = 0
            local sMult = SYS.getSkillMult(skill)
            local sDmg, sCrit = SYS.calcDamage(player, mob, sMult)
            if mob.isAdventureBoss then
                sDmg = CFG.ADVENTURE_BOSS.fixedDmgTaken
                sCrit = false
            end
            mob.hp = mob.hp - sDmg
            S.addDmgFloat(sDmg, sCrit, true, false)
            local sText = sCrit and ("暴击! " .. sDmg) or tostring(sDmg)
            S.addLog(skill.name .. " → " .. sText, {255, 180, 100, 255})
            if player.lifesteal > 0 then
                local sHeal = math.floor(sDmg * player.lifesteal / 100)
                if sHeal > 0 then
                    player.hp = math.min(player.maxHp, player.hp + sHeal)
                end
            end
        end
        ::continueSkill::
    end

    -- 怪物死亡
    if mob.hp <= 0 then
        return false, true
    end

    -- 怪物反击
    local mDmg, mCrit = SYS.calcDamage(mob, player, nil)
    player.hp = player.hp - mDmg
    S.addDmgFloat(mDmg, mCrit, false, true)
    if mDmg > 5 then
        local mDmgText = mCrit and ("暴击! " .. mDmg) or tostring(mDmg)
        S.addLog(mob.name .. " 对你造成 " .. mDmgText .. " 伤害",
            mCrit and {255, 50, 50, 255} or {255, 120, 120, 255})
    end

    if player.hp <= 0 then
        player.hp = 0
        S.isDead = true
        S.deathTimer = S.deathReviveTime
        S.currentMob = nil
        if S.hellMode then
            S.addLog("💀 地狱副本中阵亡! " .. math.ceil(S.deathReviveTime) .. "秒后复活...", {255, 50, 50, 255})
            S.autoHell = false
            S.autoHellZone = nil
            S.hellMode = false
            S.currentZone = S.previousNormalZone
            S.currentView = "combat"
        elseif S.eliteMode then
            S.addLog("💀 精英副本中阵亡! " .. math.ceil(S.deathReviveTime) .. "秒后复活...", {255, 80, 80, 255})
            S.autoElite = false
            S.autoEliteZone = nil
            S.eliteMode = false
            S.currentZone = S.previousNormalZone
            S.currentView = "combat"
        else
            S.addLog("💀 你被击败了! " .. math.ceil(S.deathReviveTime) .. "秒后复活...", {255, 80, 80, 255})
        end
        S.markDirty()
        return true, false
    end

    return false, false
end

-- ============================================================================
-- 被动收益
-- ============================================================================

--- 处理被动经验和金币收益
---@param S table 共享状态
---@param dt number
function M.updatePassiveIncome(S, dt)
    local player = S.player
    player.passiveTimer = player.passiveTimer + dt
    if player.passiveTimer >= 60 then
        player.passiveTimer = player.passiveTimer - 60
        local passive = CFG.getPassiveRates(S.currentZone)
        local expMult = 1 + player.expBonus / 100 + ((player.expPotionTimer or 0) > 0 and 0.5 or 0)
        local expGain = math.floor(passive.expPerMin * expMult)
        local goldGain = math.floor(passive.goldPerMin * (1 + player.goldBonus / 100))
        player.exp = player.exp + expGain
        player.gold = player.gold + goldGain
        SYS.checkLevelUp(player)
    end
end

-- ============================================================================
-- 怪物击杀后处理 (委托给 CombatLoot)
-- ============================================================================

--- 处理怪物击杀后的掉落和状态更新
---@param S table 共享状态
function M.onMobKilled(S)
    CombatLoot.onMobKilled(S)
end

return M
