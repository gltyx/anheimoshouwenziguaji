-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 背包 + 装备 + 装备详情 + 宝石选择面板
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")
local SaveSys = require("save_system")
local UI = require("urhox-libs/UI")
local UC = require("ui_common")
local UISettings = require("ui_market_settings")
local qc, panelTitle, divider, qualityBg, subTabBar = UC.qc, UC.panelTitle, UC.divider, UC.qualityBg, UC.subTabBar
local qualityTag, qualityCardStyle = UC.qualityTag, UC.qualityCardStyle

local M = {}

-- ============================================================================
-- 背包面板
-- ============================================================================
function M.buildInventoryPanel(ctx)
    local player = ctx.player
    local children = {}

    children[#children + 1] = panelTitle("🎒", "背包 (" .. #player.bag .. "件)")

    -- 碎片概览
    local fragTexts = {}
    for _, q in ipairs(CFG.EQUIP_QUALITIES) do
        local cnt = player.equipFragments[q.id] or 0
        if cnt > 0 then
            fragTexts[#fragTexts + 1] = q.name .. ":" .. cnt
        end
    end
    if #fragTexts > 0 then
        children[#children + 1] = UI.Label {
            text = "📦 碎片: " .. table.concat(fragTexts, " "),
            fontSize = 22, color = {140, 140, 160, 255},
        }
    end

    -- 分类筛选按钮
    local curFilter = ctx.bagFilter or "all"
    local filterItems = { { id = "all", label = "全部" } }
    for _, slot in ipairs(CFG.EQUIP_SLOTS) do
        filterItems[#filterItems + 1] = { id = slot.id, label = slot.name }
    end
    local filterBtns = {}
    for _, fi in ipairs(filterItems) do
        local active = (curFilter == fi.id)
        filterBtns[#filterBtns + 1] = UI.Button {
            text = fi.label, fontSize = 20, height = 48,
            paddingHorizontal = 6,
            variant = active and "primary" or "ghost",
            onClick = function()
                if ctx.onSetBagFilter then ctx.onSetBagFilter(fi.id) end
            end,
        }
    end
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 6,
        paddingVertical = 2,
        children = filterBtns,
    }

    -- 背包物品列表
    local bagItems = {}
    for idx, equip in ipairs(player.bag) do
        -- 按分类筛选
        if curFilter ~= "all" and equip.slot ~= curFilter then
            goto continue_bag
        end
        local eqColor = SYS.getQualityColor(equip.qualityIdx)
        local bagIdx = idx
        local bagScore = SYS.calcEquipScore(equip)

        local isUpgrade = false
        local equipped = player.equipment[equip.slot]
        if equipped then
            if bagScore > SYS.calcEquipScore(equipped) then isUpgrade = true end
        else
            isUpgrade = true
        end

        -- 属性预览子项 (流式布局，适配小屏)
        local previewChildren = {}
        -- 基础属性用流式标签
        local baseLabels = {}
        for _, bs in ipairs(equip.baseStats) do
            baseLabels[#baseLabels + 1] = UI.Label {
                text = SYS.formatStat(bs.id, bs.value),
                fontSize = 20, color = {160, 180, 160, 255},
            }
        end
        if #baseLabels > 0 then
            previewChildren[#previewChildren + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                flexWrap = "wrap",
                gap = 8,
                paddingHorizontal = 2,
                children = baseLabels,
            }
        end
        -- 词缀也用流式标签
        if equip.affixes and #equip.affixes > 0 then
            local affLabels = {}
            for _, af in ipairs(equip.affixes) do
                affLabels[#affLabels + 1] = UI.Label {
                    text = SYS.formatStat(af.id, af.value),
                    fontSize = 20, color = {120, 200, 120, 255},
                }
            end
            previewChildren[#previewChildren + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                flexWrap = "wrap",
                gap = 8,
                paddingHorizontal = 2,
                children = affLabels,
            }
        end
        -- 孔位概要 (紧凑)
        local socketParts = {}
        for si = 1, equip.maxSockets do
            local gem = equip.sockets[si]
            socketParts[#socketParts + 1] = gem and ("◆" .. gem.name) or "◇空"
        end
        if #socketParts > 0 then
            previewChildren[#previewChildren + 1] = UI.Label {
                text = table.concat(socketParts, " "),
                fontSize = 20, color = {120, 140, 200, 255},
                paddingHorizontal = 2,
            }
        end

        -- 高品质卡片样式
        local cs = qualityCardStyle(equip.qualityIdx)
        local nameSize = cs.nameFontSize or 22
        local nameWeight = cs.nameBold and "bold" or "normal"
        -- 查找部位名
        local slotName = equip.slot
        for _, s in ipairs(CFG.EQUIP_SLOTS) do
            if s.id == equip.slot then slotName = s.name break end
        end

        bagItems[#bagItems + 1] = UI.Panel {
            width = "100%",
            paddingVertical = 2,
            paddingHorizontal = 4,
            gap = 1,
            backgroundColor = qualityBg(equip.qualityIdx),
            borderRadius = 3,
            -- 升级绿色左边框优先，否则应用品质边框
            borderLeft = isUpgrade and 3 or (cs.borderLeft or cs.border or 0),
            borderTop = (not isUpgrade) and (cs.borderTop or cs.border) or nil,
            borderRight = (not isUpgrade) and cs.border or nil,
            borderBottom = (not isUpgrade) and cs.border or nil,
            borderColor = isUpgrade and {60, 200, 60, 255} or cs.borderColor or nil,
            children = {
                -- 第一行: 品阶Tag + 装备名称 + 等级·部位 + 评分
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 6,
                    children = {
                        qualityTag(equip.qualityIdx),
                        UI.Label {
                            text = (equip.locked and "🔒" or "") .. equip.name .. (equip.enhance > 0 and ("+" .. equip.enhance) or ""),
                            fontSize = nameSize, fontWeight = nameWeight,
                            color = qc(eqColor),
                            flex = 1, flexShrink = 1,
                        },
                        UI.Label {
                            text = "Lv." .. (equip.reqLv or "?") .. "·" .. slotName,
                            fontSize = 20, color = {130, 130, 155, 255},
                            flexShrink = 0,
                        },
                        UI.Label {
                            text = isUpgrade and ("↑" .. bagScore) or ("⭐" .. bagScore),
                            fontSize = 20,
                            color = isUpgrade and {80, 255, 80, 255} or {255, 215, 0, 255},
                            flexShrink = 0,
                        },
                    },
                },
                -- 第二行: 操作按钮
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 6,
                    paddingTop = 1,
                    children = {
                        UI.Button {
                            text = "装备", fontSize = 20, height = 48, paddingHorizontal = 4,
                            variant = "primary",
                            onClick = function() if ctx.onEquipItem then ctx.onEquipItem(bagIdx) end end,
                        },
                        UI.Button {
                            text = "详情", fontSize = 20, height = 48, paddingHorizontal = 4,
                            variant = "outline",
                            onClick = function()
                                if ctx.onEquipDetail then ctx.onEquipDetail(equip, equip.slot, bagIdx) end
                            end,
                        },
                        UI.Button {
                            text = equip.locked and "🔓" or "🔒", fontSize = 20, height = 48, paddingHorizontal = 3,
                            variant = "ghost",
                            onClick = function() if ctx.onToggleLock then ctx.onToggleLock("equip", bagIdx) end end,
                        },
                        UI.Button {
                            text = "分解", fontSize = 20, height = 48, paddingHorizontal = 4,
                            variant = "danger", disabled = equip.locked,
                            onClick = function() if ctx.onDecomposeEquip then ctx.onDecomposeEquip(bagIdx) end end,
                        },
                    },
                },
                -- 第三行: 属性预览
                UI.Panel { width = "100%", paddingHorizontal = 2, gap = 0, children = previewChildren },
            },
        }
        ::continue_bag::
    end

    if #bagItems == 0 then
        bagItems[#bagItems + 1] = UI.Label {
            text = "(背包空空如也)",
            fontSize = 24, color = {80, 80, 100, 255},
            paddingVertical = 8,
        }
    end

    children[#children + 1] = ctx.wrapScroll("inventory", {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        gap = 4,
        children = bagItems,
    })

    -- 自动分解设置（固定在底部，不随滚动）
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexShrink = 0,
        paddingVertical = 3,
        paddingHorizontal = 6,
        backgroundColor = {32, 28, 42, 255},
        borderRadius = 3,
        children = UISettings.buildEquipDecomposeChildren(ctx),
    }

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12,
        gap = 6,
        children = children,
    }
