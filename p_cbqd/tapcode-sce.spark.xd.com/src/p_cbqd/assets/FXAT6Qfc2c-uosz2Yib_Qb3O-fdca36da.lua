-- ============================================================================
-- 存档系统模块 (云存档 + 反作弊 + 自动保存)
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")

local M = {}

-- 云存档 Key
local KEY_CORE   = "save_core"
local KEY_EQUIP  = "save_equip"
local KEY_SKILLS = "save_skills"
local KEY_LEVEL  = "player_level"  -- SetInt, 可用于排行榜
local KEY_SESSION = "session_token" -- 会话标识 (单设备登录互踢)
local KEY_EQUIP_BAK = "save_equip_bak"  -- 装备备份 (防丢失)
local KEY_CORE_BAK  = "save_core_bak"   -- 核心数据备份 (防丢失)
local KEY_SKILLS_BAK = "save_skills_bak" -- 技能数据备份 (防丢失)

-- 状态管理
M.isSaving = false
M.isLoading = false
M.saveDirty = false
M.dirtyVersion = 0        -- 脏数据版本号 (每次markDirty递增, 保存时快照比较)
M.lastSaveTime = 0        -- os.clock() 上次保存时间
M.autoSaveTimer = 0       -- 自动保存计时器
M.lastActionTime = 0      -- 上次玩家操作时间 (os.clock)
M.actionIdleTimer = 0     -- 操作空闲计时器 (距上次操作的秒数)
M.saveError = nil          -- 最近保存错误信息
M.loadError = nil          -- 最近加载错误信息
M.lastSaveKillCount = 0   -- 上次保存时的击杀数 (用于击杀速率检测)
M.cheatFlags = {}          -- 累积异常标记 { {reason, timestamp}, ... }

-- 会话管理 (单设备登录互踢)
M.sessionId = nil          -- 当前会话 ID
M.sessionCheckTimer = 0    -- 会话检查计时器
M.isKicked = false         -- 是否已被踢下线
M.isCheckingSession = false -- 是否正在检查会话
local SESSION_CHECK_INTERVAL = 8  -- 会话检查间隔(秒)

-- ============================================================================
-- 反作弊: 校验和计算
-- ============================================================================

--- 简易哈希函数 (djb2 变体 + 盐值)
---@param str string
---@return number
local function simpleHash(str)
    local h = 5381
    for i = 1, #str do
        h = ((h << 5) + h + string.byte(str, i)) & 0x7FFFFFFF
    end
    return h
end

--- 计算玩家数据校验和
---@param core table 核心存档数据
---@return number checksum
function M.calcChecksum(core)
    -- 选取关键数值字段拼接并哈希
    local parts = {
        tostring(core.classId or ""),
        tostring(core.level or 0),
        tostring(core.gold or 0),
        tostring(core.diamonds or 0),
        tostring(core.tickets or 0),
        tostring(core.vipLevel or 0),
        tostring(core.killCount or 0),
        tostring(core.equipFragments or 0),
        tostring(core.skillFragments or 0),
        CFG.ANTI_CHEAT_SALT,
    }
    return simpleHash(table.concat(parts, "|"))
end

-- ============================================================================
-- 反作弊: 数据验证
-- ============================================================================

