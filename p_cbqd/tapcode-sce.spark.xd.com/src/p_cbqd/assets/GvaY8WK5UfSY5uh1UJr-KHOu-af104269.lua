-- ============================================================================
-- 游戏会话管理 (存档加载、踢线处理、屏幕构建)
-- 从 main.lua 拆分出来的独立模块
-- ============================================================================
local UI = require("urhox-libs/UI")
local CFG = require("config")
local SYS = require("systems")
local SaveSys = require("save_system")
local UIScreens = require("ui_screens")

local M = {}

-- 依赖注入 (由 main.lua 调用 setup 设置)
local deps = {}

--- 初始化模块依赖
--- @param d table 依赖表:
---   addLog (function), refreshUI (function), buildClassSelect (function),
---   setPlayer (function), setRootPanel (function),
---   getPlayer (function), getState (function), setState (function)
function M.setup(d)
    deps = d
end

-- ============================================================================
-- 版本比较
-- ============================================================================
M.compareVersion = UIScreens.compareVersion

-- ============================================================================
-- 屏幕构建
-- ============================================================================

function M.buildLoadingScreen(msg)
    local rootPanel = UIScreens.buildLoadingScreen(msg)
    UI.SetRoot(rootPanel, true)
    deps.setRootPanel(rootPanel)
end

function M.buildOutdatedScreen(savedVer, currentVer)
    local rootPanel = UIScreens.buildOutdatedScreen(savedVer, currentVer)
    UI.SetRoot(rootPanel, true)
    deps.setRootPanel(rootPanel)
end

function M.buildLoadErrorScreen(errMsg)
    local rootPanel = UIScreens.buildLoadErrorScreen(errMsg,
        function() M.buildLoadingScreen("正在重试..."); M.tryLoadSave() end,
        function() deps.buildClassSelect() end
    )
    UI.SetRoot(rootPanel, true)
    deps.setRootPanel(rootPanel)
end

function M.buildKickedScreen()
    local rootPanel = UIScreens.buildKickedScreen(function()
        deps.setState("isKickedOffline", false)
        SaveSys.isKicked = false
        SaveSys.sessionId = nil
        deps.setPlayer(nil)
        M.buildLoadingScreen("正在重新登录...")
        M.tryLoadSave()
    end)
    UI.SetRoot(rootPanel, true)
    deps.setRootPanel(rootPanel)
end

-- ============================================================================
-- 踢线处理
-- ============================================================================

--- 处理被踢下线: 立即保存存档后显示踢线界面
function M.handleKicked()
    if deps.getState("isKickedOffline") then return end
    deps.setState("isKickedOffline", true)
    print("[会话] 被踢下线，开始保存存档...")

    local player = deps.getPlayer()
    if player then
        -- 无论dirty状态，被踢时总是强制保存最新数据
        SaveSys.markDirty()
        SaveSys.saveImmediate(player, {
            onSuccess = function()
                print("[会话] 踢线前存档保存成功")
                M.buildKickedScreen()
            end,
            onError = function(err)
                print("[会话] 踢线前存档保存失败: " .. tostring(err))
                M.buildKickedScreen()
            end,
        })
    else
        M.buildKickedScreen()
    end
end

-- ============================================================================
-- 离线收益日志 (抽取公共逻辑，避免重复)
-- ============================================================================
local function logOfflineReward(player, offlineReward, addLog)
    local hoursStr = string.format("%.1f", offlineReward.hours)
    addLog("━━━ 离线挂机收益 ━━━", {255, 215, 0, 255})
    local multStr = offlineReward.rewardMult < 1 and " (收益" .. math.floor(offlineReward.rewardMult * 100) .. "%)" or ""
    addLog("离线 " .. hoursStr .. " 小时 (最多" .. offlineReward.maxHours .. "h)" .. multStr, {200, 200, 220, 255})
    addLog("挂机区域: " .. offlineReward.zoneName, {180, 180, 200, 255})
    if offlineReward.exp > 0 then
        addLog("  经验 +" .. SYS.formatGold(offlineReward.exp), {120, 255, 120, 255})
    end
    if offlineReward.gold > 0 then
        addLog("  金币 +" .. SYS.formatGold(offlineReward.gold), {255, 215, 0, 255})
    end
    if offlineReward.diamonds > 0 then
        addLog("  钻石 +" .. offlineReward.diamonds, {185, 242, 255, 255})
    end
    if offlineReward.tickets > 0 then
        addLog("  门票 +" .. offlineReward.tickets, {255, 180, 100, 255})
    end
    addLog("━━━━━━━━━━━━━━━", {255, 215, 0, 255})

    -- VIP1 玩家醒目升级提示
    if (player.vipLevel or 0) == 1 then
        addLog("", {0,0,0,0})
        addLog("⚡⚡⚡ VIP 升级提醒 ⚡⚡⚡", {255, 80, 80, 255})
        addLog("当前VIP1: 离线收益仅50%, 上限8小时", {255, 160, 100, 255})
        addLog("升级VIP2: 收益翻倍至100%, 上限12小时!", {80, 255, 80, 255})
        addLog("升级VIP3: 收益100%, 上限24小时!", {80, 255, 80, 255})
        addLog("💎 提升VIP = 睡觉也在变强! 💎", {255, 215, 0, 255})
        addLog("⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡", {255, 80, 80, 255})
    end

    print("[离线] 离线" .. hoursStr .. "h, 经验+" .. offlineReward.exp .. " 金币+" .. offlineReward.gold ..
        " 钻石+" .. offlineReward.diamonds .. " 门票+" .. offlineReward.tickets)
