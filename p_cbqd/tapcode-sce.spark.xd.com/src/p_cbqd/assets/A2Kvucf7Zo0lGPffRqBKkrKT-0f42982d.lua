-- ============================================================================
-- 暗黑挂机爽刷装备版本 - 黑市 + 设置 + 精英副本面板
-- ============================================================================
local CFG = require("config")
local SYS = require("systems")
local SaveSys = require("save_system")
local UI = require("urhox-libs/UI")
local UC = require("ui_common")
local qc, panelTitle, divider, subTabBar = UC.qc, UC.panelTitle, UC.divider, UC.subTabBar

local M = {}

-- 重生输入文本
local rebirthInputText = ""

-- ============================================================================
-- 黑市面板
-- ============================================================================
function M.buildMarketPanel(ctx)
    local player = ctx.player
    local msg = ctx.marketMsg

    -- 固定头部（不滚动）
    local headerChildren = {}

    headerChildren[#headerChildren + 1] = panelTitle("🏪", "黑市")

    headerChildren[#headerChildren + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 12,
        children = {
            UI.Label {
                text = "💰 " .. SYS.formatGold(player.gold),
                fontSize = 26, color = {255, 215, 0, 255},
            },
            UI.Label {
                text = "💎 " .. (player.diamonds or 0),
                fontSize = 26, color = {150, 220, 255, 255},
            },
        },
    }

    if msg then
        headerChildren[#headerChildren + 1] = UI.Panel {
            width = "100%", padding = 10,
            backgroundColor = {30, 42, 30, 255},
            borderRadius = 8,
            children = {
                UI.Label { text = msg, fontSize = 24, color = {180, 255, 180, 255} },
            },
        }
    end

    -- 可滚动内容
    local scrollChildren = {}

    -- 技能购买
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = {30, 28, 45, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 10,
        children = {
            UI.Label { text = "⚡ 购买技能", fontSize = 28, fontWeight = "bold", color = {200, 170, 255, 255} },
            UI.Label {
                text = "花费 " .. SYS.formatGold(CFG.BLACK_MARKET.skillPrice) .. " 金币随机获得一个技能",
                fontSize = 24, color = {140, 140, 160, 255},
            },
            M.buildProbDisplay(),
            UI.Button {
                text = "购买技能 (" .. SYS.formatGold(CFG.BLACK_MARKET.skillPrice) .. ")",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.gold < CFG.BLACK_MARKET.skillPrice,
                onClick = function() if ctx.onBuySkill then ctx.onBuySkill() end end,
            },
        },
    }

    -- 宝石购买
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = {28, 35, 45, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = {
            UI.Label { text = "💎 购买宝石", fontSize = 28, fontWeight = "bold", color = {150, 200, 255, 255} },
            UI.Label {
                text = "花费 " .. SYS.formatGold(CFG.BLACK_MARKET.gemPrice) .. " 金币随机获得一颗宝石",
                fontSize = 24, color = {140, 140, 160, 255},
            },
            M.buildProbDisplay(),
            UI.Button {
                text = "购买宝石 (" .. SYS.formatGold(CFG.BLACK_MARKET.gemPrice) .. ")",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.gold < CFG.BLACK_MARKET.gemPrice,
                onClick = function() if ctx.onBuyGem then ctx.onBuyGem() end end,
            },
        },
    }

    -- 转职令牌
    local classButtons = {}
    for cid, cls in pairs(CFG.CLASSES) do
        if type(cid) == "string" and cid ~= player.classId then
            local targetCid = cid
            classButtons[#classButtons + 1] = UI.Button {
                text = cls.icon .. " 转职" .. cls.name .. " (100💎)",
                fontSize = 24, width = "100%", height = 56,
                variant = "outline",
                disabled = player.diamonds < 100,
                onClick = function() if ctx.onBuyClassToken then ctx.onBuyClassToken(targetCid) end end,
            }
        end
    end
    local tokenChildren = {
        UI.Label { text = "📜 转职令牌", fontSize = 28, fontWeight = "bold", color = {255, 180, 120, 255} },
        UI.Label {
            text = "花费100钻石切换职业，非本职业技能将被卸下",
            fontSize = 22, color = {140, 140, 160, 255},
        },
        UI.Label {
            text = "当前职业: " .. (CFG.CLASSES[player.classId] and CFG.CLASSES[player.classId].icon or "") .. " " .. player.className,
            fontSize = 24, color = {200, 200, 220, 255},
        },
    }
    for _, btn in ipairs(classButtons) do
        tokenChildren[#tokenChildren + 1] = btn
    end
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = {40, 30, 28, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = tokenChildren,
    }

    -- 爆率药水
    local potionTimer = player.dropPotionTimer or 0
    local potionActive = potionTimer > 0
    local potionDesc = potionActive
        and ("生效中: 爆率+30% 剩余" .. math.floor(potionTimer) .. "秒 (可叠加时间)")
        or "购买后自动使用，爆率+30%，持续1800秒"
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = potionActive and {25, 40, 30, 255} or {28, 30, 45, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = {
            UI.Label { text = "🧪 爆率药水", fontSize = 28, fontWeight = "bold", color = {120, 255, 180, 255} },
            UI.Label {
                text = potionDesc,
                fontSize = 22, color = potionActive and {100, 255, 150, 255} or {140, 140, 160, 255},
            },
            UI.Button {
                text = potionActive and "再次购买 (150💎)" or "购买爆率药水 (150💎)",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.diamonds < 150,
                onClick = function() if ctx.onBuyDropPotion then ctx.onBuyDropPotion() end end,
            },
        },
    }

    -- 经验药水
    local expTimer = player.expPotionTimer or 0
    local expActive = expTimer > 0
    local expDesc = expActive
        and ("生效中: 经验+50% 剩余" .. SYS.formatPotionTime(expTimer) .. " (可叠加时间)")
        or "购买后自动使用，经验+50%，持续12小时"
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = expActive and {30, 35, 25, 255} or {35, 28, 45, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = {
            UI.Label { text = "📖 经验药水", fontSize = 28, fontWeight = "bold", color = {255, 220, 120, 255} },
            UI.Label {
                text = expDesc,
                fontSize = 22, color = expActive and {255, 240, 130, 255} or {140, 140, 160, 255},
            },
            UI.Button {
                text = expActive and "再次购买 (100💎)" or "购买经验药水 (100💎)",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.diamonds < 100,
                onClick = function() if ctx.onBuyExpPotion then ctx.onBuyExpPotion() end end,
            },
        },
    }

    -- 精英门票购买
    local ticketPrice = CFG.BLACK_MARKET.eliteTicketDiamondPrice
    local ticketAmount = CFG.BLACK_MARKET.eliteTicketAmount
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = {35, 28, 20, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = {
            UI.Label { text = "🎫 精英门票", fontSize = 28, fontWeight = "bold", color = {255, 180, 100, 255} },
            UI.Label {
                text = "持有: " .. (player.tickets or 0) .. " 张",
                fontSize = 24, color = {255, 200, 120, 255},
            },
            UI.Label {
                text = "花费" .. ticketPrice .. "钻石购买" .. ticketAmount .. "张精英门票",
                fontSize = 22, color = {140, 140, 160, 255},
            },
            UI.Button {
                text = "购买门票 (" .. ticketPrice .. "💎 → " .. ticketAmount .. "张)",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.diamonds < ticketPrice,
                onClick = function() if ctx.onBuyEliteTickets then ctx.onBuyEliteTickets() end end,
            },
        },
    }

    -- 装备保护卷
    local scrollCount = player.protectionScrolls or 0
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = scrollCount > 0 and {35, 30, 20, 255} or {28, 28, 45, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = {
            UI.Label { text = "📜 装备保护卷", fontSize = 28, fontWeight = "bold", color = {255, 220, 100, 255} },
            UI.Label {
                text = "持有: " .. scrollCount .. " 张",
                fontSize = 24, color = scrollCount > 0 and {255, 230, 150, 255} or {140, 140, 160, 255},
            },
            UI.Label {
                text = "强化装备时自动使用，失败不会消失，等级-1",
                fontSize = 22, color = {140, 140, 160, 255},
            },
            UI.Button {
                text = "购买保护卷 (" .. CFG.BLACK_MARKET.protectionScrollPrice .. "💎)",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.diamonds < CFG.BLACK_MARKET.protectionScrollPrice,
                onClick = function() if ctx.onBuyProtectionScroll then ctx.onBuyProtectionScroll() end end,
            },
        },
    }

    -- 宝石保护卷
    local gemScrollCount = player.gemProtectionScrolls or 0
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = gemScrollCount > 0 and {20, 30, 35, 255} or {28, 28, 45, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = {
            UI.Label { text = "📜 宝石保护卷", fontSize = 28, fontWeight = "bold", color = {150, 220, 255, 255} },
            UI.Label {
                text = "持有: " .. gemScrollCount .. " 张",
                fontSize = 24, color = gemScrollCount > 0 and {150, 230, 255, 255} or {140, 140, 160, 255},
            },
            UI.Label {
                text = "强化宝石时自动使用，失败不会消失，等级-1",
                fontSize = 22, color = {140, 140, 160, 255},
            },
            UI.Button {
                text = "购买保护卷 (" .. CFG.BLACK_MARKET.protectionScrollPrice .. "💎)",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.diamonds < CFG.BLACK_MARKET.protectionScrollPrice,
                onClick = function() if ctx.onBuyGemProtectionScroll then ctx.onBuyGemProtectionScroll() end end,
            },
        },
    }

    -- 技能保护卷
    local skillScrollCount = player.skillProtectionScrolls or 0
    scrollChildren[#scrollChildren + 1] = UI.Panel {
        width = "100%",
        padding = 12,
        backgroundColor = skillScrollCount > 0 and {30, 20, 35, 255} or {28, 28, 45, 255},
        borderRadius = 10,
        gap = 8,
        marginTop = 8,
        children = {
            UI.Label { text = "📜 技能保护卷", fontSize = 28, fontWeight = "bold", color = {200, 170, 255, 255} },
            UI.Label {
                text = "持有: " .. skillScrollCount .. " 张",
                fontSize = 24, color = skillScrollCount > 0 and {210, 180, 255, 255} or {140, 140, 160, 255},
            },
            UI.Label {
                text = "强化技能时自动使用，失败不会消失，等级-1",
                fontSize = 22, color = {140, 140, 160, 255},
            },
            UI.Button {
                text = "购买保护卷 (" .. CFG.BLACK_MARKET.protectionScrollPrice .. "💎)",
                fontSize = 26, width = "100%", height = 56,
                variant = "primary",
                disabled = player.diamonds < CFG.BLACK_MARKET.protectionScrollPrice,
                onClick = function() if ctx.onBuySkillProtectionScroll then ctx.onBuySkillProtectionScroll() end end,
            },
        },
    }

    -- 固定头部 + 可滚动内容
    local allChildren = {}
    for _, c in ipairs(headerChildren) do
        allChildren[#allChildren + 1] = c
    end
    allChildren[#allChildren + 1] = ctx.wrapScroll("market", {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        gap = 4,
        children = scrollChildren,
    })

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12, gap = 6,
        children = allChildren,
    }
end

-- 概率显示条
function M.buildProbDisplay()
    local probs = CFG.BLACK_MARKET.qualityProbs
    local names = {"灰60%", "绿23%", "蓝10%", "紫5%", "橙3%"}
    local colors = {
        {120,120,120,255}, {76,175,80,255}, {33,150,243,255},
        {156,39,176,255}, {255,152,0,255},
    }
    local children = {}
    for i = 1, 5 do
        children[#children + 1] = UI.Panel {
            width = math.floor(probs[i] * 100) .. "%",
            height = 24,
            backgroundColor = colors[i],
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label { text = names[i], fontSize = 20, color = {255,255,255,255} },
            },
        }
    end
    return UI.Panel {
        width = "100%", height = 24,
        flexDirection = "row",
        borderRadius = 6,
        overflow = "hidden",
        children = children,
    }