--- 范围检查 (基础字段 + 攻速 + 经验 + 钻石 + 击杀数)
---@param core table
---@return boolean ok
---@return string? reason
function M.validateRange(core)
    -- ====== 基础字段 ======
    -- 职业必须存在
    if core.classId and not CFG.CLASS_BY_ID[core.classId] and not CFG.CLASSES[core.classId] then
        return false, "职业不存在: " .. tostring(core.classId)
    end
    -- 等级 1 ~ AC_MAX_LEVEL
    if core.level then
        if core.level < 1 or core.level > CFG.AC_MAX_LEVEL then
            return false, "等级异常: " .. tostring(core.level)
        end
    end
    -- VIP 0-3
    if core.vipLevel and (core.vipLevel < 0 or core.vipLevel > 3) then
        return false, "VIP等级异常: " .. tostring(core.vipLevel)
    end

    -- ====== 钻石异常检测 ======
    if core.diamonds then
        if core.diamonds < 0 then
            return false, "钻石异常(负数): " .. tostring(core.diamonds)
        end
        if core.diamonds > CFG.AC_MAX_DIAMONDS then
            return false, "钻石异常(超上限): " .. tostring(core.diamonds)
        end
    end

    -- ====== 金币异常检测 ======
    if core.gold then
        if core.gold < 0 then
            return false, "金币异常(负数): " .. tostring(core.gold)
        end
        if core.gold > CFG.AC_MAX_GOLD then
            return false, "金币异常(超上限): " .. tostring(core.gold)
        end
    end

    -- ====== 门票异常检测 ======
    if core.tickets then
        if core.tickets < 0 then
            return false, "门票异常(负数): " .. tostring(core.tickets)
        end
        if core.tickets > CFG.AC_MAX_TICKETS then
            return false, "门票异常(超上限): " .. tostring(core.tickets)
        end
    end

    -- ====== 经验异常检测 ======
    if core.exp then
        -- 经验不能为负
        if core.exp < 0 then
            return false, "经验异常(负数): " .. tostring(core.exp)
        end
        -- 当前经验不应超过升级所需经验 (升级时自动扣除, 正常不会超过)
        if core.expNext and core.expNext > 0 and core.exp > core.expNext * 2 then
            return false, "经验异常(溢出): " .. tostring(core.exp) .. "/" .. tostring(core.expNext)
        end
    end

    -- ====== 击杀数基础检查 ======
    if core.killCount then
        if core.killCount < 0 then
            return false, "击杀数异常(负数): " .. tostring(core.killCount)
        end
        -- 等级与击杀数关联检测: Lv20以上, 每级至少击杀 AC_MIN_KILLS_PER_LV 只怪
        if core.level and core.level >= 20 then
            local minKills = core.level * CFG.AC_MIN_KILLS_PER_LV
            if core.killCount < minKills then
                return false, "击杀数与等级不匹配: Lv." .. core.level .. " 击杀仅" .. core.killCount
            end
        end
    end

    return true
end

--- 攻速异常检测 (反序列化后, 重算属性后调用)
--- 攻速上限2.50由 recalcStats 硬限, 如果反序列化后仍超限则存档被篡改
---@param player table 反序列化并 recalcStats 后的玩家
---@return boolean ok
---@return string? reason
function M.validateAspd(player)
    if player.aspd and player.aspd > CFG.AC_MAX_ASPD then
        return false, "攻速异常: " .. string.format("%.2f", player.aspd) .. " (上限" .. CFG.AC_MAX_ASPD .. ")"
    end
    return true
end

--- 怪物刷新速率异常检测 (保存时调用)
--- 检查两次保存间的击杀增量是否超过理论极限
---@param currentKillCount number 当前击杀数
---@return boolean ok
---@return string? reason
function M.validateKillRate(currentKillCount)
    -- 击杀速度检测已禁用
    return true
end

--- 记录异常标记 (不阻断游戏, 仅记录)
---@param reason string
function M.addCheatFlag(reason)
    M.cheatFlags[#M.cheatFlags + 1] = {
        reason = reason,
        time = os.clock(),
    }
    print("[反作弊] 异常标记: " .. reason)
end

--- 校验和验证
---@param core table
---@return boolean
function M.validateChecksum(core)
    if not core.checksum then return false end
    local expected = M.calcChecksum(core)
    return core.checksum == expected
end

