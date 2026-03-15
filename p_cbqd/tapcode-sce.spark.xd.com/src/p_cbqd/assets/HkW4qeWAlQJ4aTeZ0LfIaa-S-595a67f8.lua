-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 主入口
-- 重构版: 回调逻辑→callbacks.lua, 战斗循环→combat_loop.lua
-- ============================================================================
require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")
local CFG = require("config")
local SYS = require("systems")
local UILeft = require("ui_left")
local UIPanels = require("ui_panels")
local UILeaderboard = require("ui_leaderboard")
local SaveSys = require("save_system")
local UIScreens = require("ui_screens")
local DmgFloat = require("damage_float")
local CombatLoot = require("combat_loot")
local GameSession = require("game_session")
local CombatLoop = require("combat_loop")
local Callbacks = require("callbacks")

-- ============================================================================
-- 全局状态
-- ============================================================================
---@type table
local player = nil
local currentView = "combat"    -- combat|inventory|skills|gems|market|settings|equipDetail|gemSelect
local currentMob = nil
local combatLog = {}
local spawnTimer = 0
local spawnWaiting = false
local dailyTasks = nil       -- 每日任务数据
local currentZone = 1
local eliteMode = false
local autoElite = false
local autoEliteZone = nil
local hellMode = false
local autoHell = false
local autoHellZone = nil
local previousNormalZone = 1
local zoneKillCount = 0  -- 区域击杀计数, 每3只出精英BOSS
local marketMsg = nil
local skillMsg = nil        -- 技能面板提示消息
local gemMsg = nil           -- 宝石面板提示消息
local cdkMsg = nil          -- 兑换码结果消息
local cdkMsgOk = false      -- 兑换码结果是否成功
local rebirthMsg = nil      -- 重生结果消息
local settingsTab = "dailyTask"  -- settings子标签: dailyTask|rebirth
local bagFilter = "all"          -- 背包筛选: all|weapon|helmet|armor|boots|ring|necklace
local potionUITimer = 0  -- 药水倒计时UI刷新计时器
local combatPaused = false  -- 战斗日志暂停(战斗不暂停,只冻结日志)
local pausedLogSnapshot = nil  -- 暂停时的日志快照
local quickCombat = false     -- 极速战斗: 隐藏战斗动画和日志,减少UI重建
local showDmgFloat = true     -- 伤害飘字开关 (默认开启)
local statsExpanded = false   -- 属性面板折叠状态 (默认收起)
local zonesExpanded = false   -- 区域列表折叠状态 (默认收起)

-- 装备详情
local selectedEquip = nil
local selectedSlot = nil
local selectedBagIdx = nil
-- 宝石镶嵌选择
local socketEquip = nil
local socketIdx = nil

-- UI根
---@type table
local rootPanel = nil
---@type table
local rightContent = nil

local MAX_LOG = 50

-- 滚动位置保存/恢复 (防止UI重建时滚动位置丢失)
local scrollPositions = {}       -- { key = {x, y} }
local pendingScrollRestores = {} -- { {key, scrollViewRef}, ... }
local scrollRebuildGuard = false -- 重建期间禁止 onScroll 覆盖已保存位置
local scrollInteractionTimer = 0 -- 用户滚动后暂停自动刷新的倒计时(秒)
local SCROLL_PAUSE_DURATION = 5.0 -- 滚动后暂停自动刷新的持续时间(秒)

-- 前向声明
local buildClassSelect

-- 死亡复活状态
local isDead = false
local deathTimer = 0
local DEATH_REVIVE_TIME = 3.0  -- 3秒后复活

-- 存档状态
local saveStatusMsg = nil      -- 保存/加载状态提示
local saveStatusTimer = 0      -- 提示显示计时器
local SAVE_STATUS_DURATION = 2.0  -- 提示显示持续时间(秒)

-- 互踢状态
local isKickedOffline = false  -- 是否已被踢下线

-- 奇遇BOSS状态
local adventureBossTriggered = false