end

-- ============================================================================
-- 设置面板 (自动分解 + 兑换码)
-- ============================================================================

-- 子面板: 自动分解 (拆分为独立函数，供各面板调用)

--- 装备自动分解 UI children
function M.buildEquipDecomposeChildren(ctx)
    local player = ctx.player
    local items = {}
    items[#items + 1] = UI.Label {
        text = "分解",
        fontSize = 22, fontWeight = "bold",
        color = {140, 140, 160, 255},
        flexShrink = 0,
    }
    for _, qId in ipairs(CFG.AUTO_DECOMPOSE_EQUIP_QUALITIES) do
        local qi = CFG.QUALITY_INDEX[qId]
        local q = CFG.EQUIP_QUALITIES[qi]
        local qualityId = qId
        local isChecked = player.autoDecompose.equip[qId] == true
        items[#items + 1] = UI.Checkbox {
            checked = isChecked,
            label = q.name,
            size = 24,
            onChange = function(self, checked)
                player.autoDecompose.equip[qualityId] = checked
                SaveSys.markDirty()
                if checked then
                    local msgs = SYS.autoDecomposeExisting(player, "equip", qualityId)
                    if ctx.onAutoDecomposeNow and #msgs > 0 then ctx.onAutoDecomposeNow(msgs) end
                end
            end,
        }
    end
    return { UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        alignItems = "center",
        gap = 6,
        children = items,
    } }
