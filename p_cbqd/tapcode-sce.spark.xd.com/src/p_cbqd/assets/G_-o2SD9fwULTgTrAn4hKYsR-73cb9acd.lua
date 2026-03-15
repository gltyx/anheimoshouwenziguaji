-- ============================================================================
-- 暗黑挂机爽刷装备版本 - UI 公共工具函数
-- ============================================================================
local SYS = require("systems")
local UI = require("urhox-libs/UI")

local M = {}

-- 辅助: 品质颜色数组转RGBA
function M.qc(colorArr, a)
    return {colorArr[1], colorArr[2], colorArr[3], a or 255}
end

-- 辅助: 面板标题
function M.panelTitle(icon, text)
    return UI.Panel {
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
            UI.Label { text = icon, fontSize = 32 },
            UI.Label {
                text = text,
                fontSize = 32, fontWeight = "bold",
                color = {255, 215, 0, 255},
            },
        },
    }
end

-- 辅助: 属性行 (用于装备详情)
function M.statLine(icon, label, value, color)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingVertical = 4,
        paddingHorizontal = 8,
        children = {
            UI.Label { text = icon, fontSize = 26, width = 36 },
            UI.Label {
                text = label,
                fontSize = 24,
                color = {140, 140, 160, 255},
                width = 100,
            },
            UI.Label {
                text = value,
                fontSize = 24, fontWeight = "bold",
                color = color or {220, 220, 240, 255},
            },
        },
    }
end

-- 辅助: 品质底色 (根据品质索引返回半透明背景色，越高级越醒目)
function M.qualityBg(qualityIdx)
    local CFG = require("config")
    local q = CFG.EQUIP_QUALITIES[qualityIdx]
    if not q then return {28, 28, 40, 255} end
    local c = q.color
    -- 品质越高，底色越明显：alpha 从 35 渐增到 90
    local minA, maxA = 35, 90
    local t = math.min((qualityIdx - 1) / (#CFG.EQUIP_QUALITIES - 1), 1.0)
    local a = math.floor(minA + t * (maxA - minA))
    -- 红色以上(idx>=6)混合比例更高，底色更醒目
    local blend = 0.25
    if qualityIdx >= 10 then blend = 0.50
    elseif qualityIdx >= 7 then blend = 0.40
    elseif qualityIdx >= 6 then blend = 0.32
    end
    local base = 18
    local r = math.floor(base + c[1] * blend)
    local g = math.floor(base + c[2] * blend)
    local b = math.floor(base + c[3] * blend)
    -- 红色以上放宽亮度上限
    local cap = qualityIdx >= 6 and 120 or 80
    return {math.min(r, cap), math.min(g, cap), math.min(b, cap), a + 175}
end

-- 品阶前缀图标 (红色以上)
local QUALITY_ICONS = {
    [6]  = "★",   -- 红
    [7]  = "✦",   -- 黄金
    [8]  = "◆",   -- 铂金
    [9]  = "💎",  -- 钻石
    [10] = "🔥",  -- 暗金
    [11] = "⚡",  -- 神话
    [12] = "👑",  -- 至尊
}

-- 辅助: 品阶标签 (小Tag显示品质名，红色以上带特殊图标)
function M.qualityTag(qualityIdx)
    local CFG = require("config")
    local q = CFG.EQUIP_QUALITIES[qualityIdx]
    if not q then return nil end
    local icon = QUALITY_ICONS[qualityIdx] or ""
    local label = icon ~= "" and (icon .. q.name) or q.name
    local c = q.color
    -- 红色以上：品质色背景 + 白字；普通：深底 + 品质色字
    if qualityIdx >= 6 then
        return UI.Label {
            text = label,
            fontSize = 20, fontWeight = "bold",
            color = {255, 255, 255, 255},
            backgroundColor = {c[1], c[2], c[3], 200},
            borderRadius = 4,
            paddingHorizontal = 6,
            paddingVertical = 2,
            flexShrink = 0,
        }
    else
        return UI.Label {
            text = q.name,
            fontSize = 20,
            color = {c[1], c[2], c[3], 220},
            backgroundColor = {c[1], c[2], c[3], 40},
            borderRadius = 4,
            paddingHorizontal = 6,
            paddingVertical = 2,
            flexShrink = 0,
        }
    end
end

-- 辅助: 高品质卡片边框样式 (红色以上递进加强)
function M.qualityCardStyle(qualityIdx)
    local CFG = require("config")
    local q = CFG.EQUIP_QUALITIES[qualityIdx]
    if not q or qualityIdx < 6 then return {} end
    local c = q.color
    local bc = {c[1], c[2], c[3], 200}
    if qualityIdx >= 12 then
        -- 至尊：全边框 3px
        return { border = 3, borderColor = bc, nameFontSize = 12, nameBold = true }
    elseif qualityIdx >= 10 then
        -- 暗金/神话：全边框 2px
        return { border = 2, borderColor = bc, nameFontSize = 12, nameBold = true }
    elseif qualityIdx >= 7 then
        -- 黄金/铂金/钻石：左3 + 上1
        return { borderLeft = 3, borderTop = 1, borderColor = bc, nameFontSize = 11, nameBold = true }
    else
        -- 红：左3
        return { borderLeft = 3, borderColor = bc, nameFontSize = 11, nameBold = false }
    end
end

-- 辅助: 分割线
function M.divider()
    return UI.Panel { width = "100%", height = 2, backgroundColor = {45, 45, 60, 255}, marginVertical = 6 }
end

--- 辅助: 子标签切换栏
--- @param tabs table[] 形如 { {label="技能", view="skills"}, {label="宝石", view="gems"} }
--- @param currentView string 当前激活的视图名
--- @param ctx table 上下文（需含 onSwitchView）
--- @param activeColor? table 自定义激活按钮背景色 {r,g,b,a}，nil则使用默认 "primary"
function M.subTabBar(tabs, currentView, ctx, activeColor)
    local btns = {}
    for _, t in ipairs(tabs) do
        local isActive = (currentView == t.view)
        local targetView = t.view
        if activeColor then
            btns[#btns + 1] = UI.Button {
                text = t.label,
                fontSize = 24, height = 48,
                flex = 1,
                variant = "ghost",
                backgroundColor = isActive and activeColor or nil,
                color = isActive and {255, 255, 255, 255} or nil,
                fontWeight = isActive and "bold" or "normal",
                borderRadius = 0,
                onClick = function()
                    if ctx.onSwitchView then ctx.onSwitchView(targetView) end
                end,
            }
        else
            btns[#btns + 1] = UI.Button {
                text = t.label,
                fontSize = 24, height = 48,
                flex = 1,
                variant = isActive and "primary" or "ghost",
                borderRadius = 0,
                onClick = function()
                    if ctx.onSwitchView then ctx.onSwitchView(targetView) end
                end,
            }
        end
    end
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 0,
        marginBottom = 4,
        children = btns,
    }
end

return M