end

--- 发放离线收益到玩家数据
local function applyOfflineReward(player, offlineReward, addLog)
    player.exp = player.exp + offlineReward.exp
    player.gold = player.gold + offlineReward.gold
    player.diamonds = player.diamonds + offlineReward.diamonds
    player.tickets = player.tickets + offlineReward.tickets

    if SYS.checkLevelUp(player) then
        addLog("离线期间升级! 当前 Lv." .. player.level, {255, 255, 100, 255})
    end

    -- 离线击杀数累加到区域1隐藏称号计数
    if offlineReward.zoneIdx == 1 and (offlineReward.kills or 0) > 0 then
        local tc = player.titleCounters
        if tc then
            tc.zone1Kills = (tc.zone1Kills or 0) + offlineReward.kills
            local t = SYS.checkTitles(player, "zone1_kills")
            if t then
                addLog("━━━ 隐藏称号解锁! ━━━", t.color)
                addLog(t.icon .. " " .. t.name .. " " .. t.icon, t.color)
                addLog(t.desc, {200, 200, 220, 255})
                addLog("被动效果: 攻击+" .. (t.bonuses.atk or 0), {100, 255, 100, 255})
                addLog("━━━━━━━━━━━━━━━", t.color)
            end
        end
    end

    logOfflineReward(player, offlineReward, addLog)
    SaveSys.markDirty()
end

-- ============================================================================
-- 加载云存档
-- ============================================================================

--- 尝试加载云存档
function M.tryLoadSave()
    local addLog = deps.addLog

    SaveSys.loadGame({
        onSuccess = function(p, savedGameVersion)
            deps.setPlayer(p)
            local currentZone = p.currentZone or 1
            p.currentZone = currentZone
            deps.setState("currentZone", currentZone)
            deps.setState("spawnWaiting", true)
            deps.setState("spawnTimer", 0)
            addLog("存档加载成功! 欢迎回来, Lv." .. p.level, {100, 255, 200, 255})
            print("[存档] 云存档加载成功, 等级:" .. p.level)

            -- 版本检测: 存档版本比当前代码版本新 → 玩家运行的是旧缓存
            if savedGameVersion and M.compareVersion(savedGameVersion, CFG.GAME_VERSION) > 0 then
                print("[版本] 检测到旧版本! 当前:" .. CFG.GAME_VERSION .. " 存档:" .. savedGameVersion)
                M.buildOutdatedScreen(savedGameVersion, CFG.GAME_VERSION)
                return
            end

            -- 离线挂机收益 (VIP1/2/3)
            local offlineReward = SYS.calcOfflineEarnings(p)
            if offlineReward then
                applyOfflineReward(p, offlineReward, addLog)
            end

            -- 写入会话标识 (单设备登录互踢)
            SaveSys.writeSession()

            deps.refreshUI()
        end,
        onNoData = function()
            print("[存档] 无云端存档，显示职业选择")
            deps.buildClassSelect()
        end,
        onError = function(reason)
            print("[存档] 加载失败: " .. tostring(reason))
            M.buildLoadErrorScreen(reason)
        end,
        onCheatDetected = function(reason, p)
            print("[存档] 反作弊异常: " .. tostring(reason))
            if p then
                -- 数据异常但仍可加载，记录异常继续游戏
                deps.setPlayer(p)
                local currentZone = p.currentZone or 1
                p.currentZone = currentZone
                deps.setState("currentZone", currentZone)
                deps.setState("spawnWaiting", true)
                deps.setState("spawnTimer", 0)
                addLog("存档加载成功(版本更新已同步)", {100, 200, 255, 255})

                -- 离线挂机收益 (与 onSuccess 相同逻辑, 版本更新也应发放)
                local offlineReward = SYS.calcOfflineEarnings(p)
                if offlineReward then
                    applyOfflineReward(p, offlineReward, addLog)
                end

                -- 写入会话标识
                SaveSys.writeSession()
                -- 重新计算校验和并保存(修复校验和不匹配)
                SaveSys.markDirty()
                deps.refreshUI()
            else
                M.buildLoadErrorScreen("存档数据损坏: " .. tostring(reason))
            end
        end,
    })
end

return M