--- 完整验证 (范围 + 校验和)
---@param core table
---@return boolean ok
---@return string? reason
function M.validate(core)
    if not core then return false, "核心数据为空" end

    -- 范围检查
    local rangeOk, rangeMsg = M.validateRange(core)
    if not rangeOk then
        return false, rangeMsg
    end

    -- 版本更新时跳过校验和验证 (版本变化必然导致校验和失效)
    if core.gameVersion and core.gameVersion ~= CFG.GAME_VERSION then
        print("[存档] 版本更新 " .. tostring(core.gameVersion) .. " → " .. CFG.GAME_VERSION .. ", 跳过校验和验证")
        return true
    end

    -- 校验和验证
    if not M.validateChecksum(core) then
        return false, "校验和不匹配"
    end

    return true
end

-- ============================================================================
-- 版本迁移
-- ============================================================================

--- 存档版本迁移 (未来用于兼容旧存档)
---@param core table
---@param equipData table
---@param skillsData table
---@return table core, table equipData, table skillsData
function M.migrateVersion(core, equipData, skillsData)
    local ver = core.saveVersion or 0

    -- 版本 0 → 1: 初始版本，无需迁移
    if ver < 1 then
        core.saveVersion = 1
    end

    -- 版本 1 → 2: 经验曲线同步 (41级后改为恒定x1.1)
    if ver < 2 then
        if core.level and core.level >= 1 then
            local exp = 100
            for lv = 2, core.level do
                local mult
                if lv <= 40 then
                    mult = 1.18
                elseif lv == 41 then
                    mult = 1.18 * 100
                else
                    mult = 1.1
                end
                exp = math.floor(exp * mult)
            end
            local oldExpNext = core.expNext or exp
            core.expNext = exp
            if oldExpNext ~= exp then
                print("[迁移] 经验需求同步: Lv." .. core.level .. " " .. oldExpNext .. " → " .. exp)
            end
            -- 确保当前经验不超过新的升级经验
            if core.exp and core.exp >= core.expNext then
                core.exp = core.expNext - 1
            end
        end
        core.saveVersion = 2
    end

    -- 版本 2 → 3: 经验曲线同步 (42级后改为恒定x1.05)
    if ver < 3 then
        if core.level and core.level >= 1 then
            local exp = 100
            for lv = 2, core.level do
                local mult
                if lv <= 40 then
                    mult = 1.18
                elseif lv == 41 then
                    mult = 1.18 * 100
                else
                    mult = 1.05
                end
                exp = math.floor(exp * mult)
            end
            local oldExpNext = core.expNext or exp
            core.expNext = exp
            if oldExpNext ~= exp then
                print("[迁移] 经验需求同步(v3): Lv." .. core.level .. " " .. oldExpNext .. " → " .. exp)
            end
            if core.exp and core.exp >= core.expNext then
                core.exp = core.expNext - 1
            end
        end
        core.saveVersion = 3
    end

    return core, equipData, skillsData
end

-- ============================================================================
-- 装备备份辅助
-- ============================================================================

--- 检查装备数据是否有实质内容 (身上有装备或背包不空)
---@param equipData table 序列化后的装备数据
---@return boolean
local function hasEquipContent(equipData)
    if not equipData or type(equipData) ~= "table" then return false end
    if equipData.bag and type(equipData.bag) == "table" and #equipData.bag > 0 then return true end
    if equipData.equipment and type(equipData.equipment) == "table" then
        for _, v in pairs(equipData.equipment) do
            if v then return true end
        end
    end
    return false
end

--- 检查核心数据是否有实质内容
---@param core table
---@return boolean
local function hasCoreContent(core)
    if not core or type(core) ~= "table" then return false end
    if core.classId and core.level and core.level >= 1 then return true end
    return false
end

--- 检查技能数据是否有实质内容
---@param skillsData table
---@return boolean
local function hasSkillsContent(skillsData)
    if not skillsData or type(skillsData) ~= "table" then return false end
    if skillsData.skills and type(skillsData.skills) == "table" and #skillsData.skills > 0 then return true end
    if skillsData.gemBag and type(skillsData.gemBag) == "table" and #skillsData.gemBag > 0 then return true end
    return false