-- 排行榜状态
local rankData = {}           -- 排行榜数据 [{rank, userId, nickname, level}, ...]
local rankLoading = false     -- 是否正在加载
local rankError = false       -- 是否加载失败
local rankRefreshTimer = 0    -- 自动刷新计时器
local RANK_REFRESH_INTERVAL = 60.0  -- 自动刷新间隔(秒)
local rankFetched = false     -- 是否已经获取过一次

-- UI脏标记: 避免频繁重建UI导致闪烁/抖动
local uiDirty = false
local uiLogVersion = 0   -- 日志版本号，用于检测日志是否有变化
local uiRebuildCooldown = 0  -- UI重建冷却计时器(秒)，防止频繁重建导致手机端画面抖动
local UI_REBUILD_MIN_INTERVAL = 1.0  -- 自动刷新最小间隔(秒)，防止抖动
local function markDirty()
    uiDirty = true
end

-- ============================================================================
-- 日志
-- ============================================================================
local function addLog(text, color, bg)
    combatLog[#combatLog + 1] = { text = text, color = color or {180, 180, 200, 255}, bg = bg }
    if #combatLog > MAX_LOG then
        table.remove(combatLog, 1)
    end
    uiLogVersion = uiLogVersion + 1
end

--- 添加飘字伤害 (委托给 DmgFloat 模块)
local function addDmgFloat(value, isCrit, isSkill, isMob)
    DmgFloat.add(value, isCrit, isSkill, isMob)
end

-- ============================================================================
-- 全局状态访问器 (供 callbacks.lua 使用)
-- ============================================================================
local stateMap  -- 前向声明

--- 构建全局状态访问器对象
---@return table G
local function buildGlobalAccessor()
    -- 惰性初始化状态映射表 (getter/setter 通过闭包访问 main.lua 的 local 变量)
    if not stateMap then
        stateMap = {
            eliteMode       = { get = function() return eliteMode end,       set = function(v) eliteMode = v end },
            autoElite       = { get = function() return autoElite end,       set = function(v) autoElite = v end },
            autoEliteZone   = { get = function() return autoEliteZone end,   set = function(v) autoEliteZone = v end },
            hellMode        = { get = function() return hellMode end,        set = function(v) hellMode = v end },
            autoHell        = { get = function() return autoHell end,        set = function(v) autoHell = v end },
            autoHellZone    = { get = function() return autoHellZone end,    set = function(v) autoHellZone = v end },
            previousNormalZone = { get = function() return previousNormalZone end, set = function(v) previousNormalZone = v end },
            currentZone     = { get = function() return currentZone end,     set = function(v) currentZone = v end },
            currentMob      = { get = function() return currentMob end,      set = function(v) currentMob = v end },
            currentView     = { get = function() return currentView end,     set = function(v) currentView = v end },
            spawnWaiting    = { get = function() return spawnWaiting end,    set = function(v) spawnWaiting = v end },
            spawnTimer      = { get = function() return spawnTimer end,      set = function(v) spawnTimer = v end },
            zoneKillCount   = { get = function() return zoneKillCount end,   set = function(v) zoneKillCount = v end },
            marketMsg       = { get = function() return marketMsg end,       set = function(v) marketMsg = v end },
            skillMsg        = { get = function() return skillMsg end,        set = function(v) skillMsg = v end },
            gemMsg          = { get = function() return gemMsg end,          set = function(v) gemMsg = v end },
            cdkMsg          = { get = function() return cdkMsg end,          set = function(v) cdkMsg = v end },
            cdkMsgOk        = { get = function() return cdkMsgOk end,        set = function(v) cdkMsgOk = v end },
            rebirthMsg      = { get = function() return rebirthMsg end,      set = function(v) rebirthMsg = v end },
            settingsTab     = { get = function() return settingsTab end,     set = function(v) settingsTab = v end },
            bagFilter       = { get = function() return bagFilter end,       set = function(v) bagFilter = v end },
            quickCombat     = { get = function() return quickCombat end,     set = function(v) quickCombat = v end },
            showDmgFloat    = { get = function() return showDmgFloat end,    set = function(v) showDmgFloat = v end },
            statsExpanded   = { get = function() return statsExpanded end,   set = function(v) statsExpanded = v end },
            zonesExpanded   = { get = function() return zonesExpanded end,   set = function(v) zonesExpanded = v end },
            combatPaused    = { get = function() return combatPaused end,    set = function(v) combatPaused = v end },
            pausedLogSnapshot = { get = function() return pausedLogSnapshot end, set = function(v) pausedLogSnapshot = v end },
            combatLog       = { get = function() return combatLog end,       set = function(v) combatLog = v end },
            selectedEquip   = { get = function() return selectedEquip end,   set = function(v) selectedEquip = v end },
            selectedSlot    = { get = function() return selectedSlot end,    set = function(v) selectedSlot = v end },
            selectedBagIdx  = { get = function() return selectedBagIdx end,  set = function(v) selectedBagIdx = v end },
            socketEquip     = { get = function() return socketEquip end,     set = function(v) socketEquip = v end },
            socketIdx       = { get = function() return socketIdx end,       set = function(v) socketIdx = v end },
        }
    end
    return {
        addLog = addLog,
        refreshUI = nil,  -- 在 refreshUI 中赋值 (避免前向引用问题)
        getPlayer = function() return player end,
        getState = function(key)
            local entry = stateMap[key]
            return entry and entry.get() or nil
        end,
        setState = function(key, val)
            local entry = stateMap[key]
            if entry then entry.set(val) end
        end,
        markDirty = markDirty,
        resetState = function()
            player = nil
            selectedEquip = nil
            selectedSlot = nil
            selectedBagIdx = nil
            socketEquip = nil
            socketIdx = nil
            currentView = "combat"
            settingsTab = "decompose"
            rebirthMsg = nil
            cdkMsg = nil
            cdkMsgOk = false
            combatLog = {}
        end,
        buildClassSelect = function() buildClassSelect() end,
    }
end

-- ============================================================================
-- 排行榜数据获取
-- ============================================================================
local function fetchRankData()
    if rankLoading then return end
    rankLoading = true
    rankError = false
    markDirty()

    clientScore:GetRankList("player_level", 0, 50, {
        ok = function(rankList)
            local newData = {}
            local userIds = {}
            for i, item in ipairs(rankList) do
                newData[#newData + 1] = {
                    rank = i,
                    userId = item.userId,
                    level = item.iscore.player_level or 0,
                    nickname = nil,
                }
                userIds[#userIds + 1] = item.userId
            end

            if #userIds == 0 then
                rankData = newData
                rankLoading = false
                rankFetched = true
                markDirty()
                return
            end

            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local map = {}
                    for _, info in ipairs(nicknames) do
                        map[info.userId] = info.nickname or ""
                    end
                    for _, entry in ipairs(newData) do
                        entry.nickname = map[entry.userId] or "未知"
                    end
                    rankData = newData
                    rankLoading = false
                    rankFetched = true
                    markDirty()
                end,
                onError = function()
                    for _, entry in ipairs(newData) do
                        entry.nickname = "未知"
                    end
                    rankData = newData
                    rankLoading = false
                    rankFetched = true
                    markDirty()
                end,
            })
        end,
        error = function()
            rankLoading = false
            rankError = true
            rankFetched = true
            markDirty()
        end,
    })