end

--- 技能自动分解 UI children
function M.buildSkillDecomposeChildren(ctx)
    local player = ctx.player
    local items = {}
    items[#items + 1] = UI.Label {
        text = "分解",
        fontSize = 22, fontWeight = "bold",
        color = {140, 140, 160, 255},
        flexShrink = 0,
    }
    for _, qId in ipairs(CFG.AUTO_DECOMPOSE_SKILL_QUALITIES) do
        local qi = nil
        for i, sq in ipairs(CFG.SKILL_QUALITIES) do
            if sq.id == qId then qi = i break end
        end
        local sq = CFG.SKILL_QUALITIES[qi]
        local qualityId = qId
        items[#items + 1] = UI.Checkbox {
            checked = player.autoDecompose.skill[qId] == true,
            label = sq.name,
            size = 24,
            onChange = function(self, checked)
                player.autoDecompose.skill[qualityId] = checked
                SaveSys.markDirty()
                if checked then
                    local msgs = SYS.autoDecomposeExisting(player, "skill", qualityId)
                    if ctx.onAutoDecomposeNow and #msgs > 0 then ctx.onAutoDecomposeNow(msgs) end
                end
            end,
        }
    end
    return { UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        alignItems = "center",
        gap = 6,
        children = items,
    } }
end

