-- ============================================================================
-- 回调绑定模块 (从 main.lua refreshUI 中拆分)
-- 负责: 将所有 ctx.onXxx 回调绑定到共享状态操作
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")
local SaveSys = require("save_system")
local DmgFloat = require("damage_float")

local M = {}

--- 检查并输出称号解锁日志
---@param player table
---@param addLog function
---@param category string
local function checkTitleLog(player, addLog, category)
    local t = SYS.checkTitles(player, category)
    if t then
        addLog("━━━ 隐藏称号解锁! ━━━", t.color)
        addLog(t.icon .. " " .. t.name .. " " .. t.icon, t.color)
        addLog(t.desc, {200, 200, 220, 255})
        local b = t.bonuses
        if b.equipDropBonus then
            addLog("被动效果: 掉落率+" .. b.equipDropBonus .. "%", {100, 255, 100, 255})
        end
        if b.enhanceBonus then
            addLog("被动效果: 强化成功率+" .. b.enhanceBonus .. "%", {100, 255, 100, 255})
        end
        if b.crit then
            addLog("被动效果: 暴击+" .. b.crit .. "%", {100, 255, 100, 255})
        end
        addLog("━━━━━━━━━━━━━━━", t.color)
    end
end

--- 输出强化后的称号解锁日志 (enhanceEquip 通过 _newTitle 传递)
---@param player table
---@param addLog function
local function checkEnhanceTitle(player, addLog)
    if player._newTitle then
        local t = player._newTitle
        player._newTitle = nil
        addLog("━━━ 隐藏称号解锁! ━━━", t.color)
        addLog(t.icon .. " " .. t.name .. " " .. t.icon, t.color)
        addLog(t.desc, {200, 200, 220, 255})
        local b = t.bonuses
        if b.enhanceBonus then
            addLog("被动效果: 强化成功率+" .. b.enhanceBonus .. "%", {100, 255, 100, 255})
        elseif b.crit then
            addLog("被动效果: 暴击+" .. b.crit .. "%", {100, 255, 100, 255})
        elseif b.equipDropBonus then
            addLog("被动效果: 掉落率+" .. b.equipDropBonus .. "%", {100, 255, 100, 255})
        end
        addLog("━━━━━━━━━━━━━━━", t.color)
    end
end

--- 辅助颜色转换
local function qcArr(colorArr)
    return {colorArr[1], colorArr[2], colorArr[3], 255}
end

