-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 顶部头栏 + 底部标签栏 (竖屏重构)
-- 原 ui_left.lua: 左侧栏 → 现在拆分为顶栏 + 底栏
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")
local UI = require("urhox-libs/UI")

local M = {}

-- 区域图标映射 (每个区域独特图标)
local ZONE_ICONS = {
    "🌿", "🌾", "🌲", "⛏️", "🏚️",
    "🐸", "🌋", "❄️", "💀", "🐉",
    "🏰", "🕳️", "👿", "🌀", "⚡",
    "🌑", "🩸", "☄️", "⭐", "👑",
}

-- ============================================================================
-- 顶部头栏 (竖屏: 紧凑的一栏, 高度约 80-100px)
-- 包含: 玩家职业+等级 | HP条 | 货币 | 药水计时器
-- ============================================================================
function M.buildTopHeader(ctx)
    local player = ctx.player
    local cls = CFG.CLASSES[player.classId]
    local hpPct = player.maxHp > 0 and math.floor(player.hp / player.maxHp * 100) or 100
    local expPct = player.expNext > 0 and math.floor(player.exp / player.expNext * 100) or 0

    -- 第一行: 职业图标+等级 + 攻击力 + 货币
    local topRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 16,
        paddingVertical = 6,
        gap = 10,
        children = {
            -- 等级+HP+EXP 竖排
            UI.Panel {
                flex = 1,
                gap = 4,
                children = {
                    -- 名称+等级+攻击
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        children = {
                            UI.Label {
                                text = cls.name,
                                fontSize = 24, fontWeight = "bold",
                                color = {220, 220, 240, 255},
                            },
                            UI.Label {
                                text = "Lv." .. player.level,
                                fontSize = 24, fontWeight = "bold",
                                color = {255, 200, 0, 255},
                            },
                            UI.Panel { flex = 1 },
                            UI.Label {
                                text = "⚔️" .. math.floor(player.atk),
                                fontSize = 22,
                                color = {255, 180, 120, 255},
                            },
                            UI.Label {
                                text = ctx.statsExpanded and "▲" or "▼",
                                fontSize = 20,
                                color = {120, 120, 140, 255},
                            },
                        },
                    },
                    -- HP条 (保存引用供飘字锚点定位)
                    (function()
                    local hpBarPanel = UI.Panel {
                        width = "100%", height = 22,
                        children = {
                            UI.Panel {
                                width = "100%", height = 20,
                                backgroundColor = {50, 20, 20, 255},
                                borderRadius = 10,
                                overflow = "hidden",
                                position = "absolute",
                                children = {
                                    UI.Panel {
                                        width = hpPct .. "%", height = "100%",
                                        backgroundColor = {200, 45, 45, 255},
                                        borderRadius = 10,
                                    },
                                },
                            },
                            UI.Label {
                                text = math.floor(player.hp) .. "/" .. math.floor(player.maxHp),
                                fontSize = 18,
                                color = {255, 255, 255, 255},
                                position = "absolute",
                                width = "100%",
                                height = 20,
                                textAlign = "center",
                            },
                        },
                    }
                    ctx.playerHpBarRef = hpBarPanel
                    return hpBarPanel
                    end)(),
                    -- EXP条
                    UI.Panel {
                        width = "100%", height = 16,
                        children = {
                            UI.Panel {
                                width = "100%", height = 14,
                                backgroundColor = {20, 20, 50, 255},
                                borderRadius = 7,
                                overflow = "hidden",
                                position = "absolute",
                                children = {
                                    UI.Panel {
                                        width = expPct .. "%", height = "100%",
                                        backgroundColor = {60, 100, 200, 255},
                                        borderRadius = 7,
                                    },
                                },
                            },
                            UI.Label {
                                text = "EXP " .. expPct .. "%",
                                fontSize = 16,
                                color = {180, 200, 255, 255},
                                position = "absolute",
                                width = "100%",
                                height = 14,
                                textAlign = "center",
                            },
                        },
                    },
                },
            },
        },
    }

    -- 第二行: 货币 + 药水计时器
    local currencyItems = {
        UI.Label { text = "💰" .. SYS.formatGold(player.gold), fontSize = 22, fontWeight = "bold", color = {255, 215, 0, 255} },
        UI.Label { text = "💎" .. player.diamonds, fontSize = 22, fontWeight = "bold", color = {185, 242, 255, 255} },
        UI.Label { text = "🎫" .. player.tickets, fontSize = 22, fontWeight = "bold", color = {255, 180, 100, 255} },
        UI.Label { text = "🔥" .. (player.hellTickets or 0), fontSize = 22, fontWeight = "bold", color = {255, 100, 50, 255} },
    }

    -- 药水倒计时
    local dropTimer = player.dropPotionTimer or 0
    local expTimer = player.expPotionTimer or 0
    if dropTimer > 0 then
        currencyItems[#currencyItems + 1] = UI.Panel {
            flexDirection = "row", alignItems = "center", gap = 4,
            paddingHorizontal = 8, paddingVertical = 4,
            backgroundColor = {50, 35, 15, 255}, borderRadius = 6,
            children = {
                UI.Label { text = "🧪", fontSize = 20 },
                UI.Label { text = "爆率", fontSize = 18, color = {255, 200, 100, 255} },
                UI.Label { text = SYS.formatPotionTime(dropTimer), fontSize = 18,
                    color = dropTimer <= 300 and {255, 80, 80, 255} or {255, 220, 150, 255} },
            },
        }
    end
    if expTimer > 0 then
        currencyItems[#currencyItems + 1] = UI.Panel {
            flexDirection = "row", alignItems = "center", gap = 4,
            paddingHorizontal = 8, paddingVertical = 4,
            backgroundColor = {15, 35, 50, 255}, borderRadius = 6,
            children = {
                UI.Label { text = "📘", fontSize = 20 },
                UI.Label { text = "经验", fontSize = 18, color = {120, 200, 255, 255} },
                UI.Label { text = SYS.formatPotionTime(expTimer), fontSize = 18,
                    color = expTimer <= 300 and {255, 80, 80, 255} or {150, 220, 255, 255} },
            },
        }
    end

    local currencyRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        alignItems = "center",
        paddingHorizontal = 16,
        paddingVertical = 4,
        gap = 12,
        children = currencyItems,
    }

    -- 版本号 (顶部居中)
    local versionLabel = UI.Panel {
        width = "100%",
        alignItems = "center",
        children = {
            UI.Label {
                text = "v" .. CFG.GAME_VERSION,
                fontSize = 16,
                color = {80, 80, 100, 255},
            },
        },
    }

    local headerChildren = {
        topRow,
        currencyRow,
        versionLabel,
    }

    -- 如果属性面板展开, 在头栏下方追加详细属性
    if ctx.statsExpanded then
        headerChildren[#headerChildren + 1] = UI.Panel {
            width = "100%", height = 2, backgroundColor = {50, 50, 70, 255},
        }
        headerChildren[#headerChildren + 1] = M.buildExpandedStats(ctx)
    end

    return UI.Panel {
        width = "100%",
        flexShrink = 0,
        backgroundColor = {18, 18, 28, 255},
        borderBottom = 2,
        borderColor = {50, 50, 70, 255},
        children = headerChildren,
    }
end

-- ============================================================================
-- 展开的属性面板 (在顶栏下方展开)
-- ============================================================================
function M.buildExpandedStats(ctx)
    local player = ctx.player

    local function statRow(icon, label, value, color)
        return UI.Panel {
            width = "50%",
            height = 36,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 12,
            children = {
                UI.Label {
                    text = icon .. " ",
                    fontSize = 22,
                    color = color or {180, 180, 200, 255},
                    width = 36,
                },
                UI.Label {
                    text = label .. ":",
                    fontSize = 22,
                    color = {140, 140, 160, 255},
                    width = 80,
                },
                UI.Label {
                    text = value,
                    fontSize = 22,
                    fontWeight = "bold",
                    color = color or {220, 220, 240, 255},
                    flex = 1,
                },
            },
        }
    end

    local statsChildren = {}

    -- 核心属性 - 两列排布
    statsChildren[#statsChildren + 1] = UI.Panel {
        width = "100%", flexDirection = "row", flexWrap = "wrap",
        children = {
            statRow("⚔️", "攻击", tostring(math.floor(player.atk)), {255, 180, 120, 255}),
            statRow("🛡️", "防御", tostring(math.floor(player.def)), {120, 180, 255, 255}),
            statRow("⚡", "攻速", string.format("%.2f", player.aspd) .. "/" .. string.format("%.1f", CFG.CLASS_MAX_ASPD[player.classId] or 2.5), {255, 230, 100, 255}),
            statRow("💥", "暴击", string.format("%.0f%%", player.crit), {255, 100, 100, 255}),
            statRow("💀", "暴伤", string.format("%.0f%%", player.critDmg), {255, 80, 80, 255}),
            statRow("🛡️", "抗暴", string.format("%.0f%%", player.antiCrit), {100, 200, 255, 255}),
            statRow("🛡️", "抗伤", string.format("%.0f%%", player.antiCritDmg), {100, 200, 255, 255}),
            statRow("❤️", "吸血", string.format("%.1f%%", player.lifesteal), {255, 120, 160, 255}),
            statRow("🗡️", "穿透", string.format("%.1f%%", player.penetration), {255, 160, 80, 255}),
            statRow("📈", "经验", string.format("+%.0f%%", player.expBonus), {120, 255, 120, 255}),
            statRow("💰", "金币", string.format("+%.0f%%", player.goldBonus), {255, 215, 0, 255}),
            statRow("🎯", "掉落率", string.format("+%.0f%%", player.equipDropBonus or 0), {255, 140, 200, 255}),
        },
    }

    -- 称号区域
    local titleItems = {}
    if player.titles then
        for _, td in ipairs(CFG.TITLES) do
            if player.titles[td.id] then
                local bonusParts = {}
                local b = td.bonuses
                if b.atk then bonusParts[#bonusParts + 1] = "攻击+" .. b.atk end
                if b.def then bonusParts[#bonusParts + 1] = "防御+" .. b.def end
                if b.equipDropBonus then bonusParts[#bonusParts + 1] = "掉落率+" .. b.equipDropBonus .. "%" end
                if b.enhanceBonus then bonusParts[#bonusParts + 1] = "强化率+" .. b.enhanceBonus .. "%" end
                if b.crit then bonusParts[#bonusParts + 1] = "暴击+" .. b.crit .. "%" end
                local bonusText = table.concat(bonusParts, " ")
                titleItems[#titleItems + 1] = UI.Panel {
                    width = "50%",
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    height = 32,
                    paddingHorizontal = 12,
                    children = {
                        UI.Label {
                            text = td.icon .. " " .. td.name,
                            fontSize = 20, fontWeight = "bold",
                            color = td.color,
                            flexShrink = 1,
                        },
                        UI.Label {
                            text = bonusText,
                            fontSize = 18,
                            color = {100, 255, 100, 255},
                        },
                    },
                }
            else
                titleItems[#titleItems + 1] = UI.Panel {
                    width = "50%",
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    height = 32,
                    paddingHorizontal = 12,
                    children = {
                        UI.Label {
                            text = "🔒 ???",
                            fontSize = 20,
                            color = {80, 80, 100, 255},
                        },
                        UI.Label {
                            text = "未解锁",
                            fontSize = 18,
                            color = {80, 80, 100, 255},
                        },
                    },
                }
            end
        end
    end

    if #titleItems > 0 then
        statsChildren[#statsChildren + 1] = UI.Panel { width = "100%", height = 2, backgroundColor = {50, 50, 70, 255}, marginVertical = 4 }
        statsChildren[#statsChildren + 1] = UI.Label {
            text = "隐藏称号",
            fontSize = 22, fontWeight = "bold",
            color = {200, 180, 255, 255},
            width = "100%",
            textAlign = "center",
            marginBottom = 4,
        }
        statsChildren[#statsChildren + 1] = UI.Panel {
            width = "100%", flexDirection = "row", flexWrap = "wrap",
            children = titleItems,
        }
    end

    return UI.Panel {
        width = "100%",
        padding = 8,
        backgroundColor = {28, 28, 40, 255},
        children = statsChildren,
    }
end

-- ============================================================================
-- 独立人物属性面板 (作为底部标签入口的全屏视图)
-- 包含子标签: 人物 | 装备
-- ============================================================================
function M.buildStatsPanel(ctx)
    local player = ctx.player
    local cls = CFG.CLASSES[player.classId]
    local hpPct = player.maxHp > 0 and math.floor(player.hp / player.maxHp * 100) or 100

    local UC = require("ui_common")

    local children = {}

    -- 子标签切换栏: 人物 | 装备 (橙色调)
    children[#children + 1] = UC.subTabBar(
        { {label = "👤 人物", view = "stats"}, {label = "🛡 装备", view = "equip"} },
        "stats", ctx, {180, 110, 40, 255}
    )

    children[#children + 1] = UC.panelTitle("👤", cls.icon .. " " .. cls.name .. " Lv." .. player.level)

    -- HP 信息
    children[#children + 1] = UI.Panel {
        width = "100%", paddingHorizontal = 8, gap = 4,
        children = {
            UI.Panel {
                width = "100%", height = 24,
                backgroundColor = {50, 20, 20, 255},
                borderRadius = 12, overflow = "hidden",
                children = {
                    UI.Panel {
                        width = hpPct .. "%", height = "100%",
                        backgroundColor = hpPct > 50 and {60, 160, 60, 255} or hpPct > 20 and {200, 160, 30, 255} or {180, 40, 40, 255},
                        borderRadius = 12,
                    },
                    UI.Label {
                        text = "HP " .. math.floor(player.hp) .. "/" .. math.floor(player.maxHp),
                        fontSize = 18, color = {255, 255, 255, 255},
                        position = "absolute", width = "100%", height = 24, textAlign = "center",
                    },
                },
            },
        },
    }

    -- 详细属性
    children[#children + 1] = M.buildExpandedStats(ctx)

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12, gap = 8,
        children = children,
    }
end

-- ============================================================================
-- 底部标签栏 (6个主要标签)
-- 战斗(+精英) | 人物(+装备) | 背包 | 技能 | 商店 | 更多
-- ============================================================================
function M.buildBottomTabBar(ctx)
    local tabs = {
        { icon = "⚔️", label = "战斗",  views = {"combat", "elite"}, defaultView = "combat" },
        { icon = "👤", label = "人物",  views = {"stats", "equip", "equipDetail", "gemSelect"}, defaultView = "stats" },
        { icon = "🎒", label = "背包",  view = "inventory" },
        { icon = "⚡", label = "技能",  views = {"skills", "gems"}, defaultView = "skills" },
        { icon = "🏪", label = "黑市",  view = "market" },
        { icon = "📋", label = "更多",  views = {"settings", "leaderboard"}, defaultView = "settings" },
    }

    local tabButtons = {}
    for _, tab in ipairs(tabs) do
        -- 判断当前tab是否激活
        local isActive = false
        if tab.view then
            isActive = (ctx.currentView == tab.view)
        elseif tab.views then
            for _, v in ipairs(tab.views) do
                if ctx.currentView == v then isActive = true; break end
            end
        end

        local targetView = tab.view or tab.defaultView
        local tabView = targetView

        tabButtons[#tabButtons + 1] = UI.Button {
            flex = 1,
            height = 80,
            variant = "ghost",
            borderRadius = 0,
            backgroundColor = isActive and {45, 45, 65, 255} or {18, 18, 28, 255},
            borderTop = isActive and 3 or 0,
            borderColor = isActive and {100, 180, 255, 255} or nil,
            onClick = function()
                if ctx.onSwitchView then ctx.onSwitchView(tabView) end
            end,
            children = {
                UI.Panel {
                    width = "100%", height = "100%",
                    justifyContent = "center",
                    alignItems = "center",
                    gap = 4,
                    children = {
                        UI.Label {
                            text = tab.icon,
                            fontSize = 24,
                        },
                        UI.Label {
                            text = tab.label,
                            fontSize = 18,
                            fontWeight = isActive and "bold" or "normal",
                            color = isActive and {100, 180, 255, 255} or {140, 140, 160, 255},
                        },
                    },
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        height = 80,
        flexShrink = 0,
        flexDirection = "row",
        backgroundColor = {18, 18, 28, 255},
        borderTop = 2,
        borderColor = {50, 50, 70, 255},
        children = tabButtons,
    }
end

-- ============================================================================
-- 区域列表 (保留, 供 ui_combat.lua 调用)
-- ============================================================================
function M.buildZoneList(ctx)
    local player = ctx.player
    local children = {}

    -- 标题行 (可折叠)
    children[#children + 1] = UI.Button {
        width = "100%",
        height = 48,
        variant = "ghost",
        onClick = function()
            if ctx.onToggleZones then ctx.onToggleZones() end
        end,
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 12,
                gap = 8,
                children = {
                    UI.Label { text = "📍", fontSize = 24 },
                    UI.Label {
                        text = "区域选择",
                        fontSize = 24, fontWeight = "bold",
                        color = {255, 215, 0, 255},
                    },
                    UI.Panel { flex = 1 },
                    UI.Label {
                        text = ctx.zonesExpanded and "▲ 收起" or "▼ 展开",
                        fontSize = 20,
                        color = {120, 120, 140, 255},
                    },
                },
            },
        },
    }

    -- 如果折叠了只显示当前区域
    if not ctx.zonesExpanded then
        local curZone = CFG.ZONES[ctx.currentZone]
        if curZone then
            local icon = ZONE_ICONS[ctx.currentZone] or "📍"
            children[#children + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingVertical = 8,
                paddingHorizontal = 16,
                gap = 8,
                backgroundColor = {40, 55, 40, 255},
                borderLeft = 4,
                borderColor = {80, 200, 80, 255},
                children = {
                    UI.Label { text = icon, fontSize = 24, width = 36 },
                    UI.Label {
                        text = curZone.name,
                        fontSize = 24, fontWeight = "bold",
                        color = {curZone.color[1], curZone.color[2], curZone.color[3], 255},
                    },
                    UI.Panel { flex = 1 },
                    UI.Label {
                        text = "Lv." .. curZone.reqLv,
                        fontSize = 20,
                        color = {140, 140, 160, 255},
                    },
                },
            }
        end
        return UI.Panel {
            width = "100%",
            flexShrink = 0,
            backgroundColor = {22, 22, 32, 255},
            children = children,
        }
    end

    -- 展开: 显示所有区域
    for i, zone in ipairs(CFG.ZONES) do
        local locked = player.level < zone.reqLv
        local isCurrent = (i == ctx.currentZone) and not ctx.eliteMode
        local icon = ZONE_ICONS[i] or "📍"
        local zoneIdx = i

        local nameColor = locked and {80, 80, 100, 255}
            or {zone.color[1], zone.color[2], zone.color[3], 255}
        local bgColor = isCurrent and {40, 55, 40, 255} or {28, 28, 40, 255}

        children[#children + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            paddingVertical = 8,
            paddingHorizontal = 12,
            gap = 8,
            backgroundColor = bgColor,
            borderLeft = isCurrent and 4 or 0,
            borderColor = isCurrent and {80, 200, 80, 255} or nil,
            opacity = locked and 0.35 or 1.0,
            children = {
                UI.Label { text = icon, fontSize = 24, width = 36 },
                UI.Panel {
                    flex = 1,
                    children = {
                        UI.Label {
                            text = zone.name .. (locked and " 🔒" or ""),
                            fontSize = 24,
                            color = nameColor,
                            fontWeight = isCurrent and "bold" or "normal",
                        },
                    },
                },
                UI.Label {
                    text = "Lv." .. zone.reqLv,
                    fontSize = 20,
                    color = locked and {80, 80, 100, 255} or {140, 140, 160, 255},
                    width = 60,
                    textAlign = "right",
                },
                locked and UI.Label { text = "" } or UI.Button {
                    text = isCurrent and "⚔️" or "▶",
                    fontSize = 22,
                    width = 56, height = 44,
                    variant = isCurrent and "success" or "ghost",
                    disabled = isCurrent,
                    onClick = function()
                        if ctx.onSelectZone then ctx.onSelectZone(zoneIdx) end
                    end,
                },
            },
        }
    end

    return ctx.wrapScroll("zoneList", {
        width = "100%",
        maxHeight = 500,
        padding = 4,
        gap = 2,
        backgroundColor = {22, 22, 32, 255},
        children = children,
    })
end

-- ============================================================================
-- 货币栏 (独立组件, 供其他面板引用)
-- ============================================================================
function M.buildCurrencyBar(ctx)
    local player = ctx.player
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        padding = {6, 12},
        gap = 12,
        backgroundColor = {18, 18, 28, 255},
        children = {
            UI.Label { text = "💰" .. SYS.formatGold(player.gold), fontSize = 22, color = {255, 215, 0, 255} },
            UI.Label { text = "💎" .. player.diamonds, fontSize = 22, color = {185, 242, 255, 255} },
            UI.Label { text = "🎫" .. player.tickets, fontSize = 22, color = {255, 180, 100, 255} },
            UI.Label { text = "🔥" .. (player.hellTickets or 0), fontSize = 22, color = {255, 100, 50, 255} },
        },
    }
end

-- ============================================================================
-- 药水倒计时栏 (有激活药水时显示)
-- ============================================================================
function M.buildPotionBar(ctx)
    local player = ctx.player
    local dropTimer = player.dropPotionTimer or 0
    local expTimer = player.expPotionTimer or 0

    if dropTimer <= 0 and expTimer <= 0 then
        return nil
    end

    local items = {}

    if dropTimer > 0 then
        items[#items + 1] = UI.Panel {
            flex = 1,
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            paddingHorizontal = 12,
            paddingVertical = 6,
            backgroundColor = {50, 35, 15, 255},
            borderRadius = 8,
            borderLeft = 3,
            borderColor = {255, 160, 50, 255},
            children = {
                UI.Label { text = "🧪", fontSize = 22 },
                UI.Label { text = "爆率+30%", fontSize = 20, color = {255, 200, 100, 255}, fontWeight = "bold" },
                UI.Label {
                    text = SYS.formatPotionTime(dropTimer), fontSize = 20,
                    color = dropTimer <= 300 and {255, 80, 80, 255} or {255, 220, 150, 255},
                    flex = 1, textAlign = "right",
                },
            },
        }
    end

    if expTimer > 0 then
        items[#items + 1] = UI.Panel {
            flex = 1,
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            paddingHorizontal = 12,
            paddingVertical = 6,
            backgroundColor = {15, 35, 50, 255},
            borderRadius = 8,
            borderLeft = 3,
            borderColor = {80, 180, 255, 255},
            children = {
                UI.Label { text = "📘", fontSize = 22 },
                UI.Label { text = "经验+50%", fontSize = 20, color = {120, 200, 255, 255}, fontWeight = "bold" },
                UI.Label {
                    text = SYS.formatPotionTime(expTimer), fontSize = 20,
                    color = expTimer <= 300 and {255, 80, 80, 255} or {150, 220, 255, 255},
                    flex = 1, textAlign = "right",
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 4,
        paddingHorizontal = 8,
        paddingVertical = 4,
        backgroundColor = {18, 18, 28, 255},
        children = items,
    }
end

-- ============================================================================
-- 旧接口兼容 (build 和 buildRightTopBar 不再使用, 但保留以防引用)
-- ============================================================================
function M.build(ctx)
    -- 竖屏模式不再使用左侧栏, 返回空面板
    return UI.Panel { width = 0, height = 0 }
end

function M.buildRightTopBar(ctx)
    -- 竖屏模式不再使用右侧顶栏, 返回空面板
    return UI.Panel { width = 0, height = 0 }
end

return M