--- 宝石自动分解 UI children
function M.buildGemDecomposeChildren(ctx)
    local player = ctx.player
    local items = {}
    items[#items + 1] = UI.Label {
        text = "分解",
        fontSize = 22, fontWeight = "bold",
        color = {140, 140, 160, 255},
        flexShrink = 0,
    }
    for _, qId in ipairs(CFG.AUTO_DECOMPOSE_GEM_QUALITIES) do
        local qi = nil
        for i, gq in ipairs(CFG.GEM_QUALITIES) do
            if gq.id == qId then qi = i break end
        end
        local gq = CFG.GEM_QUALITIES[qi]
        local qualityId = qId
        items[#items + 1] = UI.Checkbox {
            checked = player.autoDecompose.gem[qId] == true,
            label = gq.name,
            size = 24,
            onChange = function(self, checked)
                player.autoDecompose.gem[qualityId] = checked
                SaveSys.markDirty()
                if checked then
                    local msgs = SYS.autoDecomposeExisting(player, "gem", qualityId)
                    if ctx.onAutoDecomposeNow and #msgs > 0 then ctx.onAutoDecomposeNow(msgs) end
                end
            end,
        }
    end
    return { UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        alignItems = "center",
        gap = 6,
        children = items,
    } }
end

-- 兼容: 设置面板中的聚合视图
local function buildDecomposeContent(ctx)
    local children = {}
    for _, c in ipairs(M.buildEquipDecomposeChildren(ctx)) do children[#children + 1] = c end
    for _, c in ipairs(M.buildSkillDecomposeChildren(ctx)) do children[#children + 1] = c end
    for _, c in ipairs(M.buildGemDecomposeChildren(ctx)) do children[#children + 1] = c end
    return children
end

-- 子面板: 每日任务
local function buildDailyTaskContent(ctx)
    local player = ctx.player
    local children = {}

    -- 确保每日任务已初始化
    SYS.initDailyTasks(player)
    local dt = player.dailyTasks

    -- 标题和重置提示
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingVertical = 4,
        children = {
            UI.Label {
                text = "🎫 精英门票: " .. (player.tickets or 0),
                fontSize = 24, fontWeight = "bold",
                color = {255, 180, 100, 255},
            },
            UI.Label {
                text = "每日6:00重置",
                fontSize = 20,
                color = {120, 120, 140, 255},
            },
        },
    }

    children[#children + 1] = divider()

    -- 统计已完成数
    local doneCount = 0
    for _, task in ipairs(CFG.DAILY_TASKS) do
        if dt.claimed[task.id] then doneCount = doneCount + 1 end
    end
    children[#children + 1] = UI.Label {
        text = "完成进度: " .. doneCount .. "/" .. #CFG.DAILY_TASKS,
        fontSize = 22, color = {180, 180, 200, 255},
        marginBottom = 6,
    }

    -- 每个任务卡片
    for _, task in ipairs(CFG.DAILY_TASKS) do
        local prog = dt.progress[task.id] or 0
        local claimed = dt.claimed[task.id] or false
        local completed = prog >= task.target
        local progText = prog >= task.target and tostring(task.target) or tostring(prog)

        -- 进度条比例
        local ratio = math.min(prog / task.target, 1.0)

        -- 卡片背景色
        local cardBg = claimed and {25, 45, 25, 240}
            or completed and {40, 35, 15, 240}
            or {30, 30, 45, 240}

        -- 按钮
        local btnText, btnVariant, btnDisabled
        if claimed then
            btnText = "已领取"
            btnVariant = "ghost"
            btnDisabled = true
        elseif completed then
            btnText = "领取"
            btnVariant = "primary"
            btnDisabled = false
        else
            btnText = progText .. "/" .. task.target
            btnVariant = "ghost"
            btnDisabled = true
        end

        local taskId = task.id
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 12,
            backgroundColor = cardBg,
            borderRadius = 10,
            borderLeft = 4,
            borderColor = claimed and {80, 200, 80, 255}
                or completed and {255, 200, 80, 255}
                or {60, 60, 80, 255},
            gap = 6,
            marginBottom = 4,
            children = {
                -- 第一行: 图标+名称+奖励
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    children = {
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = 8,
                            children = {
                                UI.Label { text = task.icon, fontSize = 28 },
                                UI.Panel {
                                    gap = 2,
                                    children = {
                                        UI.Label {
                                            text = task.name,
                                            fontSize = 24, fontWeight = "bold",
                                            color = claimed and {100, 200, 100, 255} or {220, 220, 240, 255},
                                        },
                                        UI.Label {
                                            text = task.desc .. " " .. task.target .. "次",
                                            fontSize = 18,
                                            color = {140, 140, 160, 255},
                                        },
                                    },
                                },
                            },
                        },
                        UI.Button {
                            text = btnText,
                            fontSize = 22,
                            width = 100, height = 40,
                            variant = btnVariant,
                            disabled = btnDisabled,
                            onClick = function()
                                if ctx.onClaimDailyTask then
                                    ctx.onClaimDailyTask(taskId)
                                end
                            end,
                        },
                    },
                },
                -- 第二行: 进度条
                UI.Panel {
                    width = "100%", height = 8,
                    backgroundColor = {20, 20, 30, 255},
                    borderRadius = 4,
                    overflow = "hidden",
                    children = {
                        UI.Panel {
                            width = string.format("%.1f%%", ratio * 100),
                            height = "100%",
                            backgroundColor = claimed and {80, 200, 80, 255}
                                or completed and {255, 200, 80, 255}
                                or {100, 140, 255, 255},
                            borderRadius = 4,
                        },
                    },
                },
                -- 第三行: 奖励信息
                UI.Label {
                    text = "奖励: 🎫 " .. task.reward .. " 精英门票",
                    fontSize = 18,
                    color = claimed and {80, 160, 80, 255} or {200, 180, 100, 255},
                },
            },
        }
    end

    -- 操作结果消息
    if ctx.cdkMsg then
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 12,
            backgroundColor = ctx.cdkMsgOk and {25, 45, 25, 255} or {50, 25, 25, 255},
            borderRadius = 10,
            borderLeft = 4,
            borderColor = ctx.cdkMsgOk and {80, 200, 80, 255} or {200, 80, 80, 255},
            children = {
                UI.Label {
                    text = (ctx.cdkMsgOk and "✅ " or "❌ ") .. ctx.cdkMsg,
                    fontSize = 24,
                    color = ctx.cdkMsgOk and {100, 255, 100, 255} or {255, 120, 100, 255},
                },
            },
        }
    end

    return children