end

-- ============================================================================
-- 装备面板 (已装备 + 保护卷信息)
-- ============================================================================
function M.buildEquipPanel(ctx)
    local player = ctx.player
    local children = {}

    -- 子标签切换栏: 人物 | 装备 (橙色调)
    children[#children + 1] = subTabBar(
        { {label = "👤 人物", view = "stats"}, {label = "🛡 装备", view = "equip"} },
        "equip", ctx, {180, 110, 40, 255}
    )

    children[#children + 1] = panelTitle("🛡", "装备")

    -- 保护卷数量
    local scrollCount = player.protectionScrolls or 0
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingVertical = 3,
        paddingHorizontal = 4,
        backgroundColor = scrollCount > 0 and {25, 35, 45, 255} or {35, 25, 25, 255},
        borderRadius = 4,
        children = {
            UI.Label {
                text = "📜 装备保护卷: " .. scrollCount .. " 个",
                fontSize = 24, fontWeight = "bold",
                color = scrollCount > 0 and {100, 220, 255, 255} or {180, 100, 100, 255},
                flex = 1,
            },
            UI.Label {
                text = scrollCount > 0 and "强化时自动使用" or "可在黑市购买",
                fontSize = 20,
                color = {140, 140, 160, 255},
            },
        },
    }

    children[#children + 1] = divider()

    -- 已装备区域
    children[#children + 1] = UI.Label {
        text = "📌 已装备",
        fontSize = 26, fontWeight = "bold",
        color = {180, 180, 200, 255},
    }

    local equipItems = {}
    for _, slot in ipairs(CFG.EQUIP_SLOTS) do
        local equip = player.equipment[slot.id]
        local slotId = slot.id
        if equip then
            local eqColor = SYS.getQualityColor(equip.qualityIdx)
            local score = SYS.calcEquipScore(equip)

            local eqPreview = {}
            -- 基础属性流式布局
            local eqBaseLabels = {}
            for _, bs in ipairs(equip.baseStats) do
                eqBaseLabels[#eqBaseLabels + 1] = UI.Label {
                    text = SYS.formatStat(bs.id, bs.value),
                    fontSize = 20, color = {160, 180, 160, 255},
                }
            end
            if #eqBaseLabels > 0 then
                eqPreview[#eqPreview + 1] = UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    flexWrap = "wrap",
                    gap = 8,
                    paddingHorizontal = 2,
                    children = eqBaseLabels,
                }
            end
            -- 词缀流式布局
            if equip.affixes and #equip.affixes > 0 then
                local eqAffLabels = {}
                for _, af in ipairs(equip.affixes) do
                    eqAffLabels[#eqAffLabels + 1] = UI.Label {
                        text = SYS.formatStat(af.id, af.value),
                        fontSize = 20, color = {120, 200, 120, 255},
                    }
                end
                eqPreview[#eqPreview + 1] = UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    flexWrap = "wrap",
                    gap = 8,
                    paddingHorizontal = 2,
                    children = eqAffLabels,
                }
            end
            -- 孔位概要
            local eqSocketParts = {}
            for si = 1, equip.maxSockets do
                local gem = equip.sockets[si]
                eqSocketParts[#eqSocketParts + 1] = gem and ("◆" .. gem.name) or "◇空"
            end
            if #eqSocketParts > 0 then
                eqPreview[#eqPreview + 1] = UI.Label {
                    text = table.concat(eqSocketParts, " "),
                    fontSize = 20, color = {120, 140, 200, 255},
                    paddingHorizontal = 2,
                }
            end

            -- 高品质卡片样式
            local cs2 = qualityCardStyle(equip.qualityIdx)
            local nameSize2 = cs2.nameFontSize or 24
            local nameWeight2 = cs2.nameBold and "bold" or "normal"

            equipItems[#equipItems + 1] = UI.Panel {
                width = "100%",
                paddingVertical = 3,
                paddingHorizontal = 4,
                gap = 1,
                backgroundColor = qualityBg(equip.qualityIdx),
                borderRadius = 3,
                borderLeft = cs2.borderLeft or cs2.border or 0,
                borderTop = cs2.borderTop or cs2.border or nil,
                borderRight = cs2.border or nil,
                borderBottom = cs2.border or nil,
                borderColor = cs2.borderColor or nil,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            qualityTag(equip.qualityIdx),
                            UI.Label {
                                text = slot.name .. ": " .. equip.name .. (equip.enhance > 0 and (" +" .. equip.enhance) or ""),
                                fontSize = nameSize2, fontWeight = nameWeight2,
                                color = qc(eqColor),
                                flex = 1, flexShrink = 1,
                            },
                            UI.Label {
                                text = "Lv." .. (equip.reqLv or "?"),
                                fontSize = 20, color = {130, 130, 155, 255},
                                flexShrink = 0,
                            },
                            UI.Label {
                                text = "⭐" .. score,
                                fontSize = 20, color = {255, 215, 0, 255},
                            },
                            UI.Button {
                                text = "详情", fontSize = 20, height = 48, paddingHorizontal = 5,
                                variant = "outline",
                                onClick = function()
                                    if ctx.onEquipDetail then ctx.onEquipDetail(equip, slotId) end
                                end,
                            },
                        },
                    },
                    UI.Panel { width = "100%", paddingHorizontal = 2, gap = 0, children = eqPreview },
                },
            }
        else
            equipItems[#equipItems + 1] = UI.Panel {
                width = "100%",
                paddingVertical = 4,
                paddingHorizontal = 6,
                backgroundColor = {22, 22, 32, 255},
                borderRadius = 3,
                children = {
                    UI.Label {
                        text = slot.name .. ": (空)",
                        fontSize = 24, color = {80, 80, 100, 255},
                    },
                },
            }
        end
    end

    children[#children + 1] = ctx.wrapScroll("equip", {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        gap = 6,
        children = equipItems,
    })

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12,
        gap = 6,
        children = children,
    }
