-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 战斗面板
-- ============================================================================
local SYS = require("systems")
local UI = require("urhox-libs/UI")
local UC = require("ui_common")
local UILeft = require("ui_left")
local UIMarketSettings = require("ui_market_settings")
local qc, panelTitle, subTabBar = UC.qc, UC.panelTitle, UC.subTabBar

local M = {}

function M.buildCombatPanel(ctx)
    local player = ctx.player
    local mob = ctx.currentMob
    local combatLog = ctx.combatLog or {}
    local isQuick = ctx.quickCombat

    -- 如果当前视图是 elite，显示精英面板（在战斗标签内）
    if ctx.currentView == "elite" then
        return M.buildCombatWithElite(ctx)
    end

    local children = {}

    -- 子标签切换栏: 战斗 | 精英
    children[#children + 1] = subTabBar(
        { {label = "⚔️ 战斗", view = "combat"}, {label = "👹 精英", view = "elite"} },
        "combat", ctx
    )

    -- 区域列表 (可折叠)
    children[#children + 1] = UILeft.buildZoneList(ctx)

    -- 标题栏 + 伤害飘字 + 极速战斗开关
    local showDmg = ctx.showDmgFloat
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        children = {
            UI.Label {
                text = "⚔️ 战斗",
                fontSize = 28, fontWeight = "bold",
                color = {220, 220, 240, 255},
                flex = 1,
            },
            UI.Button {
                text = showDmg and "🚫飘字" or "💥飘字",
                fontSize = 20, height = 44, paddingHorizontal = 12,
                variant = showDmg and "warning" or "ghost",
                onClick = function() if ctx.onToggleDmgFloat then ctx.onToggleDmgFloat() end end,
            },
            UI.Button {
                text = isQuick and "⚡极速" or "⚡普通",
                fontSize = 20, height = 44, paddingHorizontal = 12,
                variant = isQuick and "success" or "outline",
                onClick = function() if ctx.onToggleQuickCombat then ctx.onToggleQuickCombat() end end,
            },
        },
    }

    -- 死亡状态显示
    if ctx.isDead then
        local remaining = math.ceil(ctx.deathTimer or 0)
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 20,
            backgroundColor = {60, 20, 20, 255},
            borderRadius = 12,
            borderLeft = 4,
            borderColor = {200, 50, 50, 255},
            gap = 10,
            alignItems = "center",
            children = {
                UI.Label {
                    text = "💀",
                    fontSize = 48,
                },
                UI.Label {
                    text = "你已阵亡",
                    fontSize = 32, fontWeight = "bold",
                    color = {255, 80, 80, 255},
                },
                UI.Label {
                    text = remaining .. " 秒后复活...",
                    fontSize = 26,
                    color = {255, 200, 100, 255},
                },
                -- 复活进度条
                UI.Panel {
                    width = "80%", height = 14,
                    backgroundColor = {40, 40, 55, 255},
                    borderRadius = 7,
                    overflow = "hidden",
                    children = {
                        UI.Panel {
                            width = math.floor((1 - (ctx.deathTimer or 0) / (ctx.deathReviveTime or 3)) * 100) .. "%",
                            height = "100%",
                            backgroundColor = {80, 200, 80, 255},
                            borderRadius = 7,
                        },
                    },
                },
            },
        }
    end

    -- ============ 极速战斗模式: 精简显示 ============
    if isQuick and not ctx.isDead then
        -- 精简怪物状态行
        if mob then
            local hpPct = mob.maxHp > 0 and math.floor(mob.hp / mob.maxHp * 100) or 0
            local mobIcon = mob.icon or "❓"
            local mobPanel = UI.Panel {
                width = "100%",
                padding = 12,
                backgroundColor = {30, 30, 42, 255},
                borderRadius = 8,
                gap = 6,
                children = {
                    -- 怪物名+图标
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            UI.Label { text = mobIcon, fontSize = 28 },
                            UI.Label {
                                text = mob.name,
                                fontSize = 24, fontWeight = "bold",
                                color = mob.isElite and {255, 80, 80, 255} or {220, 220, 240, 255},
                                flex = 1,
                            },
                            UI.Label {
                                text = hpPct .. "%",
                                fontSize = 22, fontWeight = "bold",
                                color = hpPct > 50 and {100, 200, 100, 255} or hpPct > 20 and {255, 200, 50, 255} or {255, 80, 80, 255},
                            },
                        },
                    },
                    -- 血条
                    UI.Panel {
                        width = "100%", height = 14,
                        backgroundColor = {50, 18, 18, 255},
                        borderRadius = 7, overflow = "hidden",
                        children = {
                            UI.Panel {
                                width = hpPct .. "%", height = "100%",
                                backgroundColor = mob.isElite and {180, 40, 40, 255} or {160, 60, 60, 255},
                                borderRadius = 7,
                            },
                        },
                    },
                },
            }
            ctx.mobPanelRef = mobPanel
            children[#children + 1] = mobPanel
        else
            children[#children + 1] = UI.Label {
                text = "⏳ 等待下一个怪物...",
                fontSize = 24, color = {140, 140, 160, 255},
                paddingVertical = 12,
            }
        end

        -- 极速模式状态提示
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 12,
            backgroundColor = {20, 35, 20, 255},
            borderRadius = 8,
            borderLeft = 4,
            borderColor = {60, 180, 60, 255},
            gap = 6,
            children = {
                UI.Label {
                    text = "⚡ 极速战斗中 - 已隐藏动画和日志",
                    fontSize = 22, fontWeight = "bold",
                    color = {100, 220, 100, 255},
                },
                UI.Label {
                    text = "击杀: " .. SYS.formatGold(player.killCount) .. " | Lv." .. player.level .. " | 经验: " .. math.floor(player.exp / player.expNext * 100) .. "%",
                    fontSize = 20, color = {160, 160, 180, 255},
                },
                UI.Label {
                    text = "HP: " .. math.floor(player.hp) .. "/" .. math.floor(player.maxHp) .. " | 💰" .. SYS.formatGold(player.gold) .. " | 🎫" .. player.tickets .. " | 🔥" .. (player.hellTickets or 0),
                    fontSize = 20, color = {160, 160, 180, 255},
                },
            },
        }

    else
    -- ============ 普通战斗模式: 完整显示 ============

    -- 怪物信息
    if mob and not ctx.isDead then
        local hpPct = mob.maxHp > 0 and math.floor(mob.hp / mob.maxHp * 100) or 0
        local nameColor = mob.isElite and {255, 80, 80, 255} or {220, 220, 240, 255}

        local mobIcon = mob.icon or "❓"
        local mobInfoChildren = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    UI.Label { text = mobIcon, fontSize = 36 },
                    UI.Label {
                        text = mob.name,
                        fontSize = 26, fontWeight = "bold",
                        color = nameColor,
                    },
                },
            },
            -- HP条
            UI.Panel {
                width = "100%", height = 24,
                backgroundColor = {50, 18, 18, 255},
                borderRadius = 12,
                overflow = "hidden",
                children = {
                    UI.Panel {
                        width = hpPct .. "%", height = "100%",
                        backgroundColor = mob.isElite and {180, 40, 40, 255} or {160, 60, 60, 255},
                        borderRadius = 12,
                    },
                    UI.Label {
                        text = math.floor(mob.hp) .. "/" .. math.floor(mob.maxHp),
                        fontSize = 18,
                        color = {255, 255, 255, 255},
                        position = "absolute",
                        width = "100%",
                        height = 24,
                        textAlign = "center",
                    },
                },
            },
            -- 基础属性
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = 16,
                children = {
                    UI.Label {
                        text = "⚔️" .. math.floor(mob.atk),
                        fontSize = 22, color = {255, 180, 120, 255},
                    },
                    UI.Label {
                        text = "🛡️" .. math.floor(mob.def),
                        fontSize = 22, color = {120, 180, 255, 255},
                    },
                    UI.Label {
                        text = "📖" .. SYS.formatGold(mob.exp),
                        fontSize = 22, color = {120, 255, 120, 255},
                    },
                },
            },
        }

        -- 精英额外属性
        if mob.isElite then
            mobInfoChildren[#mobInfoChildren + 1] = UI.Panel {
                width = "100%",
                height = 28,
                flexDirection = "row",
                gap = 10,
                flexWrap = "wrap",
                children = {
                    UI.Label { text = "💥" .. string.format("%.0f%%", mob.crit or 0), fontSize = 20, color = {255, 100, 100, 255} },
                    UI.Label { text = "💀" .. string.format("%.0f%%", mob.critDmg or 150), fontSize = 20, color = {255, 80, 80, 255} },
                    UI.Label { text = "🛡️抗暴" .. string.format("%.0f%%", mob.antiCrit or 0), fontSize = 20, color = {100, 200, 255, 255} },
                    UI.Label { text = "🗡️" .. string.format("%.1f%%", mob.penetration or 0), fontSize = 20, color = {255, 160, 80, 255} },
                },
            }
            mobInfoChildren[#mobInfoChildren + 1] = UI.Label {
                text = "⚡ 每8秒释放技能(200%-1000%伤害)",
                fontSize = 18, color = {255, 180, 50, 255},
                height = 24,
            }
        else
            mobInfoChildren[#mobInfoChildren + 1] = UI.Panel { width = "100%", height = 28 }
            mobInfoChildren[#mobInfoChildren + 1] = UI.Panel { width = "100%", height = 24 }
        end

        local mobPanel = UI.Panel {
            width = "100%",
            padding = 12,
            backgroundColor = mob.isElite and {45, 25, 30, 255} or {30, 30, 42, 255},
            borderRadius = 8,
            borderLeft = mob.isElite and 4 or 0,
            borderColor = mob.isElite and {200, 50, 50, 255} or nil,
            gap = 6,
            children = mobInfoChildren,
        }
        ctx.mobPanelRef = mobPanel
        children[#children + 1] = mobPanel
    elseif ctx.spawnWaiting and not ctx.isDead then
        children[#children + 1] = UI.Label {
            text = "⏳ 等待下一个怪物...",
            fontSize = 24, color = {140, 140, 160, 255},
            paddingVertical = 16,
        }
    end

    -- 战斗日志标题 + 暂停按钮
    local isPaused = ctx.combatPaused
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        marginTop = 8,
        gap = 8,
        children = {
            UI.Label {
                text = "📜 战斗日志",
                fontSize = 24, fontWeight = "bold",
                color = {140, 140, 160, 255},
                flex = 1,
            },
            UI.Button {
                text = isPaused and "▶ 继续" or "⏸ 暂停",
                fontSize = 20, height = 44, paddingHorizontal = 12,
                variant = isPaused and "success" or "warning",
                onClick = function() if ctx.onTogglePause then ctx.onTogglePause() end end,
            },
        },
    }

    -- 暂停提示
    if isPaused then
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 10,
            backgroundColor = {50, 45, 20, 255},
            borderRadius = 8,
            alignItems = "center",
            children = {
                UI.Label {
                    text = "⏸ 日志已冻结 (战斗仍在继续)",
                    fontSize = 22, fontWeight = "bold",
                    color = {255, 220, 100, 255},
                },
            },
        }
    end

    -- 暂停时使用快照，继续时使用实时日志
    local displayLog = (isPaused and ctx.pausedLogSnapshot) and ctx.pausedLogSnapshot or combatLog
    local logChildren = {}
    local startIdx = math.max(1, #displayLog - 19)
    for i = #displayLog, startIdx, -1 do
        local entry = displayLog[i]
        if entry.bg then
            logChildren[#logChildren + 1] = UI.Panel {
                width = "100%",
                backgroundColor = entry.bg,
                borderRadius = 6,
                paddingVertical = 4,
                paddingHorizontal = 8,
                children = {
                    UI.Label {
                        text = entry.text,
                        fontSize = 20,
                        color = entry.color or {140, 140, 160, 255},
                    },
                },
            }
        else
            logChildren[#logChildren + 1] = UI.Label {
                text = entry.text,
                fontSize = 20,
                color = entry.color or {140, 140, 160, 255},
                paddingVertical = 2,
            }
        end
    end

    children[#children + 1] = ctx.wrapScroll("combatLog", {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        padding = 8,
        backgroundColor = {20, 20, 30, 255},
        borderRadius = 8,
        gap = 2,
        children = logChildren,
    })

    end -- isQuick else end

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12,
        gap = 6,
        children = children,
    }
end

-- ============================================================================
-- 精英面板（嵌入战斗标签的子视图）
-- ============================================================================
function M.buildCombatWithElite(ctx)
    local children = {}

    -- 子标签切换栏: 战斗 | 精英
    children[#children + 1] = subTabBar(
        { {label = "⚔️ 战斗", view = "combat"}, {label = "👹 精英", view = "elite"} },
        "elite", ctx
    )

    -- 直接复用 ui_market_settings 中的精英面板内容
    children[#children + 1] = UIMarketSettings.buildElitePanelContent(ctx)

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12,
        gap = 6,
        children = children,
    }
end

return M