end

-- ============================================================================
-- 重生内容
-- ============================================================================
local function buildRebirthContent(ctx)
    local children = {}

    children[#children + 1] = UI.Panel {
        width = "100%",
        padding = 16,
        backgroundColor = {50, 20, 20, 255},
        borderRadius = 10,
        borderLeft = 4,
        borderColor = {255, 60, 60, 255},
        gap = 10,
        children = {
            UI.Label {
                text = "⚠️ 重生警告",
                fontSize = 28, fontWeight = "bold",
                color = {255, 80, 80, 255},
            },
            UI.Label {
                text = "重生将清除所有数据，包括：",
                fontSize = 24, color = {255, 180, 180, 255},
            },
            UI.Label {
                text = "• 等级、经验、金币、钻石\n• 所有装备（已装备+背包）\n• 所有技能、宝石\n• 碎片、门票、保护卷\n• VIP等级、称号\n• 一切游戏进度",
                fontSize = 22, color = {220, 160, 160, 255},
            },
            UI.Label {
                text = "重生后将回到职业选择界面，从零开始。",
                fontSize = 24, fontWeight = "bold",
                color = {255, 200, 100, 255},
            },
        },
    }

    children[#children + 1] = divider()

    children[#children + 1] = UI.Label {
        text = "请在下方输入「确定重生」以确认：",
        fontSize = 24, color = {200, 200, 220, 255},
    }

    children[#children + 1] = UI.TextField {
        width = "100%", height = 56,
        placeholder = "请输入: 确定重生",
        fontSize = 28,
        value = rebirthInputText,
        onChange = function(self, text)
            rebirthInputText = text
            if ctx.onRefresh then ctx.onRefresh() end
        end,
    }

    local canRebirth = (rebirthInputText == "确定重生")
    children[#children + 1] = UI.Button {
        text = canRebirth and "💀 确认重生（不可撤销）" or "请输入「确定重生」后点击",
        fontSize = 26, width = "100%", height = 56,
        variant = "danger",
        disabled = not canRebirth,
        onClick = function()
            if canRebirth and ctx.onRebirth then
                rebirthInputText = ""
                ctx.onRebirth()
            end
        end,
    }

    -- 重生结果消息
    if ctx.rebirthMsg then
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 12,
            backgroundColor = {50, 25, 25, 255},
            borderRadius = 10,
            children = {
                UI.Label {
                    text = "❌ " .. ctx.rebirthMsg,
                    fontSize = 24, color = {255, 120, 100, 255},
                },
            },
        }
    end

    return children
end