end

-- ============================================================================
-- 云存档保存
-- ============================================================================

--- 标记存档为脏 (需要保存)
--- 同时记录操作时间, 用于操作间隔超1秒自动存档
function M.markDirty()
    M.saveDirty = true
    M.dirtyVersion = M.dirtyVersion + 1
    M.lastActionTime = os.clock()
    M.actionIdleTimer = 0  -- 重置空闲计时
end

--- 保存玩家数据到云端
---@param player table 玩家数据
---@param callbacks? table {onSuccess?, onError?}
function M.saveGame(player, callbacks)
    if not player then return end
    if M.isSaving then
        if callbacks and callbacks.onError then
            callbacks.onError("正在保存中")
        end
        return
    end

    -- 最小间隔检查
    local now = os.clock()
    if now - M.lastSaveTime < CFG.SAVE_MIN_INTERVAL then
        if callbacks and callbacks.onError then
            callbacks.onError("保存过于频繁")
        end
        return
    end

    M.isSaving = true
    M.saveError = nil

    -- 保存前: 击杀速率检测
    local krOk, krMsg = M.validateKillRate(player.killCount)
    if not krOk then
        M.addCheatFlag(krMsg)
    end

    -- 序列化
    local core, equipData, skillsData = SYS.serializePlayer(player)

    -- 保存前: 对序列化数据再做一次范围检查 (检测运行时篡改)
    local rangeOk, rangeMsg = M.validateRange(core)
    if not rangeOk then
        M.addCheatFlag("保存时检测: " .. rangeMsg)
    end

    -- 攻速异常检测
    local aspdOk, aspdMsg = M.validateAspd(player)
    if not aspdOk then
        M.addCheatFlag(aspdMsg)
    end

    -- 写入异常标记数量到核心数据 (服务端可据此排查)
    core.cheatFlagCount = #M.cheatFlags

    -- 计算并写入校验和
    core.checksum = M.calcChecksum(core)

    -- 云端批量写入 (含全量备份)
    local killCountSnap = player.killCount
    local savedDirtyVersion = M.dirtyVersion  -- 快照脏版本号
    local batch = clientScore:BatchSet()
        :Set(KEY_CORE, core)
        :Set(KEY_EQUIP, equipData)
        :Set(KEY_SKILLS, skillsData)
        :SetInt(KEY_LEVEL, player.level or 1)
    -- 始终同步备份 (避免备份滞后导致恢复出旧数据)
    batch:Set(KEY_CORE_BAK, core)
    batch:Set(KEY_EQUIP_BAK, equipData)
    batch:Set(KEY_SKILLS_BAK, skillsData)
    batch:Save("自动保存", {
            ok = function()
                M.isSaving = false
                -- 只有保存期间没有新改动才清除dirty
                if M.dirtyVersion == savedDirtyVersion then
                    M.saveDirty = false
                end
                M.lastSaveTime = os.clock()
                M.lastSaveKillCount = killCountSnap
                M.saveError = nil
                if callbacks and callbacks.onSuccess then
                    callbacks.onSuccess()
                end
            end,
            error = function(code, reason)
                M.isSaving = false
                M.saveError = reason or ("错误码:" .. tostring(code))
                if callbacks and callbacks.onError then
                    callbacks.onError(M.saveError)
                end
            end,
        })
end

