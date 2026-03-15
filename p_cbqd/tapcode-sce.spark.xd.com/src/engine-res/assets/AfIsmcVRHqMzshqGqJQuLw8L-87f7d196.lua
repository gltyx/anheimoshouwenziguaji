-- ============================================================================
-- clientScore API 使用示例 (客户端云变量)
-- 
-- 本文件演示 clientScore API 的所有核心用法，供 AI 参考学习
-- 
-- clientScore: 客户端积分 - 客户端可直接读写云变量
--
-- 数据类型说明:
--   - values (回调第一个参数): 通过 Set/BatchSet():Set() 写入的任意类型值
--   - iscores (回调第二个参数): 通过 SetInt/Add/BatchSet():SetInt()/Add() 写入的整数
--   - 注意: sscores 参数已废弃，不再使用
--
-- 昵称说明:
--   - 用户昵称由 TapTap 账号系统管理，不存储在云变量中
--   - 获取昵称的唯一正确方式: GetUserNickname({ userIds = {...}, onSuccess = ..., onError = ... })
--   - 全局函数，客户端/服务端通用，客户端异步、服务端同步
--   - 详见第 2 节
-- ============================================================================


-- ============================================================================
-- 1. 属性访问
-- ============================================================================

-- 获取当前用户 ID
local userId = clientScore.userId
print("当前用户 ID:", userId)

-- 获取当前地图名称
local mapName = clientScore.mapName
print("当前地图:", mapName)

-- 获取当前用户 ID（通过 lobby，与 clientScore.userId 相同）
local myUserId = lobby:GetMyUserId()
print("Lobby 用户 ID:", myUserId)


-- ============================================================================
-- 2. 获取用户昵称 - GetUserNickname(options)
-- ============================================================================

-- ⚠️ 昵称不存储在云变量中！不要用 clientScore:Set("player_name", ...) 存昵称
-- 昵称由 TapTap 账号系统管理，通过全局函数 GetUserNickname 查询
--
-- sdk:GetUserName() 仅在移动端（Android/iOS）可用
-- 全平台通用的方式是通过 GetUserNickname 查询（客户端异步，服务端同步）
--
-- 参数说明:
--   userIds:   (table) 用户 ID 列表，支持 number 或 string
--   onSuccess: (function) 成功回调，参数 nicknames = { {userId=N, nickname="..."}, ... }
--   onError:   (function) 失败回调，参数 errorCode (-1=内部错误, -2=超时)

-- 查询当前用户昵称
GetUserNickname({
    userIds = { myUserId },
    onSuccess = function(nicknames)
        for _, info in ipairs(nicknames) do
            print(string.format("用户 %s 的昵称: %s",
                tostring(info.userId), tostring(info.nickname)))
        end
    end,
    onError = function(errorCode)
        print("昵称查询失败, errorCode=" .. tostring(errorCode))
    end
})

-- 批量查询多个用户昵称（常用于排行榜场景）
-- GetUserNickname({
--     userIds = { 12345, 67890, 11111 },
--     onSuccess = function(nicknames) ... end
-- })


-- ============================================================================
-- 3. 单个读取 - clientScore:Get(key, events)
-- ============================================================================

-- 读取单个云变量
-- ⚠️ Get 只返回你请求的 key 相关数据！
-- 如果要同时读取多个 key，请使用 BatchGet（见第 7 节）
clientScore:Get("gold", {
    ok = function(values, iscores)
        -- iscores 包含整数类型云变量（通过 SetInt/Add 写入）
        local gold = iscores.gold or 0
        print("金币:", gold)

        -- values 包含任意类型云变量（通过 Set 写入）
        -- 注意: 这里只能拿到 "gold" key 对应的数据
        -- 如果 gold 是通过 SetInt 写入的，它在 iscores 里，不在 values 里
    end,
    error = function(code, reason)
        print("读取失败:", reason)
    end,
    timeout = function()
        print("读取超时")
    end
})


-- ============================================================================
-- 4. 单个写入 - clientScore:Set(key, value, events) [任意类型]
-- ============================================================================

-- Set 支持任意类型值（字符串、表、布尔等），写入到 values 表
-- 适合存储配置、游戏状态等非排行榜数据

-- 保存游戏配置
clientScore:Set("game_config", { difficulty = "hard", music = true, sfx = true }, {
    ok = function()
        print("游戏配置已保存")
    end,
    error = function(code, reason)
        print("保存失败:", reason)
    end
})