-- 兑换码内容
local cdkInputText = ""
local function buildRedeemContent(ctx)
    local children = {}

    children[#children + 1] = UI.Panel {
        width = "100%",
        padding = 16,
        backgroundColor = {28, 35, 45, 255},
        borderRadius = 10,
        borderLeft = 4,
        borderColor = {100, 200, 255, 255},
        gap = 10,
        children = {
            UI.Label {
                text = "🎁 兑换码",
                fontSize = 28, fontWeight = "bold",
                color = {100, 200, 255, 255},
            },
            UI.Label {
                text = "输入兑换码领取奖励",
                fontSize = 22, color = {140, 140, 160, 255},
            },
            UI.Label {
                text = "💎 评价游戏后可领取500钻石",
                fontSize = 22, color = {255, 215, 100, 255},
            },
            UI.Label {
                text = "👑 输入 VIP1 可免费领取VIP1权限",
                fontSize = 22, color = {255, 180, 100, 255},
            },
            UI.Label {
                text = "📢 QQ群: 1087031624",
                fontSize = 22, color = {130, 200, 255, 255},
            },
        },
    }

    children[#children + 1] = UI.TextField {
        width = "100%", height = 56,
        placeholder = "请输入兑换码",
        fontSize = 28,
        value = cdkInputText,
        onChange = function(self, text)
            cdkInputText = text
        end,
    }

    children[#children + 1] = UI.Button {
        text = "兑换",
        fontSize = 26, width = "100%", height = 56,
        variant = "primary",
        onClick = function()
            if ctx.onRedeemCDK then
                ctx.onRedeemCDK(cdkInputText)
                cdkInputText = ""
            end
        end,
    }

    -- 兑换结果消息
    if ctx.cdkMsg then
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 12,
            backgroundColor = ctx.cdkMsgOk and {25, 45, 25, 255} or {50, 25, 25, 255},
            borderRadius = 10,
            borderLeft = 4,
            borderColor = ctx.cdkMsgOk and {80, 200, 80, 255} or {200, 80, 80, 255},
            children = {
                UI.Label {
                    text = (ctx.cdkMsgOk and "✅ " or "❌ ") .. ctx.cdkMsg,
                    fontSize = 24,
                    color = ctx.cdkMsgOk and {100, 255, 100, 255} or {255, 120, 100, 255},
                },
            },
        }
    end

    return children
end

function M.buildSettingsPanel(ctx)
    local settingsTab = ctx.settingsTab or "dailyTask"
    -- 兼容旧状态: decompose/redeem tab 已移除，自动切换到每日任务
    if settingsTab == "decompose" or settingsTab == "redeem" then settingsTab = "dailyTask" end

    local tabBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 0,
        children = {
            UI.Button {
                text = "📋 每日任务",
                fontSize = 24, height = 56,
                flex = 1,
                variant = settingsTab == "dailyTask" and "primary" or "ghost",
                borderRadius = 0,
                onClick = function()
                    if ctx.onSwitchSettingsTab then ctx.onSwitchSettingsTab("dailyTask") end
                end,
            },
            UI.Button {
                text = "🎁 兑换码",
                fontSize = 24, height = 56,
                flex = 1,
                variant = settingsTab == "cdkRedeem" and "primary" or "ghost",
                borderRadius = 0,
                onClick = function()
                    if ctx.onSwitchSettingsTab then ctx.onSwitchSettingsTab("cdkRedeem") end
                end,
            },
            UI.Button {
                text = "💀 重生",
                fontSize = 24, height = 56,
                flex = 1,
                variant = settingsTab == "rebirth" and "primary" or "ghost",
                borderRadius = 0,
                onClick = function()
                    if ctx.onSwitchSettingsTab then ctx.onSwitchSettingsTab("rebirth") end
                end,
            },
        },
    }

    local contentChildren
    if settingsTab == "rebirth" then
        contentChildren = buildRebirthContent(ctx)
    elseif settingsTab == "cdkRedeem" then
        contentChildren = buildRedeemContent(ctx)
    else
        contentChildren = buildDailyTaskContent(ctx)
    end

    -- 子标签切换栏: 兑换码 | 排行榜
    local viewTabBar = subTabBar(
        { {label = "🎁 兑换码", view = "settings"}, {label = "🏆 排行榜", view = "leaderboard"} },
        "settings", ctx
    )

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12, gap = 6,
        children = {
            viewTabBar,
            panelTitle("🎁", "兑换码"),
            tabBar,
            ctx.wrapScroll("settings", {
                width = "100%", flexGrow = 1, flexBasis = 0,
                gap = 6, children = contentChildren,
            }),
        },
    }
end

-- ============================================================================
-- 精英副本面板
-- ============================================================================

-- 区域图标映射
local ZONE_ICONS = {
    "🌿", "🌾", "🌲", "⛏️", "🏚️",
    "🐸", "🌋", "❄️", "💀", "🐉",
    "🏰", "🕳️", "👿", "🌀", "⚡",
    "🌑", "🩸", "☄️", "⭐", "👑",
}