end

-- ============================================================================
-- UI 刷新
-- ============================================================================
local function buildContext()
    return {
        player = player,
        currentView = currentView,
        currentMob = currentMob,
        combatLog = combatLog,
        spawnWaiting = spawnWaiting,
        currentZone = currentZone,
        eliteMode = eliteMode,
        autoElite = autoElite,
        autoEliteZone = autoEliteZone,
        hellMode = hellMode,
        autoHell = autoHell,
        autoHellZone = autoHellZone,
        marketMsg = marketMsg,
        skillMsg = skillMsg,
        gemMsg = gemMsg,
        selectedEquip = selectedEquip,
        selectedSlot = selectedSlot,
        selectedBagIdx = selectedBagIdx,
        socketEquip = socketEquip,
        socketIdx = socketIdx,
        isDead = isDead,
        deathTimer = deathTimer,
        deathReviveTime = DEATH_REVIVE_TIME,
        combatPaused = combatPaused,
        pausedLogSnapshot = pausedLogSnapshot,
        quickCombat = quickCombat,
        showDmgFloat = showDmgFloat,
        statsExpanded = statsExpanded,
        zonesExpanded = zonesExpanded,
        cdkMsg = cdkMsg,
        cdkMsgOk = cdkMsgOk,
        rebirthMsg = rebirthMsg,
        settingsTab = settingsTab,
        bagFilter = bagFilter,
        -- 回调占位 (由 Callbacks.bind 填充)
        onSelectZone = nil,
        onSwitchView = nil,
        onEquipDetail = nil,
        onEquipItem = nil,
        onDecomposeEquip = nil,
        onEnhanceEquip = nil,
        onUnequip = nil,
        onToggleLock = nil,
        onEnhanceSkill = nil,
        onDecomposeSkill = nil,
        onEquipSkill = nil,
        onUnequipSkill = nil,
        onSwapSkill = nil,
        onBuySkill = nil,
        onBuyGem = nil,
        onBuyClassToken = nil,
        onBuyDropPotion = nil,
        onBuyExpPotion = nil,
        onDecomposeGem = nil,
        onEnhanceGem = nil,
        onSocketGem = nil,
        onUnsocketGem = nil,
        onConfirmSocket = nil,
        onAddSocket = nil,
        onRefresh = nil,
        onStartElite = nil,
        onToggleAutoElite = nil,
        onStartHell = nil,
        onToggleAutoHell = nil,
        onTogglePause = nil,
        onToggleQuickCombat = nil,
        -- 排行榜
        rankData = rankData,
        rankLoading = rankLoading,
        rankError = rankError,
        myUserId = clientScore and clientScore.userId or nil,
        onRefreshRank = function() fetchRankData() end,
        -- 滚动位置保存/恢复工具
        wrapScroll = function(name, props)
            props.onScroll = function(self, x, y)
                if not scrollRebuildGuard then
                    scrollPositions[name] = {x, y}
                    scrollInteractionTimer = SCROLL_PAUSE_DURATION
                end
            end
            local sv = UI.ScrollView(props)
            pendingScrollRestores[#pendingScrollRestores + 1] = {name, sv}
            return sv
        end,
    }
end

local function refreshUI()
    if not rootPanel then return end

    -- 快照当前滚动位置，并启用重建保护
    local scrollSnapshot = {}
    for k, v in pairs(scrollPositions) do
        scrollSnapshot[k] = {v[1], v[2]}
    end
    scrollRebuildGuard = true

    pendingScrollRestores = {}
    local ctx = buildContext()

    -- 绑定所有回调 (委托给 callbacks.lua 模块)
    local G = buildGlobalAccessor()
    G.refreshUI = refreshUI
    Callbacks.bind(ctx, G)

    -- 构建内容面板
    local contentPanel
    if currentView == "combat" then
        contentPanel = UIPanels.buildCombatPanel(ctx)
    elseif currentView == "stats" then
        contentPanel = UIPanels.buildStatsPanel(ctx)
    elseif currentView == "leaderboard" then
        contentPanel = UILeaderboard.buildLeaderboardPanel(ctx)
        if not rankFetched then
            fetchRankData()
        end
    elseif currentView == "inventory" then
        contentPanel = UIPanels.buildInventoryPanel(ctx)
    elseif currentView == "equip" then
        contentPanel = UIPanels.buildEquipPanel(ctx)
    elseif currentView == "equipDetail" then
        contentPanel = UIPanels.buildEquipDetailPanel(ctx)
    elseif currentView == "skills" then
        contentPanel = UIPanels.buildSkillsPanel(ctx)
    elseif currentView == "gems" then
        contentPanel = UIPanels.buildGemsPanel(ctx)
    elseif currentView == "market" then
        contentPanel = UIPanels.buildMarketPanel(ctx)
    elseif currentView == "elite" then
        contentPanel = UIPanels.buildCombatPanel(ctx)
    elseif currentView == "settings" then
        contentPanel = UIPanels.buildSettingsPanel(ctx)
    elseif currentView == "gemSelect" then
        contentPanel = UIPanels.buildGemSelectPanel(ctx)
    else
        contentPanel = UIPanels.buildCombatPanel(ctx)
    end

    -- 竖屏三段式布局: 顶栏 + 内容 + 底栏
    local topHeader = UILeft.buildTopHeader(ctx)
    local bottomTabBar = UILeft.buildBottomTabBar(ctx)

    -- 整体布局 (SafeAreaView 处理灵动岛/刘海屏安全区域)
    local newRoot = UI.SafeAreaView {
        edges = "all",
        width = "100%",
        height = "100%",
        backgroundColor = {20, 20, 30, 255},
        children = {
            UI.Panel {
                width = "100%",
                height = "100%",
                flexDirection = "column",
                children = {
                    topHeader,
                    UI.Panel {
                        width = "100%",
                        flex = 1,
                        children = { contentPanel },
                    },
                    bottomTabBar,
                },
            },
        },
    }

    UI.SetRoot(newRoot, true)
    rootPanel = newRoot

    -- 强制计算布局，否则 SetScroll 读取的尺寸是过期的
    UI.Layout()

    -- 同步飘字锚点到怪物面板位置 (布局计算完成后才能读取)
    if ctx.mobPanelRef and ctx.mobPanelRef.GetAbsoluteLayout then
        local l = ctx.mobPanelRef:GetAbsoluteLayout()
        if l and l.w and l.w > 0 then
            DmgFloat.anchorX = l.x + l.w * 0.5
            DmgFloat.anchorY = l.y + l.h * 0.5
        end
    end

    -- 同步受伤飘字锚点到玩家血条中间
    if ctx.playerHpBarRef and ctx.playerHpBarRef.GetAbsoluteLayout then
        local l = ctx.playerHpBarRef:GetAbsoluteLayout()
        if l and l.w and l.w > 0 then
            DmgFloat.playerAnchorX = l.x + l.w * 0.5
            DmgFloat.playerAnchorY = l.y + l.h * 0.5
        end
    end

    -- 从快照恢复所有 ScrollView 的滚动位置
    for _, entry in ipairs(pendingScrollRestores) do
        local pos = scrollSnapshot[entry[1]]
        if pos then
            entry[2]:SetScroll(pos[1], pos[2])
        end
    end
    pendingScrollRestores = {}

    -- 解除重建保护，后续用户滚动可正常保存位置
    scrollRebuildGuard = false
end

-- ============================================================================
-- 职业选择界面
-- ============================================================================
buildClassSelect = function()
    local classCards = {}
    for classId, cls in pairs(CFG.CLASSES) do
        if type(classId) ~= "string" then goto continueClass end
        local cid = classId
        classCards[#classCards + 1] = UI.Panel {
            width = "100%",
            padding = 16,
            backgroundColor = {40, 40, 55, 255},
            borderRadius = 12,
            gap = 6,
            flexDirection = "row",
            alignItems = "center",
            children = {
                UI.Label {
                    text = cls.icon,
                    fontSize = 48,
                    width = 60,
                    textAlign = "center",
                },
                UI.Panel {
                    flex = 1, flexShrink = 1,
                    gap = 4,
                    children = {
                        UI.Label {
                            text = cls.name,
                            fontSize = 28, fontWeight = "bold",
                            color = {255, 215, 0, 255},
                        },
                        UI.Label {
                            text = cls.desc,
                            fontSize = 22,
                            color = {180, 180, 200, 255},
                        },
                        UI.Label {
                            text = "生命:" .. cls.baseHp .. " 攻击:" .. cls.baseAtk .. " 防御:" .. cls.baseDef,
                            fontSize = 20,
                            color = {140, 200, 140, 255},
                        },
                        UI.Label {
                            text = "暴击:" .. cls.baseCrit .. "% 爆伤:" .. cls.baseCritDmg .. "% 攻速:" .. cls.baseAspd,
                            fontSize = 20,
                            color = {200, 180, 140, 255},
                        },
                        UI.Label {
                            text = "攻速上限: " .. (CFG.CLASS_MAX_ASPD[cid] or CFG.AC_MAX_ASPD),
                            fontSize = 20,
                            color = {255, 180, 100, 255},
                        },
                        UI.Button {
                            text = "选择" .. cls.name,
                            fontSize = 24,
                            width = "100%",
                            height = 52,
                            variant = "primary",
                            onClick = function()
                                player = SYS.createPlayer(cid)
                                currentZone = 1
                                spawnWaiting = true
                                spawnTimer = 0
                                -- 写入会话标识 (新角色也需要互踢保护)
                                SaveSys.writeSession()
                                -- 首次保存
                                SaveSys.markDirty()
                                SaveSys.saveGame(player, {
                                    onSuccess = function()
                                        print("[存档] 新角色首次保存成功")
                                    end,
                                    onError = function(err)
                                        print("[存档] 新角色首次保存失败: " .. tostring(err))
                                    end,
                                })
                                refreshUI()
                            end,
                        },
                    },
                },
            },
        }
        ::continueClass::
    end

    local selectRoot = UI.SafeAreaView {
        edges = "all",
        width = "100%",
        height = "100%",
        backgroundColor = {20, 20, 30, 255},
        children = {
            UI.Panel {
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                padding = 24,
                gap = 20,
                children = {
                    UI.Label {
                        text = "⚔️ 暗黑挂机爽刷装备版本 ⚔️",
                        fontSize = 36, fontWeight = "bold",
                        color = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "v" .. CFG.GAME_VERSION,
                        fontSize = 20,
                        color = {100, 100, 120, 255},
                    },
                    UI.Label {
                        text = "选择你的职业",
                        fontSize = 28,
                        color = {200, 200, 220, 255},
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        gap = 12,
                        children = classCards,
                    },
                },
            },
        },
    }

    UI.SetRoot(selectRoot, true)
    rootPanel = selectRoot
end

-- ============================================================================
-- 版本比较 (已拆分到 game_session.lua)
-- ============================================================================
local compareVersion = GameSession.compareVersion

-- ============================================================================
-- 构建战斗共享状态 (供 CombatLoop 模块使用)
-- ============================================================================
local function buildCombatState()
    return {
        player = player, currentMob = currentMob, currentZone = currentZone,
        eliteMode = eliteMode, hellMode = hellMode,
        autoElite = autoElite, autoEliteZone = autoEliteZone,
        autoHell = autoHell, autoHellZone = autoHellZone,
        previousNormalZone = previousNormalZone, zoneKillCount = zoneKillCount,
        spawnWaiting = spawnWaiting, spawnTimer = spawnTimer,
        adventureBossTriggered = adventureBossTriggered,
        currentView = currentView, isDead = isDead, deathTimer = deathTimer,
        deathReviveTime = DEATH_REVIVE_TIME,
        addLog = addLog, addDmgFloat = addDmgFloat, markDirty = markDirty,
    }
end

--- 从共享状态回写到 main.lua 的 local 变量
local function writeCombatState(S)
    currentMob = S.currentMob; currentZone = S.currentZone
    eliteMode = S.eliteMode; hellMode = S.hellMode
    autoElite = S.autoElite; autoEliteZone = S.autoEliteZone
    autoHell = S.autoHell; autoHellZone = S.autoHellZone
    zoneKillCount = S.zoneKillCount
    spawnWaiting = S.spawnWaiting; spawnTimer = S.spawnTimer
    adventureBossTriggered = S.adventureBossTriggered
    isDead = S.isDead; deathTimer = S.deathTimer
    currentView = S.currentView
end

-- ============================================================================
-- 战斗逻辑 (HandleUpdate)
-- ============================================================================
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if not player then return end
    if isKickedOffline then return end

    local dt = eventData:GetFloat("TimeStep")

    -- UI重建冷却计时
    uiRebuildCooldown = math.max(0, uiRebuildCooldown - dt)
    scrollInteractionTimer = math.max(0, scrollInteractionTimer - dt)

    -- 飘字伤害更新
    DmgFloat.enabled = showDmgFloat and currentView == "combat"
    if showDmgFloat and DmgFloat.hasFloats() then
        DmgFloat.update(dt)
    end

    -- 死亡复活等待
    if isDead then
        deathTimer = deathTimer - dt
        if deathTimer <= 0 then
            isDead = false
            deathTimer = 0
            player.hp = player.maxHp
            addLog("✨ 你已复活! 重新投入战斗", {100, 255, 200, 255})
            zoneKillCount = 0
            currentMob = nil
            spawnWaiting = true
            spawnTimer = 0
            markDirty()
        else
            if not M_deathUiTimer then M_deathUiTimer = 0 end
            M_deathUiTimer = M_deathUiTimer + dt
            if M_deathUiTimer >= 1.0 then
                M_deathUiTimer = 0
                markDirty()
            end
        end
        if uiDirty and uiRebuildCooldown <= 0 and scrollInteractionTimer <= 0 then
            uiDirty = false
            uiRebuildCooldown = UI_REBUILD_MIN_INTERVAL
            refreshUI()
        end
        return
    end

    -- 药水倒计时
    local dropExpired, expExpired = SYS.updatePotionTimer(player, dt)
    if dropExpired then
        addLog("爆率药水效果已结束", {255, 200, 100, 255})
        markDirty()
    end
    if expExpired then
        addLog("经验药水效果已结束", {255, 200, 100, 255})
        markDirty()
    end
    if (player.dropPotionTimer or 0) > 0 or (player.expPotionTimer or 0) > 0 then
        potionUITimer = potionUITimer + dt
        if potionUITimer >= 1.0 then
            potionUITimer = potionUITimer - 1.0
            if currentView == "combat" then
                markDirty()
            end
        end
    else
        potionUITimer = 0
    end

    -- 排行榜自动刷新
    if currentView == "leaderboard" and rankFetched then
        rankRefreshTimer = rankRefreshTimer + dt
        if rankRefreshTimer >= RANK_REFRESH_INTERVAL then
            rankRefreshTimer = 0
            fetchRankData()
        end
    end

    -- 怪物生成等待
    if spawnWaiting then
        spawnTimer = spawnTimer - dt
        if spawnTimer <= 0 then
            local S = buildCombatState()
            CombatLoop.spawnMob(S)
            writeCombatState(S)
        end
        return
    end

    if not currentMob then
        spawnWaiting = true
        spawnTimer = 0
        return
    end

    -- 精英怪物技能 (委托给 CombatLoop)
    if currentMob and currentMob.isElite and currentMob.hp > 0 then
        local S = buildCombatState()
        local dead = CombatLoop.updateEliteSkill(S, dt)
        writeCombatState(S)
        if dead then
            M_deathUiTimer = 0
            markDirty()
            return
        end
    end

    -- 玩家攻击循环 (委托给 CombatLoop)
    player.atkTimer = player.atkTimer + dt * player.aspd
    while player.atkTimer >= 1.0 do
        player.atkTimer = player.atkTimer - 1.0

        local S = buildCombatState()
        local dead, killed = CombatLoop.doAttackRound(S)
        writeCombatState(S)

        if killed then
            -- 怪物击杀后掉落处理
            local lootS = buildCombatState()
            CombatLoot.onMobKilled(lootS)
            writeCombatState(lootS)
            break
        end

        if dead then
            M_deathUiTimer = 0
            markDirty()
            return
        end
    end

    -- 被动收益 (委托给 CombatLoop)
    local passiveS = buildCombatState()
    CombatLoop.updatePassiveIncome(passiveS, dt)

    -- 战斗中定时刷新
    if not M_uiTimer then M_uiTimer = 0 end
    if not M_lastLogVer then M_lastLogVer = 0 end
    if not M_lastHpPct then M_lastHpPct = 100 end
    if not M_lastMobHpPct then M_lastMobHpPct = 100 end
    M_uiTimer = M_uiTimer + dt
    if M_uiTimer >= 0.5 then
        M_uiTimer = 0
        if currentView == "combat" then
            local curHpPct = player.maxHp > 0 and math.floor(player.hp / player.maxHp * 100) or 100
            local curMobHpPct = (currentMob and currentMob.maxHp > 0) and math.floor(currentMob.hp / currentMob.maxHp * 100) or 0
            if uiLogVersion ~= M_lastLogVer or curHpPct ~= M_lastHpPct or curMobHpPct ~= M_lastMobHpPct then
                M_lastLogVer = uiLogVersion
                M_lastHpPct = curHpPct
                M_lastMobHpPct = curMobHpPct
                markDirty()
            end
        end
    end

    -- 自动保存
    SaveSys.updateAutoSave(player, dt)

    -- 会话检查 (单设备登录互踢)
    if not isKickedOffline then
        SaveSys.updateSessionCheck(dt, function() GameSession.handleKicked() end)
    end

    -- 定时版本检测 (每60秒)
    if not versionCheckTimer then versionCheckTimer = 0 end
    if not versionCheckingNow then versionCheckingNow = false end
    versionCheckTimer = versionCheckTimer + dt
    if versionCheckTimer >= 60 and not versionCheckingNow then
        versionCheckTimer = 0
        versionCheckingNow = true
        SaveSys.checkCloudVersion(function(cloudVer)
            versionCheckingNow = false
            if cloudVer and compareVersion(cloudVer, CFG.GAME_VERSION) > 0 then
                print("[版本] 检测到新版本! 当前:" .. CFG.GAME_VERSION .. " 云端:" .. cloudVer)
                addLog("检测到新版本 v" .. cloudVer .. "，正在保存存档...", {255, 215, 0, 255})
                SaveSys.saveGame(player, {
                    onSuccess = function()
                        print("[版本] 存档已保存，显示强制更新界面")
                        GameSession.buildOutdatedScreen(cloudVer, CFG.GAME_VERSION)
                    end,
                    onError = function(err)
                        print("[版本] 保存失败:" .. tostring(err) .. "，仍然强制更新")
                        GameSession.buildOutdatedScreen(cloudVer, CFG.GAME_VERSION)
                    end,
                })
            end
        end)
    end

    -- 保存状态提示计时
    if saveStatusMsg then
        saveStatusTimer = saveStatusTimer - dt
        if saveStatusTimer <= 0 then
            saveStatusMsg = nil
            saveStatusTimer = 0
        end
    end

    -- UI脏标记刷新
    if uiDirty and currentView == "combat" and uiRebuildCooldown <= 0 and scrollInteractionTimer <= 0 then
        uiDirty = false
        uiRebuildCooldown = quickCombat and 3.0 or UI_REBUILD_MIN_INTERVAL
        refreshUI()
    end
end

-- ============================================================================
-- 引擎生命周期
-- ============================================================================

function Start()
    SampleStart()

    UI.Init({
        theme = "dark",
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
                bold   = "Fonts/MiSans-Bold.ttf",
            } },
        },
        scale = UI.Scale.DESIGN_RESOLUTION(750, 1334),
    })

    SampleInitMouseMode(MM_FREE)

    -- 伤害飘字模块初始化
    DmgFloat.init()

    -- 会话管理模块初始化
    GameSession.setup({
        addLog = addLog,
        refreshUI = refreshUI,
        buildClassSelect = buildClassSelect,
        setPlayer = function(p)
            player = p
            if p then
                currentZone = p.currentZone or 1
                p.currentZone = currentZone
                spawnWaiting = true
                spawnTimer = 0
            end
        end,
        setRootPanel = function(rp) rootPanel = rp end,
        getPlayer = function() return player end,
        getState = function(key)
            if key == "isKickedOffline" then return isKickedOffline end
        end,
        setState = function(key, val)
            if key == "isKickedOffline" then isKickedOffline = val end
        end,
    })

    GameSession.buildLoadingScreen("正在加载存档...")
    GameSession.tryLoadSave()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("InputFocus", "HandleInputFocus")

    print("=== 暗黑挂机爽刷装备版本 启动 ===")
end

--- 焦点变化事件: 失焦时立即保存存档
function HandleInputFocus(eventType, eventData)
    local focus = eventData:GetBool("Focus")
    if not focus and player then
        print("[存档] 检测到失去焦点，立即保存存档...")
        SaveSys.saveImmediate(player, {
            onSuccess = function()
                print("[存档] 失焦保存成功")
            end,
            onError = function(err)
                print("[存档] 失焦保存失败: " .. tostring(err))
            end,
        })
    end
end

function Stop()
    if player then
        SaveSys.markDirty()
        print("[存档] 引擎关闭，尝试最终保存...")
        SaveSys.saveImmediate(player)
    end
    DmgFloat.cleanup()
    UI.Shutdown()
end