--- 绑定所有回调到 ctx
---@param ctx table buildContext 返回的上下文
---@param G table 全局状态引用 (getter/setter)
function M.bind(ctx, G)
    local addLog = G.addLog
    local refreshUI = G.refreshUI
    local player = G.getPlayer()

    -- ==================== 区域选择 ====================
    ctx.onSelectZone = function(zoneIdx)
        local p = G.getPlayer()
        G.setState("eliteMode", false)
        G.setState("autoElite", false)
        G.setState("autoEliteZone", nil)
        G.setState("hellMode", false)
        G.setState("autoHell", false)
        G.setState("autoHellZone", nil)
        G.setState("previousNormalZone", zoneIdx)
        G.setState("currentZone", zoneIdx)
        p.currentZone = zoneIdx
        G.setState("zoneKillCount", 0)
        G.setState("currentMob", nil)
        G.setState("spawnWaiting", true)
        G.setState("spawnTimer", 0)
        G.setState("currentView", "combat")
        SaveSys.markDirty()
        refreshUI()
    end

    -- ==================== 精英副本 ====================
    ctx.onStartElite = function(zoneIdx, isAuto)
        local p = G.getPlayer()
        local eliteReq = CFG.getEliteReqLevel(zoneIdx)
        if not eliteReq then
            addLog("该区域没有精英副本", {255,100,100,255})
            refreshUI()
            return
        end
        if p.level < eliteReq then
            addLog("需要等级" .. eliteReq .. "才能进入精英副本", {255,100,100,255})
            refreshUI()
            return
        end
        local cost = CFG.getEliteTicketCost(zoneIdx)
        if p.tickets < cost then
            addLog("门票不足(需要" .. cost .. "张)", {255,100,100,255})
            refreshUI()
            return
        end
        p.tickets = p.tickets - cost
        if p.titleCounters then
            p.titleCounters.eliteTicketsSpent = (p.titleCounters.eliteTicketsSpent or 0) + cost
            checkTitleLog(p, addLog, "elite_tickets_spent")
        end
        G.setState("eliteMode", true)
        G.setState("currentZone", zoneIdx)
        G.setState("currentMob", nil)
        G.setState("spawnWaiting", true)
        G.setState("spawnTimer", 0)
        G.setState("currentView", "combat")
        if isAuto then
            G.setState("autoElite", true)
            G.setState("autoEliteZone", zoneIdx)
            addLog("开启自动精英挑战: " .. CFG.ZONES[zoneIdx].name, {255,200,100,255})
        else
            G.setState("autoElite", false)
            G.setState("autoEliteZone", nil)
            addLog("消耗" .. cost .. "张门票，进入精英副本!", {255,200,100,255})
        end
        SaveSys.markDirty()
        SaveSys.saveGame(p)
        refreshUI()
    end

    ctx.onToggleAutoElite = function(enabled)
        if not enabled then
            G.setState("autoElite", false)
            G.setState("autoEliteZone", nil)
            addLog("已停止自动精英挑战", {255,180,100,255})
            refreshUI()
        end
    end

    -- ==================== 地狱副本 ====================
    ctx.onStartHell = function(zoneIdx, isAuto)
        local p = G.getPlayer()
        local hellReq = CFG.getHellReqLevel(zoneIdx)
        if not hellReq then
            addLog("该区域没有地狱副本", {255,100,100,255})
            refreshUI()
            return
        end
        if p.level < hellReq then
            addLog("需要等级" .. hellReq .. "才能进入地狱副本", {255,100,100,255})
            refreshUI()
            return
        end
        local cost = CFG.getHellTicketCost()
        if p.hellTickets < cost then
            addLog("🔥地狱门票不足(需要" .. cost .. "张)", {255,100,100,255})
            refreshUI()
            return
        end
        p.hellTickets = p.hellTickets - cost
        if p.titleCounters then
            p.titleCounters.hellTicketsSpent = (p.titleCounters.hellTicketsSpent or 0) + cost
            checkTitleLog(p, addLog, "hell_tickets_spent")
        end
        G.setState("hellMode", true)
        G.setState("eliteMode", false)
        G.setState("autoElite", false)
        G.setState("autoEliteZone", nil)
        G.setState("currentZone", zoneIdx)
        G.setState("currentMob", nil)
        G.setState("spawnWaiting", true)
        G.setState("spawnTimer", 0)
        G.setState("currentView", "combat")
        if isAuto then
            G.setState("autoHell", true)
            G.setState("autoHellZone", zoneIdx)
            addLog("🔥 开启自动地狱挑战: " .. CFG.ZONES[zoneIdx].name, {255,100,50,255})
        else
            G.setState("autoHell", false)
            G.setState("autoHellZone", nil)
            addLog("🔥 消耗" .. cost .. "张地狱门票，进入地狱副本!", {255,100,50,255})
        end
        SaveSys.markDirty()
        SaveSys.saveGame(p)
        refreshUI()
    end

    ctx.onToggleAutoHell = function(enabled)
        if not enabled then
            G.setState("autoHell", false)
            G.setState("autoHellZone", nil)
            addLog("已停止自动地狱挑战", {255,180,100,255})
            refreshUI()
        end
    end

    -- ==================== 战斗控制 ====================
    ctx.onToggleQuickCombat = function()
        G.setState("quickCombat", not G.getState("quickCombat"))
        G.markDirty()
    end

    ctx.onToggleDmgFloat = function()
        G.setState("showDmgFloat", not G.getState("showDmgFloat"))
        DmgFloat.clear()
        refreshUI()
    end

    ctx.onToggleStats = function()
        G.setState("statsExpanded", not G.getState("statsExpanded"))
        refreshUI()
    end

    ctx.onToggleZones = function()
        G.setState("zonesExpanded", not G.getState("zonesExpanded"))
        refreshUI()
    end

    ctx.onTogglePause = function()
        local paused = not G.getState("combatPaused")
        G.setState("combatPaused", paused)
        if paused then
            local snapshot = {}
            local log = G.getState("combatLog")
            for i, entry in ipairs(log) do
                snapshot[i] = entry
            end
            G.setState("pausedLogSnapshot", snapshot)
        else
            G.setState("pausedLogSnapshot", nil)
        end
        G.markDirty()
    end

    -- ==================== 视图切换 ====================
    ctx.onSwitchView = function(view)
        G.setState("currentView", view)
        G.setState("marketMsg", nil)
        G.setState("skillMsg", nil)
        G.setState("gemMsg", nil)
        refreshUI()
    end

    ctx.onRefresh = function()
        refreshUI()
    end

    -- ==================== 装备操作 ====================
    ctx.onEquipDetail = function(equip, slotId, bagIdx)
        G.setState("selectedEquip", equip)
        G.setState("selectedSlot", slotId)
        G.setState("selectedBagIdx", bagIdx or nil)
        G.setState("currentView", "equipDetail")
        refreshUI()
    end

    ctx.onSetBagFilter = function(filter)
        G.setState("bagFilter", filter)
        refreshUI()
    end

    ctx.onEquipItem = function(bagIdx)
        local p = G.getPlayer()
        local equip = p.bag[bagIdx]
        if not equip then return end
        local old = p.equipment[equip.slot]
        if old then
            p.bag[bagIdx] = old
        else
            table.remove(p.bag, bagIdx)
        end
        p.equipment[equip.slot] = equip
        SYS.recalcStats(p)
        addLog("装备了 " .. equip.name, {100,255,100,255})
        SaveSys.markDirty()
        refreshUI()
    end

    ctx.onUnequip = function(slotId)
        local p = G.getPlayer()
        local equip = p.equipment[slotId]
        if equip then
            p.equipment[slotId] = nil
            p.bag[#p.bag + 1] = equip
            SYS.recalcStats(p)
            addLog("卸下了 " .. equip.name, {255,200,100,255})
            SaveSys.markDirty()
        end
        G.setState("currentView", "equip")
        refreshUI()
    end

    ctx.onDecomposeEquip = function(bagIdx)
        local p = G.getPlayer()
        local equip = p.bag[bagIdx]
        if not equip or equip.locked then return end
        local gemCount = 0
        if equip.sockets then
            for i = 1, (equip.maxSockets or 0) do
                if equip.sockets[i] then gemCount = gemCount + 1 end
            end
        end
        local count, fragId = SYS.decomposeEquip(equip, p)
        local qualName = ""
        for _, eq in ipairs(CFG.EQUIP_QUALITIES) do
            if eq.id == fragId then qualName = eq.name break end
        end
        table.remove(p.bag, bagIdx)
        addLog("分解 " .. equip.name .. " → " .. qualName .. "碎片 x" .. count, {200,200,100,255})
        if gemCount > 0 then
            addLog("自动取下 " .. gemCount .. " 颗宝石归还背包", {100,200,255,255})
        end
        SaveSys.markDirty()
        refreshUI()
    end

    ctx.onEnhanceEquip = function(equip, slotId)
        local p = G.getPlayer()
        local result, msg, destroyed = SYS.enhanceEquip(equip, p)
        if destroyed then
            if slotId and p.equipment[slotId] == equip then
                p.equipment[slotId] = nil
                SYS.recalcStats(p)
            end
            for i, e in ipairs(p.bag) do
                if e == equip then
                    table.remove(p.bag, i)
                    break
                end
            end
            addLog(msg, {255, 80, 80, 255})
            G.setState("currentView", "equip")
        else
            addLog(msg, result and {100,255,100,255} or {255,150,50,255})
        end
        checkEnhanceTitle(p, addLog)
        SaveSys.markDirty()
        SaveSys.saveGame(p)
        refreshUI()
    end

    ctx.onToggleLock = function(category, idx)
        local p = G.getPlayer()
        if category == "equip" then
            local item = p.bag[idx]
            if item then SYS.toggleLock(item) end
        elseif category == "skill" then
            local item = p.skills[idx]
            if item then SYS.toggleLock(item) end
        elseif category == "gem" then
            local item = p.gemBag[idx]
            if item then SYS.toggleLock(item) end
        end
        refreshUI()
    end

    -- ==================== 技能操作 ====================
    ctx.onEnhanceSkill = function(skillIdx)
        local p = G.getPlayer()
        local skill = p.skills[skillIdx]
        if not skill then return end
        local result, msg = SYS.enhanceSkill(skill, p)
        if result == nil then
            table.remove(p.skills, skillIdx)
            addLog(msg, {255, 80, 80, 255})
        else
            addLog(msg, result and {100,255,100,255} or {255,150,50,255})
        end
        SaveSys.markDirty()
        SaveSys.saveGame(p)
        refreshUI()
    end

    ctx.onDecomposeSkill = function(skillIdx)
        local p = G.getPlayer()
        local skill = p.skills[skillIdx]
        if not skill or skill.locked then return end
        local count, qualId = SYS.decomposeSkill(skill, p)
        local qualName = ""
        for _, sq in ipairs(CFG.SKILL_QUALITIES) do
            if sq.id == qualId then qualName = sq.name break end
        end
        table.remove(p.skills, skillIdx)
        local msg = "分解技能 " .. skill.name .. " → " .. qualName .. "碎片 x" .. count
        G.setState("skillMsg", msg)
        addLog(msg, {200,200,100,255})
        SaveSys.markDirty()
        refreshUI()
    end

    ctx.onEquipSkill = function(skillIdx)
        local p = G.getPlayer()
        local ok, msg = SYS.equipSkill(p, skillIdx)
        addLog(msg, ok and {100,255,100,255} or {255,150,50,255})
        if ok then
            SYS.recalcStats(p)
            SaveSys.markDirty()
        end
        refreshUI()
    end

    ctx.onUnequipSkill = function(skillIdx)
        local p = G.getPlayer()
        local ok, msg = SYS.unequipSkill(p, skillIdx)
        addLog(msg, ok and {100,255,100,255} or {255,150,50,255})
        if ok then SaveSys.markDirty() end
        refreshUI()
    end

    ctx.onSwapSkill = function(equippedIdx, unequippedIdx)
        local p = G.getPlayer()
        local ok, msg = SYS.swapSkill(p, equippedIdx, unequippedIdx)
        addLog(msg, ok and {100,255,100,255} or {255,150,50,255})
        if ok then
            SYS.recalcStats(p)
            SaveSys.markDirty()
        end
        refreshUI()
    end

    -- ==================== 商店操作 ====================
    ctx.onBuySkill = function()
        local p = G.getPlayer()
        local skill, msg = SYS.buySkill(p)
        if not skill then
            G.setState("marketMsg", msg)
        elseif msg then
            G.setState("marketMsg", msg)
            addLog(msg, {200,200,100,255})
            SYS.addDailyProgress(p, "buy_skills", 1)
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        else
            local sq = CFG.SKILL_QUALITIES[skill.quality]
            local m = "获得 [" .. sq.name .. "] " .. skill.name .. "!"
            G.setState("marketMsg", m)
            addLog(m, qcArr(sq.color))
            SYS.addDailyProgress(p, "buy_skills", 1)
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onBuyGem = function()
        local p = G.getPlayer()
        local gem, msg = SYS.buyGem(p)
        if not gem then
            G.setState("marketMsg", msg)
        elseif msg then
            G.setState("marketMsg", msg)
            addLog(msg, {200,200,100,255})
            SYS.addDailyProgress(p, "buy_gems", 1)
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        else
            local gq = CFG.GEM_QUALITIES[gem.qualityIdx]
            local m = "获得 " .. gem.name .. "!"
            G.setState("marketMsg", m)
            addLog(m, qcArr(gq.color))
            SYS.addDailyProgress(p, "buy_gems", 1)
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onBuyClassToken = function(newClassId)
        local p = G.getPlayer()
        if p.diamonds < 100 then
            G.setState("marketMsg", "钻石不足(需要100)")
            refreshUI()
            return
        end
        p.diamonds = p.diamonds - 100
        local ok, msg = SYS.changeClass(p, newClassId)
        if ok then
            G.setState("marketMsg", msg)
            addLog(msg, {100, 255, 200, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        else
            p.diamonds = p.diamonds + 100
            G.setState("marketMsg", msg)
        end
        refreshUI()
    end

    ctx.onBuyDropPotion = function()
        local p = G.getPlayer()
        local ok, msg = SYS.buyDropPotion(p)
        G.setState("marketMsg", msg)
        if ok then
            addLog(msg, {100, 255, 200, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onBuyExpPotion = function()
        local p = G.getPlayer()
        local ok, msg = SYS.buyExpPotion(p)
        G.setState("marketMsg", msg)
        if ok then
            addLog(msg, {100, 255, 200, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onBuyProtectionScroll = function()
        local p = G.getPlayer()
        local ok, msg = SYS.buyProtectionScroll(p)
        G.setState("marketMsg", msg)
        if ok then
            addLog(msg, {100, 255, 200, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onBuyGemProtectionScroll = function()
        local p = G.getPlayer()
        local ok, msg = SYS.buyGemProtectionScroll(p)
        G.setState("marketMsg", msg)
        if ok then
            addLog(msg, {100, 255, 200, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onBuySkillProtectionScroll = function()
        local p = G.getPlayer()
        local ok, msg = SYS.buySkillProtectionScroll(p)
        G.setState("marketMsg", msg)
        if ok then
            addLog(msg, {100, 255, 200, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onBuyEliteTickets = function()
        local p = G.getPlayer()
        local ok, msg = SYS.buyEliteTickets(p)
        G.setState("marketMsg", msg)
        if ok then
            addLog(msg, {100, 255, 200, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    -- ==================== 宝石操作 ====================
    ctx.onDecomposeGem = function(gemIdx)
        local p = G.getPlayer()
        local gem = p.gemBag[gemIdx]
        if not gem or gem.locked then return end
        local qualName = ""
        for _, gq in ipairs(CFG.GEM_QUALITIES) do
            if gq.id == gem.qualityId then qualName = gq.name break end
        end
        local count, qualId = SYS.decomposeGem(gem, p)
        table.remove(p.gemBag, gemIdx)
        local msg = "分解 [" .. qualName .. "] " .. gem.name .. " → " .. qualName .. "碎片 x" .. count
        G.setState("gemMsg", msg)
        addLog(msg, {200,200,100,255})
        SaveSys.markDirty()
        refreshUI()
    end

    ctx.onEnhanceGem = function(gemIdx)
        local p = G.getPlayer()
        local gem = p.gemBag[gemIdx]
        if not gem then return end
        local result, msg = SYS.enhanceGem(gem, p)
        if result == nil then
            table.remove(p.gemBag, gemIdx)
            addLog(msg, {255, 80, 80, 255})
            G.setState("gemMsg", msg)
        else
            addLog(msg, result and {100,255,100,255} or {255,150,50,255})
            G.setState("gemMsg", msg)
        end
        SaveSys.markDirty()
        SaveSys.saveGame(p)
        refreshUI()
    end

    ctx.onSocketGem = function(equip, sIdx)
        G.setState("socketEquip", equip)
        G.setState("socketIdx", sIdx)
        G.setState("currentView", "gemSelect")
        refreshUI()
    end

    ctx.onUnsocketGem = function(equip, sIdx)
        local p = G.getPlayer()
        local ok, msg = SYS.unsocketGem(equip, sIdx, p)
        addLog(msg, ok and {100,255,100,255} or {255,150,50,255})
        if ok then SaveSys.markDirty() end
        refreshUI()
    end

    ctx.onUnsocketAllGems = function(equip)
        local p = G.getPlayer()
        local count = 0
        for i = 1, equip.maxSockets do
            if equip.sockets[i] then
                local ok = SYS.unsocketGem(equip, i, p)
                if ok then count = count + 1 end
            end
        end
        if count > 0 then
            addLog("卸下了 " .. count .. " 颗宝石", {255, 200, 100, 255})
            SaveSys.markDirty()
        else
            addLog("没有可卸下的宝石", {140, 140, 160, 255})
        end
        refreshUI()
    end

    ctx.onConfirmSocket = function(gemIdx)
        local p = G.getPlayer()
        local gem = p.gemBag[gemIdx]
        local sEquip = G.getState("socketEquip")
        local sIdx = G.getState("socketIdx")
        if not gem or not sEquip then return end
        table.remove(p.gemBag, gemIdx)
        local ok, msg = SYS.socketGem(sEquip, sIdx, gem, p)
        addLog(msg, ok and {100,255,100,255} or {255,150,50,255})
        G.setState("selectedEquip", sEquip)
        G.setState("currentView", "equipDetail")
        G.setState("socketEquip", nil)
        G.setState("socketIdx", nil)
        SaveSys.markDirty()
        refreshUI()
    end

    ctx.onAddSocket = function(equip)
        local p = G.getPlayer()
        local ok, msg = SYS.addSocket(equip, p)
        addLog(msg, ok and {100,255,100,255} or {255,150,50,255})
        if ok then
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    -- ==================== 自动分解 / 设置 / CDK ====================
    ctx.onAutoDecomposeNow = function(msgs)
        for _, msg in ipairs(msgs) do
            addLog(msg, {200, 200, 100, 255})
        end
        if #msgs > 0 then SaveSys.markDirty() end
        refreshUI()
    end

    ctx.onSwitchSettingsTab = function(tab)
        G.setState("settingsTab", tab)
        G.setState("cdkMsg", nil)
        G.setState("cdkMsgOk", false)
        G.setState("rebirthMsg", nil)
        refreshUI()
    end

    ctx.onClaimDailyTask = function(taskId)
        local p = G.getPlayer()
        local ok, msg = SYS.claimDailyReward(p, taskId)
        if ok then
            addLog("📋 " .. msg, {100, 255, 100, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        G.setState("cdkMsg", msg)
        G.setState("cdkMsgOk", ok)
        refreshUI()
    end

    ctx.onRedeemCDK = function(code)
        if not code or code == "" then
            G.setState("cdkMsg", "请输入兑换码")
            G.setState("cdkMsgOk", false)
            refreshUI()
            return
        end
        local p = G.getPlayer()
        local ok, msg = SYS.redeemCDK(p, code)
        G.setState("cdkMsg", msg)
        G.setState("cdkMsgOk", ok)
        if ok then
            addLog("兑换成功: " .. msg, {100, 255, 100, 255})
            SaveSys.markDirty()
            SaveSys.saveGame(p)
        end
        refreshUI()
    end

    ctx.onRebirth = function()
        SaveSys.clearSave({
            onSuccess = function()
                G.resetState()
                G.buildClassSelect()
            end,
            onError = function(err)
                G.setState("rebirthMsg", "重生失败: " .. tostring(err))
                refreshUI()
            end,
        })
    end
end

return M