end

-- ============================================================================
-- 装备详情面板 (参照截图风格 v2)
-- ============================================================================
function M.buildEquipDetailPanel(ctx)
    local equip = ctx.selectedEquip
    local slotId = ctx.selectedSlot
    local bagIdx = ctx.selectedBagIdx
    if not equip then
        return UI.Panel {
            width = "100%", height = "100%",
            justifyContent = "center", alignItems = "center",
            children = { UI.Label { text = "未选择装备", fontSize = 32, color = {100,100,120,255} } },
        }
    end
    local player = ctx.player
    local eqColor = SYS.getQualityColor(equip.qualityIdx)
    local quality = CFG.EQUIP_QUALITIES[equip.qualityIdx]
    local slotData = nil
    for _, s in ipairs(CFG.EQUIP_SLOTS) do
        if s.id == equip.slot then slotData = s break end
    end
    local slotName = slotData and slotData.name or equip.slot
    local score = SYS.calcEquipScore(equip)

    local children = {}

    -- 标题行: 槽位名 + 卸下按钮
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingVertical = 4,
        borderBottom = 1,
        borderColor = {50, 50, 70, 255},
        marginBottom = 4,
        children = {
            UI.Label { text = "🔷", fontSize = 32 },
            UI.Label {
                text = " " .. slotName,
                fontSize = 36, fontWeight = "bold",
                color = {255, 215, 0, 255},
                flex = 1,
            },
            bagIdx and UI.Button {
                text = "装备", fontSize = 22, height = 48, paddingHorizontal = 8,
                variant = "primary",
                onClick = function()
                    if ctx.onEquipItem then ctx.onEquipItem(bagIdx) end
                end,
            } or UI.Button {
                text = "卸下", fontSize = 22, height = 48, paddingHorizontal = 8,
                variant = "outline",
                onClick = function()
                    if ctx.onUnequip then ctx.onUnequip(slotId) end
                end,
            },
        },
    }

    -- 装备名称行: 品阶Tag + 名称
    local detailCs = qualityCardStyle(equip.qualityIdx)
    local detailNameSize = detailCs.nameBold and 36 or 32
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingHorizontal = 4,
        children = {
            qualityTag(equip.qualityIdx),
            UI.Label {
                text = equip.name .. (equip.enhance > 0 and (" +" .. equip.enhance) or ""),
                fontSize = detailNameSize, fontWeight = "bold",
                color = qc(eqColor),
                flex = 1, flexShrink = 1,
            },
        },
    }

    -- 品质 + 等级 + 部位
    children[#children + 1] = UI.Label {
        text = quality.name .. " Lv." .. (equip.reqLv or "?") .. " · " .. slotName,
        fontSize = 24,
        color = qc(eqColor, 180),
        paddingHorizontal = 4,
    }

    children[#children + 1] = divider()

    -- 基础属性: 一行流式排列
    local baseStatLabels = {}
    local enhMult = 1 + equip.enhance * 0.5
    for _, bs in ipairs(equip.baseStats) do
        local icon = "📊"
        local color = {220, 220, 240, 255}
        if bs.id == "atk" then icon = "⚔"; color = {255, 180, 120, 255}
        elseif bs.id == "def" then icon = "🛡"; color = {120, 180, 255, 255}
        elseif bs.id == "hp"  then icon = "❤"; color = {255, 120, 160, 255}
        end
        local enhVal = math.floor(bs.value * enhMult)
        local enhBonus = enhVal - bs.value
        local txt = icon .. string.upper(bs.id) .. " +" .. enhVal
        if enhBonus > 0 then
            txt = txt .. "(+" .. enhBonus .. ")"
        end
        baseStatLabels[#baseStatLabels + 1] = UI.Label {
            text = txt,
            fontSize = 26,
            color = color,
        }
    end
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
        paddingHorizontal = 4,
        paddingVertical = 2,
        children = baseStatLabels,
    }

    -- 词缀: 流式排列
    if #equip.affixes > 0 then
        local affixIcons = {
            crit = "💥", critDmg = "💀", aspd = "⚡", lifesteal = "❤️",
            penetration = "🗡️", antiCrit = "🛡️", antiCritDmg = "🛡️",
            expBonus = "📈", goldBonus = "💰",
        }
        local affixLabels = {}
        for _, af in ipairs(equip.affixes) do
            local icon = affixIcons[af.id] or "✨"
            affixLabels[#affixLabels + 1] = UI.Label {
                text = icon .. SYS.formatStat(af.id, af.value),
                fontSize = 24,
                color = {140, 220, 140, 255},
            }
        end
        children[#children + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            flexWrap = "wrap",
            gap = 6,
            paddingHorizontal = 4,
            paddingVertical = 2,
            children = affixLabels,
        }
    end

    -- 评分
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 4,
        paddingVertical = 2,
        children = {
            UI.Label { text = "⭐ 评分: ", fontSize = 24, color = {140, 140, 160, 255} },
            UI.Label { text = tostring(score), fontSize = 28, fontWeight = "bold", color = {255, 215, 0, 255} },
        },
    }

    children[#children + 1] = divider()

    -- 孔位: 紧凑显示
    local socketSymbols = {}
    local filledCount = 0
    for i = 1, equip.maxSockets do
        if equip.sockets[i] then
            socketSymbols[#socketSymbols + 1] = "◆"
            filledCount = filledCount + 1
        else
            socketSymbols[#socketSymbols + 1] = "◇"
        end
    end
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 4,
        gap = 8,
        children = {
            UI.Label {
                text = "孔位: " .. table.concat(socketSymbols, " "),
                fontSize = 24, color = {140, 160, 200, 255},
            },
            UI.Label {
                text = "(" .. equip.maxSockets .. "孔)",
                fontSize = 22, color = {100, 100, 120, 255},
            },
        },
    }

    -- 打孔按钮
    local isNat4 = equip.naturalSockets >= 4
    local maxS = isNat4 and CFG.MAX_SOCKETS_NATURAL4 or CFG.MAX_SOCKETS_NORMAL
    if equip.maxSockets < maxS then
        local cfg
        if isNat4 and equip.maxSockets == 4 then
            cfg = CFG.SOCKET_UPGRADE.fifth
        else
            cfg = CFG.SOCKET_UPGRADE.normal
        end
        children[#children + 1] = UI.Button {
            text = "🔲 打孔 → " .. (equip.maxSockets + 1) .. "孔 (" .. cfg.cost .. "💎 " .. math.floor(cfg.rate * 100) .. "%)",
            fontSize = 24, width = "100%", height = 52,
            variant = "primary",
            disabled = player.diamonds < cfg.cost,
            onClick = function() if ctx.onAddSocket then ctx.onAddSocket(equip) end end,
        }
    end

    -- 宝石列表
    for i = 1, equip.maxSockets do
        local gem = equip.sockets[i]
        local socketIdx = i
        if gem then
            local gc = SYS.getGemQualityColor(gem.qualityIdx)
            local affixStrs = {}
            for _, ga in ipairs(gem.affixes) do
                affixStrs[#affixStrs + 1] = SYS.formatGemStat(ga.id, ga.value)
            end
            children[#children + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                paddingHorizontal = 4,
                paddingVertical = 2,
                children = {
                    UI.Label { text = "💎", fontSize = 24 },
                    UI.Label {
                        text = gem.name .. " (" .. table.concat(affixStrs, ", ") .. ")",
                        fontSize = 22, color = qc(gc),
                        flex = 1, flexShrink = 1,
                    },
                    UI.Button {
                        text = "拆卸", fontSize = 20, height = 48, paddingHorizontal = 4,
                        variant = "outline",
                        onClick = function() if ctx.onUnsocketGem then ctx.onUnsocketGem(equip, socketIdx) end end,
                    },
                },
            }
        else
            children[#children + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                paddingHorizontal = 4,
                paddingVertical = 2,
                children = {
                    UI.Label { text = "◇", fontSize = 24, color = {80, 80, 100, 255} },
                    UI.Label { text = "(空)", fontSize = 22, color = {80, 80, 100, 255}, flex = 1 },
                    UI.Button {
                        text = "镶嵌", fontSize = 20, height = 48, paddingHorizontal = 4,
                        variant = "primary",
                        onClick = function() if ctx.onSocketGem then ctx.onSocketGem(equip, socketIdx) end end,
                    },
                },
            }
        end
    end

    -- 卸下全部宝石按钮
    if filledCount > 0 then
        children[#children + 1] = UI.Button {
            text = "卸下全部宝石",
            fontSize = 22, width = "100%", height = 48,
            variant = "outline",
            onClick = function()
                if ctx.onUnsocketAllGems then ctx.onUnsocketAllGems(equip) end
            end,
        }
    end

    -- 宝石状态
    children[#children + 1] = UI.Label {
        text = filledCount >= equip.maxSockets and ("宝石已满 (" .. filledCount .. "/" .. equip.maxSockets .. ")") or ("宝石 " .. filledCount .. "/" .. equip.maxSockets),
        fontSize = 22,
        color = filledCount >= equip.maxSockets and {100, 200, 100, 255} or {100, 100, 120, 255},
        paddingHorizontal = 4,
    }

    children[#children + 1] = divider()

    -- 强化区域
    local enhCostData = SYS.getEnhanceCost(equip)
    if enhCostData then
        local fragHave = player.equipFragments[enhCostData.fragId] or 0
        local rateColor = enhCostData.rate >= 50 and {100, 255, 100, 255} or {255, 180, 80, 255}

        children[#children + 1] = UI.Label {
            text = "+" .. equip.enhance .. "→+" .. enhCostData.level .. " 强化成功率:" .. enhCostData.rate .. "%",
            fontSize = 24,
            color = rateColor,
            paddingHorizontal = 4,
        }

        local costColor = (player.gold >= enhCostData.gold and fragHave >= enhCostData.fragCost)
            and {180, 180, 200, 255} or {255, 120, 80, 255}
        children[#children + 1] = UI.Label {
            text = "需要: " .. enhCostData.gold .. "g + 🟠" .. enhCostData.qualityName .. "符文 " .. fragHave .. "/" .. enhCostData.fragCost,
            fontSize = 22,
            color = costColor,
            paddingHorizontal = 4,
        }

        local canEnhance = player.gold >= enhCostData.gold and fragHave >= enhCostData.fragCost
        children[#children + 1] = UI.Button {
            text = "✨ 强化 (" .. enhCostData.gold .. "g+" .. enhCostData.fragCost .. "材料)",
            fontSize = 24, width = "100%", height = 56,
            variant = "primary",
            disabled = not canEnhance,
            onClick = function() if ctx.onEnhanceEquip then ctx.onEnhanceEquip(equip, slotId) end end,
        }
    else
        children[#children + 1] = UI.Label {
            text = "已达最大强化等级 +15",
            fontSize = 24, color = {255, 215, 0, 255},
            paddingHorizontal = 4,
        }
    end

    -- 锁定按钮
    children[#children + 1] = UI.Button {
        text = equip.locked and "🔓解锁" or "🔒锁定",
        fontSize = 24, width = "100%", height = 52,
        variant = "ghost",
        onClick = function()
            SYS.toggleLock(equip)
            if ctx.onRefresh then ctx.onRefresh() end
        end,
    }

    -- 返回按钮
    children[#children + 1] = UI.Button {
        text = "← 返回装备",
        fontSize = 24, width = "100%", height = 52,
        variant = "ghost",
        onClick = function() if ctx.onSwitchView then ctx.onSwitchView("equip") end end,
    }

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12,
        gap = 4,
        children = {
            ctx.wrapScroll("equipDetail", {
                width = "100%", flexGrow = 1, flexBasis = 0,
                gap = 4,
                children = children,
            }),
        },
    }
end

-- ============================================================================
-- 宝石镶嵌选择面板
-- ============================================================================
function M.buildGemSelectPanel(ctx)
    local player = ctx.player
    local equip = ctx.socketEquip
    local socketIdx = ctx.socketIdx

    local children = {}
    children[#children + 1] = panelTitle("💎", "选择宝石")
    children[#children + 1] = UI.Label {
        text = "镶嵌到 " .. (equip and equip.name or "") .. " 孔" .. (socketIdx or ""),
        fontSize = 24, color = {140, 140, 160, 255},
    }

    if #player.gemBag == 0 then
        children[#children + 1] = UI.Label {
            text = "没有可用的宝石",
            fontSize = 26, color = {100,100,120,255},
            paddingVertical = 16,
        }
    end

    local gemItems = {}
    for idx, gem in ipairs(player.gemBag) do
        local gc = SYS.getGemQualityColor(gem.qualityIdx)
        local affixStrs = {}
        for _, ga in ipairs(gem.affixes) do
            affixStrs[#affixStrs + 1] = SYS.formatGemStat(ga.id, ga.value)
        end
        local gemIdx = idx
        gemItems[#gemItems + 1] = UI.Button {
            text = gem.name .. " (" .. table.concat(affixStrs, ", ") .. ")",
            fontSize = 22, width = "100%", height = 52,
            textColor = qc(gc),
            backgroundColor = {0, 0, 0, 255},
            variant = "ghost",
            onClick = function() if ctx.onConfirmSocket then ctx.onConfirmSocket(gemIdx) end end,
        }
    end

    children[#children + 1] = ctx.wrapScroll("gemSelect", {
        width = "100%", flexGrow = 1, flexBasis = 0,
        gap = 4, children = gemItems,
    })

    children[#children + 1] = UI.Button {
        text = "← 返回", fontSize = 24, width = "100%", height = 56,
        variant = "ghost",
        onClick = function() if ctx.onSwitchView then ctx.onSwitchView("equipDetail") end end,
    }

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12, gap = 8,
        children = children,
    }
end

return M