function M.buildElitePanel(ctx)
    local player = ctx.player
    local children = {}

    children[#children + 1] = panelTitle("👹", "精英副本")

    -- 门票信息
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 12,
        paddingHorizontal = 8,
        children = {
            UI.Label { text = "🎫 门票: " .. player.tickets, fontSize = 26, color = {255, 200, 120, 255} },
        },
    }

    -- 自动挑战状态提示
    if ctx.autoElite then
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 10,
            backgroundColor = {60, 30, 30, 255},
            borderRadius = 8,
            borderLeft = 4,
            borderColor = {200, 80, 80, 255},
            flexDirection = "row",
            alignItems = "center",
            gap = 10,
            children = {
                UI.Label {
                    text = "🔄 自动挑战: " .. (CFG.ZONES[ctx.autoEliteZone] and CFG.ZONES[ctx.autoEliteZone].name or "未知"),
                    fontSize = 24, color = {255, 160, 80, 255}, flex = 1,
                },
                UI.Button {
                    text = "停止", fontSize = 22, height = 48, paddingHorizontal = 12,
                    variant = "danger",
                    onClick = function() if ctx.onToggleAutoElite then ctx.onToggleAutoElite(false) end end,
                },
            },
        }
    end

    children[#children + 1] = divider()

    -- 精英副本列表
    for i, zone in ipairs(CFG.ZONES) do
        local eliteReq = CFG.getEliteReqLevel(i)
        if eliteReq then
            local cost = CFG.getEliteTicketCost(i)
            local locked = player.level < eliteReq
            local isAutoTarget = (ctx.autoElite and ctx.autoEliteZone == i)
            local icon = ZONE_ICONS[i] or "👹"
            local zoneIdx = i

            local rowBg = isAutoTarget and {55, 35, 35, 255} or {28, 28, 40, 255}

            children[#children + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingVertical = 8,
                paddingHorizontal = 10,
                gap = 8,
                backgroundColor = rowBg,
                borderRadius = 8,
                borderLeft = isAutoTarget and 4 or 0,
                borderColor = isAutoTarget and {200, 80, 80, 255} or nil,
                opacity = locked and 0.35 or 1.0,
                children = {
                    UI.Label { text = icon, fontSize = 28, width = 28 },
                    UI.Panel {
                        flex = 1,
                        children = {
                            UI.Label {
                                text = zone.name .. (locked and " 🔒" or ""),
                                fontSize = 24,
                                color = locked and {80, 80, 100, 255} or {zone.color[1], zone.color[2], zone.color[3], 255},
                                fontWeight = isAutoTarget and "bold" or "normal",
                            },
                            UI.Label {
                                text = "Lv." .. eliteReq .. " | 🎫" .. cost,
                                fontSize = 20, color = {120, 120, 140, 255},
                            },
                        },
                    },
                    UI.Button {
                        text = "挑战", fontSize = 20,
                        paddingVertical = 4, paddingHorizontal = 8,
                        height = 48,
                        variant = "outline",
                        disabled = locked or (player.tickets < cost),
                        onClick = function() if ctx.onStartElite then ctx.onStartElite(zoneIdx, false) end end,
                    },
                    UI.Button {
                        text = isAutoTarget and "停止" or "自动",
                        fontSize = 20,
                        paddingVertical = 4, paddingHorizontal = 8,
                        height = 48,
                        variant = isAutoTarget and "danger" or "warning",
                        disabled = locked or (not isAutoTarget and player.tickets < cost),
                        onClick = function()
                            if isAutoTarget then
                                if ctx.onToggleAutoElite then ctx.onToggleAutoElite(false) end
                            else
                                if ctx.onStartElite then ctx.onStartElite(zoneIdx, true) end
                            end
                        end,
                    },
                },
            }
        end
    end

    -- ============ 地狱副本区域 ============
    children[#children + 1] = divider()
    children[#children + 1] = panelTitle("🔥", "地狱副本")

    -- 地狱门票信息
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 12,
        paddingHorizontal = 8,
        children = {
            UI.Label { text = "🔥 地狱门票: " .. (player.hellTickets or 0), fontSize = 26, color = {255, 100, 50, 255} },
            UI.Label { text = "(精英通关10%掉落)", fontSize = 20, color = {120, 120, 140, 255} },
        },
    }

    -- 自动地狱挑战状态
    if ctx.autoHell then
        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 10,
            backgroundColor = {60, 20, 10, 255},
            borderRadius = 8,
            borderLeft = 4,
            borderColor = {255, 80, 30, 255},
            flexDirection = "row",
            alignItems = "center",
            gap = 10,
            children = {
                UI.Label {
                    text = "🔥 自动地狱: " .. (CFG.ZONES[ctx.autoHellZone] and CFG.ZONES[ctx.autoHellZone].elite or "未知"),
                    fontSize = 24, color = {255, 100, 50, 255}, flex = 1,
                },
                UI.Button {
                    text = "停止", fontSize = 22, height = 48, paddingHorizontal = 12,
                    variant = "danger",
                    onClick = function() if ctx.onToggleAutoHell then ctx.onToggleAutoHell(false) end end,
                },
            },
        }
    end

    -- 地狱副本列表
    for i, zone in ipairs(CFG.ZONES) do
        local hellReq = CFG.getHellReqLevel(i)
        if hellReq then
            local cost = CFG.getHellTicketCost()
            local locked = player.level < hellReq
            local isAutoTarget = (ctx.autoHell and ctx.autoHellZone == i)
            local icon = ZONE_ICONS[i] or "🔥"
            local zoneIdx = i

            local rowBg = isAutoTarget and {60, 25, 15, 255} or {35, 20, 15, 255}

            children[#children + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingVertical = 8,
                paddingHorizontal = 10,
                gap = 8,
                backgroundColor = rowBg,
                borderRadius = 8,
                borderLeft = isAutoTarget and 4 or 0,
                borderColor = isAutoTarget and {255, 80, 30, 255} or nil,
                opacity = locked and 0.35 or 1.0,
                children = {
                    UI.Label { text = icon, fontSize = 28, width = 28 },
                    UI.Panel {
                        flex = 1,
                        children = {
                            UI.Label {
                                text = "🔥" .. zone.elite .. (locked and " 🔒" or ""),
                                fontSize = 24,
                                color = locked and {80, 80, 100, 255} or {255, math.max(50, zone.color[2] - 50), math.max(0, zone.color[3] - 80), 255},
                                fontWeight = isAutoTarget and "bold" or "normal",
                            },
                            UI.Label {
                                text = "Lv." .. hellReq .. " | 🔥" .. cost .. " | 爆率x3 属性x2",
                                fontSize = 20, color = {160, 100, 80, 255},
                            },
                        },
                    },
                    UI.Button {
                        text = "挑战", fontSize = 20,
                        paddingVertical = 4, paddingHorizontal = 8,
                        height = 48,
                        variant = "outline",
                        disabled = locked or ((player.hellTickets or 0) < cost),
                        onClick = function() if ctx.onStartHell then ctx.onStartHell(zoneIdx, false) end end,
                    },
                    UI.Button {
                        text = isAutoTarget and "停止" or "自动",
                        fontSize = 20,
                        paddingVertical = 4, paddingHorizontal = 8,
                        height = 48,
                        variant = isAutoTarget and "danger" or "warning",
                        disabled = locked or (not isAutoTarget and (player.hellTickets or 0) < cost),
                        onClick = function()
                            if isAutoTarget then
                                if ctx.onToggleAutoHell then ctx.onToggleAutoHell(false) end
                            else
                                if ctx.onStartHell then ctx.onStartHell(zoneIdx, true) end
                            end
                        end,
                    },
                },
            }
        end
    end

    -- 精英/地狱类型说明
    children[#children + 1] = divider()
    children[#children + 1] = UI.Panel {
        width = "100%",
        padding = 10,
        backgroundColor = {22, 22, 34, 255},
        borderRadius = 8,
        gap = 4,
        children = {
            UI.Label { text = "精英类型:", fontSize = 22, fontWeight = "bold", color = {140, 140, 160, 255} },
            UI.Label { text = "🟠 普通精英 - 掉落x2 | 暴击+高", fontSize = 20, color = {255, 152, 0, 255} },
            UI.Label { text = "⚪ 白银精英 - 掉落x3 | 暴击+极高", fontSize = 20, color = {192, 192, 192, 255} },
            UI.Label { text = "🟡 黄金精英 - 掉落x5 | 暴击+超高", fontSize = 20, color = {255, 215, 0, 255} },
            divider(),
            UI.Label { text = "🔥 地狱副本:", fontSize = 22, fontWeight = "bold", color = {255, 80, 30, 255} },
            UI.Label { text = "🔥 爆率=精英x3 | 怪物属性=精英x2", fontSize = 20, color = {255, 120, 60, 255} },
            UI.Label { text = "🔥 Lv55+地图开放 | 需地狱门票(精英10%掉)", fontSize = 20, color = {255, 120, 60, 255} },
            divider(),
            UI.Label { text = "⚠️ 精英每8秒释放技能(200%-1000%伤害)", fontSize = 20, color = {255, 100, 50, 255} },
            UI.Label { text = "⚠️ Lv30+副本难度大幅增加，需高品质装备", fontSize = 20, color = {255, 100, 50, 255} },
        },
    }

    return UI.Panel {
        width = "100%", height = "100%",
        padding = 12, gap = 6,
        children = {
            ctx.wrapScroll("elite", {
                width = "100%", flexGrow = 1, flexBasis = 0,
                gap = 6, children = children,
            }),
        },
    }
end

-- 精英面板内容（可嵌入其他面板，如战斗标签的子视图）
function M.buildElitePanelContent(ctx)
    -- 复用 buildElitePanel 的内容，但作为可嵌入组件返回
    local panel = M.buildElitePanel(ctx)
    return panel
end

return M
