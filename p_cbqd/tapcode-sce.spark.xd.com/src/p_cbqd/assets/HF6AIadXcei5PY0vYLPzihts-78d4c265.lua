-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 排行榜面板
-- ============================================================================
local UI = require("urhox-libs/UI")
local UC = require("ui_common")
local panelTitle, subTabBar = UC.panelTitle, UC.subTabBar

local M = {}

--- 构建排行榜面板
---@param ctx table  需要 ctx.rankData, ctx.rankLoading, ctx.rankError, ctx.onRefreshRank
function M.buildLeaderboardPanel(ctx)
    local rankData = ctx.rankData or {}
    local rankLoading = ctx.rankLoading
    local rankError = ctx.rankError
    local myUserId = ctx.myUserId

    local children = {}

    -- 子标签切换栏: 设置 | 排行榜
    children[#children + 1] = subTabBar(
        { {label = "⚙️ 设置", view = "settings"}, {label = "🏆 排行榜", view = "leaderboard"} },
        "leaderboard", ctx
    )

    -- 标题行 + 刷新按钮
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        paddingVertical = 8,
        paddingHorizontal = 8,
        borderBottom = 2,
        borderColor = {50, 50, 70, 255},
        marginBottom = 8,
        children = {
            UI.Label { text = "🏆", fontSize = 36 },
            UI.Label {
                text = "等级排行榜 TOP50",
                fontSize = 32, fontWeight = "bold",
                color = {255, 215, 0, 255},
                flex = 1,
            },
            UI.Button {
                text = rankLoading and "加载中..." or "🔄 刷新",
                fontSize = 22, height = 48, paddingHorizontal = 16,
                variant = "secondary",
                disabled = rankLoading,
                onClick = function()
                    if ctx.onRefreshRank then ctx.onRefreshRank() end
                end,
            },
        },
    }

    -- 加载中 / 错误 / 空数据
    if rankLoading and #rankData == 0 then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 30, alignItems = "center",
            children = {
                UI.Label { text = "⏳", fontSize = 48 },
                UI.Label { text = "加载中...", fontSize = 28, color = {140, 140, 160, 255}, marginTop = 10 },
            },
        }
    elseif rankError and #rankData == 0 then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 30, alignItems = "center",
            children = {
                UI.Label { text = "❌", fontSize = 48 },
                UI.Label { text = "加载失败，请点击刷新重试", fontSize = 28, color = {255, 120, 100, 255}, marginTop = 10 },
            },
        }
    elseif #rankData == 0 then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 30, alignItems = "center",
            children = {
                UI.Label { text = "📭", fontSize = 48 },
                UI.Label { text = "暂无排行数据", fontSize = 28, color = {140, 140, 160, 255}, marginTop = 10 },
            },
        }
    else
        -- 表头
        children[#children + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            paddingHorizontal = 16,
            paddingVertical = 8,
            backgroundColor = {30, 30, 45, 255},
            borderRadius = 8,
            children = {
                UI.Label { text = "排名", fontSize = 24, fontWeight = "bold", color = {140, 140, 160, 255}, width = 60 },
                UI.Label { text = "玩家", fontSize = 24, fontWeight = "bold", color = {140, 140, 160, 255}, flex = 1 },
                UI.Label { text = "等级", fontSize = 24, fontWeight = "bold", color = {140, 140, 160, 255}, width = 80, textAlign = "right" },
            },
        }

        -- 排行列表
        local listChildren = {}
        for i, entry in ipairs(rankData) do
            local isMe = entry.userId == myUserId
            -- 前3名特殊颜色
            local rankColor
            if i == 1 then rankColor = {255, 215, 0, 255}       -- 金
            elseif i == 2 then rankColor = {200, 200, 210, 255}  -- 银
            elseif i == 3 then rankColor = {205, 127, 50, 255}   -- 铜
            else rankColor = {160, 160, 180, 255} end

            local nameColor = isMe and {100, 220, 255, 255} or {200, 200, 220, 255}
            local bgColor
            if isMe then
                bgColor = {35, 50, 65, 255}
            elseif i <= 3 then
                bgColor = {35, 32, 25, 255}
            elseif i % 2 == 0 then
                bgColor = {28, 28, 38, 255}
            else
                bgColor = {24, 24, 34, 255}
            end

            local rankIcon = ""
            if i == 1 then rankIcon = "🥇"
            elseif i == 2 then rankIcon = "🥈"
            elseif i == 3 then rankIcon = "🥉" end

            local nickname = entry.nickname or "未知"
            if #nickname > 18 then
                nickname = string.sub(nickname, 1, 18) .. ".."
            end

            local nameDisplay = nickname
            if isMe then nameDisplay = nickname .. " (我)" end

            listChildren[#listChildren + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 16,
                paddingVertical = 8,
                backgroundColor = bgColor,
                borderLeft = isMe and 4 or 0,
                borderColor = isMe and {100, 200, 255, 255} or nil,
                borderRadius = 4,
                children = {
                    UI.Label {
                        text = rankIcon ~= "" and rankIcon or tostring(i),
                        fontSize = rankIcon ~= "" and 26 or 22,
                        color = rankColor,
                        width = 60,
                        textAlign = rankIcon ~= "" and "left" or "center",
                    },
                    UI.Label {
                        text = nameDisplay,
                        fontSize = 26,
                        color = nameColor,
                        fontWeight = isMe and "bold" or "normal",
                        flex = 1,
                        flexShrink = 1,
                    },
                    UI.Label {
                        text = "Lv." .. tostring(entry.level or 0),
                        fontSize = 26, fontWeight = "bold",
                        color = rankColor,
                        width = 80,
                        textAlign = "right",
                    },
                },
            }
        end

        children[#children + 1] = ctx.wrapScroll("leaderboard", {
            width = "100%",
            flexGrow = 1,
            flexBasis = 0,
            gap = 2,
            children = listChildren,
        })
    end

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 16,
        gap = 8,
        children = children,
    }
end

return M