--- 立即保存 (跳过最小间隔限制, 用于下线/失焦时)
--- 如果没有脏数据则跳过; 如果正在保存中则等待完成后再保存
---@param player table
---@param callbacks? table {onSuccess?, onError?}
function M.saveImmediate(player, callbacks)
    if not player then return end
    if not M.saveDirty then
        -- 无脏数据，直接成功
        if callbacks and callbacks.onSuccess then
            callbacks.onSuccess()
        end
        return
    end
    if M.isSaving then
        -- 正在保存中，标记需要在完成后再存一次（用player引用，序列化在执行时取最新状态）
        M.pendingSaveAfterCurrent = { player = player, callbacks = callbacks }
        return
    end

    M.isSaving = true
    M.saveError = nil

    -- 保存前反作弊检测 (与 saveGame 相同)
    local krOk, krMsg = M.validateKillRate(player.killCount)
    if not krOk then M.addCheatFlag(krMsg) end

    local core, equipData, skillsData = SYS.serializePlayer(player)

    local rangeOk, rangeMsg = M.validateRange(core)
    if not rangeOk then M.addCheatFlag("下线检测: " .. rangeMsg) end

    local aspdOk, aspdMsg = M.validateAspd(player)
    if not aspdOk then M.addCheatFlag(aspdMsg) end

    core.cheatFlagCount = #M.cheatFlags
    core.checksum = M.calcChecksum(core)

    local killCountSnap = player.killCount
    local savedDirtyVersion = M.dirtyVersion  -- 快照脏版本号
    local batch = clientScore:BatchSet()
        :Set(KEY_CORE, core)
        :Set(KEY_EQUIP, equipData)
        :Set(KEY_SKILLS, skillsData)
        :SetInt(KEY_LEVEL, player.level or 1)
    -- 始终同步备份 (避免备份滞后导致恢复出旧数据)
    batch:Set(KEY_CORE_BAK, core)
    batch:Set(KEY_EQUIP_BAK, equipData)
    batch:Set(KEY_SKILLS_BAK, skillsData)
    batch:Save("下线保存", {
            ok = function()
                M.isSaving = false
                -- 只有保存期间没有新改动才清除dirty
                if M.dirtyVersion == savedDirtyVersion then
                    M.saveDirty = false
                end
                M.lastSaveTime = os.clock()
                M.lastSaveKillCount = killCountSnap
                M.saveError = nil
                M.autoSaveTimer = 0
                print("[存档] 下线保存成功")
                if callbacks and callbacks.onSuccess then
                    callbacks.onSuccess()
                end
                -- 保存期间有新改动，自动再存一次
                if M.saveDirty then
                    print("[存档] 保存期间有新改动，自动补存")
                    M.saveImmediate(player)
                elseif M.pendingSaveAfterCurrent then
                    local pending = M.pendingSaveAfterCurrent
                    M.pendingSaveAfterCurrent = nil
                    M.saveImmediate(pending.player, pending.callbacks)
                end
            end,
            error = function(code, reason)
                M.isSaving = false
                M.saveError = reason or ("错误码:" .. tostring(code))
                print("[存档] 下线保存失败: " .. tostring(M.saveError))
                if callbacks and callbacks.onError then
                    callbacks.onError(M.saveError)
                end
                -- 保存失败也要处理排队请求
                if M.pendingSaveAfterCurrent then
                    local pending = M.pendingSaveAfterCurrent
                    M.pendingSaveAfterCurrent = nil
                    M.saveImmediate(pending.player, pending.callbacks)
                end
            end,
        })
end

--- 自动保存检查 (在 HandleUpdate 中调用)
--- 策略: 玩家操作后空闲超过1秒 → 立即存档并上传云端
---@param player table
---@param dt number deltaTime
---@return boolean saved 是否触发了保存
function M.updateAutoSave(player, dt)
    if not player then return false end

    -- 操作间隔检测: 有脏数据 + 距上次操作超过1秒 → 立即保存
    if M.saveDirty and M.lastActionTime > 0 then
        M.actionIdleTimer = M.actionIdleTimer + dt
        if M.actionIdleTimer >= 1.0 then
            M.actionIdleTimer = 0
            M.lastActionTime = 0  -- 防止重复触发
            M.autoSaveTimer = 0   -- 重置常规自动保存计时
            M.saveGame(player, {
                onSuccess = function()
                    print("[存档] 操作间隔保存成功")
                end,
                onError = function(err)
                    print("[存档] 操作间隔保存失败: " .. tostring(err))
                end,
            })
            return true
        end
    end

    -- 兜底: 常规自动保存 (以防操作间隔检测未触发, 如持续挂机战斗)
    M.autoSaveTimer = M.autoSaveTimer + dt
    if M.autoSaveTimer >= CFG.SAVE_INTERVAL and M.saveDirty then
        M.autoSaveTimer = 0
        M.saveGame(player, {
            onSuccess = function()
                print("[存档] 自动保存成功")
            end,
            onError = function(err)
                print("[存档] 自动保存失败: " .. tostring(err))
            end,
        })
        return true
    end
    return false