-- 保存复杂数据结构（装备、道具等）
clientScore:Set("equipment", {
    weapon = { id = "sword_01", level = 5, enchant = "fire" },
    armor  = { id = "plate_02", level = 3 },
    ring   = { id = "ring_hp",  level = 1 }
}, {
    ok = function()
        print("装备数据已保存")
    end
})


-- ============================================================================
-- 5. 单个写入整数 - clientScore:SetInt(key, value, events)
-- ============================================================================

-- SetInt 写入整数到 iscores 表，可参与排行榜排序
clientScore:SetInt("high_score", 9999, {
    ok = function()
        print("最高分已保存")
    end,
    error = function(code, reason)
        print("保存失败:", reason)
    end
})


-- ============================================================================
-- 6. 单个整数增量 - clientScore:Add(key, delta, events)
-- ============================================================================

-- Add 对整数进行增量操作（delta 可为负数）
clientScore:Add("gold", 100, {
    ok = function()
        print("金币增加成功!")
    end
})

-- 减少金币
clientScore:Add("gold", -50, {
    ok = function()
        print("消费成功!")
    end
})


-- ============================================================================
-- 7. 批量读取 - clientScore:BatchGet()
-- ============================================================================

-- 一次读取多个云变量（推荐：比多次 Get 更高效）
clientScore:BatchGet()
    :Key("gold")
    :Key("exp")
    :Key("level")
    :Key("game_config")
    :Fetch({
        ok = function(values, iscores)
            print("金币:", iscores.gold or 0)
            print("经验:", iscores.exp or 0)
            print("等级:", iscores.level or 1)

            -- values 中获取任意类型数据
            local config = values.game_config
            if config then
                print("难度:", config.difficulty or "normal")
            end
        end,
        error = function(code, reason)
            print("批量读取失败:", reason)
        end
    })


-- ============================================================================
-- 8. 批量写入 - clientScore:BatchSet()
-- ============================================================================

-- 一次写入多个云变量（链式调用）
clientScore:BatchSet()
    :Set("game_config", { difficulty = "normal" })  -- 任意类型值 -> values
    :SetInt("gold", 100)                             -- 整数值 -> iscores（可排行榜排序）
    :SetInt("exp", 500)                              -- 整数值 -> iscores
    :Add("play_count", 1)                            -- 整数增量 -> iscores
    :Save("游戏奖励", {
        ok = function()
            print("批量保存成功")
        end,
        error = function(code, reason)
            print("批量保存失败:", reason)
        end
    })

-- BatchSet 支持的方法:
-- :Set(key, value)     设置任意类型值 -> values
-- :SetInt(key, value)  设置整数值 -> iscores（可参与排行榜排序）
-- :Add(key, delta)     增加整数值 -> iscores（delta 可以是负数）
-- :Delete(key)         删除云变量
-- :Save(desc, events)  保存所有变更


-- ============================================================================
-- 9. 获取排行榜 - clientScore:GetRankList(key, start, count, events, ...)
-- ============================================================================

-- 排行榜只能基于 iscores 中的整数值进行排序
--
-- 排行榜每条 item 的字段:
--   item.userId   (number) 用户 ID（推荐使用）
--   item.player   (number) 用户 ID（旧名称，等同于 userId，保留兼容）
--   item.iscore   (table)  该用户的整数云变量（通过 SetInt/Add 写入）
--   item.score    (table)  该用户的任意类型云变量（通过 Set 写入）
--
-- ⚠️ 排行榜不包含昵称！需要昵称请用 GetUserNickname()
--
-- 附加字段: 在 events 参数之后可以传入额外的 key 名称，
-- 排行榜返回时会同时携带这些字段的数据（减少额外请求）

clientScore:GetRankList("gold", 0, 10, {
    ok = function(rankList)
        print("排行榜 (共 " .. #rankList .. " 人):")
        for i, item in ipairs(rankList) do
            local gold = item.iscore.gold or 0
            local playCount = item.iscore.play_count or 0  -- 附加字段
            local isMe = item.userId == clientScore.userId
            print(string.format("#%d  用户:%s  金币:%d  场次:%d%s",
                i, tostring(item.userId), gold, playCount,
                isMe and " (我)" or ""))
        end

        -- 查询排行榜中所有玩家的昵称
        if #rankList > 0 then
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, item.userId)
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    for _, info in ipairs(nicknames) do
                        print(string.format("用户 %s 昵称: %s",
                            tostring(info.userId), info.nickname))
                    end
                end
            })
        end
    end,
    error = function(code, reason)
        print("获取排行榜失败:", reason)
    end
}, "play_count")  -- ← 附加字段: 同时获取每个玩家的 play_count


-- ============================================================================
-- 10. 获取用户排名 - clientScore:GetUserRank(userId, key, events)
-- ============================================================================

clientScore:GetUserRank(clientScore.userId, "gold", {
    ok = function(rank, scoreValue)
        if rank then
            print("你的排名: #" .. rank .. " (金币: " .. tostring(scoreValue or 0) .. ")")
        else
            print("你还未上榜")
        end
    end,
    error = function(code, reason)
        print("获取排名失败:", reason)
    end
})


-- ============================================================================
-- 11. 获取排行榜总人数 - clientScore:GetRankTotal(key, events)
-- ============================================================================

clientScore:GetRankTotal("gold", {
    ok = function(total)
        print("排行榜共有 " .. total .. " 人上榜")
    end,
    error = function(code, reason)
        print("获取总人数失败:", reason)
    end
})


-- ============================================================================
-- 实际使用场景示例
-- ============================================================================

-- 场景1: 游戏开始时加载玩家数据
function LoadPlayerData(callback)
    clientScore:BatchGet()
        :Key("gold")
        :Key("exp")
        :Key("level")
        :Key("high_score")
        :Key("equipment")
        :Fetch({
            ok = function(values, iscores)
                local playerData = {
                    gold = iscores.gold or 0,
                    exp = iscores.exp or 0,
                    level = iscores.level or 1,
                    highScore = iscores.high_score or 0,
                    equipment = values.equipment or {}
                }
                if callback then callback(playerData) end
            end,
            error = function(code, reason)
                print("加载玩家数据失败:", reason)
            end
        })
end

-- 场景2: 游戏结束时保存分数
function SaveGameResult(score, goldEarned)
    clientScore:BatchSet()
        :Add("gold", goldEarned)
        :Add("play_count", 1)
        :SetInt("last_score", score)
        :Save("游戏结束", {
            ok = function()
                print("游戏结果已保存")
            end
        })
end

-- 场景3: 更新最高分（如果新分数更高）
function UpdateHighScore(newScore, callback)
    clientScore:Get("high_score", {
        ok = function(values, iscores)
            local currentHighScore = iscores.high_score or 0
            if newScore > currentHighScore then
                clientScore:SetInt("high_score", newScore, {
                    ok = function()
                        print("新纪录! 最高分更新为:", newScore)
                        if callback then callback(true) end
                    end
                })
            else
                if callback then callback(false) end
            end
        end
    })
end

-- 场景4: 显示排行榜（带昵称 + 附加数据）
function ShowLeaderboard(topN, callback)
    -- GetRankList 最后的可变参数是附加字段名，会同时返回这些字段
    clientScore:GetRankList("high_score", 0, topN or 10, {
        ok = function(rankList)
            local leaderboard = {}
            local userIds = {}
            for i, item in ipairs(rankList) do
                table.insert(leaderboard, {
                    rank = i,
                    userId = item.userId,
                    nickname = nil,  -- 昵称稍后异步填充
                    score = item.iscore.high_score or 0,
                    playCount = item.iscore.play_count or 0,  -- 附加字段
                    isMe = item.userId == clientScore.userId
                })
                table.insert(userIds, item.userId)
            end

            if #userIds == 0 then
                if callback then callback(leaderboard) end
                return
            end

            -- 使用统一接口查询昵称，无需手动订阅/取消事件
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nicknameMap = {}
                    for _, info in ipairs(nicknames) do
                        nicknameMap[info.userId] = info.nickname or ""
                    end
                    for _, entry in ipairs(leaderboard) do
                        entry.nickname = nicknameMap[entry.userId] or "未知玩家"
                    end
                    if callback then callback(leaderboard) end
                end,
                onError = function(errorCode)
                    -- 昵称查询失败，仍返回排行榜数据（昵称为空）
                    if callback then callback(leaderboard) end
                end
            })
        end
    }, "play_count")  -- ← 附加字段
end

-- 场景4 使用示例:
-- ShowLeaderboard(10, function(leaderboard)
--     for _, entry in ipairs(leaderboard) do
--         print(string.format("#%d  %s (ID:%s)  分数:%d  场次:%d%s",
--             entry.rank,
--             entry.nickname or "???",
--             tostring(entry.userId),
--             entry.score,
--             entry.playCount,
--             entry.isMe and " ← 我" or ""))
--     end
-- end)