end

-- ============================================================================
-- 云存档加载
-- ============================================================================

--- 从云端加载玩家数据
---@param callbacks table {onSuccess(player), onNoData(), onError(reason), onCheatDetected?(reason, player)}
---@param retryCount? number 内部重试计数 (外部不传)
function M.loadGame(callbacks, retryCount)
    retryCount = retryCount or 0
    local MAX_RETRIES = 2  -- 最多重试2次 (共3次尝试)

    if M.isLoading then
        if callbacks.onError then
            callbacks.onError("正在加载中")
        end
        return
    end

    M.isLoading = true
    M.loadError = nil

    clientScore:BatchGet()
        :Key(KEY_CORE)
        :Key(KEY_EQUIP)
        :Key(KEY_SKILLS)
        :Key(KEY_EQUIP_BAK)
        :Key(KEY_CORE_BAK)
        :Key(KEY_SKILLS_BAK)
        :Fetch({
            ok = function(values, iscores)
                M.isLoading = false

                local core = values[KEY_CORE]
                local equipData = values[KEY_EQUIP]
                local skillsData = values[KEY_SKILLS]
                local equipBak = values[KEY_EQUIP_BAK]
                local coreBak = values[KEY_CORE_BAK]
                local skillsBak = values[KEY_SKILLS_BAK]

                -- 无存档数据 (主数据和备份都没有)
                if not hasCoreContent(core) and not hasCoreContent(coreBak) then
                    if callbacks.onNoData then
                        callbacks.onNoData()
                    end
                    return
                end

                -- === 数据丢失自动恢复 ===
                local recovered = false

                -- 核心数据丢失: 用备份恢复
                if not hasCoreContent(core) and hasCoreContent(coreBak) then
                    print("[存档] ⚠️ 核心数据丢失! 从备份恢复...")
                    core = coreBak
                    recovered = true
                end

                -- 装备丢失自动恢复: 主数据无装备但备份有效 → 用备份替换
                if not hasEquipContent(equipData) and hasEquipContent(equipBak) then
                    print("[存档] ⚠️ 检测到装备数据丢失! 从备份恢复装备...")
                    equipData = equipBak
                    recovered = true
                end

                -- 技能数据丢失: 用备份恢复
                if not hasSkillsContent(skillsData) and hasSkillsContent(skillsBak) then
                    print("[存档] ⚠️ 技能数据丢失! 从备份恢复...")
                    skillsData = skillsBak
                    recovered = true
                end

                if recovered then
                    print("[存档] 数据恢复完成, 将在登录后自动保存修复后的数据")
                end

                -- 版本迁移 (pcall 保护, 迁移失败不阻断加载)
                local migrateOk, mCore, mEquip, mSkills = pcall(M.migrateVersion, core, equipData, skillsData)
                if migrateOk then
                    core, equipData, skillsData = mCore, mEquip, mSkills
                else
                    print("[存档] ⚠️ 版本迁移出错(已跳过): " .. tostring(mCore))
                end

                -- 反作弊验证 (版本更新时放宽验证)
                local valid, reason = M.validate(core)
                if not valid then
                    print("[存档] 反作弊检测异常: " .. tostring(reason))
                    -- 尝试反序列化，即使数据异常也传给回调
                    local dsOk, cheatPlayer = pcall(SYS.deserializePlayer, core, equipData, skillsData)
                    if not dsOk then
                        print("[存档] 反序列化异常: " .. tostring(cheatPlayer))
                        cheatPlayer = nil
                    end
                    if callbacks.onCheatDetected then
                        callbacks.onCheatDetected(reason, cheatPlayer)
                    else
                        -- 默认处理: 仍然加载数据，但记录异常
                        if cheatPlayer then
                            if callbacks.onSuccess then
                                callbacks.onSuccess(cheatPlayer)
                            end
                        elseif callbacks.onError then
                            callbacks.onError("存档数据损坏")
                        end
                    end
                    return
                end

                -- 反序列化 (pcall 保护)
                local dsOk, player = pcall(SYS.deserializePlayer, core, equipData, skillsData)
                if not dsOk then
                    print("[存档] 反序列化异常: " .. tostring(player))
                    player = nil
                end

                if player then
                    -- 加载后: 攻速异常检测 (recalcStats 已在 deserialize 中调用)
                    local aspdOk, aspdMsg = M.validateAspd(player)
                    if not aspdOk then
                        M.addCheatFlag("加载检测: " .. aspdMsg)
                    end

                    -- 初始化击杀基准 (用于后续击杀速率检测)
                    M.lastSaveKillCount = player.killCount or 0

                    M.saveDirty = recovered  -- 如果恢复了数据，标记需要保存
                    M.autoSaveTimer = 0
                    if callbacks.onSuccess then
                        callbacks.onSuccess(player, core.gameVersion)
                    end
                else
                    -- 反序列化失败, 尝试从纯备份数据恢复
                    if hasCoreContent(coreBak) then
                        print("[存档] 主数据反序列化失败, 尝试从备份恢复...")
                        local bakOk, bakPlayer = pcall(SYS.deserializePlayer, coreBak, equipBak, skillsBak)
                        if not bakOk then
                            print("[存档] 备份反序列化异常: " .. tostring(bakPlayer))
                            bakPlayer = nil
                        end
                        if bakPlayer then
                            M.lastSaveKillCount = bakPlayer.killCount or 0
                            M.saveDirty = true
                            M.autoSaveTimer = 0
                            if callbacks.onSuccess then
                                callbacks.onSuccess(bakPlayer, (coreBak and coreBak.gameVersion) or nil)
                            end
                            return
                        end
                    end
                    if callbacks.onError then
                        callbacks.onError("存档数据损坏")
                    end
                end
            end,
            error = function(code, reason)
                M.isLoading = false
                M.loadError = reason or ("错误码:" .. tostring(code))
                -- 自动重试机制
                if retryCount < MAX_RETRIES then
                    local nextRetry = retryCount + 1
                    print("[存档] 加载失败(第" .. nextRetry .. "次重试): " .. tostring(M.loadError))
                    -- 延迟重试 (使用定时器模拟延迟)
                    M.loadGame(callbacks, nextRetry)
                else
                    print("[存档] 加载失败(已重试" .. MAX_RETRIES .. "次): " .. tostring(M.loadError))
                    if callbacks.onError then
                        callbacks.onError(M.loadError)
                    end
                end
            end,
        })
end

-- ============================================================================
-- 轻量级云端版本检查 (只读取 save_core 的 gameVersion)
-- ============================================================================

--- 从云端检查游戏版本
---@param callback fun(cloudVersion: string|nil) 读取到的云端版本，失败返回 nil
function M.checkCloudVersion(callback)
    clientScore:BatchGet()
        :Key(KEY_CORE)
        :Fetch({
            ok = function(values)
                local core = values[KEY_CORE]
                if core and core.gameVersion then
                    callback(core.gameVersion)
                else
                    callback(nil)
                end
            end,
            error = function()
                callback(nil)
            end,
        })
end

-- ============================================================================
-- 单设备登录互踢 (Session Management)
-- 机制: 登录时写入唯一 sessionId 到云端, 定期轮询检测是否被覆盖
-- ============================================================================

--- 生成唯一会话 ID
---@return string
local function generateSessionId()
    -- 组合: userId + 时间戳 + 随机数，确保唯一
    local uid = clientScore.userId or 0
    local ts = os.clock()
    local rnd = math.random(100000, 999999)
    return tostring(uid) .. "_" .. string.format("%.4f", ts) .. "_" .. tostring(rnd)
end

--- 写入会话标识到云端 (登录时调用)
---@param callback? fun(ok: boolean)
function M.writeSession(callback)
    M.sessionId = generateSessionId()
    M.isKicked = false
    M.sessionCheckTimer = 0
    print("[会话] 写入会话标识: " .. M.sessionId)
    clientScore:Set(KEY_SESSION, M.sessionId, {
        ok = function()
            print("[会话] 会话标识写入成功")
            if callback then callback(true) end
        end,
        error = function(code, reason)
            print("[会话] 会话标识写入失败: " .. tostring(reason))
            -- 写入失败不阻断游戏，但互踢功能可能不生效
            if callback then callback(false) end
        end,
    })
end

--- 检查会话是否仍然有效 (定期调用)
--- 如果云端 sessionId 与本地不同，说明另一台设备登录了
---@param onKicked fun() 被踢下线的回调
function M.checkSession(onKicked)
    if M.isKicked or not M.sessionId then return end
    if M.isCheckingSession then return end

    M.isCheckingSession = true
    clientScore:Get(KEY_SESSION, {
        ok = function(values)
            M.isCheckingSession = false
            local cloudSession = values[KEY_SESSION]
            if cloudSession and cloudSession ~= M.sessionId then
                -- 云端会话被另一台设备覆盖 → 本设备被踢
                print("[会话] 检测到另一台设备登录! 云端:" .. tostring(cloudSession) .. " 本地:" .. M.sessionId)
                M.isKicked = true
                if onKicked then onKicked() end
            end
        end,
        error = function(code, reason)
            M.isCheckingSession = false
            -- 网络错误不触发踢线，静默忽略
            print("[会话] 会话检查失败: " .. tostring(reason))
        end,
    })
end

--- 更新会话检查计时器 (在 HandleUpdate 中调用)
---@param dt number deltaTime
---@param onKicked fun() 被踢下线的回调
function M.updateSessionCheck(dt, onKicked)
    if M.isKicked or not M.sessionId then return end
    M.sessionCheckTimer = M.sessionCheckTimer + dt
    if M.sessionCheckTimer >= SESSION_CHECK_INTERVAL then
        M.sessionCheckTimer = 0
        M.checkSession(onKicked)
    end
end

-- ============================================================================
-- 清除存档 (重生功能)
-- ============================================================================

--- 清除云端所有存档数据
---@param callbacks? table {onSuccess?, onError?}
function M.clearSave(callbacks)
    clientScore:BatchSet()
        :Set(KEY_CORE, {})
        :Set(KEY_EQUIP, {})
        :Set(KEY_SKILLS, {})
        :Set(KEY_EQUIP_BAK, {})
        :Set(KEY_CORE_BAK, {})
        :Set(KEY_SKILLS_BAK, {})
        :SetInt(KEY_LEVEL, 0)
        :Save("重生清档", {
            ok = function()
                M.saveDirty = false
                M.lastSaveTime = 0
                M.lastSaveKillCount = 0
                M.cheatFlags = {}
                M.autoSaveTimer = 0
                print("[存档] 重生清档成功")
                if callbacks and callbacks.onSuccess then
                    callbacks.onSuccess()
                end
            end,
            error = function(code, reason)
                local err = reason or ("错误码:" .. tostring(code))
                print("[存档] 重生清档失败: " .. tostring(err))
                if callbacks and callbacks.onError then
                    callbacks.onError(err)
                end
            end,
        })
end

return M
